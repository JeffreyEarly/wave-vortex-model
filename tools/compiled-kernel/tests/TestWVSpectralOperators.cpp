#include "WaveVortexKernel/WVSpectralOperators.hpp"
#include <WVReferenceFFTEngine.hpp>
#include "WVAccelerateMatrixBackend.hpp"
#include "WVAllocationProbe.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <complex>
#include <cstring>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <thread>
#if WV_TEST_NATIVE_FFTW
#include "WVNativeFFTWEngine.hpp"
#endif

using namespace wavevortex;
namespace {
void require(bool condition, const char* message) { if (!condition) throw std::runtime_error(message); }
void require(WVKernelStatus status) { if (!status) throw std::runtime_error(status.message); }
void close(double a, double b) { require(std::abs(a-b) <= 2e-12*(1+std::abs(b)),"Independent oracle mismatch"); }
void close(WVComplex64 a, std::complex<long double> b) { close(a.real,static_cast<double>(b.real())); close(a.imag,static_cast<double>(b.imag())); }
template <typename T> bool same(const std::vector<T>& a, const std::vector<T>& b) {
    return a.size() == b.size() && (a.empty() || std::memcmp(a.data(),b.data(),a.size()*sizeof(T)) == 0);
}
struct Buffer {
    WVComplexLayout layout;
    std::vector<WVComplex64> z;
    std::vector<double> r, i;
    explicit Buffer(WVComplexLayout l) : layout(std::move(l)) {
        const auto size = 1+(layout.rows-1)*layout.rowStride+(layout.columns-1)*layout.columnStride;
        if (layout.representation == WVComplexRepresentation::interleaved) z.resize(size,{121,122});
        else { r.resize(size,121); i.resize(size,122); }
    }
    WVComplexOutput out() { return {z.empty() ? nullptr : z.data(),r.empty() ? nullptr : r.data(),i.empty() ? nullptr : i.data(),z.empty() ? r.size()*sizeof(double) : z.size()*sizeof(WVComplex64)}; }
    WVComplexInput in() const { return {z.empty() ? nullptr : z.data(),r.empty() ? nullptr : r.data(),i.empty() ? nullptr : i.data(),z.empty() ? r.size()*sizeof(double) : z.size()*sizeof(WVComplex64)}; }
    WVComplex64 get(std::size_t row, std::size_t column) const {
        const auto n = row*layout.rowStride+column*layout.columnStride;
        return z.empty() ? WVComplex64{r[n],i[n]} : z[n];
    }
    void set(std::size_t row, std::size_t column, WVComplex64 value) {
        const auto n = row*layout.rowStride+column*layout.columnStride;
        if (z.empty()) { r[n] = value.real; i[n] = value.imag; } else z[n] = value;
    }
    bool equals(const Buffer& b) const { return same(z,b.z) && same(r,b.r) && same(i,b.i); }
    void paddingUnchanged() const {
        std::vector<bool> visited(z.empty() ? r.size() : z.size(),false);
        for (std::size_t c = 0; c < layout.columns; ++c) for (std::size_t row = 0; row < layout.rows; ++row) visited[row*layout.rowStride+c*layout.columnStride] = true;
        for (std::size_t n = 0; n < visited.size(); ++n) if (!visited[n]) {
            if (z.empty()) require(r[n] == 121 && i[n] == 122,"Split padding changed");
            else require(z[n].real == 121 && z[n].imag == 122,"Complex padding changed");
        }
    }
};
std::unique_ptr<WVVerticalMatrixBackend> backend(bool native) {
    std::unique_ptr<WVVerticalMatrixBackend> b;
    require(native ? WVCreateAccelerateMatrixBackend(b) : WVCreateScalarMatrixBackend(b)); return b;
}
struct MatrixCall {
    std::size_t width=0,ldb=0,ldc=0;
    const void* input=nullptr;
    void* output=nullptr;
    double beta=0;
    bool split=false;
};
struct MatrixTrace {
    std::array<MatrixCall,16> calls{};
    std::size_t count=0;
    bool recording=true,overflow=false;
};
class TracingBackend final : public WVVerticalMatrixBackend {
public:
    TracingBackend(MatrixTrace& trace,std::unique_ptr<WVVerticalMatrixBackend> inner,
        bool concurrent = true) : trace_(trace),inner_(std::move(inner)),concurrent_(concurrent) {}
    const char* identifier() const noexcept override { return "tracing-scalar"; }
    std::size_t maximumDimension() const noexcept override { return inner_->maximumDimension(); }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this)+inner_->persistentBytes(); }
    bool supportsConcurrentCalls() const noexcept override {
        return concurrent_ && inner_->supportsConcurrentCalls();
    }
    void split(std::size_t m,std::size_t k,std::size_t n,const double* a,const double* br,const double* bi,
        std::size_t ldb,double* cr,double* ci,std::size_t ldc,double beta) const noexcept override {
        record(n,ldb,ldc,br,cr,beta,true); inner_->split(m,k,n,a,br,bi,ldb,cr,ci,ldc,beta);
    }
    void interleaved(std::size_t m,std::size_t k,std::size_t n,const WVComplex64* a,const WVComplex64* b,
        std::size_t ldb,WVComplex64* c,std::size_t ldc,double beta) const noexcept override {
        record(n,ldb,ldc,b,c,beta,false); inner_->interleaved(m,k,n,a,b,ldb,c,ldc,beta);
    }
