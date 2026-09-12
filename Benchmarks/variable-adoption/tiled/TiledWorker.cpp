// Benchmark-only inclusion: use the accepted native plan implementation and
// the exact same FFTW handles/pool for both schedules, without a production API.
#include <system_error>
#include <fftw3.h>
#include <atomic>
namespace observed {
inline bool enabled=false;
inline fftw_plan column=nullptr;
inline std::atomic<std::size_t> columns{0},rows{0};
inline void dft(fftw_plan p,fftw_complex* in,fftw_complex* out) {
    if (enabled && p==column) ++columns;
    fftw_execute_dft(p,in,out);
}
inline void c2r(fftw_plan p,fftw_complex* in,double* out) {
    if (enabled) ++rows;
    fftw_execute_dft_c2r(p,in,out);
}
}
#define fftw_execute_dft observed::dft
#define fftw_execute_dft_c2r observed::c2r
// GCC diagnoses internal native resource types when this .cpp is included.
// This standalone executable includes it once; no definition crosses TUs.
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wsubobject-linkage"
#endif
#include "../../../CompiledKernel/adapters/native-fftw/WVNativeFFTWEngine.cpp"
#if defined(__GNUC__) && !defined(__clang__)
#pragma GCC diagnostic pop
#endif
#include "../../../CompiledKernel/src/WVAdvectionConsumer.hpp"
#include "TiledOracle.hpp"
#include "nlohmann/json.hpp"
#include <fstream>
#include <iostream>
#include <numeric>

