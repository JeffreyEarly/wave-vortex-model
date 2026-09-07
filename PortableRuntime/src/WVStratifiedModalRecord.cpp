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
WVCheckpointStatus inspectFile(int file, WVStratifiedModalInspection& result) {
    WVStratifiedModalInspection candidate; auto& g = candidate.geometry;
    auto status = detail::readTextAttribute(file,"model_version",g.modelVersion,"/"); if (!status) return status;
    if (g.modelVersion.rfind("4.",0) != 0) return {WVCheckpointStatusCode::unsupportedModelVersion,"Modal reader requires a v4 scientific record.","/@model_version"};
    status = detail::readTextAttribute(file,"WVTransform",g.transformClass,"/"); if (!status) return status;
    std::string annotated; status = detail::readTextAttribute(file,"AnnotatedClass",annotated,"/"); if (!status) return status;
    if (annotated != g.transformClass) return {WVCheckpointStatusCode::schemaMismatch,"Root transform identities disagree.","/"};
    if (g.transformClass != "WVTransformStratifiedQG" && g.transformClass != "WVTransformHydrostatic")
        return {WVCheckpointStatusCode::unsupportedTransform,"This modal record reader supports Stratified QG and Hydrostatic shared F/G records.","/"};
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
        WVScientificModalGroup group; group.columns.resize(candidate->geometry_.Nkl);
        for (std::size_t i=0;i<group.columns.size();++i) group.columns[i]=i;
        candidate->groups_.push_back(std::move(group));
        candidate->sourceIdentity_ = std::string(WVStratifiedModalRecordContract)+"/record/"+std::to_string(nextIdentity());
        candidate->modeSetIdentity_ = candidate->sourceIdentity_+"/horizontal-modes";
        result = std::move(candidate); return WVCheckpointStatus::ok();
    } catch (const std::bad_alloc&) { return {WVCheckpointStatusCode::allocationFailure,"Modal record allocation failed.",path}; }
      catch (const std::overflow_error& e) { return invalid(e.what()); }
}
std::size_t WVStratifiedModalRecord::persistentBytes() const noexcept {
    std::size_t bytes = sizeof(*this)+sourceIdentity_.capacity()+modeSetIdentity_.capacity()+geometry_.transformClass.capacity()+geometry_.modelVersion.capacity()+geometry_.modes.capacity()*sizeof(WVRetainedModeKey);
    for (const auto* v : {&geometry_.x,&geometry_.y,&geometry_.z,&geometry_.j,&geometry_.k,&geometry_.l,&geometry_.N2,&geometry_.rho_nm0,&geometry_.dLnN2,&geometry_.P0,&geometry_.Q0,&geometry_.h_0,&geometry_.z_int,&PF0inv_,&QG0inv_,&PF0_,&QG0_}) bytes += v->capacity()*sizeof(double);
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
            }
            values[r+rows*c]=v;
        }
        WVVerticalSpecification spec; spec.sourceIdentity=sourceIdentity_; spec.action=action; spec.Nz=g.Nz; spec.Nj=g.Nj;
        spec.input=std::move(input); spec.output=std::move(output); spec.accumulation=accumulation;
        spec.matrices={{{sourceIdentity_,name},{values.data(),rows,columns,1,rows,values.size()*sizeof(double)},action,inFamily,outFamily}};
        WVVerticalGroup group; group.identity=groups_.front().identity; group.matrix=0; group.modes=groups_.front().columns;
        spec.groups.push_back(std::move(group));
        return WVPreparedVerticalOperator::create(spec,std::move(backend),result);
    } catch (const std::bad_alloc&) { return {WVKernelStatusCode::allocationFailure,"Modal operator preparation allocation failed."}; }
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
