#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WaveVortexRuntime/WVHydrostaticForcingEngine.hpp"
#include "WaveVortexRuntime/WVBoussinesqForcingEngine.hpp"
#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WVTestExtensionCatalog.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "WVBoussinesqModalTestFixture.hpp"

#include <array>
#include <iostream>
#include <numeric>
#include <type_traits>

using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::test_fixture;

namespace {
struct FailureCounter { std::size_t calls=0,failAt=0; };
class FailingPlan final : public WVFFTPlan {
public:
    FailingPlan(std::unique_ptr<WVFFTPlan> plan,std::shared_ptr<FailureCounter> count)
        :plan_(std::move(plan)),count_(std::move(count)) {}
    WVKernelStatus execute(const void* input,void* output) override {
        if (++count_->calls==count_->failAt)
            return {WVKernelStatusCode::fftExecutionFailure,"Injected diagnostic FFT failure."};
        return plan_->execute(input,output);
    }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this)+plan_->persistentBytes(); }
private:
    std::unique_ptr<WVFFTPlan> plan_;
    std::shared_ptr<FailureCounter> count_;
};
class FailingEngine final : public WVFFTEngine {
public:
    explicit FailingEngine(std::shared_ptr<FailureCounter> count):count_(std::move(count)) {}
    std::string identifier() const override { return "forcing-diagnostic-reference"; }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this); }
    WVKernelStatus createPlan(const WVFFTPlanSpecification& specification,std::unique_ptr<WVFFTPlan>& result) override {
        std::unique_ptr<WVFFTPlan> plan;
        auto status=reference_.createPlan(specification,plan); if (!status) return status;
        result=std::make_unique<FailingPlan>(std::move(plan),count_); return WVKernelStatus::ok();
    }
private:
    WVReferenceFFTEngine reference_;
    std::shared_ptr<FailureCounter> count_;
};
WVFrozenForcingSchedule schedule(std::size_t S,bool unpairedMean=false) {
    WVPortableTypedRecord fixed{"wave-vortex-forcing-configuration-v1",1,{}};
    std::vector<std::int64_t> indices(S); std::iota(indices.begin(),indices.end(),0);
    for (const char* name:{"Ap","Am","A0"}) {
        fixed.values.push_back({std::string(name)+"Indices",{S},indices});
        fixed.values.push_back({std::string(name)+"ValuesReal",{S},std::vector<double>(S,0)});
        fixed.values.push_back({std::string(name)+"ValuesImag",{S},std::vector<double>(S,0)});
    }
    if (unpairedMean) {
        fixed.values.clear();
        fixed.values={{"ApIndices",{1},std::vector<std::int64_t>{1}},
            {"ApValuesReal",{1},std::vector<double>{0}},
            {"ApValuesImag",{1},std::vector<double>{0}}};
    }
    WVPortableTypedRecord friction{"wave-vortex-forcing-configuration-v1",1,
        {{"r",{},std::vector<double>{2.5e-7}}}};
    WVPortableTypedRecord empty{"wave-vortex-forcing-configuration-v1",1,{}};
    WVPortableTypedRecord filter{"wave-vortex-forcing-configuration-v1",1,
        {{"Nj",{},std::vector<double>{unpairedMean?2.0:1.0}}}};
    WVFrozenForcingSchedule result;
    // Deliberately not in execution order, with actual user instance names.
    result.entries={{"WVFixedAmplitudeForcing",1,"held amplitudes",WVForcingStage::spectralAmplitude,255,3,"",fixed},
        {"WVAntialiasing",1,"mode filter",WVForcingStage::spectral,127,2,"",filter},
        {"WVBottomFrictionLinear",1,"bottom-drag",WVForcingStage::spatial,255,1,"",friction},
        {"WVNonlinearAdvection",1,"nonlinear advection",WVForcingStage::spatial,127,0,"",empty}};
    return result;
}

