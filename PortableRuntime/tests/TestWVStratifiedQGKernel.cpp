#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexKernel/WVTransformStratifiedQGKernel.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "../../tools/compiled-kernel/tests/WVAllocationProbe.hpp"
#include "WVStratifiedModalTestFixture.hpp"
#include <iostream>
#include <limits>
using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::test_fixture;
static_assert(!std::is_copy_assignable<WVStratifiedModalRecord>::value,"Published scientific records must not be reassigned.");
static_assert(!std::is_move_assignable<WVStratifiedModalRecord>::value,"Published scientific records must not be moved over.");
namespace {
struct Counters { int plans=0,engines=0,created=0,failAt=-1; };
class Plan final : public WVFFTPlan {
    std::unique_ptr<WVFFTPlan> plan_; Counters& counters_;
public:
    Plan(std::unique_ptr<WVFFTPlan> p,Counters& c):plan_(std::move(p)),counters_(c) { ++counters_.plans; }
    ~Plan() override { --counters_.plans; }
    WVKernelStatus execute(const void* a,void* b) override { return plan_->execute(a,b); }
    std::size_t persistentBytes() const noexcept override { return plan_->persistentBytes(); }
};
class Engine final : public WVFFTEngine {
    WVReferenceFFTEngine engine_; Counters& counters_;
public:
    explicit Engine(Counters& c):counters_(c) { ++counters_.engines; }
    ~Engine() override { --counters_.engines; }
    std::string identifier() const override { return "failure-probe"; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& s,std::unique_ptr<WVFFTPlan>& p) override {
        if (counters_.created++==counters_.failAt) return {WVKernelStatusCode::fftPlanFailure,"Injected plan failure."};
        std::unique_ptr<WVFFTPlan> q; auto status=engine_.createPlan(s,q); if (!status) return status;
        p=std::make_unique<Plan>(std::move(q),counters_); return WVKernelStatus::ok();
    }
};
void contracts(const std::shared_ptr<const WVStratifiedModalRecord>& source) {
    std::unique_ptr<WVTransformStratifiedQGKernel> kernel;
    require(bool(WVTransformStratifiedQGKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),kernel)),"Create failed");
    const auto& g=source->geometry(); const auto S=g.Nj*g.Nkl,R=g.Nx*g.Ny*g.Nz;
    std::vector<WVComplex64> a(S,{0.001,-0.002}),b(S,{17,19}); const auto saved=a;
    std::vector<double> spatial(R,29); WVComplexConstView input{a.data(),{g.Nj,g.Nkl}}; WVComplexView output{b.data(),{g.Nj,g.Nkl}};
    auto status=kernel->nonlinearFlux(input,{a.data(),input.shape}); require(status.code==WVKernelStatusCode::overlappingArrays,"Aliased flux accepted");
    status=kernel->nonlinearFlux(input,{b.data(),{S,1}}); require(status.code==WVKernelStatusCode::invalidShape,"Bad shape accepted");
    status=kernel->nonlinearFlux(input,output,std::numeric_limits<double>::quiet_NaN()); require(status.code==WVKernelStatusCode::invalidConfiguration,"NaN beta accepted");
    require(b[0].real==17 && spatial[0]==29,"Invalid call mutated output");
    status=kernel->transformA0ToField(input,static_cast<WVStratifiedQGField>(99),{spatial.data(),kernel->spatialShape()}); require(status.code==WVKernelStatusCode::unsupportedOperation,"Unknown field accepted");
    status=kernel->transformA0ToField(input,WVStratifiedQGField::u,{nullptr,kernel->spatialShape()}); require(status.code==WVKernelStatusCode::invalidPointer,"Null field accepted");
    for (auto operation : {&WVTransformStratifiedQGKernel::verticalDiffusivityFlux,&WVTransformStratifiedQGKernel::linearBottomFrictionFlux,&WVTransformStratifiedQGKernel::quadraticBottomFrictionFlux}) {
        status=(kernel.get()->*operation)(input,-1,output); require(status.code==WVKernelStatusCode::invalidConfiguration,"Negative closure coefficient accepted");
        status=(kernel.get()->*operation)(input,std::numeric_limits<double>::infinity(),output); require(status.code==WVKernelStatusCode::invalidConfiguration,"Infinite closure coefficient accepted");
        status=(kernel.get()->*operation)(input,1,{a.data(),input.shape}); require(status.code==WVKernelStatusCode::overlappingArrays,"Aliased closure accepted");
        require(b[0].real==17,"Invalid closure mutated output");
        require(bool((kernel.get()->*operation)(input,0,output)),"Zero closure failed");
        for (const auto x:b) require(x.real==0 && x.imag==0,"Zero closure has a tendency");
        std::fill(b.begin(),b.end(),WVComplex64{17,19});
    }
    std::vector<double> tracer(R), tracerFlux(R), velocity(3*R,0), expectedTracer(R);
    const double pi=std::acos(-1.0);
    for (std::size_t z=0;z<g.Nz;++z) for(std::size_t y=0;y<g.Ny;++y) for(std::size_t x=0;x<g.Nx;++x) {
        const auto i=x+g.Nx*(y+g.Ny*z); const double scale=1+.2*z;
        tracer[i]=scale*(std::sin(6*pi*x/g.Nx)+std::cos(4*pi*y/g.Ny)+std::cos(pi*x)+std::cos(pi*y));
        velocity[i]=1; velocity[R+i]=.5;
        expectedTracer[i]=scale*(-6*pi/g.Lx*std::cos(6*pi*x/g.Nx)+2*pi/g.Ly*std::sin(4*pi*y/g.Ny));
    }
    WVRealVolumeConstView tracerInput{tracer.data(),kernel->spatialShape()};
    WVRealVolumeView tracerOutput{tracerFlux.data(),kernel->spatialShape()};
    WVRealFieldBundleConstView advection{velocity.data(),{g.Nx,g.Ny,g.Nz,3}};
    status=kernel->advectScalarWithAdvectionFields(tracerInput,advection,false,tracerOutput); require(bool(status),"Full-grid tracer derivative failed");
    for (std::size_t i=0;i<R;++i) require(std::abs(tracerFlux[i]-expectedTracer[i])<1e-14,"Full-grid tracer derivative or Nyquist handling differs");
    status=kernel->advectScalarWithAdvectionFields(tracerInput,advection,true,tracerOutput); require(bool(status),"Tracer projection failed");
    for(double value:tracerFlux) require(std::abs(value)<1e-14,"Tracer flux failed retained-mode filtering");
    status=kernel->advectScalarWithAdvectionFields(tracerInput,advection,false,{tracer.data()+1,kernel->spatialShape()});
    require(status.code==WVKernelStatusCode::overlappingArrays,"Partial tracer alias accepted");
    require(bool(kernel->nonlinearFlux(input,output)),"Flux failed");
    allocationProbe::calls=0; allocationProbe::counting=true;
    for (int i=0;i<5;++i) {
        require(bool(kernel->advectScalarWithAdvectionFields(tracerInput,advection,true,tracerOutput)),"Prepared tracer allocation test failed");
        require(bool(kernel->nonlinearFlux(input,output)),"Prepared flux failed");
        require(bool(kernel->verticalDiffusivityFlux(input,.002,output)),"Prepared diffusivity failed");
        require(bool(kernel->linearBottomFrictionFlux(input,1e-5,output)),"Prepared linear friction failed");
        require(bool(kernel->quadraticBottomFrictionFlux(input,.003,output)),"Prepared quadratic friction failed");
        require(bool(kernel->transformA0ToField(input,WVStratifiedQGField::rhoTotal,{spatial.data(),kernel->spatialShape()},WVStratifiedQGDerivative::z)),"Prepared density derivative failed");
        require(bool(kernel->transformQGPVToA0({spatial.data(),kernel->spatialShape()},output)),"Prepared projection failed");
    }
    allocationProbe::counting=false; require(allocationProbe::calls==0,"Prepared allocation");
    for (std::size_t i=0;i<S;++i) require(a[i].real==saved[i].real && a[i].imag==saved[i].imag,"Input mutated");
    require(bool(kernel->evolveA0(input,19,{a.data(),input.shape})),"In-place stationary evolution failed");
    const auto* old=kernel.get();
    status=WVTransformStratifiedQGKernel::create({},std::make_unique<WVReferenceFFTEngine>(),kernel);
    require(!status && kernel.get()==old,"Failed setup replaced kernel");
    for (int fail=0;fail<4;++fail) {
        int count=0; Counters counters;
        status=WVTransformStratifiedQGKernel::create(source,std::make_unique<Engine>(counters),kernel,[&](std::unique_ptr<WVVerticalMatrixBackend>& backend) {
            if (count++==fail) return WVKernelStatus{WVKernelStatusCode::allocationFailure,"Injected matrix factory failure."};
            return WVCreateScalarMatrixBackend(backend);
        });
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"Matrix setup failure leaked or replaced kernel");
    }
    for (int fail=0;fail<2;++fail) {
        Counters counters; counters.failAt=fail;
        status=WVTransformStratifiedQGKernel::create(source,std::make_unique<Engine>(counters),kernel);
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"FFT setup failure leaked or replaced kernel");
    }
    bool succeeded=false;
    for (long fail=0;fail<2048;++fail) {
        Counters counters; auto engine=std::make_unique<Engine>(counters);
        allocationProbe::failAfter=fail;
        status=WVTransformStratifiedQGKernel::create(source,std::move(engine),kernel);
        allocationProbe::failAfter=-1;
        if (status) { kernel.reset(); require(!counters.engines && !counters.plans,"Successful destruction leaked"); succeeded=true; break; }
        require(kernel.get()==old && !counters.engines && !counters.plans,"Allocation failure leaked or replaced kernel");
    }
    require(succeeded,"Allocation sweep never succeeded");
}
}
int main() {
    try {
        Temporary file; fixture(file.path);
        std::shared_ptr<const WVStratifiedModalRecord> source; auto status=WVStratifiedModalReader::read(file.path.string(),source); require(bool(status),status.message.c_str());
        contracts(source);
        std::unique_ptr<WVTransformStratifiedQGKernel> kernel; require(bool(WVTransformStratifiedQGKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),kernel)),"Lifetime setup failed");
        std::weak_ptr<const WVStratifiedModalRecord> weak=source; source.reset(); require(!weak.expired(),"Kernel lost scientific owner"); kernel.reset(); require(weak.expired(),"Scientific owner leaked");
        std::cout<<"Stratified QG kernel contracts passed\n"; return 0;
    } catch(const std::exception& e) { allocationProbe::failAfter=-1; allocationProbe::counting=false; std::cerr<<e.what()<<'\n'; return 1; }
}
