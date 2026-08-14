#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <new>
#include <set>
#include <stdexcept>
#include <utility>

namespace wavevortex::runtime {
namespace {

constexpr const char *fieldNames[] = {
    "u",       "v",         "w",       "eta",    "pi",
    "p",       "psi",       "qgpv",    "rho_e",  "rho_total",
    "rho_bar", "zeta_x",    "zeta_y",  "zeta_z", "ssu",
    "ssv",     "ssh",       "energy",  "uvMax",  "wMax"};

enum Dependency : std::uint64_t {
  primitiveValues = 1ULL << 0,
  pressureHeight = 1ULL << 1,
  streamfunction = 1ULL << 2,
  potentialVorticity = 1ULL << 3,
  uDerivatives = 1ULL << 4,
  vDerivatives = 1ULL << 5,
  wDerivatives = 1ULL << 6,
  spectralEnergy = 1ULL << 7
};

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

std::size_t checkedProduct(std::size_t first, std::size_t second) {
  if (first != 0 && second > std::numeric_limits<std::size_t>::max() / first)
    throw std::overflow_error("field-evaluation size overflow");
  return first * second;
}

bool memoryOverlaps(const void *first, std::size_t firstBytes,
                    const void *second, std::size_t secondBytes) {
  if (!first || !second || firstBytes == 0 || secondBytes == 0)
    return false;
  const auto firstAddress = reinterpret_cast<std::uintptr_t>(first);
  const auto secondAddress = reinterpret_cast<std::uintptr_t>(second);
  return firstAddress < secondAddress + secondBytes &&
         secondAddress < firstAddress + firstBytes;
}

WVComplex64 subtract(WVComplex64 first, WVComplex64 second) noexcept {
  return {first.real - second.real, first.imag - second.imag};
}

WVComplex64 multiply(WVComplex64 first, WVComplex64 second) noexcept {
  return {first.real * second.real - first.imag * second.imag,
          first.real * second.imag + first.imag * second.real};
}

WVComplex64 multiply(WVComplex64 value, double scale) noexcept {
  return {value.real * scale, value.imag * scale};
}

WVComplex64 conjugate(WVComplex64 value) noexcept {
  return {value.real, -value.imag};
}

double squaredMagnitude(WVComplex64 value) noexcept {
  return value.real * value.real + value.imag * value.imag;
}

bool sameConfiguration(
    const WVTransformConstantStratificationConfiguration &first,
    const WVTransformConstantStratificationConfiguration &second) noexcept {
  return first.contractVersion == second.contractVersion && first.Nx == second.Nx &&
         first.Ny == second.Ny && first.Nz == second.Nz &&
         first.Nj == second.Nj && first.Lx == second.Lx &&
         first.Ly == second.Ly && first.Lz == second.Lz &&
         first.N0 == second.N0 && first.rho0 == second.rho0 &&
         first.g == second.g && first.planetaryRadius == second.planetaryRadius &&
         first.rotationRate == second.rotationRate &&
         first.latitude == second.latitude &&
         first.isHydrostatic == second.isHydrostatic &&
         first.shouldAntialias == second.shouldAntialias;
}

double wrapped(double coordinate, double length) noexcept {
  double value = std::fmod(coordinate, length);
  if (value < 0.0)
    value += length;
  if (value >= length)
    value = 0.0;
  return value;
}

class SplineSystem final {
public:
  explicit SplineSystem(std::size_t count) : count_(count) {
    if (count < 2)
      throw std::invalid_argument(
          "Spline interpolation requires at least two points per axis.");
    if (count < 4)
      return;
    lu_.assign(checkedProduct(count, count), 0.0);
    pivots_.resize(count);
    // Factor the transpose of the uniform-grid not-a-knot system. The
    // common grid-spacing factor cancels between the system and its RHS.
    auto setSystem = [&](std::size_t row, std::size_t column, double value) {
      lu_[column + count * row] = value;
    };
    setSystem(0, 0, -1.0);
    setSystem(0, 1, 2.0);
    setSystem(0, 2, -1.0);
    for (std::size_t row = 1; row + 1 < count; ++row) {
      setSystem(row, row - 1, 1.0);
      setSystem(row, row, 4.0);
      setSystem(row, row + 1, 1.0);
    }
    setSystem(count - 1, count - 3, -1.0);
    setSystem(count - 1, count - 2, 2.0);
    setSystem(count - 1, count - 1, -1.0);
    std::vector<double> transpose(checkedProduct(count, count));
    for (std::size_t row = 0; row < count; ++row)
      for (std::size_t column = 0; column < count; ++column)
        transpose[column + count * row] = lu_[row + count * column];
    lu_.swap(transpose);
    factor();
  }