bool equal(const std::vector<WVComplex64>& a,const std::vector<WVComplex64>& b) {
    if (a.size()!=b.size()) return false;
    for (std::size_t i=0;i<a.size();++i)
        if (a[i].real!=b[i].real || a[i].imag!=b[i].imag) return false;
    return true;
}
void relative(const std::vector<double>& a,const std::vector<double>& b) {
    double scale=0,error=0;
    for (std::size_t i=0;i<a.size();++i) {
        scale=std::max(scale,std::abs(b[i])); error=std::max(error,std::abs(a[i]-b[i]));
    }
    require(error<=1e-12*std::max(scale,1e-30),"Forcing stage difference does not match its accumulated tendency");
}

template<class Engine,class Project,class Reconstruct>
void exercise(Engine& engine,WVShape2D spectral,WVShape4D spatial,
    const std::shared_ptr<FailureCounter>& counter,Project project,Reconstruct reconstruct,bool unpairedMean=false) {
    const auto S=spectral.elementCount(),R=spatial.elementCount();
    std::vector<WVComplex64> coefficients(3*S),rhs(3*S),projected(3*S);
    for (std::size_t i=0;i<coefficients.size();++i)
        coefficients[i]={1e-4*std::sin(.17*(i+1)),1e-4*std::cos(.23*(i+1))};
    WVState state{83,17,{{coefficients.data(),spectral},{coefficients.data()+S,spectral},{coefficients.data()+2*S,spectral}}};
    if constexpr (!std::is_same_v<Engine,WVConstantStratificationForcingEngine>)
        require(bool(engine.kernel().constrainCoefficients({{coefficients.data(),spectral},
            {coefficients.data()+S,spectral},{coefficients.data()+2*S,spectral}})),"Fixture coefficient constraints");
    WVFlux flux{{rhs.data(),spectral},{rhs.data()+S,spectral},{rhs.data()+2*S,spectral}};
    const auto baselineStatus=engine.nonlinearFlux(state,flux);
    if (!baselineStatus) throw std::runtime_error("Baseline forcing RHS: "+baselineStatus.message);
    const auto stateBefore=coefficients,rhsBefore=rhs;
    const auto bytesBefore=engine.persistentBytes();
    const auto evaluationsBefore=engine.metrics().evaluationCount;
    const auto reconstructionsBefore=engine.metrics().physicalFieldReconstructionCount;
    std::array<std::vector<double>,4> fields;
    for (auto& field:fields) field.resize(R,99);
    WVForcingTendencyOutput outputs[]={ {3,{fields[3].data(),spatial}}, {2,{fields[2].data(),spatial}},
        {0,{fields[0].data(),spatial}},{1,{fields[1].data(),spatial}} };
    require(engine.forcingCount()==4 && engine.forcingInstance(0)->name()=="nonlinear advection" &&
        engine.forcingInstance(1)->name()=="bottom-drag" && engine.forcingInstance(2)->name()=="mode filter" && engine.forcingInstance(3)->name()=="held amplitudes" &&
        !engine.forcingInstance(4),"Diagnostic binding does not use the resolved stage order and instance names");
    const auto callStart=counter->calls;
    auto status=engine.evaluateForcingTendencies(state,outputs,4);
    if (!status) throw std::runtime_error(status.message);
    const auto diagnosticFFTCalls=counter->calls-callStart;
    require(equal(coefficients,stateBefore) && engine.metrics().evaluationCount==evaluationsBefore,
        "Diagnostics changed model coefficients or RHS evaluation count");
    require(engine.metrics().physicalFieldReconstructionCount==reconstructionsBefore+1,
        "Same-event forcings did not share physical fields");
    require(engine.tendencyMetrics().forcingEvaluationCount==4 &&
        engine.tendencyMetrics().spatialProjectionCount==1 &&
        engine.tendencyMetrics().spectralReconstructionCount==2 &&
        engine.tendencyMetrics().workspaceLiveBytes==0 &&
        engine.tendencyMetrics().workspaceHighWaterBytes>0 && engine.persistentBytes()==bytesBefore,
        "Forcing diagnostics repeated contributions or retained event workspace");
    std::vector<double> sum(R),expected(R);
    for (std::size_t i=0;i<R;++i) sum[i]=fields[0][i]+fields[1][i];
    require(bool(project(state,sum,projected)),"Independent accumulated tendency projection failed");
    auto removed=projected;
    for (std::size_t i=0;i<projected.size();++i) {
        const auto mode=(i%S)/spectral.rows;
        bool filtered=i%spectral.rows>(unpairedMean?1U:0U);
        if constexpr (std::is_same_v<Engine,WVConstantStratificationForcingEngine>) {
            const auto& descriptor=engine.kernel().descriptor();
            const auto& c=descriptor.configuration();
            filtered|=descriptor.fourierModes()[mode].Kh>(2.0/3.0)*2*std::acos(-1.0)*(c.Nx/2)/c.Lx;
        } else {
            const auto& g=engine.kernel().geometry();
            filtered|=std::hypot(g.k[mode],g.l[mode])>(2.0/3.0)*2*std::acos(-1.0)*(g.Nx/2)/g.Lx;
        }
        removed[i]=filtered ? WVComplex64{-projected[i].real,-projected[i].imag} : WVComplex64{};
        projected[i]=filtered ? WVComplex64{} : WVComplex64{-projected[i].real,-projected[i].imag};
    }
    require(bool(reconstruct(state,removed,expected)),"Independent filter diagnostic reconstruction failed");
    relative(fields[2],expected);
    if (unpairedMean) {
        // A forcing may independently hold just Ap at the horizontal mean.
        // Its real u/v are half the corresponding complete inertial pair.
        const auto ap=projected[1];
        std::fill(projected.begin(),projected.end(),WVComplex64{});
        projected[1]={.5*ap.real,.5*ap.imag};
        projected[S+1]={.5*ap.real,-.5*ap.imag};
    }
    require(bool(reconstruct(state,projected,expected)),"Independent amplitude diagnostic reconstruction failed");
    relative(fields[3],expected);
    require(bool(engine.nonlinearFlux(state,flux)) && equal(rhs,rhsBefore) && equal(coefficients,stateBefore),
        "RHS or scientific state changed after requesting diagnostics");

    auto invalid=outputs[0]; invalid.executionIndex=4;
    require(engine.evaluateForcingTendencies(state,&invalid,1).code==WVKernelStatusCode::invalidConfiguration,"Unbound forcing index accepted");
    invalid=outputs[0]; invalid.fields.data=reinterpret_cast<double*>(coefficients.data());
    require(engine.evaluateForcingTendencies(state,&invalid,1).code==WVKernelStatusCode::overlappingArrays,"Diagnostic output may not alias state");
    invalid=outputs[0]; invalid.fields.shape.fourth++;
    require(engine.evaluateForcingTendencies(state,&invalid,1).code==WVKernelStatusCode::invalidShape,"Wrong diagnostic channel count accepted");
    auto duplicate=std::array<WVForcingTendencyOutput,2>{outputs[0],outputs[0]};
    require(!engine.evaluateForcingTendencies(state,duplicate.data(),duplicate.size()),"Duplicate diagnostic contributions accepted");

    const auto reference=fields;
    for (auto& field:fields) std::fill(field.begin(),field.end(),99);
    // Fail after the spatial contributions have been evaluated, during the
    // final amplitude reconstruction. No partially prepared output may escape.
    counter->failAt=counter->calls+diagnosticFFTCalls;
    status=engine.evaluateForcingTendencies(state,outputs,4);
    require(status.code==WVKernelStatusCode::fftExecutionFailure,"Expected late diagnostic FFT failure");
    for (const auto& field:fields) for (auto value:field) require(value==99,"Failed diagnostic evaluation changed user output");
    require(equal(coefficients,stateBefore) && engine.tendencyMetrics().workspaceLiveBytes==0 && engine.persistentBytes()==bytesBefore,
        "Failed diagnostic evaluation changed state or retained workspace");
    counter->failAt=0;
    require(bool(engine.evaluateForcingTendencies(state,outputs,4)) && fields==reference,
        "Diagnostic retry did not reproduce the successful result");
    std::vector<double> selected(R);
    const WVForcingTendencyOutput single{3,{selected.data(),spatial}};
    require(bool(engine.evaluateForcingTendencies(state,&single,1)) && selected==reference[3],
        "Requesting only the amplitude contribution lost preceding stages");
}

