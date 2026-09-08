#include "WaveVortexRuntime/WVBoussinesqForcingEngine.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WaveVortexRuntime/WVForcingContracts.hpp"
#include "WVForcingDiagnosticWorkspace.hpp"
#include <algorithm>
#include <cmath>
#include <limits>
#include <set>
#include <sstream>
namespace wavevortex::runtime {
namespace {
constexpr double pi=3.14159265358979323846;
WVComplex64 add(WVComplex64 a,WVComplex64 b) { return {a.real+b.real,a.imag+b.imag}; }
WVComplex64 multiply(WVComplex64 a,WVComplex64 b) { return {a.real*b.real-a.imag*b.imag,a.real*b.imag+a.imag*b.real}; }
WVComplex64 scale(WVComplex64 a,double b) { return {a.real*b,a.imag*b}; }
WVComplex64 conjugate(WVComplex64 a) { return {a.real,-a.imag}; }
WVKernelStatus invalid(const char* message) { return {WVKernelStatusCode::invalidConfiguration,message}; }
class BoussinesqErrorPolicy final : public WVIntegrationErrorPolicy {
public:
    BoussinesqErrorPolicy(std::vector<double> wave,std::vector<double> vortex):wave_(std::move(wave)),vortex_(std::move(vortex)) {}
    std::size_t componentCount() const noexcept override { return 3; }
    std::size_t elementCount(std::size_t component) const noexcept override { return component<3 ? wave_.size() : 0; }
    double absoluteTolerance(std::size_t component,std::size_t index) const noexcept override { return component<3 && index<wave_.size() ? (component<2 ? wave_[index] : vortex_[index]) : std::numeric_limits<double>::quiet_NaN(); }
    std::size_t persistentBytes() const noexcept override { return sizeof(*this)+(wave_.capacity()+vortex_.capacity())*sizeof(double); }
private:
    std::vector<double> wave_,vortex_;
};
}
WVKernelStatus WVBoussinesqForcingEngine::validateSchedule(const WVStratifiedModalGeometry& g,const WVFrozenForcingSchedule& schedule,WVShape2D shape,const WVExtensionCatalog& catalog) {
    if (g.transformClass!="WVTransformBoussinesq" || shape.rows!=g.Nj || shape.columns!=g.Nkl) return invalid("Boussinesq forcing geometry and coefficients differ.");
    WVTransformConstantStratificationConfiguration compatibility;
    compatibility.Nj=g.Nj; compatibility.shouldAntialias=g.shouldAntialias; compatibility.isHydrostatic=false;
    auto s=WVConstantStratificationForcingEngine::validateSchedule(compatibility,schedule,shape,catalog); if (!s) return s;
    for (const auto& entry:schedule.entries) {
        const auto* registration=catalog.forcings().registration(entry.typeIdentifier,entry.contractVersion);
        if (!registration || !registration->boussinesqFactory) return {WVKernelStatusCode::unsupportedOperation,"No paired Boussinesq forcing implementation."};
        const char* type=entry.stage==WVForcingStage::spatial ? "NonhydrostaticSpatial" : entry.stage==WVForcingStage::spectral ? "Spectral" : "SpectralAmplitude";
        if (std::find(registration->forcingTypes.begin(),registration->forcingTypes.end(),type)==registration->forcingTypes.end()) return {WVKernelStatusCode::unsupportedOperation,"Forcing is incompatible with Boussinesq dynamics."};
        for (const char* name:{"ApIndices","AmIndices","A0Indices"}) {
            const auto* value=entry.configuration.value(name); if (!value) continue;
            const auto* indices=std::get_if<std::vector<std::int64_t>>(&value->storage);
            if (!indices) return invalid("Forcing indices must be integers.");
            for (auto index:*indices) if (index<0 || static_cast<std::size_t>(index)>=shape.elementCount()) return invalid("Forcing index outside Boussinesq coefficients.");
        }
    }
    return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::create(std::shared_ptr<const WVStratifiedModalSource> source,const WVFrozenForcingSchedule& schedule,std::shared_ptr<const WVExtensionCatalog> catalog,std::unique_ptr<WVFFTEngine> fft,std::unique_ptr<WVBoussinesqForcingEngine>& result) {
    if (!source || !catalog || !fft) return invalid("Boussinesq forcing requires scientific source, catalog and FFT engine.");
    try {
        const auto& g=source->geometry();
        auto s=validateSchedule(g,schedule,{g.Nj,g.Nkl},*catalog); if (!s) return s;
        auto candidate=std::unique_ptr<WVBoussinesqForcingEngine>(new WVBoussinesqForcingEngine);
        candidate->catalog_=std::move(catalog);
        s=WVTransformBoussinesqKernel::create(std::move(source),std::move(fft),candidate->kernel_); if (!s) return s;
        s=candidate->initialize(schedule); if (!s) return s;
        result=std::move(candidate); return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Boussinesq forcing allocation failed."}; }
}
WVKernelStatus WVBoussinesqForcingEngine::initialize(const WVFrozenForcingSchedule& schedule) {
    const auto& g=kernel().geometry();
    preparation_.maximumVerticalMode=static_cast<std::size_t>(*std::max_element(g.j.begin(),g.j.end()));
    for (std::size_t m=0;m<g.Nkl;++m) preparation_.maximumHorizontalComponent=std::max({preparation_.maximumHorizontalComponent,std::abs(g.k[m]),std::abs(g.l[m])});
    std::vector<const WVFrozenForcingEntry*> entries;
    for (const auto& e:schedule.entries) { entries.push_back(&e); preparation_.hasAdaptiveDamping|=catalog_->forcings().registration(e.typeIdentifier,e.contractVersion)->providesAdaptiveDamping; }
    for(const auto* entry:entries) {
        const auto& prepare=catalog_->forcings().registration(entry->typeIdentifier,entry->contractVersion)->prepareBoussinesqResolution;
        if(prepare) { const auto status=prepare(*entry,kernel(),preparation_); if(!status) return status; }
    }
    std::stable_sort(entries.begin(),entries.end(),[](const auto* a,const auto* b) { if (a->stage!=b->stage) return a->stage<b->stage; if (a->priority!=b->priority) return a->priority<b->priority; return a->ordinal<b->ordinal; });
    std::ostringstream identifier; identifier<<WVForcingScheduleProfileIdentifier<<':';
    for (const auto* e:entries) {
        std::unique_ptr<WVForcing> forcing;
        auto s=catalog_->forcings().registration(e->typeIdentifier,e->contractVersion)->boussinesqFactory(*e,kernel(),preparation_,forcing); if (!s) return s;
        if (!forcing || forcing->stage()!=e->stage) return invalid("Boussinesq forcing factory returned an incompatible stage.");
        identifier<<e->typeIdentifier<<',';
        if (e->stage==WVForcingStage::spatial) ++metrics_.resolvedSpatialCount;
        else if(e->stage==WVForcingStage::spectral) ++metrics_.resolvedSpectralCount;
        else ++metrics_.resolvedAmplitudeCount;
        metrics_.derivedOperatorBytes+=forcing->persistentBytes(); forcing_.push_back(std::move(forcing));
    }
    scheduleIdentifier_=identifier.str();
    const auto R=kernel().spatialShape().elementCount(),S=kernel().spectralShape().elementCount();
    physical_.resize(4*R); spatial_.resize(4*R); derivative_.resize(2*R); temporary_.resize(3*S);
    metrics_.scheduleBytes=scheduleIdentifier_.capacity()+forcing_.capacity()*sizeof(std::unique_ptr<WVForcing>);
    metrics_.workspaceCapacityBytes=(physical_.capacity()+spatial_.capacity()+derivative_.capacity())*sizeof(double)+temporary_.capacity()*sizeof(WVComplex64);
    metrics_.workspaceHighWaterBytes=metrics_.workspaceCapacityBytes;
    return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::nonlinearFlux(const WVState& state,WVFlux& flux) {
    if (executing_) return {WVKernelStatusCode::reentrantExecution,"Boussinesq forcing workspace is active."};
    const auto bytes=kernel().spectralShape().elementCount()*sizeof(WVComplex64);
    for (auto input:{state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0})
        for (auto output:{flux.Fp,flux.Fm,flux.F0}) {
            const auto a=reinterpret_cast<std::uintptr_t>(input.data),b=reinterpret_cast<std::uintptr_t>(output.data);
            if (a && b && (a<=b ? b-a<bytes : a-b<bytes)) return {WVKernelStatusCode::overlappingArrays,"Boussinesq RHS output overlaps its input state."};
        }
    // The kernel's phase operation validates all coefficient pointers, aliases,
    // values and time before user output can be cleared or written.
    auto s=kernel().evolveCoefficients(state,{flux.Fp,flux.Fm,flux.F0}); if (!s) return s;
    executing_=true; struct Guard { bool& x; ~Guard(){x=false;} } guard{executing_};
    physicalValid_=false;
    for (auto x:{flux.Fp,flux.Fm,flux.F0}) std::fill_n(x.data,x.shape.elementCount(),WVComplex64{});
    WVForcingExecutionContext context; bool initialized=true;
    context.boussinesq_=this; context.state_=&state; context.flux_=&flux; context.outputInitialized_=&initialized;
    if (!linearDynamics_) for (const auto& forcing:forcing_) { s=forcing->addRightHandSide(context); if (!s) return s; }
    ++metrics_.evaluationCount; return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::physicalFields(const WVState& state,WVRealFieldBundleConstView& fields) {
    if (diagnosticWorkspace_) {
        auto& work=*diagnosticWorkspace_;
        const auto shape=kernel().spatialShape(); const auto R=shape.elementCount();
        if (!work.physicalPrepared) {
            const WVBoussinesqField names[]={WVBoussinesqField::u,WVBoussinesqField::v,WVBoussinesqField::w,WVBoussinesqField::eta};
            for (std::size_t channel=0;channel<4;++channel) {
                auto status=kernel().transformStateField(state,names[channel],{work.physical.data()+channel*R,shape});
                if (!status) return status;
            }
            work.physicalPrepared=true; ++metrics_.physicalFieldReconstructionCount;
        } else ++metrics_.physicalFieldReuseCount;
        fields={work.physical.data(),{shape.first,shape.second,shape.third,4}};
        return WVKernelStatus::ok();
    }
    // Reuse is limited to one explicitly active RHS evaluation. External calls
    // always reconstruct, even when a caller mutates coefficients in place.
    if (!executing_) physicalValid_=false;
    const auto shape=kernel().spatialShape(); const auto R=shape.elementCount();
    if (!physicalValid_) {
        const WVBoussinesqField names[]={WVBoussinesqField::u,WVBoussinesqField::v,WVBoussinesqField::w,WVBoussinesqField::eta};
        for (std::size_t i=0;i<4;++i) { auto s=kernel().transformStateField(state,names[i],{physical_.data()+i*R,shape}); if (!s) return s; }
        physicalValid_=true; ++metrics_.physicalFieldReconstructionCount;
    } else ++metrics_.physicalFieldReuseCount;
    fields={physical_.data(),{shape.first,shape.second,shape.third,4}}; return WVKernelStatus::ok();
}
WVRealFieldBundleView WVBoussinesqForcingEngine::clearedSpatialTendency() {
    std::fill(spatial_.begin(),spatial_.end(),0); const auto g=kernel().spatialShape(); return {spatial_.data(),{g.first,g.second,g.third,4}};
}
WVKernelStatus WVBoussinesqForcingEngine::addProjectedSpatialTendency(const WVState& state,WVRealFieldBundleConstView fields,WVFlux& flux) {
    if (diagnosticWorkspace_) {
        return diagnosticWorkspace_->addSpatial(fields);
    }
    const auto R=kernel().spatialShape().elementCount(),S=kernel().spectralShape().elementCount(); const auto shape=kernel().spectralShape();
    if (fields.shape.first!=kernel().geometry().Nx || fields.shape.second!=kernel().geometry().Ny || fields.shape.third!=kernel().geometry().Nz || fields.shape.fourth!=4 || !fields.data) return invalid("Boussinesq tendency requires [Nx,Ny,Nz,4].");
    WVMutableCoefficients out{{temporary_.data(),shape},{temporary_.data()+S,shape},{temporary_.data()+2*S,shape}};
    auto s=kernel().transformUVWEtaToWaveVortex({fields.data,kernel().spatialShape()},{fields.data+R,kernel().spatialShape()},{fields.data+2*R,kernel().spatialShape()},{fields.data+3*R,kernel().spatialShape()},state.t,state.t0,out); if (!s) return s;
    const WVComplexView target[]={flux.Fp,flux.Fm,flux.F0};
    for(int j=0;j<3;++j) for(std::size_t i=0;i<S;++i) target[j].data[i]=add(target[j].data[i],temporary_[j*S+i]);
    ++metrics_.spatialTendencyProjectionCount; return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::addNonlinearFlux(const WVState& state,WVFlux& flux) {
    if (diagnosticWorkspace_) {
        WVRealFieldBundleConstView fields;
        auto status=physicalFields(state,fields); if (!status) return status;
        diagnosticWorkspace_->spatialCaptured=true;
        auto raw=diagnosticWorkspace_->rawView();
        auto temporary=diagnosticWorkspace_->temporaryView();
        return kernel().nonlinearFlux(state,temporary,&raw,&fields);
    }
    const auto S=kernel().spectralShape().elementCount(); const auto shape=kernel().spectralShape();
    WVFlux tmp{{temporary_.data(),shape},{temporary_.data()+S,shape},{temporary_.data()+2*S,shape}};
    auto s=kernel().nonlinearFlux(state,tmp); if (!s) return s;
    const WVComplexView target[]={flux.Fp,flux.Fm,flux.F0};
    for(int j=0;j<3;++j) for(std::size_t i=0;i<S;++i) target[j].data[i]=add(target[j].data[i],temporary_[j*S+i]);
    return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::addLaplacianDamping(const WVState& state,double nu,double kappa,WVLaplacianDirection direction,WVFlux& flux) {
    WVRealFieldBundleConstView fields; auto s=physicalFields(state,fields); if (!s) return s;
    const auto shape=kernel().spatialShape(); const auto R=shape.elementCount(); auto tendency=clearedSpatialTendency();
    for (std::size_t j=0;j<4;++j) {
        const double coefficient=j==3 ? kappa : nu; const WVRealVolumeConstView a{fields.data+j*R,shape};
        if (direction==WVLaplacianDirection::vertical) {
            s=kernel().differentiateVertical(a,j>=2 ? WVBoussinesqFamily::G : WVBoussinesqFamily::F,2,{derivative_.data(),shape}); if (!s) return s;
            for(std::size_t i=0;i<R;++i) tendency.data[j*R+i]=coefficient*(derivative_[i]-(j==3 ? kernel().geometry().dLnN2[i/(shape.first*shape.second)] : 0));
        } else {
            for(bool x:{true,false}) {
                s=kernel().differentiateHorizontal(a,x,{derivative_.data(),shape}); if (!s) return s;
                s=kernel().differentiateHorizontal({derivative_.data(),shape},x,{derivative_.data()+R,shape}); if (!s) return s;
                for(std::size_t i=0;i<R;++i) tendency.data[j*R+i]+=coefficient*derivative_[R+i];
            }
        }
    }
    return addProjectedSpatialTendency(state,{tendency.data,tendency.shape},flux);
}
WVKernelStatus WVBoussinesqForcingEngine::addVerticalDiffusivity(const WVState& state,double kappa,bool forceMean,WVFlux& flux) {
    WVRealFieldBundleConstView fields; auto s=physicalFields(state,fields); if (!s) return s;
    const auto shape=kernel().spatialShape(); const auto R=shape.elementCount(); auto tendency=clearedSpatialTendency();
    s=kernel().differentiateVertical({fields.data+3*R,shape},WVBoussinesqFamily::G,2,{derivative_.data(),shape}); if (!s) return s;
    for (std::size_t i=0;i<R;++i) tendency.data[3*R+i]=kappa*(derivative_[i]-(forceMean ? kernel().geometry().dLnN2[i/(shape.first*shape.second)] : 0));
    return addProjectedSpatialTendency(state,{tendency.data,tendency.shape},flux);
}
WVKernelStatus WVBoussinesqForcingEngine::speedMaxima(const WVState& state,double& uv,double& w) {
    WVRealFieldBundleConstView fields; auto s=physicalFields(state,fields); if (!s) return s;
    const auto R=kernel().spatialShape().elementCount(); uv=0; w=0;
    for(std::size_t i=0;i<R;++i) { uv=std::max(uv,std::hypot(fields.data[i],fields.data[R+i])); w=std::max(w,std::abs(fields.data[2*R+i])); }
    return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::addAdaptiveDamping(const WVState& state,const std::vector<double>& damping,WVFlux& flux) {
    double uv,w; auto s=speedMaxima(state,uv,w); if (!s) return s;
    const WVComplexConstView a[]={state.coefficients.Ap,state.coefficients.Am,state.coefficients.A0}; const WVComplexView b[]={flux.Fp,flux.Fm,flux.F0};
    for (int j=0;j<3;++j) for(std::size_t i=0;i<damping.size();++i) b[j].data[i]=add(b[j].data[i],scale(a[j].data[i],uv*damping[i]));
    return WVKernelStatus::ok();
}
WVKernelStatus WVBoussinesqForcingEngine::addPseudoTopographicGeneration(const WVState& state,const WVPseudoTopographicOperators& o,WVFlux& flux) {
    const auto& c=o.configuration; const double elapsed=state.t-c.startTime;
    if(elapsed<0) return WVKernelStatus::ok();
    const double ramp=c.rampDuration==0 || elapsed>=c.rampDuration ? 1 : .5*(1-std::cos(pi*elapsed/c.rampDuration));
    const WVComplex64 oscillation{std::cos(c.frequency*elapsed),-std::sin(c.frequency*elapsed)};
    const double u=ramp*multiply(c.barotropicVelocityAmplitude[0],oscillation).real,v=ramp*multiply(c.barotropicVelocityAmplitude[1],oscillation).real;
    for(std::size_t i=0;i<o.responsePlusX.size();++i) {
        const double angle=kernel().factors()[i].omega*(state.t-state.t0); const WVComplex64 phase{std::cos(angle),std::sin(angle)};
        flux.Fp.data[i]=add(flux.Fp.data[i],multiply(add(scale(o.responsePlusX[i],u),scale(o.responsePlusY[i],v)),conjugate(phase)));
        flux.Fm.data[i]=add(flux.Fm.data[i],multiply(add(scale(o.responseMinusX[i],u),scale(o.responseMinusY[i],v)),phase));
    }
    return WVKernelStatus::ok();
}
WVStateConstraintResult WVBoussinesqForcingEngine::restoreForcingAmplitudes(WVMutableCoefficients& a) {
    // Match MATLAB's forcing-owned accepted-state restoration. The transform's
    // modal validity is established by its input/projection contracts.
    for(auto view:{a.Ap,a.Am,a.A0}) if (!view.data || view.shape.rows!=kernel().geometry().Nj || view.shape.columns!=kernel().geometry().Nkl) return {invalid("Invalid Boussinesq accepted-state shape."),0,false};
    std::size_t modified=0; bool fsal=true;
    for (const auto& forcing:forcing_) { auto result=forcing->applyConstraint(a); if (!result) return result; modified+=result.modifiedCoefficientCount; fsal&=result.fsalCompatible; metrics_.restoredCoefficientCount+=forcing->constraintWriteCount(); }
    return {WVKernelStatus::ok(),modified,fsal};
}
WVKernelStatus WVBoussinesqForcingEngine::createErrorPolicy(double tolerance,std::unique_ptr<WVIntegrationErrorPolicy>& result) const {
    if (!(tolerance>0) || !std::isfinite(tolerance)) return invalid("Adaptive tolerance must be finite and positive.");
    try {
        const auto& g=kernel().geometry(); std::vector<double> kh(g.Nkl),unique;
        for(std::size_t i=0;i<g.Nkl;++i) kh[i]=std::hypot(g.k[i],g.l[i]);
        unique=kh; std::sort(unique.begin(),unique.end()); unique.erase(std::unique(unique.begin(),unique.end()),unique.end());
        if(unique.size()<2) return invalid("Adaptive tolerances require resolved radial modes.");
        double dk=0; for(std::size_t i=1;i<unique.size();++i) dk=std::max(dk,unique[i]-unique[i-1]);
        std::vector<double> centers; for(double k=0;k<=unique.back()+.5*dk;k+=dk) centers.push_back(k);
        std::vector<std::size_t> bins(g.Nkl,centers.size()),counts(centers.size());
        for(std::size_t m=0;m<g.Nkl;++m) for(std::size_t b=0;b<centers.size();++b) if(centers[b]-.5*dk<kh[m] && kh[m]<=centers[b]+.5*dk) { bins[m]=b; ++counts[b]; break; }
        std::vector<double> wave(g.Nj*g.Nkl,1),vortex(wave.size(),1);
        for(std::size_t i=0;i<wave.size();++i) {
            const auto b=bins[i/g.Nj]; if (b==centers.size()) return invalid("Unresolved adaptive radial bin.");
            const double energy=(centers[b]+.5*dk-std::max(centers[b]-.5*dk,0.0))/counts[b]; const auto& f=kernel().factors()[i];
            if (f.waveEnergy>0) wave[i]=tolerance*std::sqrt(energy/f.waveEnergy);
            if (f.balancedEnergy>0) vortex[i]=tolerance*std::sqrt(energy/f.balancedEnergy);
        }
        result=std::make_unique<BoussinesqErrorPolicy>(std::move(wave),std::move(vortex)); return WVKernelStatus::ok();
    } catch(const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Boussinesq tolerance allocation failed."}; }
}
std::size_t WVBoussinesqForcingEngine::persistentBytes() const noexcept {
    return sizeof(*this)+(kernel_ ? kernel_->persistentBytes() : 0)+metrics_.scheduleBytes+metrics_.derivedOperatorBytes+metrics_.workspaceCapacityBytes;
}
WVKernelStatus WVBoussinesqForcingEngine::evaluateForcingTendencies(
    const WVState& state,const WVForcingTendencyOutput* outputs,std::size_t count, const WVRealFieldBundleConstView* preparedPhysical) {
    if (executing_) return {WVKernelStatusCode::reentrantExecution,"Forcing diagnostics require an idle engine."};
    tendencyMetrics_.workspaceLastPeakBytes=0;
    const auto shape=kernel().spatialShape();
    const auto R=shape.elementCount();
    const WVShape4D spatial{shape.first,shape.second,shape.third,4};
    auto status=detail::validateForcingTendencyOutputs(forcing_,kernel().spectralShape(),spatial,state,outputs,count);
    if (!status || !count) return status;
    status=detail::validatePreparedDiagnosticFields(preparedPhysical,spatial,4,state,outputs,count);
    if (!status) return status;
    try {
        detail::WVForcingDiagnosticWorkspace work(kernel().spectralShape(),spatial);
        if (preparedPhysical) {
            std::copy_n(preparedPhysical->data,preparedPhysical->shape.elementCount(),work.physical.data());
            work.physicalPrepared=true;
        }
        auto flux=work.fluxView();
        status=kernel().evolveCoefficients(state,{flux.Fp,flux.Fm,flux.F0}); if (!status) return status;
        std::fill(work.flux.begin(),work.flux.end(),WVComplex64{});
        executing_=true; diagnosticWorkspace_=&work;
        struct Guard {
            WVBoussinesqForcingEngine& engine;
            ~Guard() {
                engine.tendencyMetrics_.workspaceLastPeakBytes=engine.diagnosticWorkspace_->bytes();
                engine.tendencyMetrics_.workspaceHighWaterBytes=std::max(engine.tendencyMetrics_.workspaceHighWaterBytes,engine.diagnosticWorkspace_->bytes());
                engine.tendencyMetrics_.workspaceLiveBytes=0;
                engine.diagnosticWorkspace_=nullptr; engine.executing_=false; engine.physicalValid_=false;
            }
        } guard{*this};
        tendencyMetrics_.workspaceLiveBytes=work.bytes();
        bool initialized=true;
        WVForcingExecutionContext context; context.boussinesq_=this;
        context.state_=&state; context.outputInitialized_=&initialized;
        return detail::evaluateForcingTendencySequence(forcing_,work,outputs,count,tendencyMetrics_,
            [&](const WVForcing& forcing,WVFlux& destination) {
                context.flux_=&destination;
                return forcing.addRightHandSide(context);
            },
            [&](WVRealFieldBundleConstView fields,WVFlux& destination) {
                return kernel().transformUVWEtaToWaveVortex({fields.data+0*R,shape},{fields.data+1*R,shape},{fields.data+2*R,shape},{fields.data+3*R,shape},state.t,state.t0,
                    {destination.Fp,destination.Fm,destination.F0});
            },
            [&](std::vector<WVComplex64>& difference,WVRealFieldBundleView destination) {
                detail::projectRealMeanTendency(difference,kernel().geometry());
                const auto spectral=kernel().spectralShape(); const auto S=spectral.elementCount();
                const WVState delta{state.t,state.t0,{{difference.data(),spectral},
                    {difference.data()+S,spectral},{difference.data()+2*S,spectral}}};
                const WVBoussinesqField names[]={WVBoussinesqField::u,WVBoussinesqField::v,WVBoussinesqField::w,WVBoussinesqField::eta};
                for (std::size_t channel=0;channel<4;++channel) {
                    auto result=kernel().transformStateField(delta,names[channel],{destination.data+channel*R,shape});
                    if (!result) return result;
                }
                return WVKernelStatus::ok();
            });
    } catch (const std::bad_alloc&) {
        return {WVKernelStatusCode::allocationFailure,"Unable to allocate event forcing diagnostic workspace."};
    }
}

}
