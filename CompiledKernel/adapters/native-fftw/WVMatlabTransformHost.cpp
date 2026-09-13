#include "WVMatlabTransformHost.hpp"
#include "WVNativeFFTWEngine.hpp"
#include "WVAccelerateMatrixBackend.hpp"
#include "WaveVortexKernel/WVOwnedStratifiedModalSource.hpp"
#include "WaveVortexRuntime/WVNativeVariablePolicy.hpp"
#include "WaveVortexRuntime/WVHydrostaticForcingEngine.hpp"
#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVIntegrationState.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WVScopedStateEvaluation.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <stdexcept>
#include <utility>

namespace {
using namespace wavevortex;
using namespace wavevortex::runtime;
struct BridgeError : std::runtime_error {
    std::string identifier;
    BridgeError(const char* id, const std::string& message)
        : std::runtime_error(message), identifier(id) {}
};
[[noreturn]] void invalid(const std::string& message) {
    throw BridgeError("WaveVortexModel:CompiledTransformInput",message);
}
void require(const WVKernelStatus& status) {
    if (!status) throw BridgeError("WaveVortexModel:CompiledTransformExecution",status.message);
}
struct ArrayDeleter { void operator()(mxArray* a) const { if(a) mxDestroyArray(a); } };
using Array = std::unique_ptr<mxArray,ArrayDeleter>;
std::string text(const mxArray* a) {
    if (!a || !mxIsChar(a)) invalid("Expected a character vector.");
    char* value=mxArrayToString(a);
    if (!value) throw std::bad_alloc();
    std::string result;
    try { result=value; } catch (...) { mxFree(value); throw; }
    mxFree(value); return result;
}
const mxArray* field(const mxArray* a,const char* name) {
    if (!a || !mxIsStruct(a) || mxGetNumberOfElements(a)!=1)
        invalid("Modal configuration must be a scalar struct.");
    const auto* value=mxGetField(a,0,name);
    if (!value) invalid(std::string("Missing modal field ")+name+'.');
    return value;
}
double scalar(const mxArray* a) {
    if (!a || (!mxIsDouble(a) && !mxIsLogical(a)) || mxIsSparse(a) ||
        mxIsComplex(a) || mxGetNumberOfElements(a)!=1 || !std::isfinite(mxGetScalar(a)))
        invalid("Expected a finite real double or logical scalar.");
    return mxGetScalar(a);
}
std::size_t extent(const mxArray* a) {
    const double n=scalar(a);
    if(n<1 || n!=std::floor(n) || n>static_cast<double>(std::numeric_limits<std::size_t>::max()/sizeof(double)))
        invalid("Modal extent must be a positive addressable integer.");
    return static_cast<std::size_t>(n);
}
std::vector<double> array(const mxArray* a,std::initializer_list<std::size_t> shape) {
    if (!a || !mxIsDouble(a) || mxIsSparse(a) || mxIsComplex(a))
        invalid("Modal arrays must be full real doubles.");
    const auto* dims=mxGetDimensions(a); const auto rank=mxGetNumberOfDimensions(a);
    std::size_t i=0;
    for (auto n:shape) {
        if ((i<rank ? dims[i] : 1)!=n) invalid("Modal array dimensions do not match the declared geometry.");
        ++i;
    }
    for (;i<rank;++i) if(dims[i]!=1) invalid("Unexpected modal array dimension.");
    const auto* values=mxGetDoubles(a);
    return {values,values+mxGetNumberOfElements(a)};
}
WVStratifiedModalArrays modalArrays(const mxArray* a) {
    if(text(field(a,"schemaVersion"))!="wv-matlab-stratified-modal-source-v1")
        invalid("Unsupported MATLAB modal-source schema.");
    WVStratifiedModalArrays data; auto& g=data.geometry;
    g.transformClass=text(field(a,"transformClass"));
    if(g.transformClass!="WVTransformHydrostatic")
        invalid("This foundation slice supports WVTransformHydrostatic only.");
    g.modelVersion=text(field(a,"modelVersion"));
    g.Nx=extent(field(a,"Nx")); g.Ny=extent(field(a,"Ny"));
    g.Nz=extent(field(a,"Nz")); g.Nj=extent(field(a,"Nj")); g.Nkl=extent(field(a,"Nkl"));
    g.Lx=scalar(field(a,"Lx")); g.Ly=scalar(field(a,"Ly")); g.Lz=scalar(field(a,"Lz"));
    g.g=scalar(field(a,"g")); g.rho0=scalar(field(a,"rho0"));
    g.latitude=scalar(field(a,"latitude")); g.rotationRate=scalar(field(a,"rotationRate"));
    g.planetaryRadius=scalar(field(a,"planetaryRadius"));
    const auto* antialias=field(a,"shouldAntialias");
    if(!mxIsLogicalScalar(antialias)) invalid("shouldAntialias must be a scalar logical.");
    g.shouldAntialias=mxIsLogicalScalarTrue(antialias);
    g.x=array(field(a,"x"),{g.Nx,1}); g.y=array(field(a,"y"),{g.Ny,1});
    g.z=array(field(a,"z"),{g.Nz,1}); g.j=array(field(a,"j"),{g.Nj,1});
    g.k=array(field(a,"k"),{g.Nkl,1}); g.l=array(field(a,"l"),{g.Nkl,1});
    g.N2=array(field(a,"N2"),{g.Nz,1}); g.rho_nm0=array(field(a,"rho_nm0"),{g.Nz,1});
    g.dLnN2=array(field(a,"dLnN2"),{g.Nz,1}); g.z_int=array(field(a,"z_int"),{g.Nz,1});
    g.P0=array(field(a,"P0"),{g.Nj,1}); g.Q0=array(field(a,"Q0"),{g.Nj,1});
    g.h_0=array(field(a,"h_0"),{g.Nj,1});
    const auto k=array(field(a,"kMode"),{g.Nkl,1}), l=array(field(a,"lMode"),{g.Nkl,1});
    for(std::size_t i=0;i<g.Nkl;++i) {
        if(!std::isfinite(k[i]) || !std::isfinite(l[i]) || k[i]!=std::floor(k[i]) || l[i]!=std::floor(l[i]) ||
           std::abs(k[i])>static_cast<double>(g.Nx) || std::abs(l[i])>static_cast<double>(g.Ny))
            invalid("Horizontal mode keys must be exact integers within the grid.");
        g.modes.push_back({static_cast<std::int64_t>(k[i]),static_cast<std::int64_t>(l[i])});
    }
    data.PF0inv=array(field(a,"PF0inv"),{g.Nz,g.Nj}); data.QG0inv=array(field(a,"QG0inv"),{g.Nz,g.Nj});
    data.PF0=array(field(a,"PF0"),{g.Nj,g.Nz}); data.QG0=array(field(a,"QG0"),{g.Nj,g.Nz});
    return data;
}
std::vector<std::string> names(const mxArray* a) {
    if(!a || !mxIsCell(a)) invalid("Variable names must be a cell array of character vectors.");
    std::vector<std::string> result;
    for(std::size_t i=0;i<mxGetNumberOfElements(a);++i) result.push_back(text(mxGetCell(a,i)));
    return result;
}
struct Host {
    std::shared_ptr<const WVOwnedStratifiedModalSource> source;
    std::unique_ptr<WVHydrostaticForcingEngine> engine;
    std::unique_ptr<WVFieldEvaluationService> fields;
    WVNativeVariablePolicy policy;
    // One explicitly prepared request. Replacing it bounds retained plan memory.
    std::vector<std::string> requested;
    WVFieldEvaluationPlan plan;
    WVIntegrationStateLayout stateLayout;
    bool planPrepared=false;
    std::size_t evaluations=0, inputBytes=0, outputBytes=0, planPreparations=0;