private:
    void record(std::size_t width,std::size_t ldb,std::size_t ldc,const void* input,void* output,double beta,bool split) const noexcept {
        if (!trace_.recording) return;
        if (trace_.count==trace_.calls.size()) { trace_.overflow=true; return; }
        trace_.calls[trace_.count++]={width,ldb,ldc,input,output,beta,split};
    }
    MatrixTrace& trace_;
    std::unique_ptr<WVVerticalMatrixBackend> inner_;
    bool concurrent_;
};
std::unique_ptr<WVVerticalMatrixBackend> tracingBackend(MatrixTrace& trace,bool native = false,
    bool concurrent = true) {
    return std::make_unique<TracingBackend>(trace,backend(native),concurrent);
}
std::unique_ptr<WVFFTEngine> fft(bool native) {
#if WV_TEST_NATIVE_FFTW
    if (native) { std::unique_ptr<WVFFTEngine> e; require(WVFFTWEngine::create(1,e)); return e; }
#else
    (void)native;
#endif
    return std::make_unique<WVReferenceFFTEngine>();
}
WVRetainedHorizontalSpecification horizontalSpecification(std::size_t nx, std::size_t ny, bool mask,
    WVComplexRepresentation representation, WVFourierNormalization normalization, bool special) {
    WVRetainedHorizontalSpecification s;
    s.grid = {nx,ny,3,2,2*nx+1,(2*nx+1)*ny+2,"F"};
    s.Lx = 19000; s.Ly = 11000; s.normalization = normalization;
    if (special) s.modes = {{4,1},{0,3},{-1,2},{0,0},{4,3},{0,1},{4,0},{1,0}};
    else {
        WVTransformConstantStratificationConfiguration c;
        c.Nx=nx; c.Ny=ny; c.Nz=7; c.Nj=3; c.Lx=s.Lx; c.Ly=s.Ly; c.Lz=1300; c.N0=5.2e-3;
        c.rho0=1025; c.g=9.81; c.planetaryRadius=6.371e6; c.rotationRate=7.2921e-5; c.latitude=33; c.shouldAntialias=mask;
        WVTransformConstantStratificationDescriptor d; require(WVTransformConstantStratificationDescriptor::create(c,d));
        for (auto it = d.fourierModes().rbegin(); it != d.fourierModes().rend(); ++it) s.modes.push_back({it->kMode,it->lMode});
    }
    s.retained = {3,s.modes.size(),2,9,representation,"F",mask ? "exact-wvm-masked" : "exact-wvm-unmasked"};
    return s;
}
void horizontalCase(std::size_t nx, std::size_t ny, bool mask, WVComplexRepresentation representation,
    WVFourierNormalization normalization, bool special, bool native) {
    auto spec = horizontalSpecification(nx,ny,mask,representation,normalization,special);
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,fft(native),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> w; require(op->createWorkspace(w));
    const auto& g = spec.grid;
    const auto size = 1+(nx-1)*g.xStride+(ny-1)*g.yStride+2*g.planeStride;
    std::vector<double> input(size,321), output(size,654);
    std::vector<bool> written(size,false);
    for (std::size_t p = 0; p < 3; ++p) for (std::size_t y = 0; y < ny; ++y) for (std::size_t x = 0; x < nx; ++x) {
        const auto n = x*g.xStride+y*g.yStride+p*g.planeStride; written[n] = true;
        input[n] = std::sin(0.37*(1+x+3*y+7*p))+0.1*p;
    }
    const auto original = input;
    WVRealInput real{input.data(),input.size()*sizeof(double)}; WVRealOutput destination{output.data(),output.size()*sizeof(double)};
    Buffer retained(spec.retained);
    require(op->forward(*w,real,retained.out()));
    const auto pi = std::acos(-1.0L);
    long double forwardScale = normalization == WVFourierNormalization::forwardUnit ? 1.0L/(nx*ny) : normalization == WVFourierNormalization::unitary ? 1/std::sqrt(static_cast<long double>(nx*ny)) : 1;
    long double inverseScale = normalization == WVFourierNormalization::inverseUnit ? 1.0L/(nx*ny) : normalization == WVFourierNormalization::unitary ? 1/std::sqrt(static_cast<long double>(nx*ny)) : 1;
    for (std::size_t mode = 0; mode < spec.modes.size(); ++mode) for (std::size_t p = 0; p < 3; ++p) {
        std::complex<long double> expected{};
        const auto key = spec.modes[mode];
        for (std::size_t y = 0; y < ny; ++y) for (std::size_t x = 0; x < nx; ++x) {
            const long double angle = -2*pi*(static_cast<long double>(key.k)*x/nx+static_cast<long double>(key.l)*y/ny);
            expected += static_cast<long double>(input[x*g.xStride+y*g.yStride+p*g.planeStride])*std::complex<long double>(std::cos(angle),std::sin(angle));
        }
        close(retained.get(p,mode),forwardScale*expected);
    }
    require(same(input,original),"Forward modified real input"); retained.paddingUnchanged();
    const auto saved = retained;
    require(op->inverse(*w,retained.in(),destination));
    for (std::size_t p = 0; p < 3; ++p) for (std::size_t y = 0; y < ny; ++y) for (std::size_t x = 0; x < nx; ++x) {
        long double expected = 0;
        for (std::size_t mode = 0; mode < spec.modes.size(); ++mode) {
            const auto key = spec.modes[mode]; const auto value = retained.get(p,mode);
            const bool self = (2*key.k)%static_cast<std::int64_t>(nx) == 0 && (2*key.l)%static_cast<std::int64_t>(ny) == 0;
            const long double angle = 2*pi*(static_cast<long double>(key.k)*x/nx+static_cast<long double>(key.l)*y/ny);
            expected += (self ? 1 : 2)*(value.real*std::cos(angle)-value.imag*std::sin(angle));
        }
        close(output[x*g.xStride+y*g.yStride+p*g.planeStride],static_cast<double>(inverseScale*expected));
    }
    require(retained.equals(saved),"Inverse modified retained input");
    for (std::size_t i = 0; i < size; ++i) if (!written[i]) require(output[i] == 654,"Inverse changed real padding");
    // Projecting a retained synthesis recovers each exact retained coefficient.
    Buffer recovered(spec.retained);
    require(op->forward(*w,{output.data(),destination.bytes},recovered.out()));
    for (std::size_t c = 0; c < spec.modes.size(); ++c) for (std::size_t p = 0; p < 3; ++p) close(recovered.get(p,c),{saved.get(p,c).real,saved.get(p,c).imag});
    allocationProbe::calls = 0; allocationProbe::counting = true;
    for (int i = 0; i < 5; ++i) { require(op->forward(*w,real,retained.out())); require(op->inverse(*w,retained.in(),destination)); }
    allocationProbe::counting = false;
    require(allocationProbe::calls == 0,"Prepared horizontal execution allocated");
    require(retained.equals(saved) && same(input,original),"Repeated horizontal execution changed input or result");
}

