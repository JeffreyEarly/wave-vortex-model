#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WVNetCDF.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <limits>
#include <new>
#include <set>
#include <stdexcept>
#include <tuple>

namespace wavevortex::runtime {
namespace {
constexpr double pi = 3.141592653589793238462643383279502884;
WVCheckpointStatus invalid(const std::string& message, const std::string& name = "") {
    return {WVCheckpointStatusCode::invalidValue,message,"/"+name};
}
std::size_t product(std::size_t a, std::size_t b) {
    if (a && b > static_cast<std::size_t>(PTRDIFF_MAX)/a) throw std::overflow_error("Modal extent exceeds the addressable range.");
    return a*b;
}
bool close(double a, double b, double scale = 1) {
    return std::abs(a-b) <= 128*std::numeric_limits<double>::epsilon()*std::max({scale,std::abs(a),std::abs(b)});
}
WVCheckpointStatus matrixVariable(int file, const char* name, const char* fast, const char* slow,
    std::size_t rows, std::size_t columns, int& variable) {
    int code = nc_inq_varid(file,name,&variable);
    if (code == NC_ENOTVAR) return {WVCheckpointStatusCode::missingVariable,"Required numeric modal input is missing.",std::string("/")+name};
    if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal variable lookup",name);
    nc_type type; int rank = 0;
    code = nc_inq_var(file,variable,nullptr,&type,&rank,nullptr,nullptr);
    if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal variable inspection",name);
    if (type != NC_DOUBLE || rank != (slow ? 2 : 1)) return {WVCheckpointStatusCode::shapeMismatch,"Modal input must be a double with its declared rank.",name};
    std::array<int,2> dims{}; code = nc_inq_vardimid(file,variable,dims.data());
    if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal dimensions",name);
    for (int i = 0; i < rank; ++i) {
        const char* expected = slow && i == 0 ? slow : fast;
        int id; code = nc_inq_dimid(file,expected,&id);
        if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal dimension lookup",expected);
        std::size_t length; code = nc_inq_dimlen(file,id,&length);
        if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal dimension length",expected);
        if (dims[i] != id || length != (slow && i == 0 ? columns : rows))
            return {WVCheckpointStatusCode::shapeMismatch,"Modal matrix orientation or dimension identity disagrees with its schema.",name};
    }
    product(product(rows,columns),sizeof(double));
    return WVCheckpointStatus::ok();
}
WVCheckpointStatus vectorInput(int file, const char* name, const char* dimension, std::size_t size, std::vector<double>& output) {
    int variable; auto status = matrixVariable(file,name,dimension,nullptr,size,1,variable); if (!status) return status;
    double fill = NC_FILL_DOUBLE; int noFill = 0;
    const int fillCode = nc_inq_var_fill(file,variable,&noFill,&fill);
    if (fillCode != NC_NOERR) return detail::netcdfFailure(fillCode,"Modal fill metadata",name);
    output.resize(size); const int code = nc_get_var_double(file,variable,output.data());
    if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal vector read",name);
    for (const double value : output) if (!std::isfinite(value) || value == fill || value == NC_FILL_DOUBLE) return invalid("Modal vector contains a nonfinite or missing value.",name);
    return WVCheckpointStatus::ok();
}
WVCheckpointStatus scanMatrix(int file, const char* name, const WVStratifiedModalGeometry& g, std::vector<double>* output) {
    const bool inverse = std::string(name).find("inv") != std::string::npos;
    const bool G = name[0] == 'Q';
    const auto rows = inverse ? g.Nz : g.Nj, columns = inverse ? g.Nj : g.Nz;
    int variable; auto status = matrixVariable(file,name,inverse ? "z" : "j",inverse ? "j" : "z",rows,columns,variable); if (!status) return status;
    double fill = NC_FILL_DOUBLE; int noFill = 0;
    const int fillCode = nc_inq_var_fill(file,variable,&noFill,&fill);
    if (fillCode != NC_NOERR) return detail::netcdfFailure(fillCode,"Modal fill metadata",name);
    if (output) output->resize(product(rows,columns));
    std::array<double,4096> buffer{};
    for (std::size_t c = 0; c < columns; ++c) {
        double maximum = 0;
        for (std::size_t first = 0; first < rows; first += std::min(buffer.size(),rows-first)) {
            const std::size_t count = std::min(buffer.size(),rows-first);
            const std::size_t start[] = {c,first}, extent[] = {1,count};
            const int code = nc_get_vara_double(file,variable,start,extent,buffer.data());
            if (code != NC_NOERR) return detail::netcdfFailure(code,"Modal payload scan",name);
            for (std::size_t i = 0; i < count; ++i) {
                const auto r = first+i; const double value = buffer[i];
                if (!std::isfinite(value) || value == fill || value == NC_FILL_DOUBLE) return invalid("Modal matrix contains a nonfinite or missing value.",name);
                const auto z = inverse ? r : c, j = inverse ? c : r;
                if (G && (g.j[j] == 0 || z == 0 || z+1 == g.Nz) && value != 0)
                    return invalid("Rigid-lid G matrices require zero boundaries and a zero barotropic mode.",name);
                if (inverse && !G && g.j[j] == 0 && !close(value,1))
                    return invalid("The preconditioned barotropic F column must equal one.",name);
                maximum = std::max(maximum,std::abs(value));
                if (output) (*output)[r+rows*c] = value;
            }
        }
        if (inverse && !(G && g.j[c] == 0) && !close(maximum,1))
            return invalid("Reconstruction columns must use the persisted unit-maximum preconditioning.",name);
    }
    return WVCheckpointStatus::ok();
}
// Scan each declared column through the same bounded buffer used by shared
// matrices. NetCDF dimensions are reversed relative to MATLAB column-major data.
WVCheckpointStatus scanWaveArray(int file,const char* name,const WVStratifiedModalGeometry& g,std::vector<double>* output) {
    const std::string key=name;
    const bool inverse=key=="PFpmInv" || key=="QGpmInv";
    const bool cross=key=="QGwg", scale=key=="Ppm" || key=="Qpm", depth=key=="h_pm";
    const bool G=key.front()=='Q';
    const std::size_t rows=inverse ? g.Nz : g.Nj,columns=scale || depth ? (depth ? g.Nkl : g.K2unique.size()) : (cross ? g.Nj : inverse ? g.Nj : g.Nz);
    const auto groups=scale || depth ? 1 : g.K2unique.size();
    const int rank=scale || depth ? 2 : 3;
    const char* dimensions[3]={scale ? "K2unique" : depth ? "kl" : "K2unique",inverse || cross ? "j" : "z",inverse ? "z" : "j"};
    if (rank==2) dimensions[1]="j";
    const std::size_t lengths[3]={rank==3 ? groups : columns,rank==3 ? columns : rows,rows};
    int variable=-1; auto code=nc_inq_varid(file,name,&variable);
    if (code==NC_ENOTVAR) return {WVCheckpointStatusCode::missingVariable,"Required Boussinesq modal array is missing.",name};
    if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave array lookup",name);
    int actualRank=0; nc_type type; code=nc_inq_var(file,variable,nullptr,&type,&actualRank,nullptr,nullptr);
    if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave array metadata",name);
    if (type!=NC_DOUBLE || actualRank!=rank) return {WVCheckpointStatusCode::shapeMismatch,"Wave array type or rank disagrees with the persisted schema.",name};
    int ids[3]; code=nc_inq_vardimid(file,variable,ids);
    if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave array dimensions",name);
    for (int i=0;i<rank;++i) {
        int expected=-1; std::size_t length=0;
        code=nc_inq_dimid(file,dimensions[i],&expected); if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave dimension lookup",name);
        code=nc_inq_dimlen(file,expected,&length); if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave dimension length",name);
        if (ids[i]!=expected || length!=lengths[i]) return {WVCheckpointStatusCode::shapeMismatch,"Wave array orientation or dimension identity is invalid.",name};
    }
    const auto count=product(product(rows,columns),groups); product(count,sizeof(double));
    if (output) output->resize(count);
    double fill=NC_FILL_DOUBLE; int noFill=0; code=nc_inq_var_fill(file,variable,&noFill,&fill);
    if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave fill metadata",name);
    std::array<double,4096> buffer{};
    for (std::size_t group=0;group<groups;++group) for (std::size_t column=0;column<columns;++column) {
        double maximum=0;
        for (std::size_t first=0;first<rows;first+=std::min(rows-first,buffer.size())) {
            const auto n=std::min(rows-first,buffer.size());
            const std::size_t start[]={group,column,first},extent[]={1,1,n};
            code=nc_get_vara_double(file,variable,start+(rank==2),extent+(rank==2),buffer.data());
            if (code!=NC_NOERR) return detail::netcdfFailure(code,"Wave payload scan",name);
            for (std::size_t i=0;i<n;++i) {
                const auto row=first+i; const double value=buffer[i];
                if (!std::isfinite(value) || value==fill || value==NC_FILL_DOUBLE) return invalid("Wave array contains a nonfinite or missing value.",name);
                if (scale || depth) {
                    if (value<=0 || (g.j[row]==0 && value!=1)) return invalid("Wave scales/depths require positive values and unit barotropic sentinels.",name);
                } else if (cross) {
                    if ((g.j[row]==0 || g.j[column]==0) && value!=0) return invalid("Wave G cross-projection must exclude the barotropic mode.",name);
                } else {
                    const auto z=inverse ? row : column,j=inverse ? column : row;
                    if (G && (g.j[j]==0 || z==0 || z+1==g.Nz) && value!=0) return invalid("Wave G matrices require rigid-lid boundaries and zero barotropic mode.",name);
                    if (inverse && !G && g.j[j]==0 && !close(value,1)) return invalid("Wave F barotropic column must equal one.",name);
                }
                maximum=std::max(maximum,std::abs(value));
                if (output) (*output)[row+rows*(column+columns*group)]=value;
            }
        }
        if (inverse && !(G && g.j[column]==0) && !close(maximum,1)) return invalid("Wave reconstruction must retain unit-maximum preconditioning.",name);
    }
    return WVCheckpointStatus::ok();
}
WVCheckpointStatus inspectFile(int file, WVStratifiedModalInspection& result) {
    WVStratifiedModalInspection candidate; auto& g = candidate.geometry;
    auto status = detail::readTextAttribute(file,"model_version",g.modelVersion,"/"); if (!status) return status;
    if (g.modelVersion.rfind("4.",0) != 0) return {WVCheckpointStatusCode::unsupportedModelVersion,"Modal reader requires a v4 scientific record.","/@model_version"};
    status = detail::readTextAttribute(file,"WVTransform",g.transformClass,"/"); if (!status) return status;
    std::string annotated; status = detail::readTextAttribute(file,"AnnotatedClass",annotated,"/"); if (!status) return status;
    if (annotated != g.transformClass) return {WVCheckpointStatusCode::schemaMismatch,"Root transform identities disagree.","/"};
    if (g.transformClass != "WVTransformStratifiedQG" && g.transformClass != "WVTransformHydrostatic" && g.transformClass != "WVTransformBoussinesq")
        return {WVCheckpointStatusCode::unsupportedTransform,"This modal record reader supports v4 Stratified QG, Hydrostatic and Boussinesq records.","/"};
    struct Dimension { const char* name; std::size_t* value; };
    for (const auto& d : {Dimension{"x",&g.Nx},{"y",&g.Ny},{"z",&g.Nz},{"j",&g.Nj},{"kl",&g.Nkl}}) {
        status = detail::dimensionLength(file,d.name,*d.value,"/"); if (!status) return status;
        if (!*d.value) return invalid("Modal dimensions must be nonempty.",d.name);
    }
    if (g.Nx < 2 || g.Ny < 2 || g.Nz < 3 || g.Nj >= g.Nz || g.Nx > static_cast<std::size_t>(INT64_MAX) || g.Ny > static_cast<std::size_t>(INT64_MAX))
        return invalid("Invalid horizontal or rigid-lid retained vertical dimensions.");
    product(product(product(g.Nx,g.Ny),g.Nz),sizeof(double));
    product(product(g.Nj,g.Nkl),sizeof(WVComplex64));
    candidate.scientificMatrixBytes = product(product(g.Nz,g.Nj),4*sizeof(double));
    struct Scalar { const char* name; double* value; };
    for (const auto& s : {Scalar{"Lx",&g.Lx},{"Ly",&g.Ly},{"Lz",&g.Lz},{"g",&g.g},{"rho0",&g.rho0},{"latitude",&g.latitude},{"rotationRate",&g.rotationRate},{"planetaryRadius",&g.planetaryRadius}}) {
        status = detail::readDoubleScalar(file,s.name,*s.value,"/"); if (!status) return status;
        if (!std::isfinite(*s.value) || (s.value != &g.latitude && *s.value <= 0)) return invalid("Invalid physical scalar.",s.name);
    }
    if (std::abs(g.latitude) < 5 || std::abs(g.latitude) > 85) return invalid("Absolute latitude must lie in [5,85].","latitude");
    status = detail::readLogicalScalar(file,"shouldAntialias",g.shouldAntialias,"/"); if (!status) return status;
    struct Vector { const char* name; const char* dimension; std::size_t size; std::vector<double>* values; };
    for (const auto& v : {Vector{"x","x",g.Nx,&g.x},{"y","y",g.Ny,&g.y},{"z","z",g.Nz,&g.z},{"j","j",g.Nj,&g.j},
        {"k","kl",g.Nkl,&g.k},{"l","kl",g.Nkl,&g.l},{"N2","z",g.Nz,&g.N2},{"rho_nm0","z",g.Nz,&g.rho_nm0},{"dLnN2","z",g.Nz,&g.dLnN2},
        {"P0","j",g.Nj,&g.P0},{"Q0","j",g.Nj,&g.Q0},{"h_0","j",g.Nj,&g.h_0},{"z_int","z",g.Nz,&g.z_int}}) {
        status = vectorInput(file,v.name,v.dimension,v.size,*v.values); if (!status) return status;
    }
    for (std::size_t i = 0; i < g.Nx; ++i) if (!close(g.x[i],g.Lx*static_cast<double>(i)/g.Nx,g.Lx)) return invalid("x must use the periodic origin and spacing.","x");
    for (std::size_t i = 0; i < g.Ny; ++i) if (!close(g.y[i],g.Ly*static_cast<double>(i)/g.Ny,g.Ly)) return invalid("y must use the periodic origin and spacing.","y");
    // MATLAB WKB quadrature inversion places endpoints to interpolation accuracy.
    if (std::abs(g.z.front()+g.Lz) > 1e-10*g.Lz || std::abs(g.z.back()) > 1e-10*g.Lz) return invalid("Vertical grid must include bottom -Lz and surface zero.","z");
    long double integral = 0;
    for (std::size_t i = 0; i < g.Nz; ++i) {
        if ((i && g.z[i] <= g.z[i-1]) || g.N2[i] <= 0 || g.rho_nm0[i] <= 0 || (i && g.rho_nm0[i] > g.rho_nm0[i-1]))
            return invalid("Vertical coordinates and stable stratification are inconsistent.","z/N2/rho_nm0");
        integral += g.z_int[i];
    }
    if (std::abs(integral-g.Lz) > 1e-10*g.Lz) return invalid("Vertical quadrature must integrate a constant to Lz.","z_int");
    for (std::size_t i = 0; i < g.Nj; ++i) {
        if (g.j[i] != std::floor(g.j[i]) || g.j[i] < 0 || g.j[i] >= static_cast<double>(g.Nz-1) || (i && g.j[i] <= g.j[i-1]))
            return invalid("Retained vertical keys must be unique increasing rigid-lid mode indices.","j");
        if (g.P0[i] <= 0 || g.Q0[i] <= 0 || g.h_0[i] <= 0) return invalid("Preconditioners and equivalent depths must be positive.","P0/Q0/h_0");
    }
    if (g.j.front() != 0 || !close(g.P0.front(),1) || !close(g.Q0.front(),1) || !close(g.h_0.front(),1)) return invalid("The barotropic mode requires its documented unit sentinel values.","j/P0/Q0/h_0");
    std::vector<double> kl; status = vectorInput(file,"kl","kl",g.Nkl,kl); if (!status) return status;
    std::set<std::pair<std::int64_t,std::int64_t>> seen;
    const double cutoff = (2.0/3.0)*(2*pi*static_cast<double>(g.Nx/2)/g.Lx);
    for (std::size_t i = 0; i < g.Nkl; ++i) {
        if (kl[i] != static_cast<double>(i)) return invalid("kl must name the ordered retained columns.","kl");
        const double k = g.k[i]*g.Lx/(2*pi), l = g.l[i]*g.Ly/(2*pi);
        if (!std::isfinite(k) || !std::isfinite(l) || std::abs(std::round(k)) > static_cast<double>((g.Nx-1)/2) || std::abs(std::round(l)) > static_cast<double>((g.Ny-1)/2) || !close(k,std::round(k)) || !close(l,std::round(l)))
            return invalid("Horizontal keys are outside the Nyquist-excluding integer grid.","k/l");
        const auto ki = static_cast<std::int64_t>(std::round(k)), li = static_cast<std::int64_t>(std::round(l));
        if (li < 0 || (li == 0 && ki < 0) || !seen.insert({ki,li}).second) return invalid("Horizontal keys must be unique primary Hermitian representatives.","k/l");
        if (g.shouldAntialias && std::hypot(g.k[i],g.l[i]) > cutoff && !close(std::hypot(g.k[i],g.l[i]),cutoff,cutoff)) return invalid("Retained key violates the declared antialias mask.","k/l");
        g.modes.push_back({ki,li});
    }
    for (const char* name : {"PF0inv","QG0inv","PF0","QG0"}) { status = scanMatrix(file,name,g,nullptr); if (!status) return status; }
    if (g.transformClass=="WVTransformBoussinesq") {
        std::size_t groups=0; status=detail::dimensionLength(file,"K2unique",groups,"/"); if (!status) return status;
        if (!groups || groups>g.Nkl) return invalid("Wave group count must be nonempty and bounded by retained columns.","K2unique");
        status=vectorInput(file,"K2unique","K2unique",groups,g.K2unique); if (!status) return status;
        std::vector<double> membership; status=vectorInput(file,"iK2unique","kl",g.Nkl,membership); if (!status) return status;
        for (std::size_t i=0;i<groups;++i) if (g.K2unique[i]<0 || (i && g.K2unique[i]<=g.K2unique[i-1])) return invalid("Wave group radii must be nonnegative and strictly increasing.","K2unique");
        if (g.K2unique.front()!=0) return invalid("Wave groups must include the inertial zero wavenumber.","K2unique");
        std::vector<std::size_t> first(groups,g.Nkl); g.waveGroup.resize(g.Nkl);
        for (std::size_t i=0;i<g.Nkl;++i) {
            const auto value=membership[i];
            if (value<1 || value>static_cast<double>(groups) || value!=std::floor(value)) return invalid("Wave membership must be a valid one-based persisted group index.","iK2unique");
            const auto group=static_cast<std::size_t>(value)-1; g.waveGroup[i]=group; first[group]=std::min(first[group],i);
            const double radius=g.k[i]*g.k[i]+g.l[i]*g.l[i];
            if (!close(radius,g.K2unique[group],std::max(radius,g.K2unique[group]))) return invalid("Persisted wave membership disagrees with its horizontal wavenumber.","iK2unique");
        }
        if (g.waveGroup.front()!=0 || std::find(first.begin(),first.end(),g.Nkl)!=first.end()) return invalid("Wave groups require complete membership and a first inertial column.","iK2unique");
        struct WaveScale { const char* name; std::vector<double>* values; };
        const WaveScale scales[]={{"Ppm",&g.Ppm},{"Qpm",&g.Qpm},{"h_pm",&g.h_pm}};
        for (const auto& entry:scales) {
            status=scanWaveArray(file,entry.name,g,entry.values); if (!status) return status;
        }
        const double f=2*g.rotationRate*std::sin(g.latitude*pi/180);
        for (double N2:g.N2) if (N2==f*f) return invalid("Boussinesq wave projection is singular where N2 equals f squared.","N2");
        for (std::size_t i=0;i<g.Nkl;++i) for (std::size_t j=0;j<g.Nj;++j)
            if (g.h_pm[j+g.Nj*i]!=g.h_pm[j+g.Nj*first[g.waveGroup[i]]]) return invalid("Equivalent depths differ within one persisted wave group.","h_pm");
        for (const char* name:{"PFpmInv","QGpmInv","PFpm","QGpm","QGwg"}) { status=scanWaveArray(file,name,g,nullptr); if (!status) return status; }
        const auto waveBytes=product(product(product(4,g.Nz)+g.Nj,g.Nj),product(groups,sizeof(double)));
        if (waveBytes>static_cast<std::size_t>(PTRDIFF_MAX)-candidate.scientificMatrixBytes) throw std::overflow_error("Scientific matrix byte count overflow.");
        candidate.scientificMatrixBytes+=waveBytes;
    }
    result = std::move(candidate); return WVCheckpointStatus::ok();
}
std::uint64_t nextIdentity() {
    static std::atomic<std::uint64_t> sequence{1};
    auto next = sequence.load();
    do { if (next == UINT64_MAX) throw std::overflow_error("Modal record identities exhausted."); }
    while (!sequence.compare_exchange_weak(next,next+1));
    return next;
}
}
WVCheckpointStatus WVStratifiedModalReader::inspect(const std::string& path, WVStratifiedModalInspection& result) {
    try {
        detail::WVNetCDFFile file; auto status = detail::WVNetCDFFile::openReadOnly(path,file); if (!status) return status;
        return inspectFile(file.id(),result);
    } catch (const std::bad_alloc&) { return {WVCheckpointStatusCode::allocationFailure,"Modal inspection allocation failed.",path}; }
      catch (const std::overflow_error& e) { return invalid(e.what()); }
}
WVCheckpointStatus WVStratifiedModalReader::read(const std::string& path, std::shared_ptr<const WVStratifiedModalRecord>& result) {
    try {
        detail::WVNetCDFFile file; auto status = detail::WVNetCDFFile::openReadOnly(path,file); if (!status) return status;
        WVStratifiedModalInspection inspection; status = inspectFile(file.id(),inspection); if (!status) return status;
        auto candidate = std::shared_ptr<WVStratifiedModalRecord>(new WVStratifiedModalRecord);
        candidate->geometry_ = std::move(inspection.geometry);
        struct Matrix { const char* name; std::vector<double>* values; };
        for (const auto& m : {Matrix{"PF0inv",&candidate->PF0inv_},{"QG0inv",&candidate->QG0inv_},{"PF0",&candidate->PF0_},{"QG0",&candidate->QG0_}}) {
            status = scanMatrix(file.id(),m.name,candidate->geometry_,m.values); if (!status) return status;
        }
        if (!candidate->geometry_.K2unique.empty()) for (const auto& m : {Matrix{"PFpmInv",&candidate->PFpmInv_},{"QGpmInv",&candidate->QGpmInv_},{"PFpm",&candidate->PFpm_},{"QGpm",&candidate->QGpm_},{"QGwg",&candidate->QGwg_}}) {
            status=scanWaveArray(file.id(),m.name,candidate->geometry_,m.values); if (!status) return status;
        }
        int functionVariable = -1;
        const int functionCode = nc_inq_varid(file.id(),"N2Function",&functionVariable);
        if (functionCode != NC_ENOTVAR) {
            if (functionCode != NC_NOERR) return detail::netcdfFailure(functionCode,"Function payload lookup","N2Function");
            int rank=0, dimension=-1; nc_type type;
            int code=nc_inq_var(file.id(),functionVariable,nullptr,&type,&rank,nullptr,nullptr);
            if (code != NC_NOERR) return detail::netcdfFailure(code,"Function payload metadata","N2Function");
            if (rank != 1 || type != NC_UBYTE) return invalid("N2Function must be an opaque uint8 vector.","N2Function");
            nc_type markerType; std::size_t markerLength=0; unsigned char marker=0;
            code=nc_inq_att(file.id(),functionVariable,"isFunctionHandleType",&markerType,&markerLength);
            if (code != NC_NOERR || markerType != NC_UBYTE || markerLength != 1)
                return invalid("N2Function requires its scalar function-handle marker.","N2Function");
            code=nc_get_att_uchar(file.id(),functionVariable,"isFunctionHandleType",&marker);
            if (code != NC_NOERR || marker != 1) return invalid("Invalid N2Function function-handle marker.","N2Function");
            code=nc_inq_vardimid(file.id(),functionVariable,&dimension); if (code != NC_NOERR) return detail::netcdfFailure(code,"Function payload dimension","N2Function");
            std::size_t size=0; code=nc_inq_dimlen(file.id(),dimension,&size); if (code != NC_NOERR) return detail::netcdfFailure(code,"Function payload length","N2Function");
            candidate->N2FunctionPayload_.resize(size);
            code=nc_get_var_uchar(file.id(),functionVariable,candidate->N2FunctionPayload_.data()); if (code != NC_NOERR) return detail::netcdfFailure(code,"Function payload read","N2Function");
        }
        candidate->groups_.resize(std::max(std::size_t{1},candidate->geometry_.K2unique.size()));
        for (std::size_t i=0;i<candidate->groups_.size();++i) candidate->groups_[i].identity=i;
        for (std::size_t i=0;i<candidate->geometry_.Nkl;++i) candidate->groups_[candidate->geometry_.waveGroup.empty() ? 0 : candidate->geometry_.waveGroup[i]].columns.push_back(i);
        candidate->sourceIdentity_ = std::string(WVStratifiedModalRecordContract)+"/record/"+std::to_string(nextIdentity());
        candidate->modeSetIdentity_ = candidate->sourceIdentity_+"/horizontal-modes";
        result = std::move(candidate); return WVCheckpointStatus::ok();
    } catch (const std::bad_alloc&) { return {WVCheckpointStatusCode::allocationFailure,"Modal record allocation failed.",path}; }
      catch (const std::overflow_error& e) { return invalid(e.what()); }
}
std::size_t WVStratifiedModalRecord::persistentBytes() const noexcept {
    std::size_t bytes = sizeof(*this)+N2FunctionPayload_.capacity()+sourceIdentity_.capacity()+modeSetIdentity_.capacity()+geometry_.transformClass.capacity()+geometry_.modelVersion.capacity()+geometry_.modes.capacity()*sizeof(WVRetainedModeKey);
    for (const auto* v : {&geometry_.x,&geometry_.y,&geometry_.z,&geometry_.j,&geometry_.k,&geometry_.l,&geometry_.N2,&geometry_.rho_nm0,&geometry_.dLnN2,&geometry_.P0,&geometry_.Q0,&geometry_.h_0,&geometry_.z_int,&PF0inv_,&QG0inv_,&PF0_,&QG0_}) bytes += v->capacity()*sizeof(double);
    for (const auto* v:{&geometry_.K2unique,&geometry_.h_pm,&geometry_.Ppm,&geometry_.Qpm,&PFpmInv_,&QGpmInv_,&PFpm_,&QGpm_,&QGwg_}) bytes+=v->capacity()*sizeof(double);
    bytes+=geometry_.waveGroup.capacity()*sizeof(std::size_t);
    bytes += groups_.capacity()*sizeof(WVScientificModalGroup);
    for (const auto& group:groups_) bytes += group.columns.capacity()*sizeof(std::size_t);
    return bytes;
}
WVKernelStatus WVStratifiedModalRecord::matrixView(WVStratifiedScientificMatrix matrix, WVVerticalMatrixRecord& result) const {
    try {
        const char* name; const char* modal; const char* grid; const std::vector<double>* values; bool inverse;
        switch(matrix) {
            case WVStratifiedScientificMatrix::PF0inv: name="PF0inv"; modal="PF0-modal"; grid="F-grid"; values=&PF0inv_; inverse=true; break;
            case WVStratifiedScientificMatrix::QG0inv: name="QG0inv"; modal="QG0-modal"; grid="G-grid"; values=&QG0inv_; inverse=true; break;
            case WVStratifiedScientificMatrix::PF0: name="PF0"; modal="PF0-modal"; grid="F-grid"; values=&PF0_; inverse=false; break;
            case WVStratifiedScientificMatrix::QG0: name="QG0"; modal="QG0-modal"; grid="G-grid"; values=&QG0_; inverse=false; break;
            default: return {WVKernelStatusCode::invalidConfiguration,"Unknown persisted modal matrix."};
        }
        const auto rows=inverse ? geometry_.Nz : geometry_.Nj, columns=inverse ? geometry_.Nj : geometry_.Nz;
        WVVerticalMatrixRecord candidate{{sourceIdentity_,name},{values->data(),rows,columns,1,rows,values->size()*sizeof(double)},
            inverse ? WVMatrixAction::reconstruction : WVMatrixAction::projection,inverse ? modal : grid,inverse ? grid : modal};
        result=std::move(candidate); return WVKernelStatus::ok();
    } catch(const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Scientific matrix view allocation failed."}; }
}
WVKernelStatus WVStratifiedModalRecord::prepareVertical(WVStratifiedModalOperator operation, WVComplexLayout input, WVComplexLayout output,
    std::unique_ptr<WVVerticalMatrixBackend> backend, std::unique_ptr<WVPreparedVerticalOperator>& result, WVAccumulation accumulation) const {
    if (operation>=WVStratifiedModalOperator::reconstructFw && operation<=WVStratifiedModalOperator::projectWaveVerticalVelocity)
        return prepareWaveVertical(operation,std::move(input),std::move(output),std::move(backend),result,accumulation);
    try {
        const auto& g = geometry_; const char* name; const char* inFamily; const char* outFamily; WVMatrixAction action;
        switch (operation) {
            case WVStratifiedModalOperator::reconstructF: name="Finv"; inFamily="F-modal"; outFamily="F-grid"; action=WVMatrixAction::reconstruction; break;
            case WVStratifiedModalOperator::projectF: name="F"; inFamily="F-grid"; outFamily="F-modal"; action=WVMatrixAction::projection; break;
            case WVStratifiedModalOperator::reconstructG: name="Ginv"; inFamily="G-modal"; outFamily="G-grid"; action=WVMatrixAction::reconstruction; break;
            case WVStratifiedModalOperator::projectG: name="G"; inFamily="G-grid"; outFamily="G-modal"; action=WVMatrixAction::projection; break;
            case WVStratifiedModalOperator::GToF: name="F*Ginv"; inFamily="G-modal"; outFamily="F-modal"; action=WVMatrixAction::crossFamily; break;
            case WVStratifiedModalOperator::FToG: name="G*Finv"; inFamily="F-modal"; outFamily="G-modal"; action=WVMatrixAction::crossFamily; break;
            default: return {WVKernelStatusCode::invalidConfiguration,"Unknown modal operator."};
        }
        if (input.family != inFamily || output.family != outFamily || input.columns != g.Nkl || output.columns != g.Nkl || input.modeSet != modeSetIdentity_ || output.modeSet != modeSetIdentity_)
            return {WVKernelStatusCode::invalidConfiguration,"Modal field family or ordered mode identity disagrees with the scientific record."};
        const auto rows = action == WVMatrixAction::reconstruction ? g.Nz : g.Nj;
        const auto columns = action == WVMatrixAction::projection ? g.Nz : g.Nj;
        std::vector<double> values(product(rows,columns));
        for (std::size_t c=0; c<columns; ++c) for (std::size_t r=0; r<rows; ++r) {
            double v=0;
            switch (operation) {
                case WVStratifiedModalOperator::reconstructF: v=PF0inv_[r+g.Nz*c]*g.P0[c]; break;
                case WVStratifiedModalOperator::reconstructG: v=QG0inv_[r+g.Nz*c]*g.Q0[c]; break;
                case WVStratifiedModalOperator::projectF: v=PF0_[r+g.Nj*c]/g.P0[r]; break;
                case WVStratifiedModalOperator::projectG: v=QG0_[r+g.Nj*c]/g.Q0[r]; break;
                case WVStratifiedModalOperator::GToF:
                    for (std::size_t z=0; z<g.Nz; ++z) v+=(PF0_[r+g.Nj*z]/g.P0[r])*(QG0inv_[z+g.Nz*c]*g.Q0[c]);
                    break;
                case WVStratifiedModalOperator::FToG:
                    for (std::size_t z=0; z<g.Nz; ++z) v+=(QG0_[r+g.Nj*z]/g.Q0[r])*(PF0inv_[z+g.Nz*c]*g.P0[c]);
                    break;
                default: break; // Wave operations were dispatched above.
            }
            values[r+rows*c]=v;
        }
        WVVerticalSpecification spec; spec.sourceIdentity=sourceIdentity_; spec.action=action; spec.Nz=g.Nz; spec.Nj=g.Nj;
        spec.input=std::move(input); spec.output=std::move(output); spec.accumulation=accumulation;
        spec.matrices={{{sourceIdentity_,name},{values.data(),rows,columns,1,rows,values.size()*sizeof(double)},action,inFamily,outFamily}};
        WVVerticalGroup group; group.identity=0; group.matrix=0; group.modes.resize(g.Nkl);
        for (std::size_t i=0;i<g.Nkl;++i) group.modes[i]=i;
        spec.groups.push_back(std::move(group));
        return WVPreparedVerticalOperator::create(spec,std::move(backend),result);
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Modal operator preparation allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
}
WVKernelStatus WVStratifiedModalRecord::prepareWaveVertical(WVStratifiedModalOperator operation,WVComplexLayout input,WVComplexLayout output,
    std::unique_ptr<WVVerticalMatrixBackend> backend,std::unique_ptr<WVPreparedVerticalOperator>& result,WVAccumulation accumulation) const {
    try {
        const auto& g=geometry_;
        if (g.transformClass!="WVTransformBoussinesq" || groups_.empty()) return {WVKernelStatusCode::unsupportedOperation,"Wave matrices require a Boussinesq source."};
        const char* name; const char* inFamily; const char* outFamily; WVMatrixAction action;
        switch (operation) {
            case WVStratifiedModalOperator::reconstructFw: name="FwInv"; inFamily="Fw-modal"; outFamily="F-grid"; action=WVMatrixAction::reconstruction; break;
            case WVStratifiedModalOperator::projectFw: name="Fw"; inFamily="F-grid"; outFamily="Fw-modal"; action=WVMatrixAction::projection; break;
            case WVStratifiedModalOperator::reconstructGw: name="GwInv"; inFamily="Gw-modal"; outFamily="G-grid"; action=WVMatrixAction::reconstruction; break;
            case WVStratifiedModalOperator::projectGw: name="Gw"; inFamily="G-grid"; outFamily="Gw-modal"; action=WVMatrixAction::projection; break;
            case WVStratifiedModalOperator::balancedGToWaveG: name="Gwg"; inFamily="G-modal"; outFamily="Gw-modal"; action=WVMatrixAction::crossFamily; break;
            case WVStratifiedModalOperator::projectWaveDivergence: name="GwDdelta"; inFamily="F-grid"; outFamily="Gw-modal"; action=WVMatrixAction::projection; break;
            case WVStratifiedModalOperator::projectWaveVerticalVelocity: name="GwVerticalVelocity"; inFamily="G-grid"; outFamily="Gw-modal"; action=WVMatrixAction::projection; break;
            default: return {WVKernelStatusCode::invalidConfiguration,"Unknown Boussinesq operator."};
        }
        if (input.family!=inFamily || output.family!=outFamily || input.columns!=g.Nkl || output.columns!=g.Nkl || input.modeSet!=modeSetIdentity_ || output.modeSet!=modeSetIdentity_)
            return {WVKernelStatusCode::invalidConfiguration,"Wave field family or exact mode identity disagrees with the source."};
        const auto rows=action==WVMatrixAction::reconstruction ? g.Nz : g.Nj, columns=action==WVMatrixAction::projection ? g.Nz : g.Nj;
        const auto plane=product(rows,columns), wavePlane=product(g.Nz,g.Nj);
        std::vector<double> values(product(plane,groups_.size()));
        std::vector<double> delta;
        const double f=2*g.rotationRate*std::sin(g.latitude*pi/180);
        if (operation==WVStratifiedModalOperator::projectWaveDivergence) {
            delta.resize(product(g.Nz,g.Nz));
            for (std::size_t c=0;c<g.Nz;++c) for (std::size_t r=0;r<g.Nz;++r) {
                double v=0;
                for (std::size_t j=0;j<g.Nj;++j) v+=QG0inv_[r+g.Nz*j]*(g.Q0[j]/g.P0[j])*PF0_[j+g.Nj*c];
                delta[r+g.Nz*c]=g.N2[r]/(g.N2[r]-f*f)*v;
            }
        }
        WVVerticalSpecification spec; spec.sourceIdentity=sourceIdentity_; spec.action=action; spec.Nz=g.Nz; spec.Nj=g.Nj;
        spec.input=std::move(input); spec.output=std::move(output); spec.accumulation=accumulation;
        for (std::size_t group=0;group<groups_.size();++group) {
            const auto offset=wavePlane*group,scaleOffset=g.Nj*group;
            for (std::size_t c=0;c<columns;++c) for (std::size_t r=0;r<rows;++r) {
                double value=0;
                switch (operation) {
                    case WVStratifiedModalOperator::reconstructFw: value=PFpmInv_[r+g.Nz*c+offset]*g.Ppm[c+scaleOffset]; break;
                    case WVStratifiedModalOperator::projectFw: value=PFpm_[r+g.Nj*c+offset]/g.Ppm[r+scaleOffset]; break;
                    case WVStratifiedModalOperator::reconstructGw: value=QGpmInv_[r+g.Nz*c+offset]*g.Qpm[c+scaleOffset]; break;
                    case WVStratifiedModalOperator::projectGw: value=QGpm_[r+g.Nj*c+offset]/g.Qpm[r+scaleOffset]; break;
                    case WVStratifiedModalOperator::balancedGToWaveG: value=QGwg_[r+g.Nj*c+g.Nj*g.Nj*group]*g.Q0[c]/g.Qpm[r+scaleOffset]; break;
                    case WVStratifiedModalOperator::projectWaveDivergence:
                        for (std::size_t z=0;z<g.Nz;++z) value+=(QGpm_[r+g.Nj*z+offset]/g.Qpm[r+scaleOffset])*delta[z+g.Nz*c];
                        break;
                    case WVStratifiedModalOperator::projectWaveVerticalVelocity: value=(QGpm_[r+g.Nj*c+offset]/g.Qpm[r+scaleOffset])*g.g/(g.N2[c]-f*f); break;
                    default: break;
                }
                values[r+rows*c+plane*group]=value;
            }
            spec.matrices.push_back({{sourceIdentity_,std::string(name)+"/"+std::to_string(groups_[group].identity)},
                {values.data()+plane*group,rows,columns,1,rows,plane*sizeof(double)},action,inFamily,outFamily});
            spec.groups.push_back({groups_[group].identity,group,groups_[group].columns});
        }
        return WVPreparedVerticalOperator::create(spec,std::move(backend),result);
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Wave operator preparation allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
}
WVKernelStatus WVStratifiedModalRecord::horizontalSpecification(std::size_t planes, WVComplexRepresentation representation,
    const std::string& family, WVRetainedHorizontalSpecification& result) const {
    try {
        const auto& g=geometry_;
        if (!planes || planes > g.Nz || family.empty() || (representation != WVComplexRepresentation::split && representation != WVComplexRepresentation::interleaved))
            return {WVKernelStatusCode::invalidConfiguration,"Invalid modal horizontal field layout."};
        WVRetainedHorizontalSpecification candidate;
        candidate.grid={g.Nx,g.Ny,planes,1,g.Nx,product(g.Nx,g.Ny),family};
        candidate.retained={planes,g.Nkl,1,planes,representation,family,modeSetIdentity_};
        candidate.Lx=g.Lx; candidate.Ly=g.Ly; candidate.modes=g.modes;
        result=std::move(candidate); return WVKernelStatus::ok();
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Modal horizontal specification allocation failed."}; }
      catch (const std::overflow_error& e) { return {WVKernelStatusCode::sizeOverflow,e.what()}; }
}
} // namespace wavevortex::runtime
