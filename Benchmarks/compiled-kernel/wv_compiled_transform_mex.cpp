#include "mex.h"

#include "WVFFTWEngine.hpp"
#include "WaveVortexKernel/WVTransformConstantStratificationKernel.hpp"

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>

using namespace wavevortex;

namespace {

std::unordered_map<std::uint64_t,std::unique_ptr<WVTransformConstantStratificationKernel>> kernels;
std::uint64_t nextHandle = 1;

void fail(const char* identifier, const std::string& message) { mexErrMsgIdAndTxt(identifier,"%s",message.c_str()); }

double scalarField(const mxArray* value, const char* name) {
    const mxArray* field = mxGetField(value,0,name);
    if (field == nullptr || (!mxIsNumeric(field) && !mxIsLogical(field)) || mxIsComplex(field) || mxGetNumberOfElements(field) != 1) fail("WaveVortexModel:CompiledKernelConfiguration",std::string("Missing scalar configuration field ") + name + '.');
    return mxGetScalar(field);
}

WVTransformConstantStratificationConfiguration configuration(const mxArray* value) {
    if (!mxIsStruct(value) || mxGetNumberOfElements(value) != 1) fail("WaveVortexModel:CompiledKernelConfiguration","Configuration must be a scalar struct.");
    WVTransformConstantStratificationConfiguration result;
    result.Nx = static_cast<std::size_t>(scalarField(value,"Nx")); result.Ny = static_cast<std::size_t>(scalarField(value,"Ny"));
    result.Nz = static_cast<std::size_t>(scalarField(value,"Nz")); result.Nj = static_cast<std::size_t>(scalarField(value,"Nj"));
    result.Lx = scalarField(value,"Lx"); result.Ly = scalarField(value,"Ly"); result.Lz = scalarField(value,"Lz");
    result.N0 = scalarField(value,"N0"); result.rho0 = scalarField(value,"rho0"); result.g = scalarField(value,"g");
    result.planetaryRadius = scalarField(value,"planetaryRadius"); result.rotationRate = scalarField(value,"rotationRate"); result.latitude = scalarField(value,"latitude");
    result.isHydrostatic = scalarField(value,"isHydrostatic") != 0.0; result.shouldAntialias = scalarField(value,"shouldAntialias") != 0.0;
    return result;
}

std::uint64_t scalarHandle(const mxArray* value) {
    if (!mxIsUint64(value) || mxGetNumberOfElements(value) != 1) fail("WaveVortexModel:CompiledKernelHandle","Kernel handle must be a uint64 scalar.");
    return *mxGetUint64s(value);
}

WVTransformConstantStratificationKernel& kernel(const mxArray* value) {
    const auto handle = scalarHandle(value);
    const auto iterator = kernels.find(handle);
    if (iterator == kernels.end()) fail("WaveVortexModel:CompiledKernelHandle","Kernel handle is invalid or deleted.");
    return *iterator->second;
}

void requireStatus(const WVKernelStatus& status) { if (!status) fail("WaveVortexModel:CompiledKernelFailure",status.message); }

WVComplexConstView complexInput(const mxArray* value, WVShape2D shape, const char* name) {
    if (!mxIsDouble(value) || !mxIsComplex(value) || mxGetM(value) != shape.rows || mxGetN(value) != shape.columns) fail("WaveVortexModel:CompiledKernelShape",std::string(name) + " must be a complex [Nj,Nkl] array.");
    return {reinterpret_cast<const WVComplex64*>(mxGetComplexDoubles(value)),shape};
}

mxArray* complexOutput(WVShape2D shape, WVComplexView& view) {
    mxArray* value = mxCreateDoubleMatrix(shape.rows,shape.columns,mxCOMPLEX);
    view = {reinterpret_cast<WVComplex64*>(mxGetComplexDoubles(value)),shape};
    return value;
}

WVRealFieldBundleConstView realBundleInput(const mxArray* value, WVShape3D spatial, std::size_t channels) {
    const auto dimensions = mxGetDimensions(value);
    const auto count = mxGetNumberOfDimensions(value);
    if (!mxIsDouble(value) || mxIsComplex(value) || count != 4 || dimensions[0] != spatial.first || dimensions[1] != spatial.second || dimensions[2] != spatial.third || dimensions[3] != channels) fail("WaveVortexModel:CompiledKernelShape","Spatial fields must be a real [Nx,Ny,Nz,Nfield] array.");
    return {mxGetDoubles(value),{spatial.first,spatial.second,spatial.third,channels}};
}

mxArray* realBundleOutput(WVShape3D spatial, std::size_t channels, WVRealFieldBundleView& view) {
    const mwSize dimensions[] = {spatial.first,spatial.second,spatial.third,channels};
    mxArray* value = mxCreateNumericArray(4,dimensions,mxDOUBLE_CLASS,mxREAL);
    view = {mxGetDoubles(value),{spatial.first,spatial.second,spatial.third,channels}};
    return value;
}

void cleanup() { kernels.clear(); }

} // namespace

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs < 1 || !mxIsChar(prhs[0])) fail("WaveVortexModel:CompiledKernelCommand","The first input must be a command string.");
    char commandBuffer[64];
    if (mxGetString(prhs[0],commandBuffer,sizeof(commandBuffer)) != 0) fail("WaveVortexModel:CompiledKernelCommand","Command is too long.");
    const std::string command(commandBuffer);
    if (command == "create") {
        if (nrhs != 3 || nlhs != 1) fail("WaveVortexModel:CompiledKernelCommand","create requires configuration and thread count.");
        std::unique_ptr<WVFFTEngine> engine;
        requireStatus(WVFFTWEngine::create(static_cast<std::size_t>(mxGetScalar(prhs[2])),engine));
        std::unique_ptr<WVTransformConstantStratificationKernel> value;
        requireStatus(WVTransformConstantStratificationKernel::create(configuration(prhs[1]),std::move(engine),value));
        const auto handle = nextHandle++;
        kernels.emplace(handle,std::move(value));
        if (kernels.size() == 1) { mexLock(); mexAtExit(cleanup); }
        plhs[0] = mxCreateNumericMatrix(1,1,mxUINT64_CLASS,mxREAL); *mxGetUint64s(plhs[0]) = handle;
        return;
    }
    if (command == "delete") {
        if (nrhs != 2 || nlhs != 0) fail("WaveVortexModel:CompiledKernelCommand","delete requires one handle.");
        if (kernels.erase(scalarHandle(prhs[1])) == 0) fail("WaveVortexModel:CompiledKernelHandle","Kernel handle is invalid or deleted.");
        if (kernels.empty()) mexUnlock();
        return;
    }
    auto& value = kernel(nrhs > 1 ? prhs[1] : nullptr);
    const auto spectral = value.descriptor().spectralShape();
    const auto spatial = value.descriptor().spatialShape();
    if (command == "forward") {
        if (nrhs != 5 || nlhs != 3) fail("WaveVortexModel:CompiledKernelCommand","forward requires handle, fields, t, and t0 and returns Ap, Am, A0.");
        const auto channels = value.descriptor().configuration().isHydrostatic ? 3U : 4U;
        const auto fields = realBundleInput(prhs[2],spatial,channels);
        WVMutableCoefficients coefficients;
        plhs[0] = complexOutput(spectral,coefficients.Ap); plhs[1] = complexOutput(spectral,coefficients.Am); plhs[2] = complexOutput(spectral,coefficients.A0);
        requireStatus(value.descriptor().configuration().isHydrostatic ? value.transformUVEtaToWaveVortex(fields,mxGetScalar(prhs[3]),mxGetScalar(prhs[4]),coefficients) : value.transformUVWEtaToWaveVortex(fields,mxGetScalar(prhs[3]),mxGetScalar(prhs[4]),coefficients));
        return;
    }
    if (command == "inverse") {
        if (nrhs != 7 || nlhs != 1) fail("WaveVortexModel:CompiledKernelCommand","inverse requires handle, Ap, Am, A0, t, and t0.");
        WVState state{mxGetScalar(prhs[5]),mxGetScalar(prhs[6]),{complexInput(prhs[2],spectral,"Ap"),complexInput(prhs[3],spectral,"Am"),complexInput(prhs[4],spectral,"A0")}};
        WVRealFieldBundleView fields; plhs[0] = realBundleOutput(spatial,4,fields);
        requireStatus(value.transformWaveVortexToUVWEta(state,fields));
        return;
    }
    if (command == "fAll" || command == "gAll") {
        if (nrhs != 4 || nlhs != 1) fail("WaveVortexModel:CompiledKernelCommand","fAll/gAll require handle, Apm, and A0.");
        WVRealFieldBundleView fields; plhs[0] = realBundleOutput(spatial,4,fields);
        const auto Apm = complexInput(prhs[2],spectral,"Apm"); const auto A0 = complexInput(prhs[3],spectral,"A0");
        requireStatus(command == "fAll" ? value.transformToSpatialDomainWithFAllDerivatives(Apm,A0,fields) : value.transformToSpatialDomainWithGAllDerivatives(Apm,A0,fields));
        return;
    }
    if (command == "metrics") {
        if (nrhs != 2 || nlhs != 1) fail("WaveVortexModel:CompiledKernelCommand","metrics requires one handle.");
        const char* names[] = {"engine","loadedLibrary","planCount","planBytes","descriptorBytes","scratchCapacityBytes","scratchHighWaterBytes","executionCount","horizontalExecutionCount","verticalExecutionCount","persistentBytes"};
        plhs[0] = mxCreateStructMatrix(1,1,11,names);
        const auto& metrics = value.metrics();
        mxSetField(plhs[0],0,"engine",mxCreateString(value.engineIdentifier().c_str()));
        mxSetField(plhs[0],0,"loadedLibrary",mxCreateString(value.engineLibraryIdentity().c_str()));
        const double numbers[] = {static_cast<double>(metrics.planCount),static_cast<double>(metrics.planBytes),static_cast<double>(metrics.descriptorBytes),static_cast<double>(metrics.scratchCapacityBytes),static_cast<double>(metrics.scratchHighWaterBytes),static_cast<double>(metrics.executionCount),static_cast<double>(metrics.horizontalExecutionCount),static_cast<double>(metrics.verticalExecutionCount),static_cast<double>(value.persistentBytes())};
        for (std::size_t i = 0; i < 9; ++i) mxSetField(plhs[0],0,names[i+2],mxCreateDoubleScalar(numbers[i]));
        return;
    }
    fail("WaveVortexModel:CompiledKernelCommand","Unknown compiled-kernel command.");
}