void constant(bool hydrostatic) {
    WVTransformConstantStratificationConfiguration c;
    c.Nx=6; c.Ny=5; c.Nz=7; c.Nj=4; c.Lx=15000; c.Ly=12000; c.Lz=1300;
    c.N0=5.2e-3; c.rho0=1027; c.g=9.80665; c.planetaryRadius=6.3712e6;
    c.rotationRate=7.292115e-5; c.latitude=33; c.isHydrostatic=hydrostatic; c.shouldAntialias=false;
    std::unique_ptr<WVConstantStratificationForcingEngine> initial;
    auto catalog=wavevortex::runtime::test::extensionCatalog();
    require(bool(WVConstantStratificationForcingEngine::create(c,{},catalog,std::make_unique<WVReferenceFFTEngine>(),initial)),"Constant setup");
    const auto spectral=initial->stateShape(); const auto S=spectral.elementCount(),R=c.Nx*c.Ny*c.Nz;
    auto counter=std::make_shared<FailureCounter>();
    std::unique_ptr<WVConstantStratificationForcingEngine> engine;
    require(bool(WVConstantStratificationForcingEngine::create(c,schedule(S),catalog,std::make_unique<FailingEngine>(counter),engine)),"Constant forcing setup");
    const WVShape4D spatial{c.Nx,c.Ny,c.Nz,hydrostatic?3U:4U};
    exercise(*engine,spectral,spatial,counter,
        [&](const WVState& state,const std::vector<double>& sum,std::vector<WVComplex64>& out) {
            WVMutableCoefficients output{{out.data(),spectral},{out.data()+S,spectral},{out.data()+2*S,spectral}};
            return hydrostatic ? engine->kernel().transformUVEtaToWaveVortex({sum.data(),spatial},state.t,state.t0,output) :
                engine->kernel().transformUVWEtaToWaveVortex({sum.data(),spatial},state.t,state.t0,output);
        },
        [&](const WVState& state,const std::vector<WVComplex64>& delta,std::vector<double>& out) {
            WVState d{state.t,state.t0,{{delta.data(),spectral},{delta.data()+S,spectral},{delta.data()+2*S,spectral}}};
            std::vector<double> values(4*R); WVRealFieldBundleView result{values.data(),{c.Nx,c.Ny,c.Nz,4}};
            auto status=engine->kernel().transformWaveVortexToUVWEta(d,result);
            if (status) { std::copy_n(values.data(),2*R,out.data());
                if (hydrostatic) std::copy_n(values.data()+3*R,R,out.data()+2*R);
                else std::copy_n(values.data()+2*R,2*R,out.data()+2*R); }
            return status;
        });
    WVPortableTypedRecord customConfiguration{"wave-vortex-forcing-configuration-v1",1,
        {{"rate",{},std::vector<double>{-.01}}}};
    WVFrozenForcingSchedule custom;
    custom.entries={{wavevortex::runtime::test::LinearCoefficientForcingIdentifier,1,
        "unqualified",WVForcingStage::spectral,90,0,"",customConfiguration}};
    std::unique_ptr<WVConstantStratificationForcingEngine> unsupported;
    require(bool(WVConstantStratificationForcingEngine::create(c,custom,catalog,
        std::make_unique<FailingEngine>(counter),unsupported)),"Custom diagnostic setup");
    std::vector<WVComplex64> coefficients(3*S);
    const WVState state{0,0,{{coefficients.data(),spectral},{coefficients.data()+S,spectral},{coefficients.data()+2*S,spectral}}};
    std::vector<double> output(spatial.elementCount(),99);
    const WVForcingTendencyOutput request{0,{output.data(),spatial}};
    const auto calls=counter->calls;
    require(unsupported->evaluateForcingTendencies(state,&request,1).code==WVKernelStatusCode::unsupportedOperation &&
        counter->calls==calls && unsupported->tendencyMetrics().workspaceHighWaterBytes==0,
        "Unqualified extension was not rejected before evaluation and allocation");
    for (auto value:output) require(value==99,"Preflight rejection changed output");

}

