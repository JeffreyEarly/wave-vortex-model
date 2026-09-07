#include "WVSpectralValidation.hpp"
#include <new>

namespace wavevortex {
namespace spectral_detail {
struct HorizontalMode {
    std::size_t row, partner;
    bool conjugate, self;
};
struct HorizontalData {
    WVRetainedHorizontalSpecification spec;
    std::vector<HorizontalMode> mapping;
    std::unique_ptr<WVFFTEngine> engine;
    std::size_t realSpan = 0, complexSpan = 0, planeSize = 0, halfSize = 0;
    double forwardScale = 1, inverseScale = 1;
};
struct HorizontalWorkspaceData {
    std::shared_ptr<const HorizontalData> owner;
    std::unique_ptr<WVFFTPlan> forward, inverse;
    std::vector<double> real;
    std::vector<WVComplex64> half;
    std::atomic<bool> active{false};
};

std::size_t gridSpan(const WVRealGridLayout& grid) {
    if (grid.family.empty() || !grid.Nx || !grid.Ny || !grid.planes || !grid.xStride || !grid.yStride || !grid.planeStride)
        throw std::invalid_argument("Grid dimensions, strides and family must be specified.");
    // A permuted, padded nested grid is supported. Interleaving dimensions with
    // overlapping bounding intervals is rejected rather than guessed safe.
    std::array<std::pair<std::size_t,std::size_t>,3> dims{{{grid.xStride,grid.Nx},{grid.yStride,grid.Ny},{grid.planeStride,grid.planes}}};
    std::sort(dims.begin(),dims.end());
    std::size_t extent = 1;
    for (const auto& dim : dims) {
        if (dim.second > 1 && dim.first < extent) throw std::invalid_argument("Grid strides overlap.");
        const auto extra = product(dim.first,dim.second-1);
        if (extra > static_cast<std::size_t>(PTRDIFF_MAX)-extent) throw std::overflow_error("Grid span overflow.");
        extent += extra;
    }
    return product(extent,sizeof(double));
}
std::size_t index(std::int64_t mode, std::size_t count) {
    const auto half = static_cast<std::int64_t>(count/2);
    if (mode < -half || mode > half) throw std::invalid_argument("Retained Fourier mode lies outside the grid.");
    return mode < 0 ? static_cast<std::size_t>(static_cast<std::int64_t>(count)+mode) : static_cast<std::size_t>(mode);
}
WVFFTPlanSpecification fftSpecification(const HorizontalData& data, bool inverse) {
    const auto& g = data.spec.grid;
    WVFFTPlanSpecification s;
    s.kind = inverse ? WVFFTPlanKind::horizontalComplexToReal2D : WVFFTPlanKind::horizontalRealToComplex2D;
    s.transformDimensions = {{g.Ny,static_cast<std::ptrdiff_t>(g.Nx),static_cast<std::ptrdiff_t>(g.Nx/2+1)},{g.Nx,1,1}};
    s.batchDimensions = {{g.planes,static_cast<std::ptrdiff_t>(data.planeSize),static_cast<std::ptrdiff_t>(data.halfSize)}};
    s.inputBytes = product(product(data.planeSize,g.planes),sizeof(double));
    s.outputBytes = product(product(data.halfSize,g.planes),sizeof(WVComplex64));
    s.destroysInput = inverse; // Only disposable workspace is passed to the full inverse.
    if (inverse) {
        for (auto& d : s.transformDimensions) std::swap(d.inputStride,d.outputStride);
        for (auto& d : s.batchDimensions) std::swap(d.inputStride,d.outputStride);
        std::swap(s.inputBytes,s.outputBytes);
    }
    return s;
}
WVKernelStatus validateHorizontalBuffers(const HorizontalData& d, WVRealInput real, WVComplexInput complex) {
    if (real.bytes < d.realSpan) return {WVKernelStatusCode::invalidShape,"Real grid buffer capacity is too small."};
    if (!addressFits(real.data,d.realSpan,alignof(double))) return {WVKernelStatusCode::invalidPointer,"Invalid real grid storage."};
    auto status = validateStorage(d.spec.retained.representation,d.complexSpan,complex);
    if (!status) return status;
    if (realOverlap(real.data,d.realSpan,complex,d.complexSpan)) return {WVKernelStatusCode::overlappingArrays,"Horizontal input and output overlap."};
    return WVKernelStatus::ok();
}
} // namespace spectral_detail
using namespace spectral_detail;

WVRetainedHorizontalWorkspace::WVRetainedHorizontalWorkspace() = default;
WVRetainedHorizontalWorkspace::~WVRetainedHorizontalWorkspace() = default;
std::size_t WVRetainedHorizontalWorkspace::persistentBytes() const noexcept {
    return sizeof(*this)+sizeof(*data_)+data_->real.capacity()*sizeof(double)+data_->half.capacity()*sizeof(WVComplex64);
}
std::size_t WVRetainedHorizontalWorkspace::planBytesLowerBound() const noexcept {
    return data_->forward->persistentBytes()+data_->inverse->persistentBytes();
}
std::size_t WVRetainedHorizontalOperator::persistentBytes() const noexcept {
    return sizeof(*this)+sizeof(*data_)+identityBytes(data_->spec.retained)+data_->spec.grid.family.capacity()+
        data_->spec.modes.capacity()*sizeof(WVRetainedModeKey)+data_->mapping.capacity()*sizeof(HorizontalMode);
}
std::size_t WVRetainedHorizontalOperator::providerBytesLowerBound() const noexcept { return data_->engine->persistentBytes(); }
WVKernelStatus WVRetainedHorizontalOperator::create(const WVRetainedHorizontalSpecification& spec,
    std::unique_ptr<WVFFTEngine> engine, std::unique_ptr<WVRetainedHorizontalOperator>& result) {
    try {
        if (!engine) return {WVKernelStatusCode::invalidPointer,"A full FFT provider is required."};
        if (spec.placement != WVOperatorPlacement::outOfPlace) return {WVKernelStatusCode::unsupportedOperation,"Retained horizontal execution is out-of-place."};
        if (!std::isfinite(spec.Lx) || !std::isfinite(spec.Ly) || spec.Lx <= 0 || spec.Ly <= 0)
            return {WVKernelStatusCode::invalidConfiguration,"Domain lengths must be finite and positive."};
        if (spec.grid.Nx > static_cast<std::size_t>(INT64_MAX) || spec.grid.Ny > static_cast<std::size_t>(INT64_MAX))
            return {WVKernelStatusCode::sizeOverflow,"Fourier grid exceeds signed mode-key range."};
        const auto rs = gridSpan(spec.grid), cs = validate(spec.retained);
        if (spec.retained.rows != spec.grid.planes || spec.retained.columns != spec.modes.size() || spec.grid.family != spec.retained.family)
            return {WVKernelStatusCode::invalidShape,"Horizontal families and extents must match the retained set."};
        auto d = std::make_shared<HorizontalData>();
        d->spec = spec; d->engine = std::move(engine); d->realSpan = rs; d->complexSpan = cs;
        d->planeSize = product(spec.grid.Nx,spec.grid.Ny);
        d->halfSize = product(spec.grid.Nx/2+1,spec.grid.Ny);
        // Check all execution allocations at preparation, before allocating the visited set.
        product(product(d->planeSize,spec.grid.planes),sizeof(double));
        product(product(d->halfSize,spec.grid.planes),sizeof(WVComplex64));
        switch (spec.normalization) {
            case WVFourierNormalization::forwardUnit: d->forwardScale = 1.0/d->planeSize; break;
            case WVFourierNormalization::unitary: d->forwardScale = d->inverseScale = 1.0/std::sqrt(static_cast<double>(d->planeSize)); break;
            case WVFourierNormalization::inverseUnit: d->inverseScale = 1.0/d->planeSize; break;
            default: return {WVKernelStatusCode::invalidConfiguration,"Unknown Fourier normalization."};
        }
        std::vector<bool> visited(d->planeSize,false);
        const auto nx = spec.grid.Nx, ny = spec.grid.Ny, half = nx/2+1;
        for (const auto& key : spec.modes) {
            const auto x = index(key.k,nx), y = index(key.l,ny);
            const auto cx = (nx-x)%nx, cy = (ny-y)%ny;
            if (visited[x+nx*y] || visited[cx+nx*cy]) return {WVKernelStatusCode::invalidConfiguration,"Retained set repeats a Hermitian orbit."};
            visited[x+nx*y] = visited[cx+nx*cy] = true;
            const bool conjugate = x > nx/2;
            const auto sx = conjugate ? cx : x, sy = conjugate ? cy : y;
            const bool boundary = sx == 0 || (nx%2 == 0 && sx == nx/2);
            const auto row = sx+half*sy;
            d->mapping.push_back({row,boundary ? sx+half*((ny-sy)%ny) : row,conjugate,x == cx && y == cy});
        }
        auto op = std::unique_ptr<WVRetainedHorizontalOperator>(new WVRetainedHorizontalOperator);
        op->data_ = std::move(d); result = std::move(op);
        return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Horizontal setup allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
      catch (const std::invalid_argument& e) { return {WVKernelStatusCode::invalidConfiguration,e.what()}; }
}
WVKernelStatus WVRetainedHorizontalOperator::createWorkspace(std::unique_ptr<WVRetainedHorizontalWorkspace>& result) const {
    try {
        auto w = std::unique_ptr<WVRetainedHorizontalWorkspace>(new WVRetainedHorizontalWorkspace);
        w->data_ = std::make_unique<HorizontalWorkspaceData>();
        auto& d = *w->data_; d.owner = data_;
        d.real.resize(product(data_->planeSize,data_->spec.grid.planes));
        d.half.resize(product(data_->halfSize,data_->spec.grid.planes));
        auto status = data_->engine->createPlan(fftSpecification(*data_,false),d.forward);
        if (!status) return status;
        status = data_->engine->createPlan(fftSpecification(*data_,true),d.inverse);
        if (!status) return status;
        if (!d.forward || !d.inverse) return {WVKernelStatusCode::fftPlanFailure,"Provider returned an empty plan."};
        result = std::move(w); return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Horizontal workspace allocation failed."}; }
}
WVKernelStatus WVRetainedHorizontalOperator::forward(WVRetainedHorizontalWorkspace& workspace, WVRealInput input, WVComplexOutput output) const {
    auto& w = *workspace.data_; const auto& d = *data_;
    if (w.owner != data_) return {WVKernelStatusCode::invalidConfiguration,"Workspace belongs to another horizontal operator."};
    auto status = validateHorizontalBuffers(d,input,output.input()); if (!status) return status;
    ActiveCall guard(w.active); if (!guard.entered) return {WVKernelStatusCode::reentrantExecution,"Horizontal workspace is active."};
    const auto& g = d.spec.grid; const auto& l = d.spec.retained;
    for (std::size_t p = 0; p < g.planes; ++p) for (std::size_t y = 0; y < g.Ny; ++y) for (std::size_t x = 0; x < g.Nx; ++x)
        w.real[p*d.planeSize+y*g.Nx+x] = input.data[p*g.planeStride+y*g.yStride+x*g.xStride];
    status = w.forward->execute(w.real.data(),w.half.data()); if (!status) return status;
    for (std::size_t mode = 0; mode < d.mapping.size(); ++mode) for (std::size_t p = 0; p < g.planes; ++p) {
        const auto& map = d.mapping[mode]; auto value = w.half[p*d.halfSize+map.row];
        value.real *= d.forwardScale; value.imag *= map.conjugate ? -d.forwardScale : d.forwardScale;
        if (map.self) value.imag = 0;
        write(output,p*l.rowStride+mode*l.columnStride,value);
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVRetainedHorizontalOperator::inverse(WVRetainedHorizontalWorkspace& workspace, WVComplexInput input, WVRealOutput output) const {
    auto& w = *workspace.data_; const auto& d = *data_;
    if (w.owner != data_) return {WVKernelStatusCode::invalidConfiguration,"Workspace belongs to another horizontal operator."};
    auto status = validateHorizontalBuffers(d,{output.data,output.bytes},input); if (!status) return status;
    ActiveCall guard(w.active); if (!guard.entered) return {WVKernelStatusCode::reentrantExecution,"Horizontal workspace is active."};
    const auto& g = d.spec.grid; const auto& l = d.spec.retained;
    // Validate all self-conjugate values before writing any caller output.
    for (std::size_t mode = 0; mode < d.mapping.size(); ++mode) if (d.mapping[mode].self)
        for (std::size_t p = 0; p < g.planes; ++p) if (read(input,p*l.rowStride+mode*l.columnStride).imag != 0)
            return {WVKernelStatusCode::invalidConfiguration,"Self-conjugate Fourier values must be real."};
    std::fill(w.half.begin(),w.half.end(),WVComplex64{});
    for (std::size_t mode = 0; mode < d.mapping.size(); ++mode) for (std::size_t p = 0; p < g.planes; ++p) {
        const auto& map = d.mapping[mode]; auto value = read(input,p*l.rowStride+mode*l.columnStride);
        if (map.conjugate) value.imag = -value.imag;
        w.half[p*d.halfSize+map.row] = value;
        if (map.partner != map.row) w.half[p*d.halfSize+map.partner] = {value.real,-value.imag};
    }
    status = w.inverse->execute(w.half.data(),w.real.data()); if (!status) return status;
    for (std::size_t p = 0; p < g.planes; ++p) for (std::size_t y = 0; y < g.Ny; ++y) for (std::size_t x = 0; x < g.Nx; ++x)
        output.data[p*g.planeStride+y*g.yStride+x*g.xStride] = d.inverseScale*w.real[p*d.planeSize+y*g.Nx+x];
    return WVKernelStatus::ok();
}
WVKernelStatus WVRetainedHorizontalOperator::spatialDerivative(WVRetainedHorizontalWorkspace& workspace, WVRealInput input, WVRealOutput output, bool xDerivative) const {
    auto& w = *workspace.data_; const auto& d = *data_;
    if (w.owner != data_) return {WVKernelStatusCode::invalidConfiguration,"Workspace belongs to another horizontal operator."};
    if (input.bytes < d.realSpan || output.bytes < d.realSpan) return {WVKernelStatusCode::invalidShape,"Derivative grid capacity is too small."};
    if (!addressFits(input.data,d.realSpan,alignof(double)) || !addressFits(output.data,d.realSpan,alignof(double)))
        return {WVKernelStatusCode::invalidPointer,"Invalid derivative grid storage."};
    if (overlap(input.data,d.realSpan,output.data,d.realSpan)) return {WVKernelStatusCode::overlappingArrays,"Derivative input and output overlap."};
    ActiveCall guard(w.active); if (!guard.entered) return {WVKernelStatusCode::reentrantExecution,"Horizontal workspace is active."};
    const auto& g = d.spec.grid;
    for (std::size_t p = 0; p < g.planes; ++p) for (std::size_t y = 0; y < g.Ny; ++y) for (std::size_t x = 0; x < g.Nx; ++x)
        w.real[p*d.planeSize+y*g.Nx+x] = input.data[p*g.planeStride+y*g.yStride+x*g.xStride];
    auto status = w.forward->execute(w.real.data(),w.half.data()); if (!status) return status;
    const auto half = g.Nx/2+1;
    for (std::size_t p = 0; p < g.planes; ++p) for (std::size_t y = 0; y < g.Ny; ++y) for (std::size_t x = 0; x < half; ++x) {
        const auto i = xDerivative ? x : y, n = xDerivative ? g.Nx : g.Ny;
        const auto mode = i <= n/2 ? static_cast<std::int64_t>(i) : static_cast<std::int64_t>(i)-static_cast<std::int64_t>(n);
        const double k = n%2 == 0 && i == n/2 ? 0.0 : 2*std::acos(-1.0)*mode/(xDerivative ? d.spec.Lx : d.spec.Ly)/d.planeSize;
        auto& value = w.half[p*d.halfSize+y*half+x]; value = {-k*value.imag,k*value.real};
    }
    status = w.inverse->execute(w.half.data(),w.real.data()); if (!status) return status;
    for (std::size_t p = 0; p < g.planes; ++p) for (std::size_t y = 0; y < g.Ny; ++y) for (std::size_t x = 0; x < g.Nx; ++x)
        output.data[p*g.planeStride+y*g.yStride+x*g.xStride] = w.real[p*d.planeSize+y*g.Nx+x];
    return WVKernelStatus::ok();
}
} // namespace wavevortex
