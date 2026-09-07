#include "WVStratifiedQGFieldEvaluationAdapter.hpp"

#include "WaveVortexRuntime/WVIntegrationState.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstring>
#include <limits>
#include <map>
#include <new>
#include <set>
#include <stdexcept>
#include <utility>

namespace wavevortex::runtime::detail {
namespace {

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::size_t checkedProduct(std::size_t first, std::size_t second) {
  if (first != 0 && second > std::numeric_limits<std::size_t>::max() / first)
    throw std::overflow_error("Stratified QG field size overflow");
  return first * second;
}

double wrapped(double coordinate, double length) noexcept {
  double result = std::fmod(coordinate, length);
  if (result < 0.0)
    result += length;
  return result >= length ? 0.0 : result;
}

std::uint64_t configurationFingerprint(
    const WVStratifiedModalGeometry &configuration) noexcept {
  std::uint64_t result = 1469598103934665603ULL;
  const auto append = [&](const auto &value) {
    const auto *bytes = reinterpret_cast<const std::uint8_t *>(&value);
    for (std::size_t index = 0; index < sizeof(value); ++index) {
      result ^= bytes[index];
      result *= 1099511628211ULL;
    }
  };
  append(configuration.Nz);
  append(configuration.Nj);
  append(configuration.Nkl);
  append(configuration.Lz);
  for (double z:configuration.z) append(z);
  append(configuration.Nx);
  append(configuration.Ny);
  append(configuration.Lx);
  append(configuration.Ly);
  for (double j:configuration.j) append(j);
  append(configuration.g);
  append(configuration.planetaryRadius);
  append(configuration.rotationRate);
  append(configuration.latitude);
  append(configuration.shouldAntialias);
  return result;
}

class SplineSystem final {
public:
  explicit SplineSystem(std::size_t count) : count_(count) {
    if (count < 2)
      throw std::invalid_argument("Spline interpolation requires two points.");
    if (count < 4)
      return;
    lu_.assign(checkedProduct(count, count), 0.0);
    pivots_.resize(count);
    const auto set = [&](std::size_t row, std::size_t column, double value) {
      lu_[column + count * row] = value;
    };
    set(0, 0, -1.0);
    set(0, 1, 2.0);
    set(0, 2, -1.0);
    for (std::size_t row = 1; row + 1 < count; ++row) {
      set(row, row - 1, 1.0);
      set(row, row, 4.0);
      set(row, row + 1, 1.0);
    }
    set(count - 1, count - 3, -1.0);
    set(count - 1, count - 2, 2.0);
    set(count - 1, count - 1, -1.0);
    std::vector<double> transpose(checkedProduct(count, count));
    for (std::size_t row = 0; row < count; ++row)
      for (std::size_t column = 0; column < count; ++column)
        transpose[column + count * row] = lu_[row + count * column];
    lu_.swap(transpose);
    factor();
  }

  void weightsInto(double spacing, double query, std::size_t circularShift,
                   std::vector<double> &result,
                   std::vector<double> &shifted,
                   std::vector<double> &rhs) const {
    const double normalized = query / spacing;
    std::fill(shifted.begin(), shifted.end(), 0.0);
    std::fill(rhs.begin(), rhs.end(), 0.0);
    std::fill(result.begin(), result.end(), 0.0);
    if (count_ == 2) {
      shifted[0] = 1.0 - normalized;
      shifted[1] = normalized;
    } else if (count_ == 3) {
      shifted[0] =
          (normalized - 1.0) * (normalized - 2.0) / 2.0;
      shifted[1] = -normalized * (normalized - 2.0);
      shifted[2] = normalized * (normalized - 1.0) / 2.0;
    } else {
      std::size_t interval = normalized <= 0.0
                                 ? 0
                                 : static_cast<std::size_t>(
                                       std::floor(normalized));
      interval = std::min(interval, count_ - 2);
      const double fraction = std::clamp(
          normalized - static_cast<double>(interval), 0.0, 1.0);
      const double first = 1.0 - fraction;
      const double second = fraction;
      rhs[interval] =
          (first * first * first - first) * spacing * spacing / 6.0;
      rhs[interval + 1] =
          (second * second * second - second) * spacing * spacing / 6.0;
      solve(rhs);
      shifted[interval] += first;
      shifted[interval + 1] += second;
      const double scale = 6.0 / (spacing * spacing);
      for (std::size_t row = 1; row + 1 < count_; ++row) {
        shifted[row - 1] += scale * rhs[row];
        shifted[row] -= 2.0 * scale * rhs[row];
        shifted[row + 1] += scale * rhs[row];
      }
    }
    for (std::size_t shiftedIndex = 0; shiftedIndex < count_; ++shiftedIndex) {
      const auto original =
          (shiftedIndex + count_ - circularShift % count_) % count_;
      result[original] += shifted[shiftedIndex];
    }
  }

  std::vector<double> weights(double spacing, double query,
                              std::size_t circularShift) const {
    std::vector<double> result(count_, 0.0);
    std::vector<double> shifted(count_, 0.0);
    std::vector<double> rhs(count_, 0.0);
    weightsInto(spacing, query, circularShift, result, shifted, rhs);
    return result;
  }

  std::size_t persistentBytes() const noexcept {
    return sizeof(*this) + lu_.capacity() * sizeof(double) +
           pivots_.capacity() * sizeof(std::size_t);
  }

private:
  void factor() {
    for (std::size_t column = 0; column < count_; ++column) {
      std::size_t pivot = column;
      double maximum = std::abs(lu_[column + count_ * column]);
      for (std::size_t row = column + 1; row < count_; ++row) {
        const double value = std::abs(lu_[column + count_ * row]);
        if (value > maximum) {
          maximum = value;
          pivot = row;
        }
      }
      if (maximum == 0.0)
        throw std::invalid_argument("Spline interpolation matrix is singular.");
      pivots_[column] = pivot;
      if (pivot != column)
        for (std::size_t entry = 0; entry < count_; ++entry)
          std::swap(lu_[entry + count_ * column],
                    lu_[entry + count_ * pivot]);
      for (std::size_t row = column + 1; row < count_; ++row) {
        lu_[column + count_ * row] /= lu_[column + count_ * column];
        const double multiplier = lu_[column + count_ * row];
        for (std::size_t entry = column + 1; entry < count_; ++entry)
          lu_[entry + count_ * row] -=
              multiplier * lu_[entry + count_ * column];
      }
    }
  }