    explicit Host(WVStratifiedModalArrays data) {
        require(WVOwnedStratifiedModalSource::create(std::move(data),source));
        policy=selectNativeVariablePolicy(true,WVPersistedTransformKind::hydrostatic,
            "native-fftw",1,false,nativeHostTopology());
        if(policy.matrixBackend!=WVNativeMatrixBackend::accelerate || !policy.compact)
            invalid("The MATLAB variable backend requires the qualified native Accelerate policy.");
        WVVariableKernelServices services; services.execution=policy.execution;
        services.matrixBackendFactory=WVCreateAccelerateMatrixBackend;
        std::shared_ptr<const WVExtensionCatalog> catalog;
        require(makeBuiltInExtensionCatalog(catalog));
        const auto* registration=catalog->forcings().registration("WVNonlinearAdvection",1);
        if(!registration) invalid("Built-in nonlinear advection is not registered.");
        WVFrozenForcingSchedule schedule; WVFrozenForcingEntry entry;
        entry.typeIdentifier=registration->matlabClassName; entry.contractVersion=1;
        entry.name=registration->defaultName; entry.stage=registration->stage; entry.priority=registration->priority;
        entry.configuration={"wave-vortex-forcing-configuration-v1",1,{}}; schedule.entries.push_back(entry);
        std::unique_ptr<WVFFTEngine> fft; require(WVFFTWEngine::create(policy.effectiveFFTThreads,fft));
        require(WVHydrostaticForcingEngine::create(source,schedule,catalog,std::move(fft),engine,services));
        require(WVFieldEvaluationService::createBorrowing(*engine,fields));
        require(fields->createStateLayout({},stateLayout));
    }
    void prepare(std::vector<std::string> next) {
        if(planPrepared && next==requested) return;
        std::vector<WVFieldRequest> requests;
        for(std::size_t i=0;i<next.size();++i) {
            if(next[i]!="u" && next[i]!="v" && next[i]!="w" && next[i]!="eta")
                invalid("The foundation adapter supports u, v, w and eta.");
            requests.push_back({std::to_string(i),next[i],{}});
        }
        WVFieldEvaluationPlan candidate; require(fields->createPlan(requests,candidate));
        plan=std::move(candidate); requested=std::move(next); planPrepared=true; ++planPreparations;
    }
};
std::map<std::uint64_t,std::unique_ptr<Host>> hosts;
std::uint64_t nextHandle=std::uint64_t{1}<<63;
Host& host(const mxArray* a) {
    if(!a || !mxIsUint64(a) || mxGetNumberOfElements(a)!=1) invalid("Expected a uint64 transform handle.");
    const auto i=hosts.find(*mxGetUint64s(a));
    if(i==hosts.end()) invalid("The transform handle is foreign, deleted or invalid.");
    return *i->second;
}
mxArray* metadata(const Host& h) {
    const char* keys[]={"transformClass","scope","matrixBackend","policy","horizontalWorkers","pointwiseWorkers",
        "sourceBytes","kernelBytes","engineBytes","fieldServiceBytes","preparedPlanBytes","planPreparations","evaluations",
        "stateInputBytes","stateInputCopyBytes","outputBytes","stateValidations","phasePreparations",
        "producerExecutions","cacheHits","duplicateExecutions","liveEvaluationBytes","peakEvaluationBytes","tiledNonlinearExecutions"};
    Array result(mxCreateStructMatrix(1,1,sizeof(keys)/sizeof(keys[0]),keys));
    auto put=[&](const char* key,double v){mxSetField(result.get(),0,key,mxCreateDoubleScalar(v));};
    mxSetField(result.get(),0,"transformClass",mxCreateString(h.source->geometry().transformClass.c_str()));
    mxSetField(result.get(),0,"scope",mxCreateString("call-scoped Hydrostatic field/nonlinear foundation"));
    mxSetField(result.get(),0,"matrixBackend",mxCreateString(nativeMatrixBackendIdentifier(h.policy.matrixBackend)));
    mxSetField(result.get(),0,"policy",mxCreateString(std::string(h.policy.selection).c_str()));
    put("horizontalWorkers",h.policy.execution.horizontalWorkers); put("pointwiseWorkers",h.policy.execution.pointwiseWorkers);
    put("sourceBytes",h.source->persistentBytes()); put("kernelBytes",h.engine->kernel().persistentBytes());
    put("engineBytes",h.engine->persistentBytes());
    put("fieldServiceBytes",h.fields->persistentBytes()); put("preparedPlanBytes",h.plan.persistentBytes());
    put("planPreparations",h.planPreparations); put("evaluations",h.evaluations);
    put("stateInputBytes",h.inputBytes); put("stateInputCopyBytes",0); put("outputBytes",h.outputBytes);
    const auto& k=h.engine->kernel().metrics(); const auto& e=h.engine->variableEvaluationMetrics();
    const auto& f=h.fields->metrics().variableEvaluation;
    put("stateValidations",k.stateValidationCount); put("phasePreparations",k.phasePreparationCount);
    put("producerExecutions",e.producerExecutions+f.producerExecutions);
    put("cacheHits",e.cacheHits+f.cacheHits); put("duplicateExecutions",e.duplicateExecutions+f.duplicateExecutions);
    put("liveEvaluationBytes",e.liveBytes+f.liveBytes);
    put("peakEvaluationBytes",std::max(e.highWaterBytes,f.highWaterBytes));
    put("tiledNonlinearExecutions",k.tiledNonlinearCount);
    return result.release();
}
WVComplexConstView coefficients(const mxArray* a,WVShape2D shape) {
    if(!a || !mxIsDouble(a) || mxIsSparse(a) || !mxIsComplex(a) || mxGetM(a)!=shape.rows || mxGetN(a)!=shape.columns)
        invalid("Coefficients must be full complex doubles in the model's [Nj,Nkl] shape.");
    static_assert(sizeof(mxComplexDouble)==sizeof(WVComplex64),"Complex coefficient layout mismatch");
    return {reinterpret_cast<const WVComplex64*>(mxGetComplexDoubles(a)),shape};
}
mxArray* evaluate(Host& h,const mxArray* const inputs[]) {
    const auto shape=h.engine->kernel().spectralShape();
    const WVState state{scalar(inputs[3]),scalar(inputs[4]),
        {coefficients(inputs[0],shape),coefficients(inputs[1],shape),coefficients(inputs[2],shape)}};
    const auto requested=names(inputs[5]);
    if(!h.planPrepared || requested!=h.requested) invalid("Prepare these variables before evaluating the transform.");
    if(!mxIsLogicalScalar(inputs[6])) invalid("shouldEvaluateFlux must be a scalar logical.");
    const bool fluxRequested=mxIsLogicalScalarTrue(inputs[6]);
    const char* keys[]={"values","flux","metrics"};
    Array result(mxCreateStructMatrix(1,1,3,keys));
    mxSetField(result.get(),0,"values",mxCreateCellMatrix(requested.size(),1));
    mxSetField(result.get(),0,"flux",mxCreateCellMatrix(fluxRequested?3:0,1));
    auto* values=mxGetField(result.get(),0,"values"); auto* fluxValues=mxGetField(result.get(),0,"flux");
    std::vector<WVFieldOutputView> outputs; std::size_t outputBytes=0;
    for(std::size_t i=0;i<h.plan.outputCount();++i) {
        const auto& spec=h.plan.outputs()[i]; std::vector<mwSize> dims(spec.dimensions.begin(),spec.dimensions.end());
        while(dims.size()<2) dims.push_back(1);
        auto* a=mxCreateNumericArray(dims.size(),dims.data(),mxDOUBLE_CLASS,spec.isComplex?mxCOMPLEX:mxREAL);
        mxSetCell(values,i,a); WVFieldOutputView out; out.elementCount=spec.elementCount;
        if(spec.isComplex) out.complexData=reinterpret_cast<WVComplex64*>(mxGetComplexDoubles(a)); else out.data=mxGetDoubles(a);
        outputs.push_back(out); outputBytes+=spec.elementCount*(spec.isComplex?sizeof(WVComplex64):sizeof(double));
    }
    WVFlux flux;
    if(fluxRequested) {
        WVComplexView* channels[]={&flux.Fp,&flux.Fm,&flux.F0};
        for(std::size_t i=0;i<3;++i) {
            auto* a=mxCreateDoubleMatrix(shape.rows,shape.columns,mxCOMPLEX); mxSetCell(fluxValues,i,a);
            *channels[i]={reinterpret_cast<WVComplex64*>(mxGetComplexDoubles(a)),shape};
        }
        outputBytes+=3*shape.elementCount()*sizeof(WVComplex64);
    }
    // Borrowed MATLAB inputs live only during this invocation. Session teardown
    // runs before outputs publish, including every C++ failure path.
    if(fluxRequested) {
        // RHS fields belong to the forcing engine's evaluation. Its physical
        // fields accessor joins this scope and reuses the tiled advection inputs.
        // A separate diagnostic session would attempt to own the same kernel.
        detail::WVScopedStateEvaluation<WVHydrostaticForcingEngine> session(*h.engine,state);
        require(session.status());
        require(h.engine->nonlinearFlux(state,flux));
        if(!outputs.empty()) {
            WVRealFieldBundleConstView physical;
            require(h.engine->physicalFields(state,physical));
            const auto count=physical.shape.first*physical.shape.second*physical.shape.third;
            for(std::size_t i=0;i<requested.size();++i) {
                const auto channel=requested[i]=="u"?0:requested[i]=="v"?1:requested[i]=="w"?2:3;
                std::copy_n(physical.data+channel*count,count,outputs[i].data);
            }
        }
    } else {
        WVIntegrationState integrationState; integrationState.waveVortex=state;
        const auto& families=h.stateLayout.coefficientFamilies();
        const WVCoefficientFamilyConstView views[]={
            {&families[0],state.coefficients.Ap.data},
            {&families[1],state.coefficients.Am.data},
            {&families[2],state.coefficients.A0.data}};
        integrationState.coefficientFamilies=views;
        integrationState.coefficientFamilyCount=3;
        WVFieldEvaluationSession session; require(h.fields->beginEvaluationSession(integrationState,session));
        if(!outputs.empty()) require(h.fields->evaluate(h.plan,integrationState,outputs.data(),outputs.size()));
    }
    ++h.evaluations; h.inputBytes+=3*shape.elementCount()*sizeof(WVComplex64); h.outputBytes+=outputBytes;
    mxSetField(result.get(),0,"metrics",metadata(h));
    return result.release();
}
}