struct VerticalFixture {
    WVVerticalSpecification spec;
    std::vector<double> a, b;
    VerticalFixture(WVMatrixAction action, WVComplexRepresentation representation, WVAccumulation accumulation, bool direct, std::size_t Nz = 5, std::size_t Nj = 3) {
        spec.Nz = Nz; spec.Nj = Nj; spec.action = action; spec.accumulation = accumulation; spec.sourceIdentity = "profile-A/basis-3/normalization-1";
        const auto m = action == WVMatrixAction::reconstruction ? spec.Nz : spec.Nj;
        const auto k = action == WVMatrixAction::projection ? spec.Nz : spec.Nj;
        const std::size_t rs = direct ? 1 : 2;
        spec.input = {k,7,rs,rs*k+3,representation,"G-modal","exact-Boussinesq-membership"};
        spec.output = {m,7,rs,rs*m+3,representation,"F-result","exact-Boussinesq-membership"};
        a.resize((m+2)*k,std::numeric_limits<double>::quiet_NaN()); b.resize((2*m+3)*k,std::numeric_limits<double>::quiet_NaN());
        for (std::size_t c = 0; c < k; ++c) for (std::size_t r = 0; r < m; ++r) {
            a[r+(m+2)*c] = c == 0 ? 0 : 0.3+r-0.7*c;
            b[2*r+(2*m+3)*c] = 0.2+r*0.13+c*0.27;
        }
        spec.matrices = {{{spec.sourceIdentity,"PF-group-3"},{a.data(),m,k,1,m+2,a.size()*sizeof(double)},action,spec.input.family,spec.output.family},{{spec.sourceIdentity,"PF-group-91"},{b.data(),m,k,2,2*m+3,b.size()*sizeof(double)},action,spec.input.family,spec.output.family}};
        spec.groups = {{3,0,direct ? std::vector<std::size_t>{0,1,2} : std::vector<std::size_t>{6,0,2}},
                       {91,1,direct ? std::vector<std::size_t>{3,4,5,6} : std::vector<std::size_t>{1,3,5,4}}};
    }
};
void verticalCase(WVMatrixAction action, WVComplexRepresentation representation, WVAccumulation accumulation, bool direct, bool native, std::size_t Nz = 5, std::size_t Nj = 3) {
    VerticalFixture f(action,representation,accumulation,direct,Nz,Nj);
    std::unique_ptr<WVPreparedVerticalOperator> op; require(WVPreparedVerticalOperator::create(f.spec,backend(native),op));
    std::unique_ptr<WVVerticalWorkspace> w; require(op->createWorkspace(w));
    require(op->uniqueMatrixCount() == 2,"Exact matrix families collapsed");
    const auto expectedBytes = f.spec.input.rows*f.spec.output.rows*2*(representation == WVComplexRepresentation::split ? sizeof(double) : sizeof(WVComplex64));
    require(op->matrixBytes() == expectedBytes,"Matrices expanded per horizontal mode");
    Buffer input(f.spec.input), output(f.spec.output);
    for (std::size_t c = 0; c < 7; ++c) {
        for (std::size_t r = 0; r < f.spec.input.rows; ++r) input.set(r,c,{std::sin(0.13*(r+3*c)),std::cos(0.17*(r+2*c))});
        for (std::size_t r = 0; r < f.spec.output.rows; ++r) output.set(r,c,{0.4,-0.3});
    }
    const auto saved = input;
    require(op->execute(*w,input.in(),output.out()));
    for (const auto& group : f.spec.groups) for (auto mode : group.modes) for (std::size_t row = 0; row < f.spec.output.rows; ++row) {
        const auto& a = f.spec.matrices[group.matrix].values;
        std::complex<long double> expected = accumulation == WVAccumulation::add ? std::complex<long double>{0.4,-0.3} : std::complex<long double>{};
        for (std::size_t j = 0; j < f.spec.input.rows; ++j) {
            const auto v = input.get(j,mode);
            expected += static_cast<long double>(a.data[row*a.rowStride+j*a.columnStride])*std::complex<long double>{v.real,v.imag};
        }
        close(output.get(row,mode),expected);
    }
    require(input.equals(saved),"Vertical operation modified input"); output.paddingUnchanged();
    const auto bytes = op->persistentBytes()+w->persistentBytes();
    allocationProbe::calls = 0; allocationProbe::counting = true;
    for (int i = 0; i < 10; ++i) require(op->execute(*w,input.in(),output.out()));
    allocationProbe::counting = false;
    require(allocationProbe::calls == 0,"Prepared vertical execution allocated");
    require(bytes == op->persistentBytes()+w->persistentBytes(),"Prepared storage grew");
    require(input.equals(saved),"Repeated vertical operation modified input");
    auto bad = output.out(); bad.bytes = 1;
    require(op->execute(*w,input.in(),bad).code == WVKernelStatusCode::invalidShape,"Undersized output accepted");
    // Same-address and partial cross-component overlap rejected before mutation.
    auto aliased = input.out(); aliased.bytes = std::max(aliased.bytes,output.out().bytes);
    require(op->execute(*w,input.in(),aliased).code == WVKernelStatusCode::overlappingArrays,"Vertical alias accepted");
}
void discontiguousDirectSegments(WVComplexRepresentation representation,WVAccumulation accumulation) {
    VerticalFixture f(WVMatrixAction::reconstruction,representation,accumulation,true);
    f.spec.groups={{3,0,{0,1,4,5}},{91,1,{2,3,6}}};
    MatrixTrace trace;
    std::unique_ptr<WVPreparedVerticalOperator> op;
    require(WVPreparedVerticalOperator::create(f.spec,tracingBackend(trace),op));
    std::unique_ptr<WVVerticalWorkspace> workspace; require(op->createWorkspace(workspace));
    require(op->uniqueMatrixCount()==2,"Direct run segmentation changed exact matrix identities");
    const auto expectedMatrixBytes=f.spec.input.rows*f.spec.output.rows*2*
        (representation==WVComplexRepresentation::split ? sizeof(double) : sizeof(WVComplex64));
    require(op->matrixBytes()==expectedMatrixBytes,"Direct run segmentation duplicated matrix storage");

    Buffer input(f.spec.input),output(f.spec.output);
    for (std::size_t mode=0;mode<f.spec.input.columns;++mode) {
        for (std::size_t row=0;row<f.spec.input.rows;++row) input.set(row,mode,{std::sin(0.13*(row+3*mode)),std::cos(0.17*(row+2*mode))});
        for (std::size_t row=0;row<f.spec.output.rows;++row) output.set(row,mode,{0.4,-0.3});
    }
    const auto saved=input;
    require(op->execute(*workspace,input.in(),output.out()));
    const std::array<std::size_t,4> starts{{0,4,2,6}},widths{{2,2,2,1}};
    require(!trace.overflow && trace.count==starts.size(),"Discontiguous exact groups did not produce maximal direct runs");
    for (std::size_t call=0;call<trace.count;++call) {
        const auto& item=trace.calls[call];
        require(item.width==widths[call] && item.ldb==f.spec.input.columnStride && item.ldc==f.spec.output.columnStride,
            "Direct run used an incorrect backend matrix boundary");
        require(item.beta==(accumulation==WVAccumulation::add ? 1.0 : 0.0) && item.split==(representation==WVComplexRepresentation::split),
            "Direct run changed accumulation or representation");
        if (representation==WVComplexRepresentation::split) {
            require(item.input==input.r.data()+starts[call]*f.spec.input.columnStride &&
                item.output==output.r.data()+starts[call]*f.spec.output.columnStride,"Split direct run was not a caller-storage view");
        } else {
            require(item.input==input.z.data()+starts[call]*f.spec.input.columnStride &&
                item.output==output.z.data()+starts[call]*f.spec.output.columnStride,"Interleaved direct run was not a caller-storage view");
        }
    }
    for (const auto& group:f.spec.groups) for (auto mode:group.modes) for (std::size_t row=0;row<f.spec.output.rows;++row) {
        const auto& matrix=f.spec.matrices[group.matrix].values;
        std::complex<long double> expected=accumulation==WVAccumulation::add ? std::complex<long double>{0.4,-0.3} : std::complex<long double>{};
        for (std::size_t j=0;j<f.spec.input.rows;++j) {
            const auto value=input.get(j,mode);
            expected+=static_cast<long double>(matrix.data[row*matrix.rowStride+j*matrix.columnStride])*std::complex<long double>{value.real,value.imag};
        }
        close(output.get(row,mode),expected);
    }
    require(input.equals(saved),"Direct run execution modified its input"); output.paddingUnchanged();

    VerticalFixture packed(WVMatrixAction::reconstruction,representation,accumulation,false);
    packed.spec.groups={{3,0,{0,1,4,5}},{91,1,{2,3,6}}};
    MatrixTrace packedTrace;
    std::unique_ptr<WVPreparedVerticalOperator> packedOp; require(WVPreparedVerticalOperator::create(packed.spec,tracingBackend(packedTrace),packedOp));
    std::unique_ptr<WVVerticalWorkspace> packedWorkspace; require(packedOp->createWorkspace(packedWorkspace));
    require(workspace->persistentBytes()<packedWorkspace->persistentBytes(),"Direct segments retained packed group buffers");
    Buffer packedInput(packed.spec.input),packedOutput(packed.spec.output);
    for (std::size_t mode=0;mode<packed.spec.input.columns;++mode) for (std::size_t row=0;row<packed.spec.input.rows;++row)
        packedInput.set(row,mode,{1.0+row+3.0*mode,-2.0-row-5.0*mode});
    require(packedOp->execute(*packedWorkspace,packedInput.in(),packedOutput.out()));
    const std::array<std::size_t,2> packedWidths{{4,3}};
    require(!packedTrace.overflow && packedTrace.count==packedWidths.size(),"Nonunit-stride fallback changed public group call boundaries");
    for (std::size_t call=0;call<packedTrace.count;++call) {
        const auto& item=packedTrace.calls[call];
        require(item.width==packedWidths[call] && item.ldb==packed.spec.input.rows && item.ldc==packed.spec.output.rows && item.beta==0,
            "Nonunit-stride fallback did not use packed backend storage");
        require(item.input!=(representation==WVComplexRepresentation::split ? static_cast<const void*>(packedInput.r.data()) : static_cast<const void*>(packedInput.z.data())) &&
            item.output!=(representation==WVComplexRepresentation::split ? static_cast<void*>(packedOutput.r.data()) : static_cast<void*>(packedOutput.z.data())),
            "Nonunit-stride fallback unexpectedly used a caller-storage direct view");
    }
    const auto bytes=op->persistentBytes()+workspace->persistentBytes();
    trace.recording=false; allocationProbe::calls=0; allocationProbe::counting=true;
    for (unsigned repeat=0;repeat<10;++repeat) require(op->execute(*workspace,input.in(),output.out()));
    allocationProbe::counting=false;
    require(allocationProbe::calls==0,"Prepared direct run execution allocated");
    require(op->persistentBytes()+workspace->persistentBytes()==bytes,"Direct run execution changed prepared storage");
}
void selectedVerticalColumn(WVComplexRepresentation representation,
    WVAccumulation accumulation,bool direct,bool native) {
    VerticalFixture f(WVMatrixAction::projection,representation,accumulation,direct);
    MatrixTrace trace;
    std::unique_ptr<WVPreparedVerticalOperator> op;
    require(WVPreparedVerticalOperator::create(f.spec,tracingBackend(trace,native),op));
    std::unique_ptr<WVVerticalWorkspace> workspace; require(op->createWorkspace(workspace));
    require(op->preparedGroupCount()==2,"Prepared full-group count differs");
    Buffer input(f.spec.input),output(f.spec.output);
    for (std::size_t mode=0;mode<f.spec.input.columns;++mode) {
        for (std::size_t row=0;row<f.spec.input.rows;++row)
            input.set(row,mode,{std::sin(.13*(row+3*mode)),std::cos(.17*(row+2*mode))});
        for (std::size_t row=0;row<f.spec.output.rows;++row) output.set(row,mode,{.4,-.3});
    }
    const auto inputBefore=input,outputBefore=output;
    const std::size_t selected=direct ? 5 : 3;
    require(op->executeColumn(*workspace,input.in(),output.out(),selected));
    require(!trace.overflow && trace.count==1 && trace.calls[0].width==1,
        "Selected vertical column did not issue one matrix call");
    const auto& matrix=f.spec.matrices[1].values;
    for (std::size_t mode=0;mode<f.spec.output.columns;++mode)
        for (std::size_t row=0;row<f.spec.output.rows;++row) {
            if (mode!=selected) {
                const auto expected=outputBefore.get(row,mode),actual=output.get(row,mode);
                require(actual.real==expected.real && actual.imag==expected.imag,
                    "Selected vertical execution changed another column");
                continue;
            }
            std::complex<long double> expected=accumulation==WVAccumulation::add ?
                std::complex<long double>{.4,-.3} : std::complex<long double>{};
            for (std::size_t j=0;j<f.spec.input.rows;++j) {
                const auto value=input.get(j,mode);
                expected+=static_cast<long double>(matrix.data[row*matrix.rowStride+j*matrix.columnStride])*
                    std::complex<long double>{value.real,value.imag};
            }
            close(output.get(row,mode),expected);
        }
    require(input.equals(inputBefore),"Selected vertical execution modified input");
    output.paddingUnchanged();
    const auto selectedResult=output;
    require(op->executeColumn(*workspace,input.in(),output.out(),f.spec.input.columns).code==
        WVKernelStatusCode::invalidShape && output.equals(selectedResult),
        "Out-of-range selected vertical column was accepted or changed output");
    auto aliased=input.out(); aliased.bytes=std::max(aliased.bytes,output.out().bytes);
    require(op->executeColumn(*workspace,input.in(),aliased,selected).code==
        WVKernelStatusCode::overlappingArrays && input.equals(inputBefore),
        "Selected vertical column accepted overlapping storage or changed input");
    std::unique_ptr<WVPreparedVerticalOperator> foreign;
    require(WVPreparedVerticalOperator::create(f.spec,backend(native),foreign));
    std::unique_ptr<WVVerticalWorkspace> foreignWorkspace;
    require(foreign->createWorkspace(foreignWorkspace));
    require(op->executeColumn(*foreignWorkspace,input.in(),output.out(),selected).code==
        WVKernelStatusCode::invalidConfiguration && output.equals(selectedResult),
        "Selected vertical column accepted a foreign workspace or changed output");
    const auto bytes=op->persistentBytes()+workspace->persistentBytes();
    trace.recording=false; allocationProbe::calls=0; allocationProbe::counting=true;
    for (unsigned repeat=0;repeat<10;++repeat)
        require(op->executeColumn(*workspace,input.in(),output.out(),selected));
    allocationProbe::counting=false;
    require(allocationProbe::calls==0 && op->persistentBytes()+workspace->persistentBytes()==bytes,
        "Selected vertical execution allocated or changed prepared storage");
}
void parallelVerticalGroups(WVComplexRepresentation representation,
    WVAccumulation accumulation,bool direct,bool native) {
    VerticalFixture f(WVMatrixAction::projection,representation,accumulation,direct);
    std::unique_ptr<WVPreparedVerticalOperator> op;
    require(WVPreparedVerticalOperator::create(f.spec,backend(native),op));
    require(op->supportsConcurrentCalls(),"Concurrent backend capability was not retained");
    std::unique_ptr<WVVerticalWorkspace> serial,parallel;
    require(op->createWorkspace(serial)); require(op->createWorkspace(3,parallel));
    std::unique_ptr<WVVerticalGroupExecutor> executor;
    require(WVVerticalGroupExecutor::create(3,executor));
    Buffer input(f.spec.input),oracle(f.spec.output),candidate(f.spec.output);
    for (std::size_t mode=0;mode<f.spec.input.columns;++mode) {
        for (std::size_t row=0;row<f.spec.input.rows;++row)
            input.set(row,mode,{std::sin(.19*(row+3*mode)),std::cos(.23*(row+2*mode))});
        for (std::size_t row=0;row<f.spec.output.rows;++row) {
            oracle.set(row,mode,{.7,-.2}); candidate.set(row,mode,{.7,-.2});
        }
    }
    const auto inputBefore=input;
    require(op->execute(*serial,input.in(),oracle.out()));
    require(op->execute(*parallel,*executor,input.in(),candidate.out()));
    require(candidate.equals(oracle) && input.equals(inputBefore),
        "Static parallel vertical groups changed the result or input");
    candidate.paddingUnchanged();
    const auto beforeMismatch=candidate;
    require(op->execute(*serial,*executor,input.in(),candidate.out()).code==
        WVKernelStatusCode::invalidConfiguration && candidate.equals(beforeMismatch),
        "Parallel execution accepted mismatched preallocated scratch");
    if (direct) require(parallel->persistentBytes()==serial->persistentBytes(),
        "All-direct vertical groups allocated per-worker packing scratch");
    else require(parallel->persistentBytes()>serial->persistentBytes(),
        "Packed vertical groups did not preallocate per-worker scratch");
    const auto bytes=op->persistentBytes()+parallel->persistentBytes()+executor->persistentBytes();
    allocationProbe::calls=0; allocationProbe::counting=true;
    for (unsigned repeat=0;repeat<10;++repeat)
        require(op->execute(*parallel,*executor,input.in(),candidate.out()));
    allocationProbe::counting=false;
    require(allocationProbe::calls==0 &&
        op->persistentBytes()+parallel->persistentBytes()+executor->persistentBytes()==bytes,
        "Parallel vertical group execution allocated or changed prepared storage");

    MatrixTrace trace;
    std::unique_ptr<WVPreparedVerticalOperator> serialOnly;
    require(WVPreparedVerticalOperator::create(f.spec,tracingBackend(trace,false,false),serialOnly));
    std::unique_ptr<WVVerticalWorkspace> serialOnlyWorkspace;
    require(serialOnly->createWorkspace(3,serialOnlyWorkspace));
    const auto beforeRejected=candidate;
    require(serialOnly->execute(*serialOnlyWorkspace,*executor,input.in(),candidate.out()).code==
        WVKernelStatusCode::unsupportedOperation && candidate.equals(beforeRejected) && trace.count==0,
        "Parallel execution silently accepted a nonconcurrent backend");
}
void singleColumn(bool native, WVComplexRepresentation representation) {
    VerticalFixture f(WVMatrixAction::reconstruction,representation,WVAccumulation::overwrite,true);
    f.spec.input.columns = f.spec.output.columns = 1;
    // The unused column stride is legal in a view but is not a valid BLAS leading dimension.
    f.spec.input.columnStride = f.spec.output.columnStride = 1;
    f.spec.matrices.resize(1); f.spec.groups = {{0,0,{0}}};
    std::unique_ptr<WVPreparedVerticalOperator> op;
    require(WVPreparedVerticalOperator::create(f.spec,backend(native),op));
    std::unique_ptr<WVVerticalWorkspace> one, two; require(op->createWorkspace(one)); require(op->createWorkspace(two));
    Buffer input(f.spec.input), a(f.spec.output), b(f.spec.output);
    for (std::size_t r = 0; r < 3; ++r) input.set(r,0,{1,2});
    std::thread worker([&] { require(op->execute(*one,input.in(),a.out())); });
    require(op->execute(*two,input.in(),b.out())); worker.join();
    require(a.equals(b),"Independent vertical workspaces interfered");
    for (std::size_t r = 0; r < 5; ++r) {
        long double sum = 0; for (std::size_t j = 0; j < 3; ++j) sum += f.a[r+7*j];
        close(a.get(r,0),{sum,2*sum});
    }
}
void identitiesAndRebuild() {
    VerticalFixture f(WVMatrixAction::reconstruction,WVComplexRepresentation::interleaved,WVAccumulation::overwrite,true);
    f.spec.matrices[1] = f.spec.matrices[0];
    std::unique_ptr<WVPreparedVerticalOperator> first, second;
    require(WVPreparedVerticalOperator::create(f.spec,backend(false),first));
    require(first->uniqueMatrixCount() == 1,"Exact source identity was not shared");
    std::unique_ptr<WVVerticalWorkspace> w; require(first->createWorkspace(w));
    Buffer input(f.spec.input), before(f.spec.output), after(f.spec.output);
    for (std::size_t c = 0; c < 7; ++c) for (std::size_t r = 0; r < 3; ++r) input.set(r,c,{1,2});
    require(first->execute(*w,input.in(),before.out()));
    // Mutating caller scientific storage cannot mutate a prepared immutable copy.
    f.a[0] = 7;
    require(first->execute(*w,input.in(),after.out())); require(before.equals(after),"Prepared matrix borrowed caller storage");
    f.spec.sourceIdentity = "profile-B/basis-3/normalization-1";
    for (auto& m : f.spec.matrices) m.identity.source = f.spec.sourceIdentity;
    require(WVPreparedVerticalOperator::create(f.spec,backend(false),second));
    require(second->execute(*w,input.in(),after.out()).code == WVKernelStatusCode::invalidConfiguration,"Stale workspace accepted by rebuilt operator");
    std::unique_ptr<WVVerticalWorkspace> fresh; require(second->createWorkspace(fresh)); require(second->execute(*fresh,input.in(),after.out()));
    require(!before.equals(after),"Changed geometry/operators reused old prepared matrix");
    // A changed name with equal values is a distinct source family, not a numerical deduplication key.
    f.spec.matrices[1].identity.name = "different-operator";
    require(WVPreparedVerticalOperator::create(f.spec,backend(false),second)); require(second->uniqueMatrixCount() == 2,"Equal-valued distinct identities merged");
    f.spec.matrices[1].identity = f.spec.matrices[0].identity;
    f.spec.matrices[1].values = {f.b.data(),5,3,2,13,f.b.size()*sizeof(double)};
    auto* previous = second.get();
    require(WVPreparedVerticalOperator::create(f.spec,backend(false),second).code == WVKernelStatusCode::invalidConfiguration && second.get() == previous,"Conflicting source identity accepted or output replaced");
}
struct Lifetime { int engines = 0, plans = 0, failAt = -1; void (*callback)(void*) = nullptr; void* context = nullptr; };
class CountingPlan final : public WVFFTPlan {
    std::unique_ptr<WVFFTPlan> inner; Lifetime& life;
public:
    CountingPlan(std::unique_ptr<WVFFTPlan> p, Lifetime& l) : inner(std::move(p)), life(l) { ++life.plans; }
    ~CountingPlan() override { --life.plans; }
    WVKernelStatus execute(const void* in, void* out) override {
        if (life.callback) { auto fn = life.callback; life.callback = nullptr; fn(life.context); }
        return inner->execute(in,out);
    }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this)+inner->persistentBytes(); }
};
class CountingEngine final : public WVFFTEngine {
    WVReferenceFFTEngine inner; Lifetime& life;
public:
    explicit CountingEngine(Lifetime& l) : life(l) { ++life.engines; }
    ~CountingEngine() override { --life.engines; }
    std::string identifier() const override { return "counting-reference"; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& s, std::unique_ptr<WVFFTPlan>& out) override {
        if (life.failAt == 0) return {WVKernelStatusCode::fftPlanFailure,"Injected plan failure"};
        if (life.failAt > 0) --life.failAt;
        std::unique_ptr<WVFFTPlan> p; auto status = inner.createPlan(s,p); if (!status) return status;
        out = std::make_unique<CountingPlan>(std::move(p),life); return WVKernelStatus::ok();
    }
};
void setupFailures() {
    auto h = horizontalSpecification(8,6,true,WVComplexRepresentation::split,WVFourierNormalization::forwardUnit,false);
    Lifetime life;
    for (int plan = 0; plan < 2; ++plan) {
        std::unique_ptr<WVRetainedHorizontalOperator> op;
        require(WVRetainedHorizontalOperator::create(h,std::make_unique<CountingEngine>(life),op));
        life.failAt = plan;
        std::unique_ptr<WVRetainedHorizontalWorkspace> w;
        require(op->createWorkspace(w).code == WVKernelStatusCode::fftPlanFailure && !w,"Plan failure was not propagated");
        require(life.plans == 0,"Partial horizontal plan setup leaked");
        life.failAt = -1; require(op->createWorkspace(w));
        op.reset(); require(life.engines == 1 && life.plans == 2,"Workspace did not retain its prepared dependencies");
        w.reset(); require(life.engines == 0 && life.plans == 0,"Workspace teardown leaked");
    }
    bool success = false;
    for (long i = 0; i < 128; ++i) {
        auto engine = std::make_unique<CountingEngine>(life);
        std::unique_ptr<WVRetainedHorizontalOperator> op;
        allocationProbe::failAfter = i;
        const auto status = WVRetainedHorizontalOperator::create(h,std::move(engine),op);
        allocationProbe::failAfter = -1;
        if (status) { op.reset(); success = true; break; }
        require(status.code == WVKernelStatusCode::allocationFailure && !op && life.engines == 0 && life.plans == 0,"Horizontal preparation allocation failure leaked");
    }
    require(success,"Horizontal allocation sweep did not finish");
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(h,std::make_unique<CountingEngine>(life),op));
    success = false;
    for (long i = 0; i < 128; ++i) {
        std::unique_ptr<WVRetainedHorizontalWorkspace> w;
        allocationProbe::failAfter = i; const auto status = op->createWorkspace(w); allocationProbe::failAfter = -1;
        if (status) { w.reset(); success = true; break; }
        require(status.code == WVKernelStatusCode::allocationFailure && !w && life.plans == 0,"Horizontal workspace allocation failure leaked");
    }
    require(success,"Horizontal workspace allocation sweep did not finish");
    op.reset(); require(life.engines == 0 && life.plans == 0,"Horizontal failure suite leaked");
    VerticalFixture f(WVMatrixAction::projection,WVComplexRepresentation::split,WVAccumulation::overwrite,false);
    success = false;
    for (long i = 0; i < 256; ++i) {
        auto b = backend(false); std::unique_ptr<WVPreparedVerticalOperator> v;
        allocationProbe::failAfter = i; const auto status = WVPreparedVerticalOperator::create(f.spec,std::move(b),v); allocationProbe::failAfter = -1;
        if (status) { success = true; break; }
        require(status.code == WVKernelStatusCode::allocationFailure && !v,"Vertical allocation failure was not propagated");
    }
    require(success,"Vertical allocation sweep did not finish");
    std::unique_ptr<WVPreparedVerticalOperator> v; require(WVPreparedVerticalOperator::create(f.spec,backend(false),v));
    success = false;
    for (long i = 0; i < 32; ++i) {
        std::unique_ptr<WVVerticalWorkspace> w;
        allocationProbe::failAfter = i; const auto status = v->createWorkspace(w); allocationProbe::failAfter = -1;
        if (status) { success = true; break; }
        require(status.code == WVKernelStatusCode::allocationFailure && !w,"Vertical workspace allocation failure was not propagated");
    }
    require(success,"Vertical workspace allocation sweep did not finish");
}
void rejectedContracts() {
    auto h = horizontalSpecification(8,6,true,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,true);
    auto rejectH = [&](const auto& bad, WVKernelStatusCode code) {
        std::unique_ptr<WVRetainedHorizontalOperator> p;
        require(WVRetainedHorizontalOperator::create(bad,fft(false),p).code == code && !p,"Invalid horizontal setup accepted");
    };
    auto bad = h; bad.modes[1] = bad.modes[0]; rejectH(bad,WVKernelStatusCode::invalidConfiguration);
    bad = h; bad.modes[1] = {-bad.modes[0].k,-bad.modes[0].l}; rejectH(bad,WVKernelStatusCode::invalidConfiguration);
    bad = h; bad.modes[0].k = INT64_MIN; rejectH(bad,WVKernelStatusCode::invalidConfiguration);
    bad = h; bad.retained.rows = 2; rejectH(bad,WVKernelStatusCode::invalidShape);
    bad = h; bad.retained.columnStride = 2; rejectH(bad,WVKernelStatusCode::invalidConfiguration);
    bad = h; bad.grid.xStride = static_cast<std::size_t>(PTRDIFF_MAX); rejectH(bad,WVKernelStatusCode::sizeOverflow);
    bad = h; bad.grid.yStride = 1; rejectH(bad,WVKernelStatusCode::invalidConfiguration);
    bad = h; bad.placement = WVOperatorPlacement::inPlace; rejectH(bad,WVKernelStatusCode::unsupportedOperation);
    std::unique_ptr<WVRetainedHorizontalOperator> op, other;
    require(WVRetainedHorizontalOperator::create(h,fft(false),op)); require(WVRetainedHorizontalOperator::create(h,fft(false),other));
    std::unique_ptr<WVRetainedHorizontalWorkspace> w; require(op->createWorkspace(w));
    std::vector<double> real(1000,43); Buffer retained(h.retained);
    WVRealOutput out{real.data(),real.size()*sizeof(double)};
    for (std::size_t c = 0; c < h.modes.size(); ++c) for (std::size_t p = 0; p < 3; ++p) retained.set(p,c,{0,0});
    const auto original = real;
    retained.set(0,3,{1,2}); // DC is deliberately fourth in the explicit set.
    require(op->inverse(*w,retained.in(),out).code == WVKernelStatusCode::invalidConfiguration && same(real,original),"Complex self-conjugate mode accepted or output changed on rejection");
    require(other->inverse(*w,retained.in(),out).code == WVKernelStatusCode::invalidConfiguration,"Foreign horizontal workspace accepted");
    auto alias = retained.in(); alias.bytes = 10000;
    require(op->inverse(*w,alias,{reinterpret_cast<double*>(retained.z.data()),10000}).code == WVKernelStatusCode::overlappingArrays,"Horizontal alias accepted");
    require(op->forward(*w,{real.data(),1},retained.out()).code == WVKernelStatusCode::invalidShape,"Undersized horizontal input accepted");
    VerticalFixture f(WVMatrixAction::reconstruction,WVComplexRepresentation::split,WVAccumulation::overwrite,false);
    auto rejectV = [&](const auto& s, WVKernelStatusCode code) { std::unique_ptr<WVPreparedVerticalOperator> p; require(WVPreparedVerticalOperator::create(s,backend(false),p).code == code && !p,"Invalid vertical setup accepted"); };
    auto v = f.spec; v.groups[1].modes[0] = v.groups[0].modes[0]; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.groups[1].modes.pop_back(); rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.groups[1].identity = v.groups[0].identity; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.matrices[0].values.bytes = 1; rejectV(v,WVKernelStatusCode::invalidShape);
    v = f.spec; v.matrices[0].identity.source = "other-normalization"; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.matrices[0].inputFamily = "different-family"; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.matrices[0].action = WVMatrixAction::projection; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.input.modeSet = "different-basis"; rejectV(v,WVKernelStatusCode::invalidConfiguration);
    v = f.spec; v.input.rowStride = PTRDIFF_MAX; rejectV(v,WVKernelStatusCode::sizeOverflow);
    v = f.spec; v.placement = WVOperatorPlacement::inPlace; rejectV(v,WVKernelStatusCode::unsupportedOperation);
    f.a[0] = std::numeric_limits<double>::infinity(); rejectV(f.spec,WVKernelStatusCode::invalidConfiguration);
    f.a[0] = 0;
    // Intentionally zero G/barotropic and truncated operators are valid.
    std::fill(f.a.begin(),f.a.end(),0); std::fill(f.b.begin(),f.b.end(),0);
    std::unique_ptr<WVPreparedVerticalOperator> zeros; require(WVPreparedVerticalOperator::create(f.spec,backend(false),zeros));
}
void workspaceConcurrency() {
    auto h = horizontalSpecification(8,6,true,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false);
    Lifetime life; std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(h,std::make_unique<CountingEngine>(life),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> one, two; require(op->createWorkspace(one)); require(op->createWorkspace(two));
    Buffer a(h.retained), b(h.retained); std::vector<double> real(1000,1);
    struct Reentry { WVRetainedHorizontalOperator* op; WVRetainedHorizontalWorkspace* w; WVRealInput real; WVComplexOutput out; WVKernelStatusCode code; };
    Reentry context{op.get(),one.get(),{real.data(),real.size()*sizeof(double)},a.out(),WVKernelStatusCode::success};
    life.context = &context; life.callback = [](void* p) { auto& c = *static_cast<Reentry*>(p); c.code = c.op->forward(*c.w,c.real,c.out).code; };
    require(op->forward(*one,context.real,a.out())); require(context.code == WVKernelStatusCode::reentrantExecution,"Active workspace reentry accepted");
    std::thread worker([&] { for (int i = 0; i < 10; ++i) require(op->forward(*one,context.real,a.out())); });
    for (int i = 0; i < 10; ++i) require(op->forward(*two,context.real,b.out()));
    worker.join(); require(a.equals(b),"Independent workspaces interfered");
}
} // namespace
int main() {
    try {
        std::unique_ptr<WVVerticalMatrixBackend> accelerate;
        const auto availability = WVCreateAccelerateMatrixBackend(accelerate);
        const bool nativeMatrix = static_cast<bool>(availability);
        require(nativeMatrix || availability.code == WVKernelStatusCode::unsupportedOperation,"Unexpected Accelerate availability failure");
        for (bool native : {false,true}) {
#if !WV_TEST_NATIVE_FFTW
            if (native) continue;
#endif
            for (bool odd : {false,true}) for (bool mask : {false,true})
                for (auto representation : {WVComplexRepresentation::split,WVComplexRepresentation::interleaved})
                    for (auto normalization : {WVFourierNormalization::forwardUnit,WVFourierNormalization::unitary,WVFourierNormalization::inverseUnit})
                        horizontalCase(odd ? 9 : 8,odd ? 7 : 6,mask,representation,normalization,false,native);
            horizontalCase(8,6,false,WVComplexRepresentation::split,WVFourierNormalization::forwardUnit,true,native);
            horizontalCase(8,6,false,WVComplexRepresentation::interleaved,WVFourierNormalization::unitary,true,native);
        }
        for (bool native : {false,true}) if (!native || nativeMatrix)
            for (auto action : {WVMatrixAction::reconstruction,WVMatrixAction::projection,WVMatrixAction::crossFamily})
                for (auto representation : {WVComplexRepresentation::split,WVComplexRepresentation::interleaved})
                    for (auto accumulation : {WVAccumulation::overwrite,WVAccumulation::add}) for (bool direct : {false,true})
                        for (const auto& sizes : {std::pair<std::size_t,std::size_t>{5,3},{8,4},{1,1}})
                            verticalCase(action,representation,accumulation,direct,native,sizes.first,sizes.second);
        for (bool native : {false,true}) if (!native || nativeMatrix)
            for (auto representation : {WVComplexRepresentation::split,WVComplexRepresentation::interleaved}) singleColumn(native,representation);
        for (auto representation:{WVComplexRepresentation::split,WVComplexRepresentation::interleaved})
            for (auto accumulation:{WVAccumulation::overwrite,WVAccumulation::add}) discontiguousDirectSegments(representation,accumulation);
        for (bool native:{false,true}) if (!native || nativeMatrix)
            for (auto representation:{WVComplexRepresentation::split,WVComplexRepresentation::interleaved})
                for (auto accumulation:{WVAccumulation::overwrite,WVAccumulation::add})
                    for (bool direct:{false,true}) selectedVerticalColumn(representation,accumulation,direct,native);
        for (bool native:{false,true}) if (!native || nativeMatrix)
            for (auto representation:{WVComplexRepresentation::split,WVComplexRepresentation::interleaved})
                for (auto accumulation:{WVAccumulation::overwrite,WVAccumulation::add})
                    for (bool direct:{false,true}) parallelVerticalGroups(representation,accumulation,direct,native);
        identitiesAndRebuild(); rejectedContracts(); setupFailures(); workspaceConcurrency();
        std::cout << "Spectral operators passed: independent DFT/matrix oracles, split/interleaved layouts, exact groups, aliases, failure cleanup, immutable preparation and zero prepared allocations. Accelerate=" << nativeMatrix << '\n';
        return 0;
    } catch (const std::exception& e) {
        allocationProbe::counting = false; allocationProbe::failAfter = -1;
        std::cerr << e.what() << '\n'; return 1;
    }
}