  void solve(std::vector<double> &rhs) const {
    for (std::size_t column = 0; column < count_; ++column) {
      if (pivots_[column] != column)
        std::swap(rhs[column], rhs[pivots_[column]]);
      for (std::size_t row = column + 1; row < count_; ++row)
        rhs[row] -= lu_[column + count_ * row] * rhs[column];
    }
    for (std::size_t reverse = 0; reverse < count_; ++reverse) {
      const auto row = count_ - 1 - reverse;
      for (std::size_t column = row + 1; column < count_; ++column)
        rhs[row] -= lu_[column + count_ * row] * rhs[column];
      rhs[row] /= lu_[row + count_ * row];
    }
  }

  std::size_t count_ = 0;
  std::vector<double> lu_;
  std::vector<std::size_t> pivots_;
};

class VerticalSpline final {
public:
  explicit VerticalSpline(const std::vector<double>& z):z_(z),second_(z.size()*z.size(),0) {
    const auto n=z_.size(); if(n<4) return;
    std::vector<double> matrix(n*n,0);
    auto set=[&](std::size_t r,std::size_t c,double v){matrix[r*n+c]=v;};
    auto h=[&](std::size_t i){return z_[i+1]-z_[i];};
    set(0,0,-h(1)); set(0,1,h(0)+h(1)); set(0,2,-h(0));
    for(std::size_t r=1;r+1<n;++r) {
      set(r,r-1,h(r-1)); set(r,r,2*(h(r-1)+h(r))); set(r,r+1,h(r));
      second_[r*n+r-1]=6/h(r-1); second_[r*n+r]=-6*(1/h(r-1)+1/h(r)); second_[r*n+r+1]=6/h(r);
    }
    set(n-1,n-3,-h(n-2)); set(n-1,n-2,h(n-3)+h(n-2)); set(n-1,n-1,-h(n-3));
    for(std::size_t col=0;col<n;++col) {
      std::size_t pivot=col;
      for(std::size_t r=col+1;r<n;++r) if(std::abs(matrix[r*n+col])>std::abs(matrix[pivot*n+col])) pivot=r;
      if(matrix[pivot*n+col]==0) throw std::invalid_argument("Singular vertical interpolation grid.");
      for(std::size_t c=0;c<n;++c) {std::swap(matrix[col*n+c],matrix[pivot*n+c]);std::swap(second_[col*n+c],second_[pivot*n+c]);}
      const double diagonal=matrix[col*n+col];
      for(std::size_t c=0;c<n;++c) {matrix[col*n+c]/=diagonal;second_[col*n+c]/=diagonal;}
      for(std::size_t r=0;r<n;++r) if(r!=col) {
        const double factor=matrix[r*n+col];
        for(std::size_t c=0;c<n;++c) {matrix[r*n+c]-=factor*matrix[col*n+c];second_[r*n+c]-=factor*second_[col*n+c];}
      }
    }
  }
  void weightsInto(double z,std::vector<double>& weights) const {
    const auto n=z_.size(); std::fill(weights.begin(),weights.end(),0);
    if(z<z_.front() || z>z_.back()) return;
    if(n<4) {
      for(std::size_t i=0;i<n;++i) {weights[i]=1;for(std::size_t j=0;j<n;++j) if(i!=j) weights[i]*=(z-z_[j])/(z_[i]-z_[j]);}
      return;
    }
    const auto i=std::min(static_cast<std::size_t>(std::upper_bound(z_.begin(),z_.end(),z)-z_.begin()-1),n-2);
    const double h=z_[i+1]-z_[i],b=(z-z_[i])/h,a=1-b;
    for(std::size_t j=0;j<n;++j) weights[j]=(h*h/6)*((a*a*a-a)*second_[i*n+j]+(b*b*b-b)*second_[(i+1)*n+j]);
    weights[i]+=a; weights[i+1]+=b;
  }
  std::size_t persistentBytes() const noexcept {return sizeof(*this)+(z_.capacity()+second_.capacity())*sizeof(double);}
private:
  std::vector<double> z_,second_;
};

bool surface(WVStratifiedQGField field) {return field==WVStratifiedQGField::ssh || field==WVStratifiedQGField::ssu || field==WVStratifiedQGField::ssv;}

enum class ScalarField : std::uint8_t { none, energy, uvMax, wMax };

struct Weight {
  std::array<std::size_t, 2> xIndices{};
  std::array<std::size_t, 2> yIndices{};
  std::array<double, 2> xWeights{};
  std::array<double, 2> yWeights{};
  std::vector<double> xSpline;
  std::vector<double> ySpline;
  std::vector<double> zSpline;
  std::array<std::size_t,2> zIndices{};
  std::array<double,2> zWeights{1,0};
  bool outside = false;
};

struct Request {
  WVStratifiedQGField field = WVStratifiedQGField::u;
  ScalarField scalar = ScalarField::none;
  WVFieldSamplingKind sampling = WVFieldSamplingKind::fullGrid;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
  std::vector<Weight> weights;
  std::vector<std::size_t> profileIndices;
  std::size_t output = 0;
};

struct Plan {
  std::uint64_t fingerprint = 0;
  std::vector<Request> requests;
  std::size_t persistentBytes() const noexcept {
    std::size_t bytes = sizeof(*this) + requests.capacity() * sizeof(Request);
    for (const auto &request : requests) {
      bytes += request.weights.capacity() * sizeof(Weight)+request.profileIndices.capacity()*sizeof(std::size_t);
      for (const auto &weight : request.weights)
        bytes += (weight.xSpline.capacity() + weight.ySpline.capacity() + weight.zSpline.capacity()) *
                 sizeof(double);
    }
    return bytes;
  }
};

struct MovingRequest {
  WVStratifiedQGField field = WVStratifiedQGField::u;
  std::size_t offset = 0;
  std::size_t count = 0;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
  std::size_t output = 0;
};

struct MovingPlan {
  std::uint64_t fingerprint = 0;
  std::vector<MovingRequest> requests;
  std::size_t positionCount = 0;
  std::size_t persistentBytes() const noexcept {
    return sizeof(*this) + requests.capacity() * sizeof(MovingRequest);
  }
};

struct EventRequest {
  WVStratifiedQGField field = WVStratifiedQGField::u;
  std::size_t positionSet = 0;
  WVPositionInterpolation interpolation = WVPositionInterpolation::linear;
  std::size_t output = 0;
};

struct EventPlan {
  std::uint64_t fingerprint = 0;
  std::vector<EventRequest> requests;
  std::size_t positionSetCount = 0;
  std::size_t persistentBytes() const noexcept {
    return sizeof(*this) + requests.capacity() * sizeof(EventRequest);
  }
};

struct EventGeometry {
  std::shared_ptr<const EventPlan> eventPlan;
  std::shared_ptr<const Plan> plan;
  std::size_t persistentBytes() const noexcept {
    return sizeof(*this) + (plan ? plan->persistentBytes() : 0);
  }
};

WVKernelStatus resolveField(const std::string &name,
                            WVStratifiedQGField &field,
                            ScalarField &scalar) {
  scalar = ScalarField::none;
  if (name == "u")
    field = WVStratifiedQGField::u;
  else if (name == "v")
    field = WVStratifiedQGField::v;
  else if (name == "p") field = WVStratifiedQGField::p;
  else if (name == "rho_e") field = WVStratifiedQGField::rhoE;
  else if (name == "rho_total") field = WVStratifiedQGField::rhoTotal;
  else if (name == "ssu") field = WVStratifiedQGField::ssu;
  else if (name == "ssv") field = WVStratifiedQGField::ssv;
  else if (name == "eta")
    field = WVStratifiedQGField::eta;
  else if (name == "pi")
    field = WVStratifiedQGField::pi;
  else if (name == "psi")
    field = WVStratifiedQGField::psi;
  else if (name == "qgpv")
    field = WVStratifiedQGField::qgpv;
  else if (name == "zeta_z")
    field = WVStratifiedQGField::zetaZ;
  else if (name == "ssh")
    field = WVStratifiedQGField::ssh;
  else if (name == "energy")
    scalar = ScalarField::energy;
  else if (name == "uvMax")
    scalar = ScalarField::uvMax;
  else
    return {WVKernelStatusCode::unsupportedOperation,
            "WVTransformStratifiedQG does not support field " + name + "."};
  return WVKernelStatus::ok();
}

Weight weightsFor(double x, double y, double z, bool horizontal, WVPositionInterpolation interpolation,
                  const WVStratifiedModalGeometry &configuration,
                  const SplineSystem *xSpline,
                  const SplineSystem *ySpline, const VerticalSpline *zSpline) {
  const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
  const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
  const double xWrapped = wrapped(x, configuration.Lx);
  const double yWrapped = wrapped(y, configuration.Ly);
  const auto xLower = std::min(
      static_cast<std::size_t>(std::floor(xWrapped / dx)),
      configuration.Nx - 1);
  const auto yLower = std::min(
      static_cast<std::size_t>(std::floor(yWrapped / dy)),
      configuration.Ny - 1);
  Weight result;
  if (interpolation == WVPositionInterpolation::linear) {
    result.xIndices = {xLower, (xLower + 1) % configuration.Nx};
    result.yIndices = {yLower, (yLower + 1) % configuration.Ny};
    const double xFraction =
        (xWrapped - static_cast<double>(xLower) * dx) / dx;
    const double yFraction =
        (yWrapped - static_cast<double>(yLower) * dy) / dy;
    result.xWeights = {1.0 - xFraction, xFraction};
    result.yWeights = {1.0 - yFraction, yFraction};
  } else {
    const bool xBoundary = configuration.Nx < 4 || xLower < 3 ||
                           xLower > configuration.Nx - 4;
    const bool yBoundary = configuration.Ny < 4 || yLower < 3 ||
                           yLower > configuration.Ny - 4;
    const std::size_t xShift = xBoundary ? 4 : 0;
    const std::size_t yShift = yBoundary ? 4 : 0;
    const double xQuery = xBoundary
                              ? wrapped(x + 4.0 * dx, configuration.Lx)
                              : xWrapped;
    const double yQuery = yBoundary
                              ? wrapped(y + 4.0 * dy, configuration.Ly)
                              : yWrapped;
    result.xSpline = xSpline->weights(dx, xQuery, xShift);
    result.ySpline = ySpline->weights(dy, yQuery, yShift);
  }
  if (!horizontal) {
    result.outside=z<configuration.z.front() || z>configuration.z.back();
    if (!result.outside) {
      auto iz=std::min(static_cast<std::size_t>(std::upper_bound(configuration.z.begin(),configuration.z.end(),z)-configuration.z.begin()-1),configuration.Nz-2);
      const double fraction=(z-configuration.z[iz])/(configuration.z[iz+1]-configuration.z[iz]);
      result.zIndices={iz,iz+1}; result.zWeights={1-fraction,fraction};
      if(interpolation==WVPositionInterpolation::spline) {result.zSpline.resize(configuration.Nz);zSpline->weightsInto(z,result.zSpline);}
    }
  } else if(interpolation==WVPositionInterpolation::spline) result.zSpline={1};
  return result;
}

double interpolate(const double *field,const Weight& weight,WVPositionInterpolation interpolation,std::size_t Nx,std::size_t Ny,std::size_t Nz) noexcept {
  if(weight.outside) return 0;
  double value=0;
  if(interpolation==WVPositionInterpolation::linear) {
    for(std::size_t z=0;z<(Nz==1?1:2);++z) for(std::size_t y=0;y<2;++y) for(std::size_t x=0;x<2;++x)
      value+=weight.xWeights[x]*weight.yWeights[y]*weight.zWeights[z]*field[weight.xIndices[x]+Nx*(weight.yIndices[y]+Ny*weight.zIndices[z])];
  } else {
    for(std::size_t z=0;z<Nz;++z) for(std::size_t y=0;y<Ny;++y) for(std::size_t x=0;x<Nx;++x)
      value+=weight.xSpline[x]*weight.ySpline[y]*weight.zSpline[z]*field[x+Nx*(y+Ny*z)];
  }
  return value;
}

WVKernelStatus coefficientView(const WVIntegrationState &state,
                               const WVTransformStratifiedQGKernel &kernel,
                               WVComplexConstView &A0) {
  if (state.coefficientFamilyCount != 1 ||
      state.coefficientFamilies == nullptr ||
      state.coefficientFamilies[0].layout == nullptr ||
      state.coefficientFamilies[0].layout->identifier != "A0" ||
      state.coefficientFamilies[0].layout->elementCount !=
          kernel.geometry().Nj*kernel.geometry().Nkl ||
      state.coefficientFamilies[0].data == nullptr)
    return {WVKernelStatusCode::invalidShape,
            "Stratified QG field evaluation requires compact A0 state."};
  A0 = {state.coefficientFamilies[0].data,
        kernel.spectralShape()};
  return WVKernelStatus::ok();
}

} // namespace

struct WVStratifiedQGFieldEvaluationAdapter::MovingInterpolationWorkspace {
  MovingInterpolationWorkspace(std::size_t Nx, std::size_t Ny,const std::vector<double>& z)
      : xSpline(Nx), ySpline(Ny), zSpline(z), xWeights(Nx), yWeights(Ny), zWeights(z.size()),
        xShifted(Nx), yShifted(Ny), xRhs(Nx), yRhs(Ny) {}

