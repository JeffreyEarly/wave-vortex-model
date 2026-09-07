#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WVAllocationProbe.hpp"
#include <netcdf.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace wavevortex;
using namespace wavevortex::runtime;
namespace {
void require(bool condition,const char* message) { if (!condition) throw std::runtime_error(message); }
void nc(int code) { if (code!=NC_NOERR) throw std::runtime_error(nc_strerror(code)); }
struct File {
    int id=-1;
    explicit File(const std::filesystem::path& path,bool create=false) { if (create) nc(nc_create(path.c_str(),NC_NETCDF4|NC_CLOBBER,&id)); else nc(nc_open(path.c_str(),NC_WRITE,&id)); }
    ~File() { if(id>=0) nc_close(id); }
};
struct Temporary {
    std::filesystem::path path=std::filesystem::temp_directory_path()/("wvm-modal-"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count())+".nc");
    ~Temporary(){std::error_code ec;std::filesystem::remove(path,ec);}
};
void fixture(const std::filesystem::path& path,std::size_t Nz=7) {
    File f(path,true); int x,y,z,j,kl;
    nc(nc_def_dim(f.id,"x",8,&x)); nc(nc_def_dim(f.id,"y",6,&y)); nc(nc_def_dim(f.id,"z",Nz,&z)); nc(nc_def_dim(f.id,"j",3,&j)); nc(nc_def_dim(f.id,"kl",3,&kl));
    for(const auto* name:{"WVTransform","AnnotatedClass"}) nc(nc_put_att_text(f.id,NC_GLOBAL,name,std::char_traits<char>::length("WVTransformStratifiedQG"),"WVTransformStratifiedQG"));
    nc(nc_put_att_text(f.id,NC_GLOBAL,"model_version",5,"4.3.0"));
    auto scalar=[&](const char* name,double value) { int v; nc(nc_def_var(f.id,name,NC_DOUBLE,0,nullptr,&v)); nc(nc_put_var_double(f.id,v,&value)); };
    scalar("Lx",19000);scalar("Ly",11000);scalar("Lz",1000);scalar("g",9.81);scalar("rho0",1025);scalar("latitude",33);scalar("rotationRate",7.2921e-5);scalar("planetaryRadius",6.371e6);
    int mask; nc(nc_def_var(f.id,"shouldAntialias",NC_UBYTE,0,nullptr,&mask)); unsigned char yes=1; nc(nc_put_var_uchar(f.id,mask,&yes));
    auto vector=[&](const char* name,int dimension,const std::vector<double>& data) {int v;nc(nc_def_var(f.id,name,NC_DOUBLE,1,&dimension,&v));nc(nc_put_var_double(f.id,v,data.data()));};
    std::vector<double> xx(8),yy(6),zz(Nz),rho(Nz),weights(Nz),N2(Nz,1e-4),zero(Nz,0);
    for(std::size_t i=0;i<8;++i)xx[i]=19000.0*i/8;
    for(std::size_t i=0;i<6;++i)yy[i]=11000.0*i/6;
    for(std::size_t i=0;i<Nz;++i){zz[i]=-1000+1000.0*i/(Nz-1);rho[i]=1025-0.01*zz[i];weights[i]=1000.0/(Nz-1)*((i==0||i+1==Nz)?0.5:1);}
    vector("x",x,xx);vector("y",y,yy);vector("z",z,zz);vector("j",j,{0,1,2});vector("kl",kl,{0,1,2});
    const double pi=std::acos(-1.0);
    vector("k",kl,{0,2*pi/19000,0});vector("l",kl,{0,0,2*pi/11000});
    vector("N2",z,N2);vector("rho_nm0",z,rho);vector("dLnN2",z,zero);vector("z_int",z,weights);
    vector("P0",j,{1,2,3});vector("Q0",j,{1,4,5});vector("h_0",j,{1,0.5,0.2});
    std::vector<double> F(Nz*3),G(Nz*3),PF(Nz*3),QG(Nz*3);
    for(std::size_t c=0;c<3;++c){double maximum=0;for(std::size_t r=0;r<Nz;++r){F[r+Nz*c]=std::cos(c*pi*r/(Nz-1));G[r+Nz*c]=c==0||r==0||r+1==Nz?0:std::sin(c*pi*r/(Nz-1));maximum=std::max(maximum,std::abs(G[r+Nz*c]));PF[c+3*r]=F[r+Nz*c]/Nz;QG[c+3*r]=G[r+Nz*c]/Nz;}if(c)for(std::size_t r=0;r<Nz;++r)G[r+Nz*c]/=maximum;}
    auto matrix=[&](const char* name,int slow,int fast,const std::vector<double>& data){int v;const int dims[]={slow,fast};nc(nc_def_var(f.id,name,NC_DOUBLE,2,dims,&v));nc(nc_put_var_double(f.id,v,data.data()));};
    matrix("PF0inv",j,z,F);matrix("QG0inv",j,z,G);matrix("PF0",z,j,PF);matrix("QG0",z,j,QG);
}
void change(const std::filesystem::path& path,const char* name,double value,std::size_t first=0,std::size_t second=0) {
    File f(path);int v;nc(nc_inq_varid(f.id,name,&v));const std::size_t index[]={first,second};nc(nc_put_var1_double(f.id,v,index,&value));
}
void contracts(const std::filesystem::path& path) {
    WVStratifiedModalInspection inspection; auto status=WVStratifiedModalReader::inspect(path.string(),inspection); require(static_cast<bool>(status),status.message.c_str());
    std::shared_ptr<const WVStratifiedModalRecord> record;status=WVStratifiedModalReader::read(path.string(),record);require(static_cast<bool>(status),status.message.c_str());
    require(record->PF0inv().size()*4*sizeof(double)==inspection.scientificMatrixBytes,"Scientific matrix accounting mismatch");
    WVVerticalMatrixRecord raw; require(static_cast<bool>(record->matrixView(WVStratifiedScientificMatrix::PF0inv,raw)),"Scientific view failed");
    require(raw.values.data==record->PF0inv().data()&&raw.values.rows==7&&raw.values.columns==3&&raw.identity.source==record->sourceIdentity()&&raw.identity.name=="PF0inv","Scientific view lost exact identity or orientation");
    require(record->groups().size()==1&&record->groups()[0].identity==0&&record->groups()[0].columns==std::vector<std::size_t>{0,1,2},"Scientific group membership changed");
    const auto saved=record->PF0inv();
    WVComplexLayout input{3,3,1,3,WVComplexRepresentation::interleaved,"F-modal",record->modeSetIdentity()},output{7,3,1,7,WVComplexRepresentation::interleaved,"F-grid",record->modeSetIdentity()};
    std::unique_ptr<WVVerticalMatrixBackend> backend; require(static_cast<bool>(WVCreateScalarMatrixBackend(backend)),"Backend failed");
    std::unique_ptr<WVPreparedVerticalOperator> prepared;require(static_cast<bool>(record->prepareVertical(WVStratifiedModalOperator::reconstructF,input,output,std::move(backend),prepared)),"Preparation failed");
    std::unique_ptr<WVVerticalWorkspace> workspace;require(static_cast<bool>(prepared->createWorkspace(workspace)),"Workspace failed");
    std::vector<WVComplex64> in(9,{1,2}),out(21);
    allocationProbe::calls=0;allocationProbe::counting=true;
    for(int i=0;i<10;++i)require(static_cast<bool>(prepared->execute(*workspace,{in.data(),nullptr,nullptr,in.size()*sizeof(WVComplex64)},{out.data(),nullptr,nullptr,out.size()*sizeof(WVComplex64)})),"Execution failed");
    allocationProbe::counting=false;require(allocationProbe::calls==0,"Prepared modal execution allocated");
    require(record->PF0inv()==saved,"Preparation altered scientific matrices");
    change(path,"P0",7,1);
    require(record->geometry().P0[1]==2,"Scientific record borrowed mutable file data");
    std::shared_ptr<const WVStratifiedModalRecord> fresh;require(static_cast<bool>(WVStratifiedModalReader::read(path.string(),fresh)),"Rebuild read failed");
    require(fresh->sourceIdentity()!=record->sourceIdentity()&&fresh->geometry().P0[1]==7,"Changed scientific input reused identity");
    require(static_cast<bool>(WVCreateScalarMatrixBackend(backend)),"Backend failed");
    require(fresh->prepareVertical(WVStratifiedModalOperator::reconstructF,input,output,std::move(backend),prepared).code==WVKernelStatusCode::invalidConfiguration,"Old field identities accepted");
    record.reset();require(static_cast<bool>(prepared->execute(*workspace,{in.data(),nullptr,nullptr,in.size()*sizeof(WVComplex64)},{out.data(),nullptr,nullptr,out.size()*sizeof(WVComplex64)})),"Prepared operator depended on released scientific input");
}
void rejection(const std::filesystem::path& path) {
    struct Bad {const char* name;double value;std::size_t first,second;};
    for(const auto& bad:{Bad{"P0",0,1,0},{"Q0",0,1,0},{"h_0",0,1,0},{"N2",-1,3,0},{"rho_nm0",2000,6,0},{"z",-1100,2,0},
        {"j",1,2,0},{"j",6,2,0},{"k",1.123,1,0},{"k",0,1,0},{"l",-0.0001,2,0},{"QG0inv",1,1,0},{"QG0inv",1,0,3},{"QG0",1,0,1},
        {"PF0inv",2,0,3},{"PF0inv",2,1,2},{"PF0",NC_FILL_DOUBLE,5,1},{"QG0",std::numeric_limits<double>::quiet_NaN(),5,1},{"z_int",-1000,2,0}}) {
        fixture(path);std::shared_ptr<const WVStratifiedModalRecord> record;require(static_cast<bool>(WVStratifiedModalReader::read(path.string(),record)),"Base fixture invalid");
        const auto* saved=record.get();WVStratifiedModalInspection inspection;inspection.scientificMatrixBytes=17;
        change(path,bad.name,bad.value,bad.first,bad.second);
        require(!WVStratifiedModalReader::inspect(path.string(),inspection)&&inspection.scientificMatrixBytes==17,"Invalid record accepted or inspection output mutated");
        require(!WVStratifiedModalReader::read(path.string(),record)&&record.get()==saved,"Invalid record replaced scientific owner");
    }
    fixture(path);{File f(path);int v;nc(nc_inq_varid(f.id,"PF0",&v));nc(nc_rename_var(f.id,v,"missing_PF0"));}
    WVStratifiedModalInspection inspection;require(WVStratifiedModalReader::inspect(path.string(),inspection).code==WVCheckpointStatusCode::missingVariable,"Missing matrix accepted");
    fixture(path);{File f(path);int v;nc(nc_inq_varid(f.id,"PF0",&v));nc(nc_rename_var(f.id,v,"old_PF0"));int j,z;nc(nc_inq_dimid(f.id,"j",&j));nc(nc_inq_dimid(f.id,"z",&z));int dims[]={j,z};nc(nc_def_var(f.id,"PF0",NC_DOUBLE,2,dims,&v));}
    require(WVStratifiedModalReader::inspect(path.string(),inspection).code==WVCheckpointStatusCode::shapeMismatch,"Transposed matrix schema accepted");
    fixture(path,4101);change(path,"PF0",std::numeric_limits<double>::infinity(),4100,2);
    require(!WVStratifiedModalReader::inspect(path.string(),inspection),"Late payload outside scan buffer was not validated");
}
void allocationFailures(const std::filesystem::path& path) {
    fixture(path);const auto name=path.string();bool success=false;
    for(long i=0;i<256;++i){std::shared_ptr<const WVStratifiedModalRecord> record;allocationProbe::failAfter=i;const auto status=WVStratifiedModalReader::read(name,record);allocationProbe::failAfter=-1;if(status){success=true;break;}require(!record&&status.code==WVCheckpointStatusCode::allocationFailure,"Allocation failure escaped or published partial record");}
    require(success,"Allocation sweep did not reach successful read");
}
}
int main(){try{Temporary temporary;fixture(temporary.path);contracts(temporary.path);rejection(temporary.path);allocationFailures(temporary.path);std::cout<<"Modal records: validated scientific ownership, bounded payload scan, invalid records, rebuilds and prepared allocations passed.\n";return 0;}catch(const std::exception& e){allocationProbe::counting=false;allocationProbe::failAfter=-1;std::cerr<<e.what()<<'\n';return 1;}}