std::size_t WVMatlabTransformCount() noexcept { return hosts.size(); }
void WVCleanupMatlabTransforms() noexcept { hosts.clear(); }

bool WVDispatchMatlabTransform(const std::string& command,int nlhs,mxArray* plhs[],int nrhs,const mxArray* prhs[]) {
    if(command.rfind("transform",0)!=0) return false;
    // MATLAB error dispatch happens after stack unwinding, never inside a live
    // C++ scope owning scientific resources or partially constructed outputs.
    std::string errorId,errorMessage;
    try {
        if(command=="transformCreate") {
            if(nrhs!=2 || nlhs!=1) invalid("transformCreate requires one modal struct and one output.");
            auto candidate=std::make_unique<Host>(modalArrays(prhs[1]));
            Array output(mxCreateNumericMatrix(1,1,mxUINT64_CLASS,mxREAL));
            if(nextHandle==std::numeric_limits<std::uint64_t>::max()) invalid("Transform handle space exhausted.");
            const auto id=nextHandle++; *mxGetUint64s(output.get())=id;
            hosts.emplace(id,std::move(candidate));
            if(hosts.size()==1) mexLock();
            plhs[0]=output.release(); return true;
        }
        if(nrhs<2) invalid("A transform command requires its handle.");
        auto& h=host(prhs[1]);
        if(command=="transformDelete") {
            if(nrhs!=2 || nlhs!=0) invalid("transformDelete takes one handle and no output.");
            hosts.erase(*mxGetUint64s(prhs[1])); if(hosts.empty()) mexUnlock();
        } else if(command=="transformMetadata") {
            if(nrhs!=2 || nlhs!=1) invalid("transformMetadata takes one handle and returns one struct.");
            plhs[0]=metadata(h);
        } else if(command=="transformPrepare") {
            if(nrhs!=3 || nlhs!=0) invalid("transformPrepare takes handle and variable names with no output.");
            h.prepare(names(prhs[2]));
        } else if(command=="transformEvaluate") {
            if(nrhs!=9 || nlhs!=1) invalid("transformEvaluate takes handle, Ap, Am, A0, t, t0, names and flux flag.");
            plhs[0]=evaluate(h,prhs+2);
        } else invalid("Unknown transform command.");
        return true;
    } catch(const BridgeError& e) { errorId=e.identifier; errorMessage=e.what(); }
      catch(const std::bad_alloc&) { errorId="WaveVortexModel:CompiledTransformAllocation"; errorMessage="Unable to allocate compiled transform storage."; }
      catch(const std::exception& e) { errorId="WaveVortexModel:CompiledTransformFailure"; errorMessage=e.what(); }
    mexErrMsgIdAndTxt(errorId.c_str(),"%s",errorMessage.c_str());
    return true;
}