  std::size_t persistentBytes() const noexcept {
    return sizeof(*this) +
           xSpline.persistentBytes() + ySpline.persistentBytes() + zSpline.persistentBytes() +
           (xWeights.capacity() + yWeights.capacity() + zWeights.capacity() +
            xShifted.capacity() + yShifted.capacity() + xRhs.capacity() +
            yRhs.capacity()) *
               sizeof(double);
  }

  std::size_t scratchBytes() const noexcept {
    return (xWeights.capacity() + yWeights.capacity() + zWeights.capacity() +
            xShifted.capacity() + yShifted.capacity() + xRhs.capacity() +
            yRhs.capacity()) *
           sizeof(double);
  }

  SplineSystem xSpline;
  SplineSystem ySpline;
  VerticalSpline zSpline;
  std::vector<double> xWeights;
  std::vector<double> yWeights;
  std::vector<double> zWeights;
  std::vector<double> xShifted;
  std::vector<double> yShifted;
  std::vector<double> xRhs;
  std::vector<double> yRhs;
};

WVStratifiedQGFieldEvaluationAdapter::~WVStratifiedQGFieldEvaluationAdapter() =
    default;

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::create(
    std::shared_ptr<const WVStratifiedModalSource> source,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVStratifiedQGFieldEvaluationAdapter> &adapter) {
  adapter.reset();
  try {
    auto candidate = std::unique_ptr<WVStratifiedQGFieldEvaluationAdapter>(
        new WVStratifiedQGFieldEvaluationAdapter());
    auto status = WVTransformStratifiedQGKernel::create(
        source, std::move(engine), candidate->ownedKernel_);
    if (!status)
      return status;
    candidate->kernel_ = candidate->ownedKernel_.get();
    candidate->fieldScratch_.resize(
        candidate->kernel_->spatialShape().elementCount());
    candidate->movingInterpolation_ =
        std::make_unique<MovingInterpolationWorkspace>(
            source->geometry().Nx, source->geometry().Ny, source->geometry().z);
    candidate->metrics_.transformPersistentBytes =
        candidate->kernel_->persistentBytes();
    candidate->metrics_.scratchCapacityBytes =
        candidate->fieldScratch_.capacity() * sizeof(double) +
        candidate->movingInterpolation_->scratchBytes();
    candidate->metrics_.servicePersistentBytes = candidate->persistentBytes();
    adapter = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate Stratified QG field service."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::createBorrowing(
    WVTransformStratifiedQGKernel &kernel,
    std::unique_ptr<WVStratifiedQGFieldEvaluationAdapter> &adapter) {
  adapter.reset();
  try {
    auto candidate = std::unique_ptr<WVStratifiedQGFieldEvaluationAdapter>(
        new WVStratifiedQGFieldEvaluationAdapter());
    candidate->kernel_ = &kernel;
    candidate->fieldScratch_.resize(
        kernel.spatialShape().elementCount());
    candidate->movingInterpolation_ =
        std::make_unique<MovingInterpolationWorkspace>(
            kernel.geometry().Nx, kernel.geometry().Ny, kernel.geometry().z);
    candidate->metrics_.transformPersistentBytes = kernel.persistentBytes();
    candidate->metrics_.scratchCapacityBytes =
        candidate->fieldScratch_.capacity() * sizeof(double) +
        candidate->movingInterpolation_->scratchBytes();
    candidate->metrics_.servicePersistentBytes = candidate->persistentBytes();
    adapter = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate borrowed Stratified QG field service."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::createPlan(
    const std::vector<WVFieldRequest> &requests,
    WVFieldEvaluationPlan &plan) const {
  try {
    auto implementation = std::make_shared<Plan>();
    implementation->fingerprint = configurationFingerprint(configuration());
    implementation->requests.reserve(requests.size());
    WVFieldEvaluationPlan candidate;
    candidate.outputs_.reserve(requests.size());
    std::set<std::string> identifiers;
    const bool needsSpline = std::any_of(
        requests.begin(), requests.end(), [](const auto &request) {
          return request.sampling.kind == WVFieldSamplingKind::positions &&
                 request.sampling.interpolation ==
                     WVPositionInterpolation::spline;
        });
    std::unique_ptr<SplineSystem> xSpline;
    std::unique_ptr<SplineSystem> ySpline;
    std::unique_ptr<VerticalSpline> zSpline;
    if (needsSpline) {
      xSpline = std::make_unique<SplineSystem>(configuration().Nx);
      ySpline = std::make_unique<SplineSystem>(configuration().Ny);
      zSpline = std::make_unique<VerticalSpline>(configuration().z);
    }
    for (std::size_t index = 0; index < requests.size(); ++index) {
      const auto &input = requests[index];
      if (input.identifier.empty() || !identifiers.insert(input.identifier).second)
        return invalid("Stratified QG field identifiers must be nonempty and unique.");
      Request request;
      auto status = resolveField(input.fieldName, request.field, request.scalar);
      if (!status)
        return status;
      request.sampling = input.sampling.kind;
      request.interpolation = input.sampling.interpolation;
      request.output = index;
      WVFieldOutputSpecification output{
          input.identifier, input.fieldName, input.sampling.kind, {}, 0};
      if (request.scalar != ScalarField::none) {
        if (input.sampling.kind != WVFieldSamplingKind::fullGrid)
          return invalid("Scalar Stratified QG fields do not support position sampling.");
        output.elementCount = 1;
      } else if (input.sampling.kind == WVFieldSamplingKind::fullGrid) {
        output.dimensions = {configuration().Nx, configuration().Ny};
        output.elementCount = checkedProduct(configuration().Nx,configuration().Ny);
        if (!surface(request.field)) {output.dimensions.push_back(configuration().Nz);output.elementCount=checkedProduct(output.elementCount,configuration().Nz);}
      } else if (input.sampling.kind == WVFieldSamplingKind::positions) {
        if (input.sampling.x.empty() ||
            input.sampling.x.size() != input.sampling.y.size() || (!surface(request.field) && input.sampling.z.size()!=input.sampling.x.size()))
          return invalid("Stratified QG position arrays must be equal and nonempty.");
        if (input.sampling.interpolation != WVPositionInterpolation::linear &&
            input.sampling.interpolation != WVPositionInterpolation::spline)
          return invalid("Stratified QG interpolation method is unsupported.");
        request.weights.reserve(input.sampling.x.size());
        for (std::size_t position = 0; position < input.sampling.x.size();
             ++position) {
          if (!std::isfinite(input.sampling.x[position]) ||
              !std::isfinite(input.sampling.y[position]) || (!surface(request.field) && !std::isfinite(input.sampling.z[position])))
            return invalid("Stratified QG positions must be finite.");
          request.weights.push_back(weightsFor(
              input.sampling.x[position], input.sampling.y[position],surface(request.field)?0:input.sampling.z[position],surface(request.field),
              input.sampling.interpolation, configuration(), xSpline.get(),ySpline.get(),zSpline.get()));
        }
        output.dimensions = {input.sampling.x.size()};
        output.elementCount = input.sampling.x.size();
      } else if(input.sampling.kind==WVFieldSamplingKind::fixedVerticalProfiles && !surface(request.field)) {
        if(input.sampling.xIndices.empty() || input.sampling.xIndices.size()!=input.sampling.yIndices.size()) return invalid("Profile grid indices must be paired and nonempty.");
        for(std::size_t i=0;i<input.sampling.xIndices.size();++i) {
          const auto x=input.sampling.xIndices[i],y=input.sampling.yIndices[i];
          if(!x || x>configuration().Nx || !y || y>configuration().Ny) return invalid("Profile index outside the grid.");
          request.profileIndices.push_back(x-1+configuration().Nx*(y-1));
        }
        output.dimensions={configuration().Nz,request.profileIndices.size()};output.elementCount=checkedProduct(configuration().Nz,request.profileIndices.size());
      } else return invalid("Unsupported SQG sampling request.");
      implementation->requests.push_back(std::move(request));
      candidate.outputs_.push_back(std::move(output));
    }
    candidate.transformPlan_ = implementation;
    candidate.transformPlanBytes_ = implementation->persistentBytes();
    plan = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::overflow_error &error) {
    return {WVKernelStatusCode::sizeOverflow, error.what()};
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate a Stratified QG field plan."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::evaluate(
    const WVFieldEvaluationPlan &publicPlan,
    const WVIntegrationState &state, WVFieldOutputView *outputs,
    std::size_t outputCount) {
  const auto plan =
      std::static_pointer_cast<const Plan>(publicPlan.transformPlan_);
  if (!plan || plan->fingerprint != configurationFingerprint(configuration()))
    return invalid("Stratified QG field plan belongs to another transform.");
  if (outputCount != publicPlan.outputs_.size() ||
      (outputCount != 0 && outputs == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Stratified QG outputs do not match the resolved plan."};
  for (std::size_t output = 0; output < outputCount; ++output)
    if (outputs[output].data == nullptr ||
        outputs[output].elementCount !=
            publicPlan.outputs_[output].elementCount)
      return {WVKernelStatusCode::invalidShape,
              "A Stratified QG output has the wrong shape."};
  WVComplexConstView A0;
  auto status = coefficientView(state, *kernel_, A0);
  if (!status)
    return status;
  if (executing_)
    return {WVKernelStatusCode::reentrantExecution,
            "Stratified QG field evaluation is not reentrant."};
  executing_ = true;
  struct Guard {
    bool &executing;
    ~Guard() { executing = false; }
  } guard{executing_};

  std::array<bool, 14> evaluated{};
  const auto spatial = kernel_->spatialShape();
  for (const auto &request : plan->requests) {
    if (request.scalar != ScalarField::none) {
      double value = 0.0;
      status = request.scalar == ScalarField::energy
                   ? kernel_->totalEnergy(A0, value)
                   : request.scalar==ScalarField::wMax ? WVKernelStatus::ok() : kernel_->uvMax(A0, value);
      if (!status)
        return status;
      outputs[request.output].data[0] = value;
      ++metrics_.outputElementWriteCount;
      continue;
    }
    const auto fieldIndex = static_cast<std::size_t>(request.field);
    if (!evaluated[fieldIndex]) {
      WVRealVolumeView view{fieldScratch_.data(),{spatial.first,spatial.second,surface(request.field)?1:spatial.third}};
      status = kernel_->transformA0ToField(A0, request.field, view);
      if (!status)
        return status;

      ++metrics_.transformCount;
      ++metrics_.primitiveFieldEvaluationCount;
      evaluated[fieldIndex] = true;
      for (const auto &destination : plan->requests) {
        if (destination.scalar != ScalarField::none ||
            destination.field != request.field)
          continue;
        auto &output = outputs[destination.output];
        if (destination.sampling == WVFieldSamplingKind::fullGrid) {
          std::copy_n(fieldScratch_.data(),output.elementCount,output.data);
          ++metrics_.fullGridWriteCount;
        } else if(destination.sampling==WVFieldSamplingKind::fixedVerticalProfiles) {
          const auto plane=configuration().Nx*configuration().Ny;
          for(std::size_t p=0;p<destination.profileIndices.size();++p) for(std::size_t z=0;z<configuration().Nz;++z)
            output.data[z+configuration().Nz*p]=fieldScratch_[destination.profileIndices[p]+plane*z];
        } else {
          for (std::size_t position = 0;
               position < destination.weights.size(); ++position)
            output.data[position] = interpolate(
                fieldScratch_.data(), destination.weights[position],
                destination.interpolation, configuration().Nx,
                configuration().Ny,surface(destination.field)?1:configuration().Nz);
          if (destination.interpolation == WVPositionInterpolation::linear)
            metrics_.linearInterpolationCount += destination.weights.size();
          else
            metrics_.splineInterpolationCount += destination.weights.size();
        }
        metrics_.outputElementWriteCount += output.elementCount;
        if (&destination != &request)
          ++metrics_.primitiveFieldReuseCount;
      }
    }
  }
  ++metrics_.evaluationCount;
  metrics_.scratchHighWaterBytes = std::max(
      metrics_.scratchHighWaterBytes,
      fieldScratch_.size() * sizeof(double));
  metrics_.servicePersistentBytes = persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::createMovingPlan(
    const std::vector<WVMovingFieldRequest> &requests,
    WVMovingFieldEvaluationPlan &plan) const {
  try {
    auto implementation = std::make_shared<MovingPlan>();
    implementation->fingerprint = configurationFingerprint(configuration());
    WVMovingFieldEvaluationPlan candidate;
    std::set<std::string> identifiers;
    for (std::size_t index = 0; index < requests.size(); ++index) {
      const auto &input = requests[index];
      WVStratifiedQGField field;
      ScalarField scalar;
      auto status = resolveField(input.fieldName, field, scalar);
      if (!status || scalar != ScalarField::none)
        return status ? invalid("A scalar field cannot be sampled at moving positions.") : status;
      if (input.identifier.empty() || !identifiers.insert(input.identifier).second ||
          input.positionCount == 0 ||
          (input.interpolation != WVPositionInterpolation::linear &&
           input.interpolation != WVPositionInterpolation::spline) ||
          input.positionOffset > std::numeric_limits<std::size_t>::max() -
                                     input.positionCount)
        return invalid("Stratified QG moving-field request is invalid.");
      implementation->positionCount =
          std::max(implementation->positionCount,
                   input.positionOffset + input.positionCount);
      implementation->requests.push_back(
          {field, input.positionOffset, input.positionCount,
           input.interpolation, index});
      candidate.outputs_.push_back(
          {input.identifier, input.fieldName, WVFieldSamplingKind::positions,
           {input.positionCount}, input.positionCount});
    }
    candidate.positionCount_ = implementation->positionCount;
    candidate.transformPlan_ = implementation;
    candidate.transformPlanBytes_ = implementation->persistentBytes();
    plan = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate a Stratified QG moving-field plan."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::evaluateMoving(
    const WVMovingFieldEvaluationPlan &publicPlan,
    const WVIntegrationState &state, WVMovingPositionView positions,
    WVFieldOutputView *outputs, std::size_t outputCount) {
  return evaluateMovingImpl(publicPlan, state, nullptr, positions, outputs,
                            outputCount);
}

WVKernelStatus
WVStratifiedQGFieldEvaluationAdapter::evaluateMovingFromAdvectionFields(
    const WVMovingFieldEvaluationPlan &publicPlan,
    const WVIntegrationState &state,
    const WVRealFieldBundleConstView &advectionFields,
    WVMovingPositionView positions, WVFieldOutputView *outputs,
    std::size_t outputCount) {
  return evaluateMovingImpl(publicPlan, state, &advectionFields, positions,
                            outputs, outputCount);
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::evaluateMovingImpl(
    const WVMovingFieldEvaluationPlan &publicPlan,
    const WVIntegrationState &state,
    const WVRealFieldBundleConstView *advectionFields,
    WVMovingPositionView positions, WVFieldOutputView *outputs,
    std::size_t outputCount) {
  const auto plan =
      std::static_pointer_cast<const MovingPlan>(publicPlan.transformPlan_);
  if (!plan || plan->fingerprint != configurationFingerprint(configuration()))
    return invalid("Stratified QG moving plan belongs to another transform.");
  if (positions.positionCount != plan->positionCount ||
      (positions.positionCount != 0 &&
       (positions.x == nullptr || positions.y == nullptr)) ||
      outputCount != publicPlan.outputs_.size() ||
      (outputCount != 0 && outputs == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Stratified QG moving positions or outputs have the wrong shape."};
  for (std::size_t output = 0; output < outputCount; ++output)
    if (outputs[output].data == nullptr ||
        outputs[output].elementCount !=
            publicPlan.outputs_[output].elementCount)
      return {WVKernelStatusCode::invalidShape,
              "A Stratified QG moving-field output has the wrong shape."};
  for (std::size_t position = 0; position < positions.positionCount;
       ++position)
    if (!std::isfinite(positions.x[position]) ||
        !std::isfinite(positions.y[position]))
      return invalid("Stratified QG moving positions must be finite.");
  WVComplexConstView A0;
  auto status = coefficientView(state, *kernel_, A0);
  if (!status)
    return status;
  const auto& g=configuration();
  if(executing_) return {WVKernelStatusCode::reentrantExecution,"SQG field workspace is active."};
  executing_=true; struct Guard {bool& value;~Guard(){value=false;}} guard{executing_};
  const auto R=g.Nx*g.Ny*g.Nz; auto& workspace=*movingInterpolation_;
  if(advectionFields && (advectionFields->data==nullptr || advectionFields->shape.first!=g.Nx || advectionFields->shape.second!=g.Ny || advectionFields->shape.third!=g.Nz || advectionFields->shape.fourth!=3)) return invalid("SQG advection fields require [Nx,Ny,Nz,3].");
  for(const auto& request:plan->requests) if(!surface(request.field) && !positions.z) return invalid("SQG volume samples require z coordinates.");
  std::array<bool,14> evaluated{};
  for(const auto& request:plan->requests) {
    const auto fieldIndex=static_cast<std::size_t>(request.field);if(evaluated[fieldIndex]) continue;
    const double* values=fieldScratch_.data();
    if(advectionFields && (request.field==WVStratifiedQGField::u || request.field==WVStratifiedQGField::v || request.field==WVStratifiedQGField::w)) {
      values=advectionFields->data+static_cast<std::size_t>(request.field)*R; ++metrics_.primitiveFieldReuseCount;
    } else {
      status=kernel_->transformA0ToField(A0,request.field,{fieldScratch_.data(),{g.Nx,g.Ny,surface(request.field)?1:g.Nz}});if(!status) return status;
      ++metrics_.transformCount; ++metrics_.movingPrimitiveTransformCount;
    }
    evaluated[fieldIndex]=true;
    for(const auto& destination:plan->requests) if(destination.field==request.field) {
      for(std::size_t p=0;p<destination.count;++p) {
        const auto index=p+destination.offset; const double x=positions.x[index],y=positions.y[index];
        const bool horizontal=surface(request.field); const double z=horizontal?g.z.front():positions.z[index];
        if(!std::isfinite(z)) return invalid("SQG positions must be finite.");
        double value=0;
        if(z>=g.z.front() && z<=g.z.back()) {
          const double dx=g.Lx/g.Nx,dy=g.Ly/g.Ny,xx=wrapped(x,g.Lx),yy=wrapped(y,g.Ly);
          const auto ix=std::min(static_cast<std::size_t>(xx/dx),g.Nx-1),iy=std::min(static_cast<std::size_t>(yy/dy),g.Ny-1);
          const auto iz=horizontal?0:std::min(static_cast<std::size_t>(std::upper_bound(g.z.begin(),g.z.end(),z)-g.z.begin()-1),g.Nz-2);
          if(destination.interpolation==WVPositionInterpolation::linear) {
            const double fx=xx/dx-ix,fy=yy/dy-iy,fz=horizontal?0:(z-g.z[iz])/(g.z[iz+1]-g.z[iz]);
            for(std::size_t k=0;k<(horizontal?1:2);++k) for(std::size_t j=0;j<2;++j) for(std::size_t i=0;i<2;++i)
              value+=(i?fx:1-fx)*(j?fy:1-fy)*(k?fz:1-fz)*values[(ix+i)%g.Nx+g.Nx*((iy+j)%g.Ny+g.Ny*(iz+k))];
            ++metrics_.linearInterpolationCount;
          } else {
            const bool bx=g.Nx<4 || ix<3 || ix>g.Nx-4,by=g.Ny<4 || iy<3 || iy>g.Ny-4;
            workspace.xSpline.weightsInto(dx,bx?wrapped(x+4*dx,g.Lx):xx,bx?4:0,workspace.xWeights,workspace.xShifted,workspace.xRhs);
            workspace.ySpline.weightsInto(dy,by?wrapped(y+4*dy,g.Ly):yy,by?4:0,workspace.yWeights,workspace.yShifted,workspace.yRhs);
            if(!horizontal) workspace.zSpline.weightsInto(z,workspace.zWeights);
            for(std::size_t k=0;k<(horizontal?1:g.Nz);++k) for(std::size_t j=0;j<g.Ny;++j) for(std::size_t i=0;i<g.Nx;++i)
              value+=workspace.xWeights[i]*workspace.yWeights[j]*(horizontal?1:workspace.zWeights[k])*values[i+g.Nx*(j+g.Ny*k)];
            ++metrics_.splineInterpolationCount;
          }
        }
        outputs[destination.output].data[p]=value;
      }
      metrics_.outputElementWriteCount+=destination.count;
    }
  }
  ++metrics_.evaluationCount;
  ++metrics_.movingEvaluationCount;
  metrics_.movingPositionCount += positions.positionCount;
  metrics_.scratchHighWaterBytes = std::max(
      metrics_.scratchHighWaterBytes,
      fieldScratch_.size() * sizeof(double) + workspace.scratchBytes());
  metrics_.servicePersistentBytes = persistentBytes();
  return WVKernelStatus::ok();
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::createEventPlan(
    const std::vector<WVEventFieldRequest> &requests,
    WVEventFieldEvaluationPlan &plan) {
  try {
    auto implementation = std::make_shared<EventPlan>();
    implementation->fingerprint = configurationFingerprint(configuration());
    WVEventFieldEvaluationPlan candidate;
    candidate.outputs_.reserve(requests.size());
    std::set<std::string> identifiers;
    for (std::size_t index = 0; index < requests.size(); ++index) {
      if (requests[index].identifier.empty() || !identifiers.insert(requests[index].identifier).second)
        return invalid("SQG event output identifiers must be nonempty and unique.");
      if (requests[index].positionSetSlot == std::numeric_limits<std::size_t>::max())
        return invalid("SQG event position-set slot exceeds the supported range.");
      WVStratifiedQGField field;
      ScalarField scalar;
      auto status = resolveField(requests[index].fieldName, field, scalar);
      if (!status)
        return status;
      if (scalar != ScalarField::none)
        return invalid("Scalar fields cannot use event position sampling.");
      implementation->positionSetCount = std::max(
          implementation->positionSetCount, requests[index].positionSetSlot + 1);
      implementation->requests.push_back(
          {field, requests[index].positionSetSlot,
           requests[index].interpolation, index});
      candidate.outputs_.push_back(
          {requests[index].identifier, requests[index].fieldName,
           findPortableVariable(requests[index].fieldName)->identifier, surface(field)?WVPortableNaturalRank::horizontal:WVPortableNaturalRank::volume, 0,
           requests[index].positionSetSlot, requests[index].interpolation});
    }
    candidate.positionSetCount_ = implementation->positionSetCount;
    candidate.fingerprint_ = implementation->fingerprint;
    candidate.transformPlan_ = implementation;
    candidate.transformPlanBytes_ = implementation->persistentBytes();
    plan = std::move(candidate);
    ++metrics_.eventPlanCreationCount;
    metrics_.eventPlanFieldResolutionCount += requests.size();
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate a Stratified QG event-field plan."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::prepareEventGeometry(
    const WVEventFieldEvaluationPlan &publicPlan,
    const WVEventPositionSetView *positionSets,
    std::size_t positionSetCount, WVPreparedFieldGeometry &geometry) {
  const auto eventPlan =
      std::static_pointer_cast<const EventPlan>(publicPlan.transformPlan_);
  if (!eventPlan || eventPlan->fingerprint != configurationFingerprint(configuration()) ||
      positionSetCount != eventPlan->positionSetCount ||
      (positionSetCount != 0 && positionSets == nullptr))
    return {WVKernelStatusCode::invalidShape,
            "Stratified QG event geometry does not match its plan."};
  try {
    std::vector<WVFieldRequest> requests;
    requests.reserve(eventPlan->requests.size());
    WVPreparedFieldGeometry candidate;
    candidate.positionSets_.reserve(positionSetCount);
    candidate.positionCount_ = 0;
    for (std::size_t slot = 0; slot < positionSetCount; ++slot) {
      const auto &view = positionSets[slot];
      if (view.extentCount != 0 && view.extents == nullptr)
        return {WVKernelStatusCode::invalidPointer,"SQG event extents are null."};
      if (view.positionCount != 0 && (view.x == nullptr || view.y == nullptr))
        return {WVKernelStatusCode::invalidPointer,
                "Stratified QG event coordinates are null."};
      WVPreparedFieldGeometry::PositionSet stored;
      stored.x = view.x;
      stored.y = view.y;
      stored.z = view.z;
      stored.positionCount = view.positionCount;
      if (view.extentCount == 0)
        stored.extents = {view.positionCount};
      else
        stored.extents.assign(view.extents, view.extents + view.extentCount);
      std::size_t count = 1;
      for (const auto extent : stored.extents)
        count = checkedProduct(count, extent);
      if (count != view.positionCount)
        return {WVKernelStatusCode::invalidShape,
                "Stratified QG event extents do not match coordinates."};
      candidate.positionCount_ += view.positionCount;
      candidate.borrowedCoordinateBytes_ +=
          3 * view.positionCount * sizeof(double);
      candidate.positionSets_.push_back(std::move(stored));
    }
    for (const auto &request : eventPlan->requests) {
      const auto &set = positionSets[request.positionSet];
      WVFieldSamplingRequest sampling;
      sampling.kind = WVFieldSamplingKind::positions;
      sampling.interpolation = request.interpolation;
      if (set.positionCount != 0) {
        sampling.x.assign(set.x, set.x + set.positionCount);
        sampling.y.assign(set.y, set.y + set.positionCount);
      }
      if(set.z) sampling.z.assign(set.z,set.z+set.positionCount);
      requests.push_back({publicPlan.outputs_[request.output].identifier,
                          publicPlan.outputs_[request.output].fieldName,
                          std::move(sampling)});
      candidate.outputs_.push_back(
          {request.output, request.positionSet,
           candidate.positionSets_[request.positionSet].extents,
           set.positionCount});
    }
    WVFieldEvaluationPlan evaluationPlan;
    auto status = createPlan(requests, evaluationPlan);
    if (!status)
      return status;
    auto geometryImpl = std::make_shared<EventGeometry>();
    geometryImpl->eventPlan = eventPlan;
    geometryImpl->plan =
        std::static_pointer_cast<const Plan>(evaluationPlan.transformPlan_);
    candidate.fieldPlanFingerprint_ = publicPlan.fingerprint_;
    candidate.geometryFingerprint_ = publicPlan.fingerprint_;
    for (const auto &set : candidate.positionSets_) {
      const auto byteCount = set.positionCount * sizeof(double);
      for (const auto *data : {set.x, set.y, set.z}) {
        if(!data) continue;
        const auto *bytes = reinterpret_cast<const std::uint8_t *>(data);
        for (std::size_t byte = 0; byte < byteCount; ++byte) {
          candidate.geometryFingerprint_ ^= bytes[byte];
          candidate.geometryFingerprint_ *= 1099511628211ULL;
        }
      }
    }
    candidate.transformGeometry_ = geometryImpl;
    candidate.transformGeometryBytes_ = geometryImpl->persistentBytes();
    candidate.evaluationPlan_ = std::move(evaluationPlan);
    geometry = std::move(candidate);
    ++metrics_.eventGeometryPreparationCount;
    metrics_.eventPositionSetCount += positionSetCount;
    metrics_.eventPositionCount += geometry.positionCount_;
    metrics_.lastPreparedGeometryRetainedBytes = geometry.retainedBytes();
    metrics_.maximumPreparedGeometryRetainedBytes = std::max(
        metrics_.maximumPreparedGeometryRetainedBytes,
        metrics_.lastPreparedGeometryRetainedBytes);
    return WVKernelStatus::ok();
  } catch (const std::overflow_error &error) {
    return {WVKernelStatusCode::sizeOverflow, error.what()};
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate Stratified QG event geometry."};
  }
}

WVKernelStatus WVStratifiedQGFieldEvaluationAdapter::evaluateEventBatch(
    const WVIntegrationState &state,
    const WVEventFieldEvaluationBatchEntry *entries,
    std::size_t entryCount) {
  if (entryCount != 0 && entries == nullptr)
    return {WVKernelStatusCode::invalidPointer,
            "Stratified QG event batch entries are null."};
  for (std::size_t entry = 0; entry < entryCount; ++entry) {
    if (entries[entry].plan == nullptr || entries[entry].geometry == nullptr)
      return {WVKernelStatusCode::invalidPointer,
              "Stratified QG event entry is incomplete."};
    const auto geometry = std::static_pointer_cast<const EventGeometry>(entries[entry].geometry->transformGeometry_);
    if (!geometry || geometry->eventPlan.get() != entries[entry].plan->transformPlan_.get())
      return invalid("SQG event geometry was prepared for a different field plan.");
    const auto status = evaluate(
        entries[entry].geometry->evaluationPlan_, state,
        entries[entry].outputs, entries[entry].outputCount);
    if (!status)
      return status;
  }
  ++metrics_.eventBatchEvaluationCount;
  metrics_.eventBatchOccurrenceCount += entryCount;
  metrics_.eventEvaluationCount += entryCount;
  return WVKernelStatus::ok();
}

bool WVStratifiedQGFieldEvaluationAdapter::isCompatibleWith(
    const WVIntegrationStateLayout &layout) const noexcept {
  const auto &spatial = layout.spatialDimensions();
  return spatial == std::vector<std::size_t>{configuration().Nx,
                                             configuration().Ny,configuration().Nz} &&
         layout.coefficientFamilyCount() == 1 &&
         layout.coefficientFamilies()[0].identifier == "A0" &&
         layout.coefficientFamilies()[0].elementCount ==
             kernel_->geometry().Nj*kernel_->geometry().Nkl;
}

const WVStratifiedModalGeometry &
WVStratifiedQGFieldEvaluationAdapter::configuration() const noexcept {
  return kernel_->geometry();
}

std::size_t
WVStratifiedQGFieldEvaluationAdapter::persistentBytes() const noexcept {
  return sizeof(*this) +
         (ownedKernel_ ? kernel_->persistentBytes() : 0) +
         fieldScratch_.capacity() * sizeof(double) +
         (movingInterpolation_ ? movingInterpolation_->persistentBytes() : 0);
}

} // namespace wavevortex::runtime::detail