template<bool Hydrostatic> void stratified(bool unpairedMean=false) {
    Temporary file;
    if constexpr (Hydrostatic) {
        fixture(file.path); File f(file.path);
        for (const char* name:{"WVTransform","AnnotatedClass"}) nc(nc_put_att_text(f.id,NC_GLOBAL,name,std::char_traits<char>::length("WVTransformHydrostatic"),"WVTransformHydrostatic"));
    } else boussinesqFixture(file.path);
    change(file.path,"shouldAntialias",0);
    std::shared_ptr<const WVStratifiedModalRecord> source;
    require(bool(WVStratifiedModalReader::read(file.path.string(),source)),"Stratified fixture read");
    using Engine=std::conditional_t<Hydrostatic,WVHydrostaticForcingEngine,WVBoussinesqForcingEngine>;
    const auto& g=source->geometry(); const WVShape2D spectral{g.Nj,g.Nkl};
    const auto S=spectral.elementCount(),R=g.Nx*g.Ny*g.Nz;
    const WVShape4D spatial{g.Nx,g.Ny,g.Nz,Hydrostatic?3U:4U}; const WVShape3D volume{g.Nx,g.Ny,g.Nz};
    auto counter=std::make_shared<FailureCounter>(); std::unique_ptr<Engine> engine;
    require(bool(Engine::create(source,schedule(S,unpairedMean),wavevortex::runtime::test::extensionCatalog(),std::make_unique<FailingEngine>(counter),engine)),"Stratified forcing setup");
    exercise(*engine,spectral,spatial,counter,
        [&](const WVState& state,const std::vector<double>& sum,std::vector<WVComplex64>& out) {
            WVMutableCoefficients output{{out.data(),spectral},{out.data()+S,spectral},{out.data()+2*S,spectral}};
            if constexpr (Hydrostatic) return engine->kernel().transformUVEtaToWaveVortex({sum.data(),volume},{sum.data()+R,volume},{sum.data()+2*R,volume},state.t,state.t0,output);
            else return engine->kernel().transformUVWEtaToWaveVortex({sum.data(),volume},{sum.data()+R,volume},{sum.data()+2*R,volume},{sum.data()+3*R,volume},state.t,state.t0,output);
        },
        [&](const WVState& state,const std::vector<WVComplex64>& delta,std::vector<double>& out) {
            const WVState d{state.t,state.t0,{{delta.data(),spectral},{delta.data()+S,spectral},{delta.data()+2*S,spectral}}};
            for (std::size_t channel=0;channel<spatial.fourth;++channel) {
                WVKernelStatus status;
                if constexpr (Hydrostatic) {
                    const WVHydrostaticField fields[]={WVHydrostaticField::u,WVHydrostaticField::v,WVHydrostaticField::eta};
                    status=engine->kernel().transformStateField(d,fields[channel],{out.data()+channel*R,volume});
                } else {
                    const WVBoussinesqField fields[]={WVBoussinesqField::u,WVBoussinesqField::v,WVBoussinesqField::w,WVBoussinesqField::eta};
                    status=engine->kernel().transformStateField(d,fields[channel],{out.data()+channel*R,volume});
                }
                if (!status) return status;
            }
            return WVKernelStatus::ok();
        },unpairedMean);
}
}
int main() {
    try {
        constant(false); constant(true); stratified<true>(); stratified<false>(); stratified<true>(true); stratified<false>(true);
        std::cout<<"PASS: ordered forcing diagnostics, state isolation, and transactional retry\n";
        return 0;
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