  std::vector<double> weights(double origin, double spacing, double query,
                              std::size_t circularShift = 0) const {
    const double normalized = (query - origin) / spacing;
    auto restoreOriginalOrdering = [&](std::vector<double> shifted) {
      if (circularShift == 0)
        return shifted;
      std::vector<double> original(count_, 0.0);
      for (std::size_t shiftedIndex = 0; shiftedIndex < count_;
           ++shiftedIndex) {
        const auto originalIndex =
            (shiftedIndex + count_ - circularShift % count_) % count_;
        original[originalIndex] += shifted[shiftedIndex];
      }
      return original;
    };
    if (count_ == 2)
      return restoreOriginalOrdering({1.0 - normalized, normalized});
    if (count_ == 3) {
      std::vector<double> quadratic = {
          (normalized - 1.0) * (normalized - 2.0) / 2.0,
          -normalized * (normalized - 2.0),
          normalized * (normalized - 1.0) / 2.0};
      return restoreOriginalOrdering(std::move(quadratic));
    }
    std::size_t interval = normalized <= 0.0
                               ? 0
                               : static_cast<std::size_t>(std::floor(normalized));
    interval = std::min(interval, count_ - 2);
    const double fraction = std::clamp(normalized - static_cast<double>(interval),
                                       0.0, 1.0);
    const double first = 1.0 - fraction;
    const double second = fraction;
    std::vector<double> rhs(count_, 0.0);
    rhs[interval] = (first * first * first - first) * spacing * spacing / 6.0;
    rhs[interval + 1] =
        (second * second * second - second) * spacing * spacing / 6.0;
    solve(rhs);
    std::vector<double> shifted(count_, 0.0);
    shifted[interval] += first;
    shifted[interval + 1] += second;
    const double rhsScale = 6.0 / (spacing * spacing);
    for (std::size_t row = 1; row + 1 < count_; ++row) {
      shifted[row - 1] += rhsScale * rhs[row];
      shifted[row] -= 2.0 * rhsScale * rhs[row];
      shifted[row + 1] += rhsScale * rhs[row];
    }
    return restoreOriginalOrdering(std::move(shifted));
  }

private:
  void factor() {
    for (std::size_t column = 0; column < count_; ++column) {
      std::size_t pivot = column;
      double maximum = std::abs(lu_[column + count_ * column]);
      for (std::size_t row = column + 1; row < count_; ++row) {
        const double candidate = std::abs(lu_[column + count_ * row]);
        if (candidate > maximum) {
          maximum = candidate;
          pivot = row;
        }
      }
      if (maximum == 0.0)
        throw std::invalid_argument("Spline interpolation system is singular.");
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

  void solve(std::vector<double> &rightHandSide) const {
    for (std::size_t column = 0; column < count_; ++column) {
      if (pivots_[column] != column)
        std::swap(rightHandSide[column], rightHandSide[pivots_[column]]);
      for (std::size_t row = column + 1; row < count_; ++row)
        rightHandSide[row] -=
            lu_[column + count_ * row] * rightHandSide[column];
    }
    for (std::size_t reverse = 0; reverse < count_; ++reverse) {
      const std::size_t row = count_ - 1 - reverse;
      for (std::size_t column = row + 1; column < count_; ++column)
        rightHandSide[row] -=
            lu_[column + count_ * row] * rightHandSide[column];
      rightHandSide[row] /= lu_[row + count_ * row];
    }
  }

  std::size_t count_ = 0;
  std::vector<double> lu_;
  std::vector<std::size_t> pivots_;
};

class ExecutionGuard final {
public:
  explicit ExecutionGuard(bool &executing)
      : executing_(executing), entered_(!executing) {
    if (entered_)
      executing_ = true;
  }
  ~ExecutionGuard() {
    if (entered_)
      executing_ = false;
  }
  bool entered() const noexcept { return entered_; }

private:
  bool &executing_;
  bool entered_ = false;
};

} // namespace

std::size_t WVFieldEvaluationPlan::PositionWeights::persistentBytes() const
    noexcept {
  return xSplineWeights.capacity() * sizeof(double) +
         ySplineWeights.capacity() * sizeof(double) +
         zSplineWeights.capacity() * sizeof(double);
}

std::size_t WVFieldEvaluationPlan::ResolvedRequest::persistentBytes() const
    noexcept {
  std::size_t value = profileXIndices.capacity() * sizeof(std::size_t) +
                      profileYIndices.capacity() * sizeof(std::size_t) +
                      positionWeights.capacity() * sizeof(PositionWeights);
  for (const auto &weights : positionWeights)
    value += weights.persistentBytes();
  return value;
}

std::size_t WVFieldEvaluationPlan::persistentBytes() const noexcept {
  std::size_t value = sizeof(*this) +
                      requests_.capacity() * sizeof(ResolvedRequest) +
                      outputs_.capacity() * sizeof(WVFieldOutputSpecification);
  for (const auto &request : requests_)
    value += request.persistentBytes();
  for (const auto &output : outputs_) {
    value += output.identifier.capacity() + output.fieldName.capacity() +
             output.dimensions.capacity() * sizeof(std::size_t);
  }
  return value;
}

WVKernelStatus WVFieldEvaluationService::create(
    const WVTransformConstantStratificationConfiguration &configuration,
    std::unique_ptr<WVFFTEngine> engine,
    std::unique_ptr<WVFieldEvaluationService> &service) {
  try {
    auto candidate = std::unique_ptr<WVFieldEvaluationService>(
        new WVFieldEvaluationService());
    auto status = WVTransformConstantStratificationKernel::create(
        configuration, std::move(engine), candidate->transform_);
    if (!status)
      return status;
    const auto fieldElements = candidate->transform_->descriptor()
                                   .spatialShape()
                                   .elementCount();
    const auto coefficientElements = candidate->transform_->descriptor()
                                         .spectralShape()
                                         .elementCount();
    candidate->realScratch_.resize(checkedProduct(6, fieldElements));
    candidate->complexScratch_.resize(checkedProduct(2, coefficientElements));
    candidate->metrics_.transformPersistentBytes =
        candidate->transform_->persistentBytes();
    candidate->metrics_.scratchCapacityBytes =
        candidate->realScratch_.capacity() * sizeof(double) +
        candidate->complexScratch_.capacity() * sizeof(WVComplex64);
    candidate->metrics_.servicePersistentBytes = candidate->persistentBytes();
    service = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate bounded field-evaluation storage."};
  } catch (const std::overflow_error &error) {
    return {WVKernelStatusCode::sizeOverflow, error.what()};
  }
}

std::vector<std::string> WVFieldEvaluationService::supportedFieldNames() {
  return {std::begin(fieldNames), std::end(fieldNames)};
}

WVKernelStatus WVFieldEvaluationService::createPlan(
    const std::vector<WVFieldRequest> &requests,
    WVFieldEvaluationPlan &plan) const {
  try {
    WVFieldEvaluationPlan candidate;
    const auto &configuration = transform_->descriptor().configuration();
    candidate.configuration_ = configuration;
    candidate.requests_.reserve(requests.size());
    candidate.outputs_.reserve(requests.size());
    std::set<std::string> identifiers;
    bool needsSpline = false;
    for (const auto &request : requests)
      needsSpline = needsSpline ||
                    (request.sampling.kind == WVFieldSamplingKind::positions &&
                     request.sampling.interpolation ==
                         WVPositionInterpolation::spline);
    std::unique_ptr<SplineSystem> xSpline;
    std::unique_ptr<SplineSystem> ySpline;
    std::unique_ptr<SplineSystem> zSpline;
    if (needsSpline) {
      xSpline = std::make_unique<SplineSystem>(configuration.Nx);
      ySpline = std::make_unique<SplineSystem>(configuration.Ny);
    }
    const double dx = configuration.Lx / static_cast<double>(configuration.Nx);
    const double dy = configuration.Ly / static_cast<double>(configuration.Ny);
    const double dz = configuration.Lz /
                      static_cast<double>(configuration.Nz - 1);
    for (std::size_t outputIndex = 0; outputIndex < requests.size();
         ++outputIndex) {
      const auto &request = requests[outputIndex];
      if (request.identifier.empty())
        return invalid("Every field request must have a nonempty identifier.");
      if (!identifiers.insert(request.identifier).second)
        return invalid("Field request identifiers must be unique: " +
                       request.identifier + ".");
      const auto fieldIterator =
          std::find(std::begin(fieldNames), std::end(fieldNames), request.fieldName);
      if (fieldIterator == std::end(fieldNames))
        return invalid("Unknown or unsupported field: " + request.fieldName + ".");
      const auto fieldIndex =
          static_cast<std::size_t>(fieldIterator - std::begin(fieldNames));
      const auto field =
          static_cast<WVFieldEvaluationPlan::Field>(fieldIndex);
      WVFieldEvaluationPlan::NativeRank rank =
          WVFieldEvaluationPlan::NativeRank::volume;
      if (field == WVFieldEvaluationPlan::Field::rhoBar)
        rank = WVFieldEvaluationPlan::NativeRank::vertical;
      else if (field == WVFieldEvaluationPlan::Field::ssu ||
               field == WVFieldEvaluationPlan::Field::ssv ||
               field == WVFieldEvaluationPlan::Field::ssh)
        rank = WVFieldEvaluationPlan::NativeRank::horizontal;
      else if (field == WVFieldEvaluationPlan::Field::energy ||
               field == WVFieldEvaluationPlan::Field::uvMax ||
               field == WVFieldEvaluationPlan::Field::wMax)
        rank = WVFieldEvaluationPlan::NativeRank::scalar;

      WVFieldEvaluationPlan::ResolvedRequest resolved;
      if (request.sampling.kind != WVFieldSamplingKind::fullGrid &&
          request.sampling.kind !=
              WVFieldSamplingKind::fixedVerticalProfiles &&
          request.sampling.kind != WVFieldSamplingKind::positions)
        return invalid("Unknown field-sampling kind.");
      if (request.sampling.kind == WVFieldSamplingKind::positions &&
          request.sampling.interpolation != WVPositionInterpolation::linear &&
          request.sampling.interpolation != WVPositionInterpolation::spline)
        return invalid("Unknown position-interpolation method.");
      resolved.field = field;
      resolved.nativeRank = rank;
      resolved.samplingKind = request.sampling.kind;
      resolved.interpolation = request.sampling.interpolation;
      resolved.outputIndex = outputIndex;
      WVFieldOutputSpecification output;
      output.identifier = request.identifier;
      output.fieldName = request.fieldName;
      output.samplingKind = request.sampling.kind;
      if (request.sampling.kind == WVFieldSamplingKind::fullGrid) {
        if (rank == WVFieldEvaluationPlan::NativeRank::volume)
          output.dimensions = {configuration.Nx, configuration.Ny,
                               configuration.Nz};
        else if (rank == WVFieldEvaluationPlan::NativeRank::horizontal)
          output.dimensions = {configuration.Nx, configuration.Ny};
        else if (rank == WVFieldEvaluationPlan::NativeRank::vertical)
          output.dimensions = {configuration.Nz};
      } else if (request.sampling.kind ==
                 WVFieldSamplingKind::fixedVerticalProfiles) {
        if (rank != WVFieldEvaluationPlan::NativeRank::volume)
          return invalid("Fixed vertical profiles require a three-dimensional field: " +
                         request.fieldName + ".");
        if (request.sampling.xIndices.empty() ||
            request.sampling.xIndices.size() !=
                request.sampling.yIndices.size())
          return invalid("Fixed-profile xIndices and yIndices must be nonempty and have equal length.");
        resolved.profileXIndices.reserve(request.sampling.xIndices.size());
        resolved.profileYIndices.reserve(request.sampling.yIndices.size());
        for (std::size_t index = 0; index < request.sampling.xIndices.size();
             ++index) {
          const auto xIndex = request.sampling.xIndices[index];
          const auto yIndex = request.sampling.yIndices[index];
          if (xIndex == 0 || xIndex > configuration.Nx || yIndex == 0 ||
              yIndex > configuration.Ny)
            return invalid("Fixed-profile indices must use MATLAB one-based values within the model grid.");
          resolved.profileXIndices.push_back(xIndex - 1);
          resolved.profileYIndices.push_back(yIndex - 1);
        }
        output.dimensions = {configuration.Nz,
                             request.sampling.xIndices.size()};
      } else {
        if (rank == WVFieldEvaluationPlan::NativeRank::scalar ||
            rank == WVFieldEvaluationPlan::NativeRank::vertical)
          return invalid("Position sampling is unsupported for field " +
                         request.fieldName + ".");
        const auto positionCount = request.sampling.x.size();
        if (positionCount == 0 || request.sampling.y.size() != positionCount)
          return invalid("Position x and y arrays must be nonempty and have equal length.");
        if (rank == WVFieldEvaluationPlan::NativeRank::volume &&
            request.sampling.z.size() != positionCount)
          return invalid("Three-dimensional position sampling requires equal-length x, y, and z arrays.");
        if (rank == WVFieldEvaluationPlan::NativeRank::horizontal &&
            !request.sampling.z.empty() &&
            request.sampling.z.size() != positionCount)
          return invalid("Optional z positions must be empty or match x and y.");
        resolved.positionWeights.reserve(positionCount);
        for (std::size_t position = 0; position < positionCount; ++position) {
          const double x = request.sampling.x[position];
          const double y = request.sampling.y[position];
          const double z = rank == WVFieldEvaluationPlan::NativeRank::volume
                               ? request.sampling.z[position]
                               : 0.0;
          if (!std::isfinite(x) || !std::isfinite(y) ||
              (rank == WVFieldEvaluationPlan::NativeRank::volume &&
               !std::isfinite(z)))
            return invalid("Position coordinates must be finite.");
          WVFieldEvaluationPlan::PositionWeights weights;
          const double xWrapped = wrapped(x, configuration.Lx);
          const double yWrapped = wrapped(y, configuration.Ly);
          const auto xLower = std::min(
              static_cast<std::size_t>(std::floor(xWrapped / dx)),
              configuration.Nx - 1);
          const auto yLower = std::min(
              static_cast<std::size_t>(std::floor(yWrapped / dy)),
              configuration.Ny - 1);
          if (request.sampling.interpolation ==
              WVPositionInterpolation::linear) {
            weights.xLinearIndices = {xLower, (xLower + 1) % configuration.Nx};
            weights.yLinearIndices = {yLower, (yLower + 1) % configuration.Ny};
            const double xFraction =
                (xWrapped - static_cast<double>(xLower) * dx) / dx;
            const double yFraction =
                (yWrapped - static_cast<double>(yLower) * dy) / dy;
            weights.xLinearWeights = {1.0 - xFraction, xFraction};
            weights.yLinearWeights = {1.0 - yFraction, yFraction};
            if (rank == WVFieldEvaluationPlan::NativeRank::volume) {
              weights.outsideInterpolationDomain =
                  z < -configuration.Lz || z > 0.0;
              if (!weights.outsideInterpolationDomain) {
                const double normalizedZ = (z + configuration.Lz) / dz;
                const auto zLower = std::min(
                    static_cast<std::size_t>(std::max(0.0, std::floor(normalizedZ))),
                    configuration.Nz - 2);
                const double zFraction =
                    std::clamp(normalizedZ - static_cast<double>(zLower), 0.0,
                               1.0);
                weights.zLinearIndices = {zLower, zLower + 1};
                weights.zLinearWeights = {1.0 - zFraction, zFraction};
              }
            }
          } else {
            const bool xBoundary = xLower < 3 || xLower > configuration.Nx - 4;
            const bool yBoundary = yLower < 3 || yLower > configuration.Ny - 4;
            const std::size_t xShift = xBoundary ? 4 : 0;
            const std::size_t yShift = yBoundary ? 4 : 0;
            const double xQuery = xBoundary
                                      ? wrapped(x + 4.0 * dx, configuration.Lx)
                                      : xWrapped;
            const double yQuery = yBoundary
                                      ? wrapped(y + 4.0 * dy, configuration.Ly)
                                      : yWrapped;
            // MATLAB's interpn(...,"spline",0) applies the zero fill value
            // when a boundary-shifted query lies beyond the last stored
            // periodic grid point (the duplicated x=L/y=L points are absent).
            weights.outsideInterpolationDomain =
                xQuery > static_cast<double>(configuration.Nx - 1) * dx ||
                yQuery > static_cast<double>(configuration.Ny - 1) * dy;
            if (!weights.outsideInterpolationDomain) {
              weights.xSplineWeights =
                  xSpline->weights(0.0, dx, xQuery, xShift);
              weights.ySplineWeights =
                  ySpline->weights(0.0, dy, yQuery, yShift);
            }
            if (rank == WVFieldEvaluationPlan::NativeRank::volume) {
              weights.outsideInterpolationDomain =
                  weights.outsideInterpolationDomain ||
                  z < -configuration.Lz || z > 0.0;
              if (!weights.outsideInterpolationDomain) {
                if (!zSpline)
                  zSpline = std::make_unique<SplineSystem>(configuration.Nz);
                weights.zSplineWeights =
                    zSpline->weights(-configuration.Lz, dz, z);
              }
            }
          }
          resolved.positionWeights.push_back(std::move(weights));
        }
        output.dimensions = {positionCount};
      }
      output.elementCount = 1;
      for (const auto dimension : output.dimensions)
        output.elementCount = checkedProduct(output.elementCount, dimension);
      candidate.requestedFieldMask_ |= 1ULL << fieldIndex;
      switch (field) {
      case WVFieldEvaluationPlan::Field::u:
      case WVFieldEvaluationPlan::Field::v:
      case WVFieldEvaluationPlan::Field::w:
      case WVFieldEvaluationPlan::Field::eta:
      case WVFieldEvaluationPlan::Field::rhoE:
      case WVFieldEvaluationPlan::Field::rhoTotal:
      case WVFieldEvaluationPlan::Field::rhoBar:
      case WVFieldEvaluationPlan::Field::ssu:
      case WVFieldEvaluationPlan::Field::ssv:
      case WVFieldEvaluationPlan::Field::uvMax:
      case WVFieldEvaluationPlan::Field::wMax:
        candidate.dependencyMask_ |= primitiveValues;
        break;
      case WVFieldEvaluationPlan::Field::pi:
      case WVFieldEvaluationPlan::Field::p:
      case WVFieldEvaluationPlan::Field::ssh:
        candidate.dependencyMask_ |= pressureHeight;
        break;
      case WVFieldEvaluationPlan::Field::psi:
        if (transform_->descriptor().verticalModes().coriolisFrequency == 0.0)
          return {WVKernelStatusCode::unsupportedOperation,
                  "Streamfunction evaluation is undefined when the Coriolis "
                  "frequency is zero."};
        candidate.dependencyMask_ |= streamfunction;
        break;
      case WVFieldEvaluationPlan::Field::qgpv:
        candidate.dependencyMask_ |= potentialVorticity;
        break;
      case WVFieldEvaluationPlan::Field::zetaX:
        candidate.dependencyMask_ |= vDerivatives | wDerivatives;
        break;
      case WVFieldEvaluationPlan::Field::zetaY:
        candidate.dependencyMask_ |= uDerivatives | wDerivatives;
        break;
      case WVFieldEvaluationPlan::Field::zetaZ:
        candidate.dependencyMask_ |= uDerivatives | vDerivatives;
        break;
      case WVFieldEvaluationPlan::Field::energy:
        candidate.dependencyMask_ |= spectralEnergy;
        break;
      case WVFieldEvaluationPlan::Field::count:
        break;
      }
      candidate.requests_.push_back(std::move(resolved));
      candidate.outputs_.push_back(std::move(output));
    }
    plan = std::move(candidate);
    return WVKernelStatus::ok();
  } catch (const std::bad_alloc &) {
    return {WVKernelStatusCode::allocationFailure,
            "Unable to allocate immutable field-evaluation plan storage."};
  } catch (const std::overflow_error &error) {
    return {WVKernelStatusCode::sizeOverflow, error.what()};
  } catch (const std::invalid_argument &error) {
    return invalid(error.what());
  }
}

WVKernelStatus WVFieldEvaluationService::evaluate(
    const WVFieldEvaluationPlan &plan, const WVState &state,
    WVFieldOutputView *outputs, std::size_t outputCount) {
  if (!sameConfiguration(plan.configuration_,
                         transform_->descriptor().configuration()))
    return invalid("The evaluation plan was created for a different transform configuration.");
  if (outputCount != plan.outputs_.size())
    return {WVKernelStatusCode::invalidShape,
            "The output-view count must match the evaluation plan."};
  if (outputCount != 0 && outputs == nullptr)
    return {WVKernelStatusCode::invalidPointer,
            "Field-evaluation outputs have a null view pointer."};
  if (!std::isfinite(state.t) || !std::isfinite(state.t0))
    return invalid("Field-evaluation state times must be finite.");
  const auto spectral = transform_->descriptor().spectralShape();
  const auto coefficientBytes = spectral.elementCount() * sizeof(WVComplex64);
  const void *coefficientInputs[] = {state.coefficients.Ap.data,
                                     state.coefficients.Am.data,
                                     state.coefficients.A0.data};
  const WVComplexConstView coefficientViews[] = {
      state.coefficients.Ap, state.coefficients.Am, state.coefficients.A0};
  for (const auto &view : coefficientViews) {
    if (view.shape.rows != spectral.rows ||
        view.shape.columns != spectral.columns)
      return {WVKernelStatusCode::invalidShape,
              "Field-evaluation coefficients must have shape [Nj,Nkl]."};
    if (view.data == nullptr)
      return {WVKernelStatusCode::invalidPointer,
              "Field-evaluation coefficients have a null pointer."};
  }
  for (std::size_t output = 0; output < outputCount; ++output) {
    if (outputs[output].elementCount != plan.outputs_[output].elementCount)
      return {WVKernelStatusCode::invalidShape,
              "Caller-owned output has the wrong element count for request " +
                  plan.outputs_[output].identifier + "."};
    if (outputs[output].data == nullptr)
      return {WVKernelStatusCode::invalidPointer,
              "Caller-owned output has a null pointer for request " +
                  plan.outputs_[output].identifier + "."};
    const auto bytes = outputs[output].elementCount * sizeof(double);
    for (const auto *input : coefficientInputs)
      if (memoryOverlaps(outputs[output].data, bytes, input,
                         coefficientBytes))
        return {WVKernelStatusCode::overlappingArrays,
                "Field outputs must not overlap coefficient inputs."};
    for (std::size_t other = output + 1; other < outputCount; ++other)
      if (memoryOverlaps(outputs[output].data, bytes, outputs[other].data,
                         outputs[other].elementCount * sizeof(double)))
        return {WVKernelStatusCode::overlappingArrays,
                "Caller-owned field outputs must not overlap each other."};
  }
  ExecutionGuard guard(executing_);
  if (!guard.entered())
    return {WVKernelStatusCode::reentrantExecution,
            "Field evaluation is not reentrant."};

  ++metrics_.evaluationCount;
  if (outputCount > 1)
    ++metrics_.coincidentBatchCount;
  metrics_.lastPlanBytes = plan.persistentBytes();
  metrics_.maximumPlanBytes =
      std::max(metrics_.maximumPlanBytes, metrics_.lastPlanBytes);

  const auto &configuration = transform_->descriptor().configuration();
  const auto spatial = transform_->descriptor().spatialShape();
  const auto fieldElements = spatial.elementCount();
  const auto horizontalElements = configuration.Nx * configuration.Ny;
  const auto coefficientElements = spectral.elementCount();
  auto updateScratchHighWater = [&](std::size_t realElements,
                                    std::size_t complexElements) {
    const auto bytes = realElements * sizeof(double) +
                       complexElements * sizeof(WVComplex64);
    metrics_.scratchHighWaterBytes =
        std::max(metrics_.scratchHighWaterBytes, bytes);
  };
  auto invokeTransform = [&](auto &&operation) {
    const auto before = transform_->metrics().executionCount;
    ++metrics_.transformCount;
    const auto status = operation();
    metrics_.fftExecutionCount +=
        transform_->metrics().executionCount - before;
    return status;
  };

  auto fieldRequested = [&](WVFieldEvaluationPlan::Field field) {
    return (plan.requestedFieldMask_ &
            (1ULL << static_cast<std::size_t>(field))) != 0;
  };

  auto writeField = [&](WVFieldEvaluationPlan::Field field,
                        WVFieldEvaluationPlan::NativeRank rank,
                        const double *source) -> WVKernelStatus {
    std::size_t sourceElements = 1;
    if (rank == WVFieldEvaluationPlan::NativeRank::volume)
      sourceElements = fieldElements;
    else if (rank == WVFieldEvaluationPlan::NativeRank::horizontal)
      sourceElements = horizontalElements;
    else if (rank == WVFieldEvaluationPlan::NativeRank::vertical)
      sourceElements = configuration.Nz;
    const double *samplingSource = source;
    std::size_t firstFullOutput = outputCount;
    std::size_t consumer = 0;
    for (const auto &request : plan.requests_) {
      if (request.field != field)
        continue;
      if (request.samplingKind == WVFieldSamplingKind::fullGrid &&
          firstFullOutput == outputCount) {
        std::copy(source, source + sourceElements,
                  outputs[request.outputIndex].data);
        samplingSource = outputs[request.outputIndex].data;
        firstFullOutput = request.outputIndex;
        ++metrics_.fullGridWriteCount;
        metrics_.outputElementWriteCount += sourceElements;
      }
      ++consumer;
    }
    if (consumer > 1)
      metrics_.primitiveFieldReuseCount += consumer - 1;
    for (const auto &request : plan.requests_) {
      if (request.field != field)
        continue;
      auto &output = outputs[request.outputIndex];
      if (request.samplingKind == WVFieldSamplingKind::fullGrid) {
        if (request.outputIndex != firstFullOutput) {
          std::copy(samplingSource, samplingSource + sourceElements,
                    output.data);
          ++metrics_.fullGridWriteCount;
          metrics_.outputElementWriteCount += sourceElements;
        }
        continue;
      }
      if (request.samplingKind ==
          WVFieldSamplingKind::fixedVerticalProfiles) {
        for (std::size_t profile = 0;
             profile < request.profileXIndices.size(); ++profile) {
          const auto horizontalIndex =
              request.profileXIndices[profile] +
              configuration.Nx * request.profileYIndices[profile];
          for (std::size_t z = 0; z < configuration.Nz; ++z)
            output.data[z + configuration.Nz * profile] =
                samplingSource[horizontalIndex + horizontalElements * z];
        }
        ++metrics_.profileWriteCount;
        metrics_.outputElementWriteCount += output.elementCount;
        continue;
      }
      for (std::size_t position = 0;
           position < request.positionWeights.size(); ++position) {
        const auto &weights = request.positionWeights[position];
        double value = 0.0;
        if (!weights.outsideInterpolationDomain) {
          if (request.interpolation == WVPositionInterpolation::linear) {
            const std::size_t zCount =
                rank == WVFieldEvaluationPlan::NativeRank::volume ? 2 : 1;
            for (std::size_t iz = 0; iz < zCount; ++iz)
              for (std::size_t iy = 0; iy < 2; ++iy)
                for (std::size_t ix = 0; ix < 2; ++ix) {
                  const auto zIndex =
                      rank == WVFieldEvaluationPlan::NativeRank::volume
                          ? weights.zLinearIndices[iz]
                          : 0;
                  const auto sourceIndex =
                      weights.xLinearIndices[ix] +
                      configuration.Nx * weights.yLinearIndices[iy] +
                      horizontalElements * zIndex;
                  const double zWeight =
                      rank == WVFieldEvaluationPlan::NativeRank::volume
                          ? weights.zLinearWeights[iz]
                          : 1.0;
                  value += samplingSource[sourceIndex] *
                           weights.xLinearWeights[ix] *
                           weights.yLinearWeights[iy] * zWeight;
                }
            ++metrics_.linearInterpolationCount;
          } else {
            const std::size_t zCount =
                rank == WVFieldEvaluationPlan::NativeRank::volume
                    ? configuration.Nz
                    : 1;
            for (std::size_t iz = 0; iz < zCount; ++iz)
              for (std::size_t iy = 0; iy < configuration.Ny; ++iy)
                for (std::size_t ix = 0; ix < configuration.Nx; ++ix) {
                  const auto sourceIndex = ix + configuration.Nx * iy +
                                           horizontalElements * iz;
                  const double zWeight =
                      rank == WVFieldEvaluationPlan::NativeRank::volume
                          ? weights.zSplineWeights[iz]
                          : 1.0;
                  value += samplingSource[sourceIndex] *
                           weights.xSplineWeights[ix] *
                           weights.ySplineWeights[iy] * zWeight;
                }
            ++metrics_.splineInterpolationCount;
          }
        } else if (request.interpolation == WVPositionInterpolation::linear) {
          ++metrics_.linearInterpolationCount;
        } else {
          ++metrics_.splineInterpolationCount;
        }
        output.data[position] = value;
      }
      metrics_.outputElementWriteCount += output.elementCount;
    }
    return WVKernelStatus::ok();
  };

  if ((plan.dependencyMask_ & primitiveValues) != 0) {
    updateScratchHighWater(4 * fieldElements, 0);
    WVRealFieldBundleView primitiveBundle{
        realScratch_.data(),
        {configuration.Nx, configuration.Ny, configuration.Nz, 4}};
    auto status = invokeTransform(
        [&]() { return transform_->transformWaveVortexToUVWEta(state, primitiveBundle); });
    if (!status)
      return status;
    const bool primitiveNeeded[] = {
        fieldRequested(WVFieldEvaluationPlan::Field::u) ||
            fieldRequested(WVFieldEvaluationPlan::Field::ssu) ||
            fieldRequested(WVFieldEvaluationPlan::Field::uvMax),
        fieldRequested(WVFieldEvaluationPlan::Field::v) ||
            fieldRequested(WVFieldEvaluationPlan::Field::ssv) ||
            fieldRequested(WVFieldEvaluationPlan::Field::uvMax),
        fieldRequested(WVFieldEvaluationPlan::Field::w) ||
            fieldRequested(WVFieldEvaluationPlan::Field::wMax),
        fieldRequested(WVFieldEvaluationPlan::Field::eta) ||
            fieldRequested(WVFieldEvaluationPlan::Field::rhoE) ||
            fieldRequested(WVFieldEvaluationPlan::Field::rhoTotal) ||
            fieldRequested(WVFieldEvaluationPlan::Field::rhoBar)};
    metrics_.primitiveFieldEvaluationCount +=
        static_cast<std::size_t>(primitiveNeeded[0]) +
        static_cast<std::size_t>(primitiveNeeded[1]) +
        static_cast<std::size_t>(primitiveNeeded[2]) +
        static_cast<std::size_t>(primitiveNeeded[3]);
    const double *u = realScratch_.data();
    const double *v = u + fieldElements;
    const double *w = v + fieldElements;
    const double *eta = w + fieldElements;
    if (fieldRequested(WVFieldEvaluationPlan::Field::u))
      writeField(WVFieldEvaluationPlan::Field::u,
                 WVFieldEvaluationPlan::NativeRank::volume, u);
    if (fieldRequested(WVFieldEvaluationPlan::Field::v))
      writeField(WVFieldEvaluationPlan::Field::v,
                 WVFieldEvaluationPlan::NativeRank::volume, v);
    if (fieldRequested(WVFieldEvaluationPlan::Field::w))
      writeField(WVFieldEvaluationPlan::Field::w,
                 WVFieldEvaluationPlan::NativeRank::volume, w);
    if (fieldRequested(WVFieldEvaluationPlan::Field::eta))
      writeField(WVFieldEvaluationPlan::Field::eta,
                 WVFieldEvaluationPlan::NativeRank::volume, eta);
    if (fieldRequested(WVFieldEvaluationPlan::Field::ssu))
      writeField(WVFieldEvaluationPlan::Field::ssu,
                 WVFieldEvaluationPlan::NativeRank::horizontal,
                 u + fieldElements - horizontalElements);
    if (fieldRequested(WVFieldEvaluationPlan::Field::ssv))
      writeField(WVFieldEvaluationPlan::Field::ssv,
                 WVFieldEvaluationPlan::NativeRank::horizontal,
                 v + fieldElements - horizontalElements);
    if (fieldRequested(WVFieldEvaluationPlan::Field::uvMax)) {
      double maximum = 0.0;
      for (std::size_t index = 0; index < fieldElements; ++index)
        maximum = std::max(maximum, std::sqrt(u[index] * u[index] +
                                              v[index] * v[index]));
      writeField(WVFieldEvaluationPlan::Field::uvMax,
                 WVFieldEvaluationPlan::NativeRank::scalar, &maximum);
    }
    if (fieldRequested(WVFieldEvaluationPlan::Field::wMax)) {
      double maximum = 0.0;
      for (std::size_t index = 0; index < fieldElements; ++index)
        maximum = std::max(maximum, std::abs(w[index]));
      writeField(WVFieldEvaluationPlan::Field::wMax,
                 WVFieldEvaluationPlan::NativeRank::scalar, &maximum);
    }
    double *derived = realScratch_.data() + 4 * fieldElements;
    const double densityScale =
        configuration.rho0 * configuration.N0 * configuration.N0 /
        configuration.g;
    if (fieldRequested(WVFieldEvaluationPlan::Field::rhoE) ||
        fieldRequested(WVFieldEvaluationPlan::Field::rhoTotal)) {
      updateScratchHighWater(5 * fieldElements, 0);
      for (std::size_t index = 0; index < fieldElements; ++index)
        derived[index] = densityScale * eta[index];
      if (fieldRequested(WVFieldEvaluationPlan::Field::rhoE))
        writeField(WVFieldEvaluationPlan::Field::rhoE,
                   WVFieldEvaluationPlan::NativeRank::volume, derived);
      if (fieldRequested(WVFieldEvaluationPlan::Field::rhoTotal)) {
        for (std::size_t z = 0; z < configuration.Nz; ++z) {
          const double rhoNoMotion =
              configuration.rho0 - densityScale *
                                       transform_->descriptor().verticalModes().z[z];
          for (std::size_t horizontal = 0; horizontal < horizontalElements;
               ++horizontal) {
            const auto index = horizontal + horizontalElements * z;
            derived[index] = rhoNoMotion + densityScale * eta[index];
          }
        }
        writeField(WVFieldEvaluationPlan::Field::rhoTotal,
                   WVFieldEvaluationPlan::NativeRank::volume, derived);
      }
    }
    if (fieldRequested(WVFieldEvaluationPlan::Field::rhoBar)) {
      updateScratchHighWater(4 * fieldElements + configuration.Nz, 0);
      for (std::size_t z = 0; z < configuration.Nz; ++z) {
        double meanEta = 0.0;
        for (std::size_t horizontal = 0; horizontal < horizontalElements;
             ++horizontal)
          meanEta += eta[horizontal + horizontalElements * z];
        meanEta /= static_cast<double>(horizontalElements);
        derived[z] =
            configuration.rho0 -
            densityScale * transform_->descriptor().verticalModes().z[z] +
            densityScale * meanEta;
      }
      writeField(WVFieldEvaluationPlan::Field::rhoBar,
                 WVFieldEvaluationPlan::NativeRank::vertical, derived);
    }
  }

  auto fillFFieldCoefficients = [&](WVFieldEvaluationPlan::Field field) {
    const auto &modes = transform_->descriptor().verticalModes();
    const auto &horizontalModes = transform_->descriptor().fourierModes();
    auto *wave = complexScratch_.data();
    auto *zeroFrequency = wave + coefficientElements;
    const double elapsed = state.t - state.t0;
    const double f = modes.coriolisFrequency;
    for (std::size_t mode = 0; mode < horizontalModes.size(); ++mode) {
      const double Kh2 = horizontalModes[mode].Kh * horizontalModes[mode].Kh;
      for (std::size_t j = 0; j < configuration.Nj; ++j) {
        const auto index = j + configuration.Nj * mode;
        wave[index] = {};
        zeroFrequency[index] = {};
        if (field == WVFieldEvaluationPlan::Field::pi) {
          const WVComplex64 phase{std::cos(modes.omega[index] * elapsed),
                                  std::sin(modes.omega[index] * elapsed)};
          const auto positive = multiply(state.coefficients.Ap.data[index], phase);
          const auto negative =
              multiply(state.coefficients.Am.data[index], conjugate(phase));
          const double rawNAp =
              modes.NApField[index] / modes.gWaveScale[j];
          wave[index] = multiply(subtract(positive, negative), rawNAp);
        }
        if (horizontalModes[mode].Kh > 0.0) {
          const double inverseRossbySquared =
              j == 0 ? 0.0 : f * f / (configuration.g * modes.h0[j]);
          const double denominator = Kh2 + inverseRossbySquared;
          if (field == WVFieldEvaluationPlan::Field::pi)
            zeroFrequency[index] =
                multiply(state.coefficients.A0.data[index],
                         -(f / configuration.g) / denominator);
          else if (field == WVFieldEvaluationPlan::Field::psi)
            zeroFrequency[index] =
                multiply(state.coefficients.A0.data[index], -1.0 / denominator);
          else if (field == WVFieldEvaluationPlan::Field::qgpv)
            zeroFrequency[index] = state.coefficients.A0.data[index];
        } else if (j > 0) {
          if (field == WVFieldEvaluationPlan::Field::pi)
            zeroFrequency[index] = state.coefficients.A0.data[index];
          else if (field == WVFieldEvaluationPlan::Field::psi)
            zeroFrequency[index] =
                multiply(state.coefficients.A0.data[index], configuration.g / f);
          else if (field == WVFieldEvaluationPlan::Field::qgpv)
            zeroFrequency[index] =
                multiply(state.coefficients.A0.data[index], -f / modes.h0[j]);
        }
      }
    }
  };

  auto evaluateFField = [&](WVFieldEvaluationPlan::Field field) {
    fillFFieldCoefficients(field);
    updateScratchHighWater(4 * fieldElements, 2 * coefficientElements);
    WVRealFieldBundleView fieldAndDerivatives{
        realScratch_.data(),
        {configuration.Nx, configuration.Ny, configuration.Nz, 4}};
    const WVComplexConstView wave{complexScratch_.data(), spectral};
    const WVComplexConstView zeroFrequency{
        complexScratch_.data() + coefficientElements, spectral};
    return invokeTransform([&]() {
      return transform_->transformToSpatialDomainWithFAllDerivatives(
          wave, zeroFrequency, fieldAndDerivatives);
    });
  };

  if ((plan.dependencyMask_ & pressureHeight) != 0) {
    auto status = evaluateFField(WVFieldEvaluationPlan::Field::pi);
    if (!status)
      return status;
    ++metrics_.primitiveFieldEvaluationCount;
    const double *pressureHeightField = realScratch_.data();
    if (fieldRequested(WVFieldEvaluationPlan::Field::pi))
      writeField(WVFieldEvaluationPlan::Field::pi,
                 WVFieldEvaluationPlan::NativeRank::volume,
                 pressureHeightField);
    if (fieldRequested(WVFieldEvaluationPlan::Field::p)) {
      double *pressure = realScratch_.data() + 4 * fieldElements;
      updateScratchHighWater(5 * fieldElements, 2 * coefficientElements);
      const double pressureScale = configuration.rho0 * configuration.g;
      for (std::size_t index = 0; index < fieldElements; ++index)
        pressure[index] = pressureScale * pressureHeightField[index];
      writeField(WVFieldEvaluationPlan::Field::p,
                 WVFieldEvaluationPlan::NativeRank::volume, pressure);
    }
    if (fieldRequested(WVFieldEvaluationPlan::Field::ssh))
      writeField(WVFieldEvaluationPlan::Field::ssh,
                 WVFieldEvaluationPlan::NativeRank::horizontal,
                 pressureHeightField + fieldElements - horizontalElements);
  }

  if ((plan.dependencyMask_ & streamfunction) != 0) {
    if (transform_->descriptor().verticalModes().coriolisFrequency == 0.0)
      return {WVKernelStatusCode::unsupportedOperation,
              "Streamfunction evaluation is undefined when the Coriolis frequency is zero."};
    auto status = evaluateFField(WVFieldEvaluationPlan::Field::psi);
    if (!status)
      return status;
    ++metrics_.primitiveFieldEvaluationCount;
    writeField(WVFieldEvaluationPlan::Field::psi,
               WVFieldEvaluationPlan::NativeRank::volume,
               realScratch_.data());
  }

  if ((plan.dependencyMask_ & potentialVorticity) != 0) {
    auto status = evaluateFField(WVFieldEvaluationPlan::Field::qgpv);
    if (!status)
      return status;
    ++metrics_.primitiveFieldEvaluationCount;
    writeField(WVFieldEvaluationPlan::Field::qgpv,
               WVFieldEvaluationPlan::NativeRank::volume,
               realScratch_.data());
  }

  if ((plan.dependencyMask_ & spectralEnergy) != 0) {
    const auto &modes = transform_->descriptor().verticalModes();
    const auto &horizontalModes = transform_->descriptor().fourierModes();
    const double f = modes.coriolisFrequency;
    double energy = 0.0;
    for (std::size_t mode = 0; mode < horizontalModes.size(); ++mode) {
      const double Kh = horizontalModes[mode].Kh;
      const double Kh2 = Kh * Kh;
      for (std::size_t j = 0; j < configuration.Nj; ++j) {
        const auto index = j + configuration.Nj * mode;
        const double M = modes.verticalWavenumber[j];
        double hWave = 1.0;
        if (j > 0)
          hWave = configuration.isHydrostatic
                      ? configuration.N0 * configuration.N0 /
                            (configuration.g * M * M)
                      : (configuration.N0 * configuration.N0 - f * f) /
                            (configuration.g * (M * M + Kh2));
        double waveFactor = 0.0;
        if (Kh > 0.0 && j > 0)
          waveFactor = 2.0 * hWave;
        else if (Kh == 0.0)
          waveFactor = j == 0 ? configuration.Lz : hWave;
        double zeroFactor = 0.0;
        if (Kh > 0.0) {
          if (j == 0)
            zeroFactor = configuration.Lz / Kh2;
          else {
            const double denominator =
                Kh2 + f * f / (configuration.g * modes.h0[j]);
            zeroFactor = modes.h0[j] / denominator;
          }
        } else if (j > 0) {
          zeroFactor = configuration.g / 2.0;
        }
        energy += waveFactor *
                      (squaredMagnitude(state.coefficients.Ap.data[index]) +
                       squaredMagnitude(state.coefficients.Am.data[index])) +
                  zeroFactor *
                      squaredMagnitude(state.coefficients.A0.data[index]);
      }
    }
    writeField(WVFieldEvaluationPlan::Field::energy,
               WVFieldEvaluationPlan::NativeRank::scalar, &energy);
  }

  const auto derivativeDependencies =
      uDerivatives | vDerivatives | wDerivatives;
  if ((plan.dependencyMask_ & derivativeDependencies) != 0) {
    updateScratchHighWater(6 * fieldElements, 0);
    double *zetaX = realScratch_.data();
    double *zetaY = zetaX + fieldElements;
    double *zetaZ = zetaY + fieldElements;
    double *derivatives = zetaZ + fieldElements;
    std::fill(zetaX, zetaX + 3 * fieldElements, 0.0);
    WVRealFieldBundleView derivativeBundle{
        derivatives,
        {configuration.Nx, configuration.Ny, configuration.Nz, 3}};
    if ((plan.dependencyMask_ & uDerivatives) != 0) {
      auto status = invokeTransform([&]() {
        return transform_->transformStateFieldDerivatives(
            state, WVDynamicalField::u, derivativeBundle);
      });
      if (!status)
        return status;
      ++metrics_.primitiveFieldEvaluationCount;
      const double *uy = derivatives + fieldElements;
      const double *uz = uy + fieldElements;
      for (std::size_t index = 0; index < fieldElements; ++index) {
        zetaY[index] += uz[index];
        zetaZ[index] -= uy[index];
      }
    }
    if ((plan.dependencyMask_ & vDerivatives) != 0) {
      auto status = invokeTransform([&]() {
        return transform_->transformStateFieldDerivatives(
            state, WVDynamicalField::v, derivativeBundle);
      });
      if (!status)
        return status;
      ++metrics_.primitiveFieldEvaluationCount;
      const double *vx = derivatives;
      const double *vz = derivatives + 2 * fieldElements;
      for (std::size_t index = 0; index < fieldElements; ++index) {
        zetaX[index] -= vz[index];
        zetaZ[index] += vx[index];
      }
    }
    if ((plan.dependencyMask_ & wDerivatives) != 0) {
      auto status = invokeTransform([&]() {
        return transform_->transformStateFieldDerivatives(
            state, WVDynamicalField::w, derivativeBundle);
      });
      if (!status)
        return status;
      ++metrics_.primitiveFieldEvaluationCount;
      const double *wx = derivatives;
      const double *wy = derivatives + fieldElements;
      for (std::size_t index = 0; index < fieldElements; ++index) {
        zetaX[index] += wy[index];
        zetaY[index] -= wx[index];
      }
    }
    if (fieldRequested(WVFieldEvaluationPlan::Field::zetaX))
      writeField(WVFieldEvaluationPlan::Field::zetaX,
                 WVFieldEvaluationPlan::NativeRank::volume, zetaX);
    if (fieldRequested(WVFieldEvaluationPlan::Field::zetaY))
      writeField(WVFieldEvaluationPlan::Field::zetaY,
                 WVFieldEvaluationPlan::NativeRank::volume, zetaY);
    if (fieldRequested(WVFieldEvaluationPlan::Field::zetaZ))
      writeField(WVFieldEvaluationPlan::Field::zetaZ,
                 WVFieldEvaluationPlan::NativeRank::volume, zetaZ);
  }

  return WVKernelStatus::ok();
}

const WVTransformConstantStratificationConfiguration &
WVFieldEvaluationService::configuration() const noexcept {
  return transform_->descriptor().configuration();
}

std::size_t WVFieldEvaluationService::persistentBytes() const noexcept {
  return sizeof(*this) + transform_->persistentBytes() +
         realScratch_.capacity() * sizeof(double) +
         complexScratch_.capacity() * sizeof(WVComplex64);
}

} // namespace wavevortex::runtime
