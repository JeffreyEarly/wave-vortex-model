#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexKernel/WVTransformHydrostaticKernel.hpp"
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
struct Counters { int plans=0,engines=0,created=0,failAt=-1,executed=0; };
struct DerivativeAccessProbe {
    std::size_t cachedField=0,cachedDerivative=0,captures=0;
    WVRealVolumeConstView cached{};
    bool failLookup=false,failCapture=false;
    static WVKernelStatus lookup(void* context,std::size_t field,std::size_t derivative,
        WVRealVolumeConstView& result) {
        auto& probe=*static_cast<DerivativeAccessProbe*>(context);
        if(probe.failLookup)
            return {WVKernelStatusCode::invalidConfiguration,"Injected derivative lookup failure."};
        result=field==probe.cachedField && derivative==probe.cachedDerivative ?
            probe.cached : WVRealVolumeConstView{};
        return WVKernelStatus::ok();
    }
    static WVKernelStatus capture(void* context,std::size_t,std::size_t,
        WVRealVolumeConstView) {
        auto& probe=*static_cast<DerivativeAccessProbe*>(context);
        ++probe.captures;
        return probe.failCapture ?
            WVKernelStatus{WVKernelStatusCode::invalidConfiguration,
                "Injected derivative capture failure."} : WVKernelStatus::ok();
    }
    WVStateDerivativeAccess access() {return {this,lookup,capture};}
};
class Plan final : public WVFFTPlan {
    std::unique_ptr<WVFFTPlan> plan_; Counters& counters_;
public:
    Plan(std::unique_ptr<WVFFTPlan> p,Counters& c):plan_(std::move(p)),counters_(c) { ++counters_.plans; }
    ~Plan() override { --counters_.plans; }
    WVKernelStatus execute(const void* a,void* b) override { ++counters_.executed; return plan_->execute(a,b); }
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
    Counters counters;
    std::unique_ptr<WVTransformHydrostaticKernel> kernel;
    require(bool(WVTransformHydrostaticKernel::create(source,std::make_unique<Engine>(counters),kernel)),"Create failed");
    const auto& g=source->geometry(); const auto S=g.Nj*g.Nkl,R=g.Nx*g.Ny*g.Nz;
    const auto shape=kernel->spectralShape(); const auto volume=kernel->spatialShape();
    std::array<std::vector<WVComplex64>,3> a,b;
    for (auto& x:a) x.resize(S,{.001,-.002});
    for (auto& x:b) x.resize(S,{17,19});
    WVMutableCoefficients amplitudes{{a[0].data(),shape},{a[1].data(),shape},{a[2].data(),shape}};
    require(bool(kernel->constrainCoefficients(amplitudes)),"Constraints failed");
    WVState state{83,17,{{a[0].data(),shape},{a[1].data(),shape},{a[2].data(),shape}}};
    WVMutableCoefficients out{{b[0].data(),shape},{b[1].data(),shape},{b[2].data(),shape}};
    WVFlux flux{out.Ap,out.Am,out.A0};
    std::vector<double> spatial(R,29),scratch(R,31); WVRealVolumeView field{spatial.data(),volume};
    kernel->resetMetrics();
    int evaluationOwner=0,foreignOwner=0;
    require(bool(kernel->beginStateEvaluation(state,&evaluationOwner)),"Begin scoped state evaluation failed");
    require(kernel->metrics().stateValidationCount==1 && kernel->metrics().phasePreparationCount==1,
        "Scoped setup did not validate and prepare phase exactly once");
    require(!kernel->beginStateEvaluation(state),"Nested state evaluation was accepted");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::u,field)),"Scoped field reconstruction failed");
    WVComplexConstView scopedPhase;
    require(bool(kernel->preparedPhase(state,scopedPhase)) && scopedPhase.data!=nullptr && scopedPhase.shape.rows==shape.rows && scopedPhase.shape.columns==shape.columns,
        "Scoped prepared phase was unavailable");
    require(bool(kernel->transformUVEtaToWaveVortex({spatial.data(),volume},{spatial.data(),volume},{spatial.data(),volume},state.t,state.t0,out)),
        "Matching scoped projection was rejected");
    require(kernel->evolveCoefficients(state,amplitudes).code==WVKernelStatusCode::overlappingArrays,
        "Scoped evolution mutated the active immutable state");
    require(kernel->constrainCoefficients(amplitudes).code==WVKernelStatusCode::overlappingArrays,
        "Scoped constraints mutated the active immutable state");
    require(kernel->transformUVEtaToWaveVortex({spatial.data(),volume},{spatial.data(),volume},{spatial.data(),volume},state.t,state.t0,amplitudes).code==WVKernelStatusCode::overlappingArrays,
        "Scoped projection mutated the active immutable state");
    require(kernel->metrics().stateValidationCount==1 && kernel->metrics().phasePreparationCount==1 &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::u)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1,
        "Scoped calls repeated preparation or lost reconstruction metrics");
    require(!kernel->transformUVEtaToWaveVortex({spatial.data(),volume},{spatial.data(),volume},{spatial.data(),volume},state.t+1,state.t0,out),
        "Mismatched scoped projection time was accepted");
    auto registeredCoefficients=a;
    auto foreignState=state;
    foreignState.coefficients={{registeredCoefficients[0].data(),shape},{registeredCoefficients[1].data(),shape},{registeredCoefficients[2].data(),shape}};
    require(!kernel->transformStateField(foreignState,WVHydrostaticField::u,field),"Foreign scoped state was accepted");
    std::vector<double> tendencyFields(3*R);
    WVRealFieldBundleView tendencyBundle{tendencyFields.data(),{g.Nx,g.Ny,g.Nz,3}};
    require(bool(kernel->transformCoefficientTendencyToUVEta(foreignState,tendencyBundle)),
        "Derived coefficient tendency was rejected by the active primary-state scope");
    require(kernel->metrics().stateValidationCount==1 &&
        kernel->metrics().derivedValidationCount==1 &&
        kernel->metrics().tendencyReconstructionCount==std::array<std::size_t,4>{1,1,1,0} &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::u)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1,
        "Derived tendency validation or production was attributed to the primary state");
    require(!kernel->addStateEvaluationView(foreignState,&foreignOwner),"Foreign evaluation owner registered a state view");
    require(bool(kernel->addStateEvaluationView(foreignState,&evaluationOwner,2)),"Additional immutable state view was rejected");
    const auto registeredStatus=kernel->transformStateField(foreignState,WVHydrostaticField::u,field);
    require(bool(registeredStatus),registeredStatus.message.c_str());
    require(kernel->metrics().stateValidationCount==2 && kernel->metrics().phasePreparationCount==1,
        "Additional state view skipped validation or repeated phase preparation");
    require(kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::u)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)][2]==1,
        "Registered Hydrostatic component production lost its component identity");
    require(!kernel->removeStateEvaluationView(state,&evaluationOwner,0),
        "Primary Hydrostatic state view was removed");
    require(!kernel->removeStateEvaluationView(foreignState,&foreignOwner,2),
        "Foreign owner removed a Hydrostatic state view");
    require(bool(kernel->removeStateEvaluationView(foreignState,&evaluationOwner,2)),
        "Hydrostatic state view removal failed");
    require(!kernel->validateStateEvaluation(foreignState) &&
                !kernel->removeStateEvaluationView(foreignState,&evaluationOwner,2),
        "Removed Hydrostatic state view remained registered");
    require(bool(kernel->addStateEvaluationView(foreignState,&evaluationOwner,3)) &&
                bool(kernel->validateStateEvaluation(foreignState)),
        "Hydrostatic state view storage could not be re-registered");
    require(bool(kernel->endStateEvaluation()),"End scoped state evaluation failed");
    const auto savedScopedCoefficient=a[0][0]; a[0][0].real=std::numeric_limits<double>::infinity();
    require(!kernel->beginStateEvaluation(state),"New scope skipped validation for mutated same-pointer state");
    a[0][0]=savedScopedCoefficient;
    kernel->resetMetrics();
    require(bool(kernel->transformStateField(state,WVHydrostaticField::u,field)),"Standalone field reconstruction failed");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::v,field)),"Second standalone field reconstruction failed");
    require(kernel->metrics().stateValidationCount==2 && kernel->metrics().phasePreparationCount==2,
        "Standalone calls did not perform fresh state preparation");
    std::vector<double> compoundReference(R),compoundFirst(R),compoundSecond(R),compoundResult(R);
    require(bool(kernel->beginStateEvaluation(state)),"Compound producer scope begin failed");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::zetaX,
        {compoundReference.data(),volume})),"Reference horizontal vorticity failed");
    kernel->resetMetrics();
    require(bool(kernel->transformStateField(state,WVHydrostaticField::w,
        {compoundFirst.data(),volume},WVHydrostaticDerivative::y)),"Prepared w_y failed");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::v,
        {compoundSecond.data(),volume},WVHydrostaticDerivative::z)),"Prepared v_z failed");
    require(bool(kernel->combinePreparedHorizontalVorticity(WVHydrostaticField::zetaX,
        {compoundFirst.data(),volume},{compoundSecond.data(),volume},
        {compoundResult.data(),volume})),"Prepared horizontal vorticity combination failed");
    require(compoundResult==compoundReference &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::w)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::y)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1 &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::v)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::z)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1 &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::zetaX)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1,
        "Prepared horizontal vorticity changed values or repeated a producer");
    require(bool(kernel->combinePreparedHorizontalVorticity(WVHydrostaticField::zetaX,
        {compoundFirst.data(),volume},{compoundSecond.data(),volume},
        {compoundFirst.data(),volume},WVHydrostaticComponent::geostrophic)) &&
        compoundFirst==compoundReference &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::zetaX)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)]
            [static_cast<std::size_t>(WVHydrostaticComponent::geostrophic)]==1,
        "Exact prepared vorticity alias or component attribution failed");
    std::vector<double> partialCompound(R+1);
    std::copy_n(compoundReference.data(),R,partialCompound.data());
    require(kernel->combinePreparedHorizontalVorticity(WVHydrostaticField::zetaX,
        {partialCompound.data(),volume},{compoundSecond.data(),volume},
        {partialCompound.data()+1,volume}).code==WVKernelStatusCode::overlappingArrays,
        "Partial prepared vorticity alias was accepted");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::rhoTotal,
        {compoundReference.data(),volume},WVHydrostaticDerivative::z)),"Reference density derivative failed");
    kernel->resetMetrics();
    require(bool(kernel->transformStateField(state,WVHydrostaticField::eta,
        {compoundFirst.data(),volume},WVHydrostaticDerivative::z)),"Prepared eta_z failed");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::eta,
        {compoundSecond.data(),volume})),"Prepared eta failed");
    require(bool(kernel->combinePreparedDensityZDerivative(WVHydrostaticField::rhoTotal,
        {compoundFirst.data(),volume},{compoundSecond.data(),volume},
        {compoundResult.data(),volume})),"Prepared density derivative combination failed");
    for(std::size_t i=0;i<R;++i)
        require(std::abs(compoundResult[i]-compoundReference[i])<=1e-12*
            std::max(1.0,std::abs(compoundReference[i])),
            "Prepared density derivative changed values");
    require(kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::eta)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::z)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1 &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::eta)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::value)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1 &&
        kernel->metrics().reconstructionCount[static_cast<std::size_t>(WVHydrostaticField::rhoTotal)]
            [static_cast<std::size_t>(WVHydrostaticDerivative::z)]
            [static_cast<std::size_t>(WVHydrostaticComponent::all)]==1,
        "Prepared density derivative repeated a producer");
    require(bool(kernel->combinePreparedDensityZDerivative(WVHydrostaticField::rhoTotal,
        {compoundFirst.data(),volume},{compoundSecond.data(),volume},
        {compoundFirst.data(),volume})),
        "Exact prepared density alias was rejected");
    for(std::size_t i=0;i<R;++i)
        require(std::abs(compoundFirst[i]-compoundReference[i])<=1e-12*
            std::max(1.0,std::abs(compoundReference[i])),
            "Exact prepared density alias changed values");
    std::copy_n(compoundReference.data(),R,partialCompound.data());
    require(kernel->combinePreparedDensityZDerivative(WVHydrostaticField::rhoTotal,
        {partialCompound.data(),volume},{compoundSecond.data(),volume},
        {partialCompound.data()+1,volume}).code==WVKernelStatusCode::overlappingArrays,
        "Partial prepared density alias was accepted");
    require(!kernel->combinePreparedDensityZDerivative(WVHydrostaticField::u,
        {compoundFirst.data(),volume},{compoundSecond.data(),volume},
        {compoundResult.data(),volume}),"Invalid prepared density target was accepted");
    require(bool(kernel->endStateEvaluation()),"Compound producer scope end failed");
    std::fill(spatial.begin(),spatial.end(),29);
    allocationProbe::calls=0; allocationProbe::counting=true;
    require(bool(kernel->beginStateEvaluation(state)),"Allocation probe scope begin failed");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::u,field)),"Allocation probe scoped field failed");
    require(bool(kernel->endStateEvaluation()),"Allocation probe scope end failed");
    allocationProbe::counting=false;
    require(allocationProbe::calls==0,"Scoped state preparation or reuse allocated");
    std::fill(spatial.begin(),spatial.end(),29);
    auto status=kernel->nonlinearFlux(state,flux); require(bool(status),status.message.c_str());
    const auto referenceFlux=b,referenceState=a;
    const auto retainedBytes=kernel->persistentBytes();
    std::vector<double> raw(3*R),physical(4*R),gradient(R),expected(3*R,0);
    WVRealFieldBundleView rawView{raw.data(),{g.Nx,g.Ny,g.Nz,3}};
    const WVHydrostaticField dynamical[]={WVHydrostaticField::u,WVHydrostaticField::v,WVHydrostaticField::w,WVHydrostaticField::eta};
    for(std::size_t channel=0;channel<4;++channel)
        require(bool(kernel->transformStateField(state,dynamical[channel],{physical.data()+channel*R,volume})),"Prepare shared physical fields");
    const WVRealFieldBundleConstView prepared{physical.data(),{g.Nx,g.Ny,g.Nz,4}};
    const auto physicalBefore=physical;
    const auto fullStart=counters.executed;
    require(bool(kernel->nonlinearFlux(state,flux,&rawView,&prepared)),"Observe raw nonlinear tendency");
    const auto fullExecutions=counters.executed-fullStart;
    for(std::size_t channel=0;channel<3;++channel) {
        const auto target=channel==2 ? 3 : channel;
        for(std::size_t axis=0;axis<3;++axis) {
            require(bool(kernel->transformStateField(state,dynamical[target],{gradient.data(),volume},static_cast<WVHydrostaticDerivative>(axis+1))),"Independent tendency derivative");
            for(std::size_t i=0;i<R;++i) {
                const double correction=target==3 && axis==2 ? physical[3*R+i]*g.dLnN2[i/(g.Nx*g.Ny)] : 0;
                expected[channel*R+i]-=physical[axis*R+i]*(gradient[i]+correction);
            }
        }
    }
    require(raw==expected && physical==physicalBefore,"Raw tendencies precede projection and preserve borrowed fields");
    require(bool(kernel->transformStateField(state,WVHydrostaticField::u,
        {gradient.data(),volume},WVHydrostaticDerivative::z)),
        "Prepare cached Hydrostatic derivative");
    kernel->resetMetrics();
    DerivativeAccessProbe derivativeProbe;
    derivativeProbe.cachedField=static_cast<std::size_t>(WVHydrostaticField::u);
    derivativeProbe.cachedDerivative=static_cast<std::size_t>(WVHydrostaticDerivative::z);
    derivativeProbe.cached={gradient.data(),volume};
    auto derivativeAccess=derivativeProbe.access();
    require(bool(kernel->nonlinearFlux(state,flux,&rawView,&prepared,false,
                &derivativeAccess)) && raw==expected,
        "Hydrostatic nonlinear derivative reuse changed the spatial tendency");
    require(kernel->metrics().reconstructionCount
                [static_cast<std::size_t>(WVHydrostaticField::u)]
                [static_cast<std::size_t>(WVHydrostaticDerivative::z)]
                [static_cast<std::size_t>(WVHydrostaticComponent::all)]==0 &&
            derivativeProbe.captures==8,
        "Hydrostatic nonlinear path reproduced a cached derivative or missed capture");
    derivativeProbe.failLookup=true;
    require(!kernel->nonlinearFlux(state,flux,&rawView,&prepared,false,
                &derivativeAccess),
        "Hydrostatic nonlinear derivative lookup failure was ignored");
    derivativeProbe.failLookup=false;
    derivativeProbe.failCapture=true;
    derivativeProbe.cachedField=99;
    require(!kernel->nonlinearFlux(state,flux,&rawView,&prepared,false,
                &derivativeAccess),
        "Hydrostatic nonlinear derivative capture failure was ignored");
    for(std::size_t channel=0;channel<3;++channel) for(std::size_t i=0;i<S;++i)
        require(b[channel][i].real==referenceFlux[channel][i].real && b[channel][i].imag==referenceFlux[channel][i].imag &&
                a[channel][i].real==referenceState[channel][i].real && a[channel][i].imag==referenceState[channel][i].imag,"Observation changed flux or input state");
    for (auto& values:b) std::fill(values.begin(),values.end(),WVComplex64{17,19});
    const auto rawStart=counters.executed;
    require(bool(kernel->nonlinearFlux(state,flux,&rawView,&prepared,false)),"Spatial-only nonlinear tendency");
    require(raw==expected && physical==physicalBefore && counters.executed-rawStart<fullExecutions,
        "Spatial-only evaluation changed the tendency or retained redundant projection work");
    for(const auto& values:b) for(const auto value:values)
        require(value.real==17 && value.imag==19,"Spatial-only evaluation wrote spectral flux");
    const auto rejectedStart=counters.executed;
    require(kernel->nonlinearFlux(state,flux,nullptr,&prepared,false).code==WVKernelStatusCode::invalidConfiguration &&
        counters.executed==rejectedStart,"Spatial-only evaluation accepted missing output or rejected after FFT work");
    auto badRaw=rawView; badRaw.data=physical.data();
    require(kernel->nonlinearFlux(state,flux,&badRaw,&prepared).code==WVKernelStatusCode::overlappingArrays,"Observed tendency aliases shared fields");
    badRaw=rawView; badRaw.shape.fourth=4;
    require(kernel->nonlinearFlux(state,flux,&badRaw,&prepared).code==WVKernelStatusCode::invalidShape,"Wrong tendency channel count accepted");
    badRaw=rawView; badRaw.data=nullptr;
    require(kernel->nonlinearFlux(state,flux,&badRaw,&prepared).code==WVKernelStatusCode::invalidPointer,"Null tendency output accepted");
    require(raw==expected && physical==physicalBefore,"Invalid observation mutated output");
    allocationProbe::calls=0; allocationProbe::counting=true;
    require(bool(kernel->nonlinearFlux(state,flux,&rawView,&prepared)),"Prepared observation failed");
    allocationProbe::counting=false;
    require(allocationProbe::calls==0 && kernel->persistentBytes()==retainedBytes,"Observation allocated persistent storage");
    for (auto& x:b) std::fill(x.begin(),x.end(),WVComplex64{17,19});
    auto badFlux=flux; badFlux.Fp=amplitudes.Ap;
    status=kernel->nonlinearFlux(state,badFlux); require(status.code==WVKernelStatusCode::overlappingArrays,"Aliased flux accepted");
    badFlux=flux; badFlux.Fm=flux.Fp;
    status=kernel->nonlinearFlux(state,badFlux); require(status.code==WVKernelStatusCode::overlappingArrays,"Overlapping outputs accepted");
    badFlux=flux; badFlux.F0.shape={S,1};
    status=kernel->nonlinearFlux(state,badFlux); require(status.code==WVKernelStatusCode::invalidShape,"Bad shape accepted");
    badFlux=flux; badFlux.Fm.data=nullptr;
    status=kernel->nonlinearFlux(state,badFlux); require(status.code==WVKernelStatusCode::invalidPointer,"Null output accepted");
    auto invalid=state; invalid.t=std::numeric_limits<double>::quiet_NaN();
    require(!kernel->nonlinearFlux(invalid,flux),"NaN time accepted");
    invalid=state; invalid.t=std::numeric_limits<double>::max(); invalid.t0=-invalid.t;
    require(!kernel->evolveCoefficients(invalid,out),"Elapsed-time overflow accepted");
    require(!kernel->transformStateField(state,static_cast<WVHydrostaticField>(99),field),"Invalid field accepted");
    require(!kernel->transformStateField(state,WVHydrostaticField::u,field,static_cast<WVHydrostaticDerivative>(99)),"Invalid derivative accepted");
    require(!kernel->transformStateField(state,WVHydrostaticField::u,field,WVHydrostaticDerivative::value,static_cast<WVHydrostaticComponent>(99)),"Invalid component accepted");
    require(!kernel->transformStateField(state,WVHydrostaticField::zetaX,field,WVHydrostaticDerivative::x),"Unsupported vorticity derivative accepted");
    require(!kernel->transformStateField(state,WVHydrostaticField::rhoTotal,field,WVHydrostaticDerivative::value,WVHydrostaticComponent::wave),"Masked background accepted");
    require(!kernel->transformStateField(state,WVHydrostaticField::ssh,field),"Wrong surface shape accepted");
    require(!kernel->differentiateVertical({scratch.data(),volume},WVHydrostaticFamily::F,0,field),"Order zero accepted");
    require(!kernel->differentiateVertical({scratch.data(),volume},WVHydrostaticFamily::F,5,field),"Order five accepted");
    require(!kernel->integrateVertical({scratch.data(),volume},static_cast<WVHydrostaticFamily>(99),field),"Invalid family accepted");
    require(!kernel->differentiateVertical({spatial.data()+1,volume},WVHydrostaticFamily::G,1,field),"Partial calculus alias accepted");
    auto aliased=out; aliased.Ap=amplitudes.Am;
    require(!kernel->evolveCoefficients(state,aliased),"Cross-family evolution alias accepted");
    const auto saved=a;
    a[2][S-1].real=std::numeric_limits<double>::infinity();
    require(!kernel->transformStateField(state,WVHydrostaticField::u,field),"Infinite coefficient accepted");
    double energy=71;
    require(!kernel->totalEnergy(state.coefficients,energy) && energy==71,"Invalid energy mutated scalar");
    a[2][S-1]=saved[2][S-1];
    for (auto& x:b) for (auto value:x) require(value.real==17 && value.imag==19,"Invalid call mutated coefficients");
    for (auto value:spatial) require(value==29,"Invalid call mutated field");
    require(bool(kernel->evolveCoefficients(state,out)),"Evolution failed");
    require(bool(kernel->evolveCoefficients(state,amplitudes)),"In-place evolution failed");
    for (int j=0;j<3;++j) for (std::size_t i=0;i<S;++i) require(a[j][i].real==b[j][i].real && a[j][i].imag==b[j][i].imag,"In-place evolution differs");
    const auto bytes=kernel->persistentBytes();
    allocationProbe::calls=0; allocationProbe::counting=true;
    for (int i=0;i<5;++i) {
        require(bool(kernel->nonlinearFlux(state,flux)),"Prepared flux failed");
        require(bool(kernel->transformStateField(state,WVHydrostaticField::rhoTotal,field,WVHydrostaticDerivative::z)),"Prepared density failed");
        require(bool(kernel->transformUVEtaToWaveVortex({spatial.data(),volume},{spatial.data(),volume},{spatial.data(),volume},83,17,out)),"Prepared projection failed");
        require(bool(kernel->differentiateVertical({scratch.data(),volume},WVHydrostaticFamily::F,4,field)),"Prepared derivative failed");
        require(bool(kernel->integrateVertical({scratch.data(),volume},WVHydrostaticFamily::G,field)),"Prepared integral failed");
    }
    allocationProbe::counting=false; require(allocationProbe::calls==0 && kernel->persistentBytes()==bytes,"Prepared execution allocates or changes storage");
    const auto* old=kernel.get();
    status=WVTransformHydrostaticKernel::create({},std::make_unique<WVReferenceFFTEngine>(),kernel);
    require(!status && kernel.get()==old,"Failed setup replaced kernel");
    for (int fail=0;fail<4;++fail) {
        int count=0; Counters counters;
        status=WVTransformHydrostaticKernel::create(source,std::make_unique<Engine>(counters),kernel,[&](std::unique_ptr<WVVerticalMatrixBackend>& backend) {
            if (count++==fail) return WVKernelStatus{WVKernelStatusCode::allocationFailure,"Injected matrix factory failure."};
            return WVCreateScalarMatrixBackend(backend);
        });
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"Matrix setup failure leaked or replaced kernel");
    }
    for (int fail=0;fail<2;++fail) {
        Counters counters; counters.failAt=fail;
        status=WVTransformHydrostaticKernel::create(source,std::make_unique<Engine>(counters),kernel);
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"FFT setup failure leaked or replaced kernel");
    }
    bool succeeded=false;
    for (long fail=0;fail<2048;++fail) {
        Counters counters; auto engine=std::make_unique<Engine>(counters);
        allocationProbe::failAfter=fail;
        status=WVTransformHydrostaticKernel::create(source,std::move(engine),kernel);
        allocationProbe::failAfter=-1;
        if (status) { kernel.reset(); require(!counters.engines && !counters.plans,"Successful destruction leaked"); succeeded=true; break; }
        require(kernel.get()==old && !counters.engines && !counters.plans,"Allocation failure leaked or replaced kernel");
    }
    require(succeeded,"Allocation sweep never succeeded");
}