using namespace wavevortex;
using nlohmann::json;
namespace {
void check(WVKernelStatus s) { if (!s) throw std::runtime_error(s.message); }
struct Split {
    std::vector<double> r,i;
    explicit Split(std::size_t n=0):r(n),i(n) {}
    WVComplexInput input() const { return {nullptr,r.data(),i.data(),r.size()*sizeof(double)}; }
    WVComplexOutput output() { return {nullptr,r.data(),i.data(),r.size()*sizeof(double)}; }
    WVComplex64 get(std::size_t n) const { return {r[n],i[n]}; }
    void set(std::size_t n,WVComplex64 x) { r[n]=x.real;i[n]=x.imag; }
};
WVComplex64 ik(WVComplex64 a,double k) { return {a.real*0-a.imag*k,a.real*k+a.imag*0}; }
struct Map { std::size_t row,partner; bool conjugate,self; double k,l; };
struct Screen {
    std::size_t nx,ny,nz,plane,half,columns,modes,workers,depth,targets,H,R;
    bool hydro,share;
    WVRetainedHorizontalSpecification spec;
    std::vector<std::pair<std::int64_t,std::int64_t>> keys;
    std::vector<Map> maps;
    std::unique_ptr<RetainedFFTWPlan> plan;
    std::shared_ptr<RetainedFFTWResources> resources;
    RetainedWorkers pointwise;
    std::vector<Split> base,dz,referenceProjection,candidateProjection;
    Split materialized;
    std::vector<double> referenceFields,candidateFields,referenceFlux,referenceDerivative;
    std::vector<double> referenceSpatial,candidateSpatial,correction,xFactors;
    std::vector<WVComplex64> packed,stages;
    std::vector<double> localReal;
    bool capture=false;
    Screen(std::size_t x,std::size_t y,std::size_t z,bool h,std::size_t d,std::size_t w,bool reuse)
        :nx(x),ny(y),nz(z),plane(x*y),half((x/2+1)*y),columns(x/3+1),modes(0),workers(std::min(w,z)),depth(d),targets(h?3:4),H(0),R(x*y*z),hydro(h),share(reuse),pointwise(std::min(std::size_t{8},workers)) {
        if (x<6 || y<6 || !z || !d || d>16 || !w) throw std::runtime_error("Invalid screen geometry/counts");
        const double cutoff=(2.0/3.0)*static_cast<double>(nx/2);
        for (std::int64_t l=0;l<=static_cast<std::int64_t>((ny-1)/2);++l)
            for (std::int64_t k=-(static_cast<std::int64_t>(nx)-1)/2;k<=static_cast<std::int64_t>((nx-1)/2);++k)
                if ((l>0 || k>=0) && std::hypot(static_cast<double>(k),static_cast<double>(l))<=cutoff) keys.emplace_back(k,l);
        modes=keys.size();H=nz*modes;columns=0;
        for (const auto& key:keys) columns=std::max(columns,static_cast<std::size_t>(std::abs(key.first))+1);
        spec.grid={nx,ny,nz,1,nx,plane,"screen"};spec.retained={nz,modes,1,nz,WVComplexRepresentation::split,"screen","canonical-dealiased"};
        spec.Lx=spec.Ly=6.2831853071795864769;spec.normalization=WVFourierNormalization::forwardUnit;spec.schedule=WVRetainedHorizontalSchedule::streamingPrunedTile16;spec.outerWorkers=workers;
        xFactors.resize(columns);for (std::size_t i=0;i<columns;++i) xFactors[i]=2*std::acos(-1.0)*static_cast<double>(i)/spec.Lx;
        for (const auto& key:keys) {
            spec.modes.push_back({key.first,key.second});
            const bool conjugate=key.first<0;
            const auto sx=static_cast<std::size_t>(std::abs(key.first));
            const auto sy=conjugate?(ny-static_cast<std::size_t>(key.second))%ny:static_cast<std::size_t>(key.second);
            const auto row=sx+(nx/2+1)*sy;
            const auto partner=sx==0?(nx/2+1)*((ny-sy)%ny):row;
            maps.push_back({row,partner,conjugate,key.first==0&&key.second==0,static_cast<double>(key.first),static_cast<double>(key.second)});
        }
        fftw_init_threads();std::vector<std::weak_ptr<RetainedFFTWResources>> cache;
        plan=std::make_unique<RetainedFFTWPlan>(spec);check(plan->prepare(cache));resources=cache.back().lock();observed::column=resources->columnInverse_.get();
        for (std::size_t f=0;f<4;++f) {
            base.emplace_back(H);dz.emplace_back(H);referenceProjection.emplace_back(H);candidateProjection.emplace_back(H);
            for (std::size_t m=0;m<modes;++m) for (std::size_t zz=0;zz<nz;++zz) {
                auto a=tile_screen::coefficient(f,keys[m].first,keys[m].second,zz,nz,false);
                auto b=tile_screen::coefficient(f,keys[m].first,keys[m].second,zz,nz,true);
                a.real/=modes;a.imag/=modes;b.real/=modes;b.imag/=modes;
                base.back().set(zz+nz*m,a);dz.back().set(zz+nz*m,b);
            }
        }
        materialized=Split(H);referenceFields.resize(4*R);candidateFields.resize(4*R);
        referenceFlux.resize(R);referenceDerivative.resize(R);referenceSpatial.resize(targets*R);candidateSpatial.resize(targets*R);
        correction.resize(nz);for (std::size_t zz=0;zz<nz;++zz) correction[zz]=tile_screen::densityCorrection(zz,nz);
        // Four base input tiles and target-specific dz/projection tiles. Only a
        // single plane of inverse-y columns survives while its fields execute.
        packed.resize(workers*(4+2*targets)*depth*modes);
        stages.resize(share?workers*targets*columns*ny:0);
        localReal.resize(workers*2*plane);
    }
    std::size_t field(std::size_t target) const { return target<2?target:(target==2?3:2); }
    std::size_t partition(std::size_t worker) const { return (nz/workers)*worker+std::min(worker,nz%workers); }
    struct Materialization { Screen* s;std::size_t f,axis; };
    static void materialize(void* pointer,std::size_t worker) noexcept {
        auto& c=*static_cast<Materialization*>(pointer);auto& s=*c.s;
        const auto n=std::min(std::size_t{8},s.workers);
        const auto start=(s.H/n)*worker+std::min(worker,s.H%n),end=(s.H/n)*(worker+1)+std::min(worker+1,s.H%n);
        for (auto i=start;i<end;++i) s.materialized.set(i,ik(s.base[c.f].get(i),c.axis==0?s.maps[i/s.nz].k:s.maps[i/s.nz].l));
    }
    void baseline() {
        for (std::size_t f=0;f<4;++f) check(plan->inverse(base[f].input(),{referenceFields.data()+f*R,R*sizeof(double)}));
        for (std::size_t t=0;t<targets;++t) {
            const auto f=field(t);std::fill(referenceFlux.begin(),referenceFlux.end(),0.0);
            for (std::size_t axis=0;axis<3;++axis) {
                WVComplexInput input=dz[f].input();
                if (axis<2) {Materialization c{this,f,axis};pointwise.run(materialize,&c);input=materialized.input();}
                kernel_detail::WVAdvectionConsumer advection{referenceFlux.data(),referenceFields.data()+axis*R,referenceFields.data()+3*R,correction.data(),plane,f==3&&axis==2};
                WVRealOutputConsumer consumer{&advection,kernel_detail::WVAdvectionConsumer::consume};
                check(plan->inverseAndConsume(input,{referenceDerivative.data(),R*sizeof(double)},consumer));
            }
            if (capture) std::copy(referenceFlux.begin(),referenceFlux.end(),referenceSpatial.begin()+t*R);
            check(plan->forward({referenceFlux.data(),R*sizeof(double)},referenceProjection[t].output()));
        }
    }
    void gather(const Split& source,WVComplex64* tile,std::size_t first,std::size_t count) const noexcept {
        std::array<WVComplex64,16*32> block;
        for (std::size_t m0=0;m0<modes;m0+=32) {
            const auto n=std::min(std::size_t{32},modes-m0);
            for (std::size_t m=0;m<n;++m) for (std::size_t lane=0;lane<count;++lane) block[m*16+lane]=source.get(first+lane+nz*(m0+m));
            for (std::size_t lane=0;lane<count;++lane) for (std::size_t m=0;m<n;++m) tile[lane*modes+m0+m]=block[m*16+lane];
        }
    }
    void scatter(const WVComplex64* values,WVComplex64* scratch,int derivative) const noexcept {
        std::fill_n(scratch,half,WVComplex64{});
        for (std::size_t m=0;m<modes;++m) {
            const auto& map=maps[m];auto value=values[m];
            if (derivative==1 || derivative==2) value=ik(value,derivative==1?map.k:map.l);
            if (map.conjugate) value.imag=-value.imag;
            scratch[map.row]=value;
            if (map.partner!=map.row) scratch[map.partner]={value.real,-value.imag};
        }
    }
    void inverseY(WVComplex64* scratch) const noexcept {fftw_execute_dft(resources->columnInverse_.get(),reinterpret_cast<fftw_complex*>(scratch),reinterpret_cast<fftw_complex*>(scratch));}
    void inverseX(WVComplex64* scratch,double* out) const noexcept {fftw_execute_dft_c2r(resources->rowInverse_.get(),reinterpret_cast<fftw_complex*>(scratch),out);}
    static void fused(void* ptr,std::size_t worker) noexcept {
        auto& s=*static_cast<Screen*>(ptr);
        const auto tileSize=s.depth*s.modes,halfWidth=s.nx/2+1,stageSize=s.columns*s.ny;
        auto* packed=s.packed.data()+worker*(4+2*s.targets)*tileSize;
        auto* stage=s.share?s.stages.data()+worker*s.targets*stageSize:nullptr;
        auto* scratch=s.resources->scratch.data()+worker*s.half;
        auto* flux=s.localReal.data()+worker*2*s.plane;auto* deriv=flux+s.plane;
        for (auto first=s.partition(worker);first<s.partition(worker+1);first+=s.depth) {
            const auto count=std::min(s.depth,s.partition(worker+1)-first);
            for (std::size_t f=0;f<4;++f) s.gather(s.base[f],packed+f*tileSize,first,count);
            for (std::size_t t=0;t<s.targets;++t) s.gather(s.dz[s.field(t)],packed+(4+t)*tileSize,first,count);
            for (std::size_t lane=0;lane<count;++lane) {
                const auto z=first+lane,offset=z*s.plane;
                for (std::size_t f=0;f<4;++f) {
                    s.scatter(packed+f*tileSize+lane*s.modes,scratch,0);s.inverseY(scratch);
                    if (s.share && (!s.hydro||f!=2)) for (std::size_t y=0;y<s.ny;++y) std::copy_n(scratch+y*halfWidth,s.columns,stage+(f==3?2:f==2?3:f)*stageSize+y*s.columns);
                    s.inverseX(scratch,s.candidateFields.data()+f*s.R+offset);
                }
                for (std::size_t t=0;t<s.targets;++t) {
                    const auto f=s.field(t);std::fill_n(flux,s.plane,0.0);
                    for (std::size_t axis=0;axis<3;++axis) {
                        if (axis==0 && s.share) {
                            std::fill_n(scratch,s.half,WVComplex64{});
                            for (std::size_t y=0;y<s.ny;++y) for (std::size_t x=0;x<s.columns;++x) scratch[x+y*halfWidth]=ik(stage[t*stageSize+x+y*s.columns],s.xFactors[x]);
                        } else {
                            s.scatter(packed+(axis<2?f:4+t)*tileSize+lane*s.modes,scratch,axis<2?static_cast<int>(axis+1):0);s.inverseY(scratch);
                        }
                        s.inverseX(scratch,deriv);
                        const auto* velocity=s.candidateFields.data()+axis*s.R+offset;
                        const auto* eta=s.candidateFields.data()+3*s.R+offset;
                        for (std::size_t i=0;i<s.plane;++i) {
                            const auto correction=f==3&&axis==2?eta[i]*s.correction[z]:0.0;
                            flux[i]-=velocity[i]*(deriv[i]+correction);
                        }
                    }
                    if (s.capture) std::copy_n(flux,s.plane,s.candidateSpatial.data()+t*s.R+offset);
                    fftw_execute_dft_r2c(s.resources->rowForward_.get(),flux,reinterpret_cast<fftw_complex*>(scratch));
                    fftw_execute_dft(s.resources->columnForward_.get(),reinterpret_cast<fftw_complex*>(scratch),reinterpret_cast<fftw_complex*>(scratch));
                    for (std::size_t m=0;m<s.modes;++m) {
                        auto value=scratch[s.maps[m].row];const double scale=1.0/static_cast<double>(s.plane);value.real*=scale;value.imag*=scale;
                        if (s.maps[m].conjugate) value.imag=-value.imag;
                        if (s.maps[m].self) value.imag=0;
                        packed[(4+s.targets+t)*tileSize+lane*s.modes+m]=value;
                    }
                }
            }
            std::array<WVComplex64,16*32> block;
            for (std::size_t t=0;t<s.targets;++t) for (std::size_t m0=0;m0<s.modes;m0+=32) {
                const auto n=std::min(std::size_t{32},s.modes-m0);
                for (std::size_t lane=0;lane<count;++lane) for (std::size_t m=0;m<n;++m) block[m*16+lane]=packed[(4+s.targets+t)*tileSize+lane*s.modes+m0+m];
                for (std::size_t m=0;m<n;++m) for (std::size_t lane=0;lane<count;++lane) s.candidateProjection[t].set(first+lane+s.nz*(m0+m),block[m*16+lane]);
            }
        }
    }
    void candidate() {resources->pool.run(fused,this);}
    json verify() {
        capture=true;observed::columns=0;observed::rows=0;observed::enabled=true;
        baseline();const auto baselineColumns=observed::columns.load(),baselineRows=observed::rows.load();
        observed::columns=0;observed::rows=0;candidate();const auto candidateColumns=observed::columns.load(),candidateRows=observed::rows.load();
        observed::enabled=false;capture=false;
        if (baselineColumns!=nz*(4+3*targets) || candidateColumns!=nz*(4+(share?2:3)*targets) || baselineRows!=nz*(4+3*targets) || candidateRows!=baselineRows) throw std::runtime_error("Actual FFT counts differ from schedule");
        double fieldError=0,fluxError=0,projectionError=0,oracleError=0;
        const auto difference=[](double a,double b) { if (!std::isfinite(a)||!std::isfinite(b)) throw std::runtime_error("Nonfinite output");return std::abs(a-b)/(1+std::abs(a));};
        for (std::size_t i=0;i<4*R;++i) fieldError=std::max(fieldError,difference(referenceFields[i],candidateFields[i]));
        for (std::size_t i=0;i<targets*R;++i) fluxError=std::max(fluxError,difference(referenceSpatial[i],candidateSpatial[i]));
        for (std::size_t t=0;t<targets;++t) for (std::size_t i=0;i<H;++i) {
            projectionError=std::max(projectionError,difference(referenceProjection[t].r[i],candidateProjection[t].r[i]));
            projectionError=std::max(projectionError,difference(referenceProjection[t].i[i],candidateProjection[t].i[i]));
        }
        for (std::size_t sample=0;sample<8;++sample) {
            const auto x=(sample*19+1)%nx,y=(sample*13+3)%ny,z=(sample*7)%nz,index=x+nx*y+plane*z;
            for (std::size_t f=0;f<4;++f) oracleError=std::max(oracleError,difference(tile_screen::directValue(f,x,y,z,nx,ny,nz,keys,0),candidateFields[f*R+index]));
            for (std::size_t t=0;t<targets;++t) oracleError=std::max(oracleError,difference(tile_screen::directFlux(field(t),x,y,z,nx,ny,nz,keys,hydro),candidateSpatial[t*R+index]));
        }
        if (fieldError!=0 || std::max(fluxError,projectionError)>(share?1e-12:0.0) || oracleError>1e-12) throw std::runtime_error(json{{"fieldError",fieldError},{"fluxError",fluxError},{"projectionError",projectionError},{"oracleError",oracleError}}.dump());
        return {{"fieldError",fieldError},{"fluxError",fluxError},{"projectionError",projectionError},{"directOracleError",oracleError},{"passed",true},{"actualBaselineColumnInverses",baselineColumns},{"actualCandidateColumnInverses",candidateColumns},{"actualRowInverses",baselineRows}};
    }
};
}
int main(int argc,char** argv) {
    try {
        if (argc!=10) throw std::runtime_error("Usage: worker NX NY NZ hydro|bouss TILE WORKERS SAMPLES ORDER(0|1) SHARE_COLUMNS(0|1)");
        const auto n=[](const char* p){return static_cast<std::size_t>(std::stoull(p));};
        const auto samples=n(argv[7]),order=n(argv[8]);if (!samples || order>1 || n(argv[9])>1 || (std::string(argv[4])!="hydro" && std::string(argv[4])!="bouss")) throw std::runtime_error("Invalid samples, family or boolean flag");
        Screen s(n(argv[1]),n(argv[2]),n(argv[3]),std::string(argv[4])=="hydro",n(argv[5]),n(argv[6]),n(argv[9])!=0);
        const auto verification=s.verify();
        for (int i=0;i<2;++i) {s.baseline();s.candidate();}
        json pairs=json::array();
        for (std::size_t i=0;i<samples;++i) {
            double times[2]{};
            for (std::size_t j=0;j<2;++j) {
                const auto role=(i+j+order)%2;auto start=std::chrono::steady_clock::now();
                if (role==0)s.baseline();else s.candidate();
                times[role]=std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count();
            }
            pairs.push_back({{"baselineSeconds",times[0]},{"candidateSeconds",times[1]},{"ratio",times[1]/times[0]}});
        }
        const auto postflight=s.verify();
        const auto identity=WVFFTWEngine::linkedLibraries();
        const auto baselineScratch=2*s.R*sizeof(double)+2*s.H*sizeof(double);
        const auto candidateScratch=(s.packed.capacity()+s.stages.capacity())*sizeof(WVComplex64)+s.localReal.capacity()*sizeof(double);
        std::cout<<json{{"schema","wvm-tiled-horizontal-screen-v1"},{"grid",{s.nx,s.ny,s.nz}},{"family",argv[4]},{"tile",s.depth},{"shareColumns",s.share},{"workers",s.workers},{"samples",pairs},{"verification",verification},{"postflight",postflight},{"baselineAdditionalScratchBytes",baselineScratch},{"candidateAdditionalScratchBytes",candidateScratch},{"commonNativeResourceBytes",s.resources->bytes()},{"excludedCommonStorage","Four physical fields, prepared base and dz spectra, projected outputs; both schedules use identical source spectra and FFTW plans. Verification captures excluded from timing."},{"baselineColumnInverseCallsPerExecution",s.nz*(4+3*s.targets)},{"candidateColumnInverseCallsPerExecution",s.nz*(4+(s.share?2:3)*s.targets)},{"baselineRowInverseCallsPerExecution",s.nz*(4+3*s.targets)},{"candidateRowInverseCallsPerExecution",s.nz*(4+3*s.targets)},{"provider",{{"version",identity.version},{"baseLibrary",identity.baseLibrary},{"threadLibrary",identity.threadLibrary}}}}.dump()<<'\n';
        return 0;
    } catch (const std::exception& e) {std::cerr<<e.what()<<'\n';return 1;}
}
