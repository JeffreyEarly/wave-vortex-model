#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexKernel/WVTransformBoussinesqKernel.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "../../tools/compiled-kernel/tests/WVAllocationProbe.hpp"
#include "WVBoussinesqModalTestFixture.hpp"
#include <iostream>
#include <limits>
using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::test_fixture;
static_assert(!std::is_copy_assignable<WVStratifiedModalRecord>::value,"Published scientific records must not be reassigned.");
static_assert(!std::is_move_assignable<WVStratifiedModalRecord>::value,"Published scientific records must not be moved over.");
namespace {
struct Counters { int plans=0,engines=0,created=0,failAt=-1,executed=0; };
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
    std::unique_ptr<WVTransformBoussinesqKernel> kernel;
    require(bool(WVTransformBoussinesqKernel::create(source,std::make_unique<Engine>(counters),kernel)),"Create failed");
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
    auto status=kernel->nonlinearFlux(state,flux); require(bool(status),status.message.c_str());
    const auto referenceFlux=b,referenceState=a;
    const auto retainedBytes=kernel->persistentBytes();
    std::vector<double> raw(4*R),physical(4*R),gradient(R),expected(4*R,0);
    WVRealFieldBundleView rawView{raw.data(),{g.Nx,g.Ny,g.Nz,4}};
    const WVBoussinesqField dynamical[]={WVBoussinesqField::u,WVBoussinesqField::v,WVBoussinesqField::w,WVBoussinesqField::eta};
    for(std::size_t channel=0;channel<4;++channel)
        require(bool(kernel->transformStateField(state,dynamical[channel],{physical.data()+channel*R,volume})),"Prepare shared physical fields");
    const WVRealFieldBundleConstView prepared{physical.data(),{g.Nx,g.Ny,g.Nz,4}};
    const auto physicalBefore=physical;
    const auto fullStart=counters.executed;
    require(bool(kernel->nonlinearFlux(state,flux,&rawView,&prepared)),"Observe raw nonlinear tendency");
    const auto fullExecutions=counters.executed-fullStart;
    for(std::size_t channel=0;channel<4;++channel) {
        const auto target=channel;
        for(std::size_t axis=0;axis<3;++axis) {
            require(bool(kernel->transformStateField(state,dynamical[target],{gradient.data(),volume},static_cast<WVBoussinesqDerivative>(axis+1))),"Independent tendency derivative");
            for(std::size_t i=0;i<R;++i) {
                const double correction=target==3 && axis==2 ? physical[3*R+i]*g.dLnN2[i/(g.Nx*g.Ny)] : 0;
                expected[channel*R+i]-=physical[axis*R+i]*(gradient[i]+correction);
            }
        }
    }
    require(raw==expected && physical==physicalBefore,"Raw tendencies precede projection and preserve borrowed fields");
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
    badRaw=rawView; badRaw.shape.fourth=5;
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
    require(!kernel->transformStateField(state,static_cast<WVBoussinesqField>(99),field),"Invalid field accepted");
    require(!kernel->transformStateField(state,WVBoussinesqField::u,field,static_cast<WVBoussinesqDerivative>(99)),"Invalid derivative accepted");
    require(!kernel->transformStateField(state,WVBoussinesqField::u,field,WVBoussinesqDerivative::value,static_cast<WVBoussinesqComponent>(99)),"Invalid component accepted");
    require(!kernel->transformStateField(state,WVBoussinesqField::zetaX,field,WVBoussinesqDerivative::x),"Unsupported vorticity derivative accepted");
    require(!kernel->transformStateField(state,WVBoussinesqField::rhoTotal,field,WVBoussinesqDerivative::value,WVBoussinesqComponent::wave),"Masked background accepted");
    require(!kernel->transformStateField(state,WVBoussinesqField::ssh,field),"Wrong surface shape accepted");
    require(!kernel->differentiateVertical({scratch.data(),volume},WVBoussinesqFamily::F,0,field),"Order zero accepted");
    require(!kernel->differentiateVertical({scratch.data(),volume},WVBoussinesqFamily::F,5,field),"Order five accepted");
    require(!kernel->integrateVertical({scratch.data(),volume},static_cast<WVBoussinesqFamily>(99),field),"Invalid family accepted");
    require(!kernel->differentiateVertical({spatial.data()+1,volume},WVBoussinesqFamily::G,1,field),"Partial calculus alias accepted");
    auto aliased=out; aliased.Ap=amplitudes.Am;
    require(!kernel->evolveCoefficients(state,aliased),"Cross-family evolution alias accepted");
    auto invalidVolume=volume; invalidVolume.third=1;
    require(!kernel->transformUVWEtaToWaveVortex({scratch.data(),volume},{scratch.data(),volume},{scratch.data(),invalidVolume},{scratch.data(),volume},83,17,out),"Invalid vertical-velocity shape accepted");
    require(!kernel->transformUVWEtaToWaveVortex({scratch.data(),volume},{scratch.data(),volume},{reinterpret_cast<const double*>(out.Ap.data),volume},{scratch.data(),volume},83,17,out),"Aliased vertical velocity accepted");
    const auto saved=a;
    a[2][S-1].real=std::numeric_limits<double>::infinity();
    require(!kernel->transformStateField(state,WVBoussinesqField::u,field),"Infinite coefficient accepted");
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
        require(bool(kernel->transformStateField(state,WVBoussinesqField::rhoTotal,field,WVBoussinesqDerivative::z)),"Prepared density failed");
        require(bool(kernel->transformUVEtaToWaveVortex({spatial.data(),volume},{spatial.data(),volume},{spatial.data(),volume},83,17,out)),"Prepared projection failed");
        require(bool(kernel->transformUVWEtaToWaveVortex({scratch.data(),volume},{scratch.data(),volume},{scratch.data(),volume},{scratch.data(),volume},83,17,out)),"Prepared four-field projection failed");
        require(bool(kernel->differentiateVertical({scratch.data(),volume},WVBoussinesqFamily::F,4,field)),"Prepared derivative failed");
        require(bool(kernel->integrateVertical({scratch.data(),volume},WVBoussinesqFamily::G,field)),"Prepared integral failed");
    }
    allocationProbe::counting=false; require(allocationProbe::calls==0 && kernel->persistentBytes()==bytes,"Prepared execution allocates or changes storage");
    const auto* old=kernel.get();
    status=WVTransformBoussinesqKernel::create({},std::make_unique<WVReferenceFFTEngine>(),kernel);
    require(!status && kernel.get()==old,"Failed setup replaced kernel");
    for (int fail=0;fail<11;++fail) {
        int count=0; Counters counters;
        status=WVTransformBoussinesqKernel::create(source,std::make_unique<Engine>(counters),kernel,[&](std::unique_ptr<WVVerticalMatrixBackend>& backend) {
            if (count++==fail) return WVKernelStatus{WVKernelStatusCode::allocationFailure,"Injected matrix factory failure."};
            return WVCreateScalarMatrixBackend(backend);
        });
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"Matrix setup failure leaked or replaced kernel");
    }
    for (int fail=0;fail<2;++fail) {
        Counters counters; counters.failAt=fail;
        status=WVTransformBoussinesqKernel::create(source,std::make_unique<Engine>(counters),kernel);
        require(!status && kernel.get()==old && !counters.engines && !counters.plans,"FFT setup failure leaked or replaced kernel");
    }
    bool succeeded=false;
    for (long fail=0;fail<2048;++fail) {
        Counters counters; auto engine=std::make_unique<Engine>(counters);
        allocationProbe::failAfter=fail;
        status=WVTransformBoussinesqKernel::create(source,std::move(engine),kernel);
        allocationProbe::failAfter=-1;
        if (status) { kernel.reset(); require(!counters.engines && !counters.plans,"Successful destruction leaked"); succeeded=true; break; }
        require(kernel.get()==old && !counters.engines && !counters.plans,"Allocation failure leaked or replaced kernel");
    }
    require(succeeded,"Allocation sweep never succeeded");
}
void modalContracts(const std::filesystem::path& path) {
    std::shared_ptr<const WVStratifiedModalRecord> original; auto status=WVStratifiedModalReader::read(path.string(),original); require(bool(status),status.message.c_str());
    require(original->groups().size()==3 && original->groups()[2].columns==std::vector<std::size_t>{2},"Persisted wave group was lost");
    WVStratifiedModalInspection inspection; require(bool(WVStratifiedModalReader::inspect(path.string(),inspection)),"Wave inspection failed");
    require(inspection.scientificMatrixBytes==(4*7*3+3*(4*7*3+3*3))*sizeof(double),"Wave matrix accounting differs");
    const auto reject=[&]() {
        auto retained=original; WVStratifiedModalInspection observed; observed.scientificMatrixBytes=17;
        require(!WVStratifiedModalReader::inspect(path.string(),observed) && observed.scientificMatrixBytes==17,"Bad wave metadata accepted or partial inspection published");
        require(!WVStratifiedModalReader::read(path.string(),retained) && retained==original,"Bad wave record replaced immutable source");
    };
    const double f=2*7.2921e-5*std::sin(33*std::acos(-1.0)/180);
    struct Bad {const char* name; double value; std::size_t first,second;};
    for (const auto& bad:{Bad{"iK2unique",0,1,0},{"iK2unique",1.5,1,0},{"iK2unique",4,1,0},{"iK2unique",3,1,0},
        {"K2unique",0,1,0},{"Ppm",0,1,1},{"Qpm",NC_FILL_DOUBLE,2,2},{"h_pm",-1,1,1},{"N2",f*f,2,0}}) {
        boussinesqFixture(path); change(path,bad.name,bad.value,bad.first,bad.second); reject();
    }
    for (const auto* matrix:{"PFpmInv","QGpmInv","PFpm","QGpm","QGwg"}) {
        boussinesqFixture(path); changeWave(path,matrix,std::numeric_limits<double>::quiet_NaN(),2,1,1); reject();
        boussinesqFixture(path); { File f(path); int v; nc(nc_inq_varid(f.id,matrix,&v)); nc(nc_rename_var(f.id,v,"missing_wave_matrix")); } reject();
    }
    boussinesqFixture(path); changeWave(path,"QGpmInv",1,2,1,0); reject();
    boussinesqFixture(path); changeWave(path,"PFpmInv",2,2,0,0); reject();
    boussinesqFixture(path); changeWave(path,"QGwg",1,2,0,1); reject();
    boussinesqFixture(path);
    { File f(path); int v,z,j,k; nc(nc_inq_varid(f.id,"PFpmInv",&v)); nc(nc_rename_var(f.id,v,"old_wave")); nc(nc_inq_dimid(f.id,"z",&z)); nc(nc_inq_dimid(f.id,"j",&j)); nc(nc_inq_dimid(f.id,"K2unique",&k)); int dims[]={k,z,j}; nc(nc_def_var(f.id,"PFpmInv",NC_DOUBLE,3,dims,&v)); } reject();
    boussinesqFixture(path);
    // Allocations during the grouped scientific read must remain transactional.
    const auto name=path.string(); bool success=false;
    for (long i=0;i<512;++i) {
        auto retained=original; allocationProbe::failAfter=i; status=WVStratifiedModalReader::read(name,retained); allocationProbe::failAfter=-1;
        if (status) { success=true; break; }
        require(status.code==WVCheckpointStatusCode::allocationFailure && retained==original,"Wave read allocation failure escaped or published partial state");
    }
    require(success,"Wave record allocation sweep never succeeded");
}

}
int main() {
    try {
        Temporary file; boussinesqFixture(file.path);
        std::shared_ptr<const WVStratifiedModalRecord> source; auto status=WVStratifiedModalReader::read(file.path.string(),source); require(bool(status),status.message.c_str());
        modalContracts(file.path);
        contracts(source);
        std::unique_ptr<WVTransformBoussinesqKernel> kernel; require(bool(WVTransformBoussinesqKernel::create(source,std::make_unique<WVReferenceFFTEngine>(),kernel)),"Lifetime setup failed");
        std::weak_ptr<const WVStratifiedModalRecord> weak=source; source.reset(); require(!weak.expired(),"Kernel lost scientific owner"); kernel.reset(); require(weak.expired(),"Scientific owner leaked");
        std::cout<<"Boussinesq kernel contracts passed\n"; return 0;
    } catch(const std::exception& e) { allocationProbe::failAfter=-1; allocationProbe::counting=false; std::cerr<<e.what()<<'\n'; return 1; }
}