void variableScheduleParity(const std::shared_ptr<const WVStratifiedModalRecord>& source,bool compact = false) {
    std::unique_ptr<WVTransformHydrostaticKernel> frozen, candidate;
    require(bool(WVTransformHydrostaticKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),frozen)),"Frozen schedule setup failed");
    WVVariableExecutionOptions options{WVRetainedHorizontalSchedule::streamingPrunedTile16,2,true};
    if (compact) options.spectralSchedule=WVVariableSpectralSchedule::compactSplitFusedViews;
    options.pointwiseWorkers=2;
    require(bool(WVTransformHydrostaticKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),candidate, WVCreateScalarMatrixBackend, options)),"Candidate schedule setup failed");
    require(std::string(candidate->horizontalScheduleIdentifier())=="full-fft-gather","Reference provider fallback was not reported");
    const auto& g=source->geometry(); const auto S=g.Nj*g.Nkl,R=g.Nx*g.Ny*g.Nz;
    std::array<std::vector<WVComplex64>,3> input,frozenOut,candidateOut;
    for (std::size_t j=0;j<3;++j) { input[j].resize(S); frozenOut[j].resize(S); candidateOut[j].resize(S); for (std::size_t i=0;i<S;++i) input[j][i]={.001*std::sin(.17*i+j),-.002*std::cos(.11*i+j)}; }
    WVMutableCoefficients validInput{{input[0].data(),{g.Nj,g.Nkl}},{input[1].data(),{g.Nj,g.Nkl}},{input[2].data(),{g.Nj,g.Nkl}}};
    require(bool(frozen->constrainCoefficients(validInput)),"Parity input constraints failed");
    const auto inputBefore=input;
    const WVState state{83,17,{{input[0].data(),{g.Nj,g.Nkl}},{input[1].data(),{g.Nj,g.Nkl}},{input[2].data(),{g.Nj,g.Nkl}}}};
    WVFlux frozenFlux{{frozenOut[0].data(),{g.Nj,g.Nkl}},{frozenOut[1].data(),{g.Nj,g.Nkl}},{frozenOut[2].data(),{g.Nj,g.Nkl}}};
    WVFlux candidateFlux{{candidateOut[0].data(),{g.Nj,g.Nkl}},{candidateOut[1].data(),{g.Nj,g.Nkl}},{candidateOut[2].data(),{g.Nj,g.Nkl}}};
    require(bool(frozen->nonlinearFlux(state,frozenFlux)),"Frozen nonlinear flux failed");
    require(bool(candidate->nonlinearFlux(state,candidateFlux)),"Candidate nonlinear flux failed");
    for (std::size_t j=0;j<3;++j) for (std::size_t i=0;i<S;++i) require(std::abs(frozenOut[j][i].real-candidateOut[j][i].real)<1e-12 && std::abs(frozenOut[j][i].imag-candidateOut[j][i].imag)<1e-12,"Candidate nonlinear flux differs");
    auto serialOptions=options; serialOptions.pointwiseWorkers=1;
    std::unique_ptr<WVTransformHydrostaticKernel> serial; std::array<std::vector<WVComplex64>,3> serialOut;
    for (auto& values:serialOut) values.resize(S);
    require(bool(WVTransformHydrostaticKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),serial,
        WVCreateScalarMatrixBackend,serialOptions)),"Single-worker candidate setup failed");
    WVFlux serialFlux{{serialOut[0].data(),{g.Nj,g.Nkl}},{serialOut[1].data(),{g.Nj,g.Nkl}},{serialOut[2].data(),{g.Nj,g.Nkl}}};
    require(bool(serial->nonlinearFlux(state,serialFlux)),"Single-worker candidate flux failed");
    for (std::size_t j=0;j<3;++j) for (std::size_t i=0;i<S;++i)
        require(serialOut[j][i].real==candidateOut[j][i].real && serialOut[j][i].imag==candidateOut[j][i].imag,
            "Pointwise worker partition changed hydrostatic arithmetic");
    std::vector<double> ff(4*R),cf(4*R),fr(3*R),cr(3*R);
    const WVHydrostaticField fields[]={WVHydrostaticField::u,WVHydrostaticField::v,WVHydrostaticField::w,WVHydrostaticField::eta};
    for (std::size_t j=0;j<4;++j) { require(bool(frozen->transformStateField(state,fields[j],{ff.data()+j*R,{g.Nx,g.Ny,g.Nz}})),"Frozen borrowed fields failed"); require(bool(candidate->transformStateField(state,fields[j],{cf.data()+j*R,{g.Nx,g.Ny,g.Nz}})),"Candidate borrowed fields failed"); }
    const auto ffBefore=ff,cfBefore=cf;
    WVRealFieldBundleConstView ffields{ff.data(),{g.Nx,g.Ny,g.Nz,4}},cfields{cf.data(),{g.Nx,g.Ny,g.Nz,4}}; WVRealFieldBundleView frv{fr.data(),{g.Nx,g.Ny,g.Nz,3}},crv{cr.data(),{g.Nx,g.Ny,g.Nz,3}};
    require(bool(frozen->nonlinearFlux(state,frozenFlux,&frv,&ffields)),"Frozen raw flux failed"); allocationProbe::calls=0; allocationProbe::counting=true; require(bool(candidate->nonlinearFlux(state,candidateFlux,&crv,&cfields)),"Candidate raw flux failed"); allocationProbe::counting=false; require(allocationProbe::calls==0,"Candidate prepared nonlinear flux allocated");
    require(ff==ffBefore && cf==cfBefore,"Candidate mutated borrowed fields");
    for (std::size_t i=0;i<fr.size();++i) require(std::abs(fr[i]-cr[i])<1e-12,"Candidate raw tendency differs");
    for (std::size_t i=0;i<ff.size();++i) require(std::abs(ff[i]-cf[i])<1e-12,"Candidate reconstructed field differs");
    for (std::size_t j=0;j<3;++j) for (std::size_t i=0;i<S;++i) require(std::abs(frozenOut[j][i].real-candidateOut[j][i].real)<1e-12 && std::abs(frozenOut[j][i].imag-candidateOut[j][i].imag)<1e-12,"Candidate prepared nonlinear flux differs");
    for (auto* outputs:{&frozenOut,&candidateOut}) for (auto& values:*outputs) std::fill(values.begin(),values.end(),WVComplex64{17,19});
    require(bool(frozen->nonlinearFlux(state,frozenFlux,&frv,&ffields,false)),"Frozen spatial-only flux failed");
    require(bool(candidate->nonlinearFlux(state,candidateFlux,&crv,&cfields,false)),"Candidate spatial-only flux failed");
    require(ff==ffBefore && cf==cfBefore,"Candidate spatial-only evaluation mutated borrowed fields");
    for (std::size_t i=0;i<fr.size();++i) require(std::abs(fr[i]-cr[i])<1e-12,"Candidate spatial-only tendency differs");
    for (const auto* outputs:{&frozenOut,&candidateOut}) for (const auto& values:*outputs) for (const auto value:values)
        require(value.real==17 && value.imag==19,"Spatial-only evaluation wrote spectral flux");
    for (std::size_t j=0;j<3;++j) for (std::size_t i=0;i<S;++i)
        require(input[j][i].real==inputBefore[j][i].real && input[j][i].imag==inputBefore[j][i].imag,"Parity evaluation mutated input coefficients");
    require(frozen->storage().realScratchBytes==10*R*sizeof(double) && candidate->storage().realScratchBytes==6*R*sizeof(double),"Hydrostatic streamed scratch accounting differs");
    require(frozen->storage().spectralScratchBytes==candidate->storage().spectralScratchBytes,"Hydrostatic streamed spectral scratch changed");
    require(candidate->executionOptions().horizontalWorkers==2 && candidate->executionOptions().streamedNonlinear &&
        candidate->executionOptions().pointwiseWorkers==2,"Candidate options were not retained");
    auto* retained=candidate.get(); WVVariableExecutionOptions invalidOptions; invalidOptions.pointwiseWorkers=0;
    const auto status=WVTransformHydrostaticKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),candidate,
        WVCreateScalarMatrixBackend,invalidOptions);
    require(status.code==WVKernelStatusCode::invalidConfiguration && candidate.get()==retained,
        "Zero pointwise workers were accepted or replaced the retained kernel");
}
}
int main() {
    try {
        Temporary file; fixture(file.path);
        { File f(file.path); for (const auto* name:{"WVTransform","AnnotatedClass"}) nc(nc_put_att_text(f.id,NC_GLOBAL,name,std::char_traits<char>::length("WVTransformHydrostatic"),"WVTransformHydrostatic")); }
        std::shared_ptr<const WVStratifiedModalRecord> source; auto status=WVStratifiedModalReader::read(file.path.string(),source); require(bool(status),status.message.c_str());
        contracts(source);
        variableScheduleParity(source);
        variableScheduleParity(source,true);
        std::unique_ptr<WVTransformHydrostaticKernel> kernel; require(bool(WVTransformHydrostaticKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),kernel)),"Lifetime setup failed");
        std::weak_ptr<const WVStratifiedModalRecord> weak=source; source.reset(); require(!weak.expired(),"Kernel lost scientific owner"); kernel.reset(); require(weak.expired(),"Scientific owner leaked");
        std::cout<<"Hydrostatic kernel contracts passed\n"; return 0;
    } catch(const std::exception& e) { allocationProbe::failAfter=-1; allocationProbe::counting=false; std::cerr<<e.what()<<'\n'; return 1; }
}
