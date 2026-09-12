#include "WaveVortexKernel/WVSpectralOperators.hpp"
#include <WVReferenceFFTEngine.hpp>
#include "WVNativeFFTWEngine.hpp"
#include "WVAllocationProbe.hpp"
#include <algorithm>
#include <cmath>
#include <complex>
#include <cstring>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <atomic>
#include <thread>
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
struct ConsumerProbe {
    std::size_t size;
    std::unique_ptr<std::atomic<unsigned>[]> visits;
    std::atomic<std::size_t> calls{0};
    std::atomic<bool> invalidRange{false};
    explicit ConsumerProbe(std::size_t count) : size(count), visits(new std::atomic<unsigned>[count]) { reset(); }
    void reset() noexcept {
        calls=0; invalidRange=false;
        for (std::size_t n=0;n<size;++n) visits[n]=0;
    }
    static void consume(void* context,std::size_t begin,std::size_t end,const double*) noexcept {
        auto& probe=*static_cast<ConsumerProbe*>(context);
        ++probe.calls;
        if (begin>end || end>probe.size) { probe.invalidRange=true; return; }
        for (std::size_t n=begin;n<end;++n) ++probe.visits[n];
    }
    WVRealOutputConsumer consumer() noexcept { return {this,&consume}; }
    void requireExactly(unsigned expected) const {
        require(!invalidRange.load(),"Inverse consumer received an invalid range");
        require(calls.load()>0,"Inverse consumer was not invoked");
        for (std::size_t n=0;n<size;++n) require(visits[n].load()==expected,"Inverse consumer ranges did not cover output exactly once");
    }
};
std::unique_ptr<WVFFTEngine> fft(bool native) {
    if (!native) return std::make_unique<WVReferenceFFTEngine>();
    std::unique_ptr<WVFFTEngine> engine; require(WVFFTWEngine::create(2,engine)); return engine;
}
class MarkerRetainedPlan final : public WVRetainedHorizontalPlan {
public:
    WVKernelStatus forward(WVRealInput,WVComplexOutput) override { return {WVKernelStatusCode::unsupportedOperation,"Marker retained plan is not executable."}; }
    WVKernelStatus inverse(WVComplexInput,WVRealOutput) override { return {WVKernelStatusCode::unsupportedOperation,"Marker retained plan is not executable."}; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    std::size_t planBytesLowerBound() const noexcept override { return 0; }
    std::size_t workerCount() const noexcept override { return 1; }
    const char* identifier() const noexcept override { return "marker-retained"; }
};
class RetainedReferenceEngine final : public WVFFTEngine {
public:
    std::string identifier() const override { return "retained-reference"; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    WVKernelStatus createRetainedHorizontalPlan(const WVRetainedHorizontalSpecification&,std::unique_ptr<WVRetainedHorizontalPlan>& result) override {
        result=std::make_unique<MarkerRetainedPlan>(); return WVKernelStatus::ok();
    }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& spec,std::unique_ptr<WVFFTPlan>& result) override {
        return full_.createPlan(spec,result);
    }
private:
    WVReferenceFFTEngine full_;
};
WVRetainedHorizontalSpecification specification(std::size_t nx,std::size_t ny,std::size_t planes,
    WVComplexRepresentation representation,WVFourierNormalization normalization,bool padded,bool pruned) {
    WVRetainedHorizontalSpecification s;
    s.grid={nx,ny,planes,padded?2u:1u,padded?2*nx+1:nx,padded?(2*nx+1)*ny+2:nx*ny+3,"F"};
    s.Lx=19000; s.Ly=11000; s.normalization=normalization;
    s.schedule=WVRetainedHorizontalSchedule::streamingPrunedTile16; s.outerWorkers=3;
    std::vector<bool> seen(nx*ny,false);
    for (std::size_t y=0;y<ny;++y) for (std::size_t x=0;x<nx;++x) {
        const auto cx=(nx-x)%nx,cy=(ny-y)%ny;
        if (seen[x+nx*y] || seen[cx+nx*cy]) continue;
        seen[x+nx*y]=seen[cx+nx*cy]=true;
        if (pruned && std::min(x,cx)>1) continue;
        // Alternate representatives exercise negative k and ky, including
        // both even-grid self-conjugate boundary columns.
        const bool reverse=(x+y)%2;
        const auto k=reverse?cx:x,l=reverse?cy:y;
        s.modes.push_back({k<=nx/2?static_cast<std::int64_t>(k):static_cast<std::int64_t>(k)-static_cast<std::int64_t>(nx),
                           l<=ny/2?static_cast<std::int64_t>(l):static_cast<std::int64_t>(l)-static_cast<std::int64_t>(ny)});
    }
    std::reverse(s.modes.begin(),s.modes.end());
    s.retained={planes,s.modes.size(),2,2*planes+3,representation,"F","explicit-ordered-orbits"};
    return s;
}
void horizontalCase(std::size_t nx, std::size_t ny, std::size_t planes, WVComplexRepresentation representation,
    WVFourierNormalization normalization, bool native, bool padded, bool pruned) {
    auto spec = specification(nx,ny,planes,representation,normalization,padded,pruned);
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,fft(native),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> w; require(op->createWorkspace(w,false));
    require(std::string(w->scheduleIdentifier()) == (native && !padded ? "fftw-streaming-pruned-tile16" : "plane-streamed-full-fft-gather"),"Incorrect actual schedule identifier");
    require(w->workerCount() == (native && !padded ? std::min(planes,std::size_t{3}) : 1),"Incorrect actual worker count");
    const auto retainedBytes=w->persistentBytes(), planBytes=w->planBytesLowerBound();
    const auto lifetime=WVFFTWEngine::lifetimeMetrics();
    const auto& g = spec.grid;
    const auto size = 1+(nx-1)*g.xStride+(ny-1)*g.yStride+(planes-1)*g.planeStride;
    std::vector<double> input(size,321), output(size,654);
    std::vector<bool> written(size,false);
    for (std::size_t p = 0; p < planes; ++p) for (std::size_t y = 0; y < ny; ++y) for (std::size_t x = 0; x < nx; ++x) {
        const auto n = x*g.xStride+y*g.yStride+p*g.planeStride; written[n] = true;
        input[n] = std::sin(0.37*(1+x+3*y+7*p))+0.1*p;
    }
    const auto original = input;
    WVRealInput real{input.data(),input.size()*sizeof(double)}; WVRealOutput destination{output.data(),output.size()*sizeof(double)};
    Buffer retained(spec.retained);
    auto tooSmall=retained.out(); tooSmall.bytes=0;
    require(op->forward(*w,real,tooSmall).code==WVKernelStatusCode::invalidShape,"Undersized retained output accepted");
    auto alias=retained.out();
    if (representation==WVComplexRepresentation::interleaved) alias.interleaved=reinterpret_cast<WVComplex64*>(input.data());
    else alias.real=input.data();
    require(op->forward(*w,real,alias).code==WVKernelStatusCode::overlappingArrays,"Horizontal alias accepted");
    require(op->forward(*w,real,retained.out()));
    const auto pi = std::acos(-1.0L);
    long double forwardScale = normalization == WVFourierNormalization::forwardUnit ? 1.0L/(nx*ny) : normalization == WVFourierNormalization::unitary ? 1/std::sqrt(static_cast<long double>(nx*ny)) : 1;
    long double inverseScale = normalization == WVFourierNormalization::inverseUnit ? 1.0L/(nx*ny) : normalization == WVFourierNormalization::unitary ? 1/std::sqrt(static_cast<long double>(nx*ny)) : 1;
    for (std::size_t mode = 0; mode < spec.modes.size(); ++mode) for (std::size_t p = 0; p < planes; ++p) {
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
    for (std::size_t p = 0; p < planes; ++p) for (std::size_t y = 0; y < ny; ++y) for (std::size_t x = 0; x < nx; ++x) {
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
    for (std::size_t c = 0; c < spec.modes.size(); ++c) for (std::size_t p = 0; p < planes; ++p) close(recovered.get(p,c),{saved.get(p,c).real,saved.get(p,c).imag});
    allocationProbe::calls = 0; allocationProbe::counting = true;
    for (int i = 0; i < 5; ++i) { require(op->forward(*w,real,retained.out())); require(op->inverse(*w,retained.in(),destination)); }
    allocationProbe::counting = false;
    require(allocationProbe::calls == 0,"Prepared horizontal execution allocated");
    require(retained.equals(saved) && same(input,original),"Repeated horizontal execution changed input or result");
    require(w->persistentBytes()==retainedBytes && w->planBytesLowerBound()==planBytes,"Execution changed prepared storage");
    const auto after=WVFFTWEngine::lifetimeMetrics();
    require(after.activePlans==lifetime.activePlans && after.totalPlansCreated==lifetime.totalPlansCreated,"Execution created FFT plans");
    require(op->spatialDerivative(*w,real,destination,true).code==WVKernelStatusCode::unsupportedOperation,"Compact-only workspace unexpectedly offered full derivative");
    // A late self-conjugate error must leave the complete caller output intact.
    for (std::size_t m=0;m<spec.modes.size();++m) if(spec.modes[m].k==0 && spec.modes[m].l==0) retained.set(planes-1,m,{1,1});
    const auto before=output;
    require(op->inverse(*w,retained.in(),destination).code==WVKernelStatusCode::invalidConfiguration,"Nonreal self-conjugate coefficient accepted");
    require(same(output,before),"Rejected inverse modified output");
}

void multiplierCase(std::size_t nx,std::size_t ny,std::size_t planes,WVComplexRepresentation representation,
    WVFourierNormalization normalization,bool native) {
    auto spec=specification(nx,ny,planes,representation,normalization,false,true);
    spec.grid.planeStride=nx*ny;
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,fft(native),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> workspace;
    require(op->createWorkspace(workspace,false));
    require(workspace->supportsInverseMultiplier(),"Prepared provider omitted inverse-multiplier capability");
    require(std::string(workspace->scheduleIdentifier())==(native ? "fftw-streaming-pruned-tile16" : "plane-streamed-full-fft-gather"),
        "Inverse-multiplier case selected the wrong implementation");

    Buffer retained(spec.retained),materialized(spec.retained);
    for (std::size_t mode=0;mode<spec.modes.size();++mode) for (std::size_t p=0;p<planes;++p) {
        const auto key=spec.modes[mode];
        const bool self=(2*key.k)%static_cast<std::int64_t>(nx)==0 && (2*key.l)%static_cast<std::int64_t>(ny)==0;
        retained.set(p,mode,{0.07*(1+p)+0.011*key.k-0.013*key.l,self ? 0.0 : 0.03*(1+mode)-0.017*p});
    }
    const auto saved=retained;
    std::vector<double> factors(spec.modes.size());
    const auto oldProduct=[](WVComplex64 value,double factor) {
        const WVComplex64 multiplier{0,factor};
        return WVComplex64{value.real*multiplier.real-value.imag*multiplier.imag,
            value.real*multiplier.imag+value.imag*multiplier.real};
    };
    bool positive=false,negative=false;
    for (std::size_t mode=0;mode<spec.modes.size();++mode) {
        const auto key=spec.modes[mode];
        const bool self=(2*key.k)%static_cast<std::int64_t>(nx)==0 && (2*key.l)%static_cast<std::int64_t>(ny)==0;
        factors[mode]=self ? 0.0 : 0.19*key.k+0.07*key.l;
        positive=positive || factors[mode]>0; negative=negative || factors[mode]<0;
        for (std::size_t p=0;p<planes;++p) materialized.set(p,mode,oldProduct(retained.get(p,mode),factors[mode]));
    }
    require(positive && negative,"Multiplier case omitted signed retained modes");
    const auto savedFactors=factors;
    const auto size=nx*ny*planes;
    std::vector<double> expected(size,654),actual(size,987);
    require(op->inverse(*workspace,materialized.in(),{expected.data(),expected.size()*sizeof(double)}));
    ConsumerProbe probe(size);
    require(op->inverseWithMultiplier(*workspace,retained.in(),{actual.data(),actual.size()*sizeof(double)},
        {factors.data(),factors.size()},probe.consumer()));
    probe.requireExactly(1);
    require(same(actual,expected),"Fused inverse multiplier differs from the explicitly materialized product");

    const auto pi=std::acos(-1.0L);
    const long double inverseScale=normalization==WVFourierNormalization::inverseUnit ? 1.0L/(nx*ny) :
        normalization==WVFourierNormalization::unitary ? 1/std::sqrt(static_cast<long double>(nx*ny)) : 1;
    for (std::size_t p=0;p<planes;++p) for (std::size_t y=0;y<ny;++y) for (std::size_t x=0;x<nx;++x) {
        long double oracle=0;
        for (std::size_t mode=0;mode<spec.modes.size();++mode) {
            const auto key=spec.modes[mode];
            const auto value=oldProduct(retained.get(p,mode),factors[mode]);
            const bool self=(2*key.k)%static_cast<std::int64_t>(nx)==0 && (2*key.l)%static_cast<std::int64_t>(ny)==0;
            const long double angle=2*pi*(static_cast<long double>(key.k)*x/nx+static_cast<long double>(key.l)*y/ny);
            oracle+=(self ? 1 : 2)*(value.real*std::cos(angle)-value.imag*std::sin(angle));
        }
        close(actual[p*nx*ny+y*nx+x],static_cast<double>(inverseScale*oracle));
    }
    require(retained.equals(saved) && same(factors,savedFactors),"Inverse multiplier modified a borrowed input");
    retained.paddingUnchanged(); materialized.paddingUnchanged();

    probe.reset();
    allocationProbe::calls=0; allocationProbe::counting=true;
    for (unsigned repeat=0;repeat<3;++repeat)
        require(op->inverseWithMultiplier(*workspace,retained.in(),{actual.data(),actual.size()*sizeof(double)},
            {factors.data(),factors.size()},probe.consumer()));
    allocationProbe::counting=false;
    require(allocationProbe::calls==0,"Prepared inverse multiplier allocated");
    probe.requireExactly(3);
    require(same(actual,expected) && retained.equals(saved) && same(factors,savedFactors),"Warmed inverse multiplier changed its result or inputs");
}

void multiplierValidation() {
    constexpr std::size_t nx=8,ny=6,planes=3;
    auto spec=specification(nx,ny,planes,WVComplexRepresentation::split,WVFourierNormalization::forwardUnit,false,true);
    spec.grid.planeStride=nx*ny;
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,fft(true),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> workspace;
    require(op->createWorkspace(workspace,false));
    Buffer retained(spec.retained);
    for (std::size_t mode=0;mode<spec.modes.size();++mode) for (std::size_t p=0;p<planes;++p) retained.set(p,mode,{0,0});
    std::size_t zeroMode=spec.modes.size();
    for (std::size_t mode=0;mode<spec.modes.size();++mode) if (spec.modes[mode].k==0 && spec.modes[mode].l==0) zeroMode=mode;
    require(zeroMode<spec.modes.size(),"Multiplier validation omitted the zero mode");
    std::vector<double> factors(spec.modes.size(),0.25);
    for (std::size_t mode=0;mode<spec.modes.size();++mode) {
        const auto key=spec.modes[mode];
        if ((2*key.k)%static_cast<std::int64_t>(nx)==0 && (2*key.l)%static_cast<std::int64_t>(ny)==0) factors[mode]=0;
    }
    std::vector<double> output(nx*ny*planes,4321);
    ConsumerProbe probe(output.size());
    auto reject=[&](WVImaginaryModeMultiplier multiplier,WVKernelStatusCode code,const char* message) {
        std::fill(output.begin(),output.end(),4321); const auto before=output; probe.reset();
        const auto status=op->inverseWithMultiplier(*workspace,retained.in(),{output.data(),output.size()*sizeof(double)},multiplier,probe.consumer());
        require(status.code==code,message);
        require(same(output,before),"Rejected inverse multiplier modified output");
        require(probe.calls.load()==0,"Rejected inverse multiplier invoked its consumer");
    };
    reject({factors.data(),factors.size()-1},WVKernelStatusCode::invalidShape,"Short inverse multiplier accepted");
    reject({factors.data(),factors.size()+1},WVKernelStatusCode::invalidShape,"Long inverse multiplier accepted");
    reject({nullptr,factors.size()},WVKernelStatusCode::invalidPointer,"Null inverse multiplier accepted");
    std::vector<unsigned char> unaligned(factors.size()*sizeof(double)+1);
    reject({reinterpret_cast<const double*>(unaligned.data()+1),factors.size()},WVKernelStatusCode::invalidPointer,"Unaligned inverse multiplier accepted");
    const auto invalidAddress=std::numeric_limits<std::uintptr_t>::max() & ~std::uintptr_t(alignof(double)-1);
    reject({reinterpret_cast<const double*>(invalidAddress),factors.size()},WVKernelStatusCode::invalidPointer,"Overflowing inverse multiplier span accepted");
    reject({output.data(),factors.size()},WVKernelStatusCode::overlappingArrays,"Inverse multiplier overlapping output accepted");
    factors[1]=std::numeric_limits<double>::quiet_NaN();
    reject({factors.data(),factors.size()},WVKernelStatusCode::invalidConfiguration,"NaN inverse multiplier accepted");
    factors[1]=std::numeric_limits<double>::infinity();
    reject({factors.data(),factors.size()},WVKernelStatusCode::invalidConfiguration,"Infinite inverse multiplier accepted");
    factors[1]=0.25;

    // Validation is applied to the multiplied value: an imaginary base self
    // can become real, while a real base self can become imaginary.
    retained.set(planes-1,zeroMode,{0,1}); factors[zeroMode]=1;
    probe.reset();
    require(op->inverseWithMultiplier(*workspace,retained.in(),{output.data(),output.size()*sizeof(double)},
        {factors.data(),factors.size()},probe.consumer()));
    probe.requireExactly(1);
    retained.set(planes-1,zeroMode,{1,0});
    reject({factors.data(),factors.size()},WVKernelStatusCode::invalidConfiguration,"Imaginary multiplied self-conjugate value accepted");

    // Every rejected preflight released the workspace and preserved recovery.
    retained.set(planes-1,zeroMode,{1,0}); factors[zeroMode]=0; probe.reset();
    require(op->inverseWithMultiplier(*workspace,retained.in(),{output.data(),output.size()*sizeof(double)},
        {factors.data(),factors.size()},probe.consumer()));
    probe.requireExactly(1);
}

void unsupportedMultiplierProvider() {
    auto spec=specification(8,6,2,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,true);
    spec.grid.planeStride=spec.grid.Nx*spec.grid.Ny;
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,std::make_unique<RetainedReferenceEngine>(),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> workspace;
    require(op->createWorkspace(workspace,false));
    require(!workspace->supportsInverseMultiplier(),"Legacy retained provider advertised inverse-multiplier support");
    Buffer retained(spec.retained);
    for (std::size_t mode=0;mode<spec.modes.size();++mode) for (std::size_t p=0;p<spec.grid.planes;++p) retained.set(p,mode,{0,0});
    std::vector<double> factors(spec.modes.size(),0),output(spec.grid.planeStride*spec.grid.planes,654);
    const auto before=output;
    ConsumerProbe probe(output.size());
    require(op->inverseWithMultiplier(*workspace,retained.in(),{output.data(),output.size()*sizeof(double)},
        {factors.data(),factors.size()},probe.consumer()).code==WVKernelStatusCode::unsupportedOperation,
        "Legacy retained provider silently fell back for an inverse multiplier");
    require(same(output,before) && probe.calls.load()==0,"Unsupported inverse multiplier published output");
}

void fallbackAndLifetime() {
    const auto initial=WVFFTWEngine::lifetimeMetrics();
    auto spec=specification(8,6,7,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,true);
    spec.schedule=WVRetainedHorizontalSchedule::fullFFT;
    auto engine=std::shared_ptr<WVFFTEngine>(fft(true));
    const std::weak_ptr<WVFFTEngine> weak=engine;
    std::unique_ptr<WVRetainedHorizontalOperator> first,second;
    require(WVRetainedHorizontalOperator::createShared(spec,engine,first));
    require(WVRetainedHorizontalOperator::createShared(spec,engine,second));
    std::unique_ptr<WVRetainedHorizontalWorkspace> full,stream;
    require(first->createWorkspace(full)); require(second->createWorkspace(stream,false));
    require(std::string(full->scheduleIdentifier())=="full-fft-gather","Default schedule switched implicitly");
    require(std::string(stream->scheduleIdentifier())=="plane-streamed-full-fft-gather","Reference fallback not streamed");
    require(stream->persistentBytes()<full->persistentBytes(),"Streamed fallback retained full batch scratch");
    std::vector<double> input(spec.grid.planeStride*spec.grid.planes),derivative(input.size());
    const double pi=std::acos(-1.0);
    for (std::size_t p=0;p<spec.grid.planes;++p) for (std::size_t y=0;y<spec.grid.Ny;++y) for (std::size_t x=0;x<spec.grid.Nx;++x)
        input[p*spec.grid.planeStride+y*spec.grid.Nx+x]=std::sin(2*pi*(2.0*x/spec.grid.Nx+double(y)/spec.grid.Ny));
    require(first->spatialDerivative(*full,{input.data(),input.size()*sizeof(double)},{derivative.data(),derivative.size()*sizeof(double)},true));
    for (std::size_t p=0;p<spec.grid.planes;++p) for (std::size_t y=0;y<spec.grid.Ny;++y) for (std::size_t x=0;x<spec.grid.Nx;++x)
        close(derivative[p*spec.grid.planeStride+y*spec.grid.Nx+x],4*pi/spec.Lx*std::cos(2*pi*(2.0*x/spec.grid.Nx+double(y)/spec.grid.Ny)));
    auto* original=stream.get();
    allocationProbe::failAfter=0;
    auto failed=second->createWorkspace(stream,false);
    allocationProbe::failAfter=-1;
    require(failed.code==WVKernelStatusCode::allocationFailure && stream.get()==original,"Failed preparation replaced existing workspace");
    engine.reset(); first.reset(); second.reset();
    require(!weak.expired(),"Workspace did not preserve shared provider lifetime");
    full.reset(); stream.reset(); require(weak.expired(),"Provider ownership leaked");
    const auto final=WVFFTWEngine::lifetimeMetrics();
    require(final.activePlans==initial.activePlans && final.outstandingPlanningBytes==0,"Prepared plan lifetime leaked");
}
void boundedDerivative() {
    const auto initial=WVFFTWEngine::lifetimeMetrics();
    auto spec=specification(12,10,37,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,true);
    auto engine=std::shared_ptr<WVFFTEngine>(fft(true));
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::createShared(spec,engine,op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> compact,derivative;
    require(op->createWorkspace(compact,false));
    const auto afterCompact=WVFFTWEngine::lifetimeMetrics();
    require(op->createWorkspace(derivative,true));
    const auto afterPrepare=WVFFTWEngine::lifetimeMetrics();
    require(std::string(derivative->scheduleIdentifier())=="fftw-streaming-pruned-tile16","Derivative preparation replaced retained execution");
    require(afterPrepare.activePlans==afterCompact.activePlans+2 && afterPrepare.totalPlansCreated==afterCompact.totalPlansCreated+2,
        "Bounded derivative did not prepare exactly one full FFT pair");
    const auto planeScratch=spec.grid.Nx*spec.grid.Ny*sizeof(double)+(spec.grid.Nx/2+1)*spec.grid.Ny*sizeof(WVComplex64);
    const auto volumeScratch=planeScratch*spec.grid.planes;
    require(derivative->persistentBytes()>compact->persistentBytes(),"Derivative workspace omitted full-spectrum scratch");
    const auto derivativeScratch=derivative->persistentBytes()-compact->persistentBytes();
    require(derivativeScratch>=planeScratch && derivativeScratch<volumeScratch,"Retained derivative scratch was not bounded to a plane");

    const auto& g=spec.grid;
    const auto size=1+(g.Nx-1)*g.xStride+(g.Ny-1)*g.yStride+(g.planes-1)*g.planeStride;
    std::vector<double> input(size,321),dx(size,654),dy(size,987);
    std::vector<bool> written(size,false);
    const double pi=std::acos(-1.0);
    for (std::size_t p=0;p<g.planes;++p) for (std::size_t y=0;y<g.Ny;++y) for (std::size_t x=0;x<g.Nx;++x) {
        const auto n=p*g.planeStride+y*g.yStride+x*g.xStride; written[n]=true;
        const double phase=2*pi*(3.0*x/g.Nx+2.0*y/g.Ny)+0.17*p;
        input[n]=std::sin(phase)+0.25*(x%2 ? -1.0 : 1.0)+0.125*(y%2 ? -1.0 : 1.0);
    }
    const auto original=input,dxBefore=dx,dyBefore=dy;
    require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)-1},{dx.data(),dx.size()*sizeof(double)},true).code==WVKernelStatusCode::invalidShape,
        "Undersized derivative input accepted");
    require(same(dx,dxBefore),"Rejected derivative input changed output");
    require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)},{dy.data(),dy.size()*sizeof(double)-1},false).code==WVKernelStatusCode::invalidShape,
        "Undersized derivative output accepted");
    require(same(dy,dyBefore),"Rejected derivative output changed storage");
    require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)},{dx.data(),dx.size()*sizeof(double)},true));
    require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)},{dy.data(),dy.size()*sizeof(double)},false));
    for (std::size_t p=0;p<g.planes;++p) for (std::size_t y=0;y<g.Ny;++y) for (std::size_t x=0;x<g.Nx;++x) {
        const auto n=p*g.planeStride+y*g.yStride+x*g.xStride;
        const double phase=2*pi*(3.0*x/g.Nx+2.0*y/g.Ny)+0.17*p;
        close(dx[n],6*pi/spec.Lx*std::cos(phase));
        close(dy[n],4*pi/spec.Ly*std::cos(phase));
    }
    for (std::size_t n=0;n<size;++n) if (!written[n]) {
        require(dx[n]==654 && dy[n]==987,"Derivative changed grid padding");
    }
    require(same(input,original),"Derivative modified input");
    const auto bytes=derivative->persistentBytes(),planBytes=derivative->planBytesLowerBound();
    allocationProbe::calls=0; allocationProbe::counting=true;
    for (unsigned repeat=0;repeat<3;++repeat) {
        require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)},{dx.data(),dx.size()*sizeof(double)},true));
        require(op->spatialDerivative(*derivative,{input.data(),input.size()*sizeof(double)},{dy.data(),dy.size()*sizeof(double)},false));
    }
    allocationProbe::counting=false;
    require(allocationProbe::calls==0,"Prepared bounded derivative allocated");
    require(derivative->persistentBytes()==bytes && derivative->planBytesLowerBound()==planBytes,"Derivative execution changed prepared storage");
    const auto afterExecute=WVFFTWEngine::lifetimeMetrics();
    require(afterExecute.activePlans==afterPrepare.activePlans && afterExecute.totalPlansCreated==afterPrepare.totalPlansCreated,"Derivative execution created FFT plans");
    derivative.reset();
    require(WVFFTWEngine::lifetimeMetrics().activePlans==afterCompact.activePlans,"Bounded derivative FFT plans outlived their workspace");
    compact.reset(); op.reset(); engine.reset();
    const auto final=WVFFTWEngine::lifetimeMetrics();
    require(final.activePlans==initial.activePlans && final.outstandingPlanningBytes==0,"Bounded derivative plan lifetime leaked");
}
void stridedBoundedDerivative() {
    auto spec=specification(8,6,4,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,true,true);
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::create(spec,std::make_unique<RetainedReferenceEngine>(),op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> workspace;
    require(op->createWorkspace(workspace,true));
    require(std::string(workspace->scheduleIdentifier())=="marker-retained","Strided derivative did not retain the prepared provider path");
    const auto& g=spec.grid;
    const auto size=1+(g.Nx-1)*g.xStride+(g.Ny-1)*g.yStride+(g.planes-1)*g.planeStride;
    std::vector<double> input(size,321),output(size,654);
    std::vector<bool> written(size,false);
    const double pi=std::acos(-1.0);
    for (std::size_t p=0;p<g.planes;++p) for (std::size_t y=0;y<g.Ny;++y) for (std::size_t x=0;x<g.Nx;++x) {
        const auto n=p*g.planeStride+y*g.yStride+x*g.xStride; written[n]=true;
        const double phase=2*pi*(2.0*x/g.Nx+1.0*y/g.Ny)+0.13*p;
        input[n]=std::sin(phase)+0.25*(x%2 ? -1.0 : 1.0);
    }
    require(op->spatialDerivative(*workspace,{input.data(),input.size()*sizeof(double)},{output.data(),output.size()*sizeof(double)},true));
    for (std::size_t p=0;p<g.planes;++p) for (std::size_t y=0;y<g.Ny;++y) for (std::size_t x=0;x<g.Nx;++x) {
        const auto n=p*g.planeStride+y*g.yStride+x*g.xStride;
        const double phase=2*pi*(2.0*x/g.Nx+1.0*y/g.Ny)+0.13*p;
        close(output[n],4*pi/spec.Lx*std::cos(phase));
    }
    for (std::size_t n=0;n<size;++n) if (!written[n]) require(output[n]==654,"Strided derivative changed grid padding");
}
void sharedResources() {
    const auto before=WVFFTWEngine::lifetimeMetrics();
    auto engine=std::shared_ptr<WVFFTEngine>(fft(true));
    auto a=specification(32,24,67,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,true);
    auto b=specification(32,24,71,WVComplexRepresentation::split,WVFourierNormalization::unitary,false,true);
    auto different=a; different.outerWorkers=2;
    std::unique_ptr<WVRetainedHorizontalOperator> opA,opB,opDifferent;
    require(WVRetainedHorizontalOperator::createShared(a,engine,opA));
    require(WVRetainedHorizontalOperator::createShared(b,engine,opB));
    require(WVRetainedHorizontalOperator::createShared(different,engine,opDifferent));
    std::unique_ptr<WVRetainedHorizontalWorkspace> wa,wb,wd;
    require(opA->createWorkspace(wa,false));
    const auto firstPlans=WVFFTWEngine::lifetimeMetrics().totalPlansCreated;
    require(opB->createWorkspace(wb,false));
    require(wa->sharedResourceIdentity()!=nullptr && wa->sharedResourceIdentity()==wb->sharedResourceIdentity(),"Compatible layouts did not share resources");
    require(wa->sharedResourceBytes()==wb->sharedResourceBytes() && wa->sharedResourceBytes()>0,"Shared resource accounting mismatch");
    require(WVFFTWEngine::lifetimeMetrics().totalPlansCreated==firstPlans,"Same-key peer created duplicate FFTW plans");
    require(opDifferent->createWorkspace(wd,false));
    require(wd->sharedResourceIdentity()!=wa->sharedResourceIdentity(),"Different effective worker counts shared a resource");
    auto topology=a;
    for (auto& key:topology.modes) if (key.k==1 || key.k==-1) { key.k=2; break; }
    std::unique_ptr<WVRetainedHorizontalOperator> opTopology;
    std::unique_ptr<WVRetainedHorizontalWorkspace> wt;
    require(WVRetainedHorizontalOperator::createShared(topology,engine,opTopology)); require(opTopology->createWorkspace(wt,false));
    require(wt->sharedResourceIdentity()!=wa->sharedResourceIdentity(),"Different active-column topology shared a resource");
    std::vector<double> ia(a.grid.planeStride*a.grid.planes,1.0),ib(b.grid.planeStride*b.grid.planes,2.0);
    Buffer oa(a.retained),ob(b.retained);
    std::atomic<unsigned> ready{0},rejected{0},unexpected{0}; std::atomic<bool> go{false};
    auto exercise=[&](WVRetainedHorizontalOperator& op,WVRetainedHorizontalWorkspace& workspace,std::vector<double>& input,Buffer& output) {
        ++ready; while (!go.load()) std::this_thread::yield();
        for (unsigned i=0;i<64;++i) {
            const auto status=op.forward(workspace,{input.data(),input.size()*sizeof(double)},output.out());
            if (status.code==WVKernelStatusCode::reentrantExecution) ++rejected;
            else if (!status) ++unexpected;
            std::this_thread::yield();
        }
    };
    std::thread ta([&] { exercise(*opA,*wa,ia,oa); }),tb([&] { exercise(*opB,*wb,ib,ob); });
    while (ready.load()!=2) std::this_thread::yield();
    go=true;
    ta.join(); tb.join();
    require(rejected>0 && unexpected==0,"Shared resource did not safely reject concurrent peers");
    require(opA->forward(*wa,{ia.data(),ia.size()*sizeof(double)},oa.out()));
    require(opB->forward(*wb,{ib.data(),ib.size()*sizeof(double)},ob.out()));
    for (std::size_t m=0;m<a.modes.size();++m) for (std::size_t p=0;p<a.grid.planes;++p)
        close(oa.get(p,m),{a.modes[m].k==0 && a.modes[m].l==0 ? 1.0L : 0.0L,0});
    for (std::size_t m=0;m<b.modes.size();++m) for (std::size_t p=0;p<b.grid.planes;++p)
        close(ob.get(p,m),{b.modes[m].k==0 && b.modes[m].l==0 ? 2*std::sqrt(static_cast<long double>(b.grid.Nx*b.grid.Ny)) : 0.0L,0});
    const auto identity=wb->sharedResourceIdentity(); wa.reset(); opA.reset();
    require(wb->sharedResourceIdentity()==identity,"Destroying one owner invalidated its peer");
    require(opB->forward(*wb,{ib.data(),ib.size()*sizeof(double)},ob.out()));
    wb.reset(); wd.reset(); wt.reset(); opB.reset(); opDifferent.reset(); opTopology.reset();
    require(WVFFTWEngine::lifetimeMetrics().activePlans==before.activePlans,"Weak cache retained execution resources");
    // Repeated one-key lifetimes must reuse expired slots, not grow the cache.
    std::size_t bytes=0;
    for (unsigned repeat=0;repeat<4;++repeat) {
        require(WVRetainedHorizontalOperator::createShared(a,engine,opA)); require(opA->createWorkspace(wa,false));
        if (repeat) require(engine->persistentBytes()==bytes,"Expired cache slots grew indefinitely");
        bytes=engine->persistentBytes(); wa.reset(); opA.reset();
    }
    engine.reset();
    require(WVFFTWEngine::lifetimeMetrics().activePlans==before.activePlans,"Shared resource plans leaked");
}
class FailingRetainedEngine final : public WVFFTEngine {
public:
    std::size_t fullCalls=0;
    std::string identifier() const override { return "failing-retained-test"; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    WVKernelStatus createPlan(const WVFFTPlanSpecification&,std::unique_ptr<WVFFTPlan>&) override {
        ++fullCalls; return {WVKernelStatusCode::fftPlanFailure,"Unexpected fallback"};
    }
    WVKernelStatus createRetainedHorizontalPlan(const WVRetainedHorizontalSpecification&,std::unique_ptr<WVRetainedHorizontalPlan>&) override {
        return {WVKernelStatusCode::fftPlanFailure,"Injected genuine provider failure"};
    }
};
void noFailureFallback() {
    auto spec=specification(8,6,2,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,true);
    auto engine=std::make_shared<FailingRetainedEngine>();
    std::unique_ptr<WVRetainedHorizontalOperator> op;
    require(WVRetainedHorizontalOperator::createShared(spec,engine,op));
    std::unique_ptr<WVRetainedHorizontalWorkspace> workspace;
    require(op->createWorkspace(workspace,false).code==WVKernelStatusCode::fftPlanFailure,"Provider failure masked");
    require(!workspace && engine->fullCalls==0,"Genuine provider error triggered fallback");
}
}
int main() {
    try {
        for (auto representation:{WVComplexRepresentation::interleaved,WVComplexRepresentation::split})
            for (auto normalization:{WVFourierNormalization::forwardUnit,WVFourierNormalization::unitary,WVFourierNormalization::inverseUnit}) {
                horizontalCase(12,10,53,representation,normalization,true,false,false);
                horizontalCase(9,7,5,representation,normalization,true,false,true);
            }
        horizontalCase(8,6,2,WVComplexRepresentation::split,WVFourierNormalization::forwardUnit,true,true,true);
        horizontalCase(8,6,2,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,false,false,true);
        multiplierCase(12,10,17,WVComplexRepresentation::interleaved,WVFourierNormalization::forwardUnit,true);
        multiplierCase(9,7,5,WVComplexRepresentation::split,WVFourierNormalization::unitary,true);
        multiplierCase(9,7,3,WVComplexRepresentation::interleaved,WVFourierNormalization::inverseUnit,false);
        multiplierValidation(); unsupportedMultiplierProvider();
        fallbackAndLifetime(); boundedDerivative(); stridedBoundedDerivative(); noFailureFallback(); sharedResources();
        std::cout << "Pruned horizontal: independent DFT, fused retained multipliers, tile/tail, Hermitian boundaries, strided layouts, immutable inputs, zero prepared allocations, bounded derivatives/fallback and shared lifetimes passed.\n";
        return 0;
    } catch(const std::exception& e) {
        allocationProbe::counting=false; allocationProbe::failAfter=-1;
        std::cerr << e.what() << '\n'; return 1;
    }
}
