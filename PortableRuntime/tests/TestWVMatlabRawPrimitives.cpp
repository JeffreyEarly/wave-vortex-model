#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexKernel/WVTransformHydrostaticKernel.hpp"
#include "WaveVortexKernel/WVTransformBoussinesqKernel.hpp"
#include "WaveVortexKernel/WVTransformStratifiedQGKernel.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "WVBoussinesqModalTestFixture.hpp"
#include "WVStratifiedModalTestFixture.hpp"

#include <cmath>
#include <complex>
#include <filesystem>
#include <iostream>
#include <memory>
#include <vector>

using namespace wavevortex;
using namespace wavevortex::runtime;
using namespace wavevortex::test_fixture;

namespace {
constexpr double pi=3.141592653589793238462643383279502884;
void hydrostaticFixture(const std::filesystem::path& path) {
    fixture(path);
    File file(path);
    for (const auto* name : {"WVTransform","AnnotatedClass"})
        nc(nc_put_att_text(file.id,NC_GLOBAL,name,std::char_traits<char>::length("WVTransformHydrostatic"),"WVTransformHydrostatic"));
}
std::shared_ptr<const WVStratifiedModalRecord> read(const std::filesystem::path& path) {
    std::shared_ptr<const WVStratifiedModalRecord> record;
    const auto status=WVStratifiedModalReader::read(path.string(),record);
    require(static_cast<bool>(status),status.message.c_str());
    return record;
}

template <typename Kernel>
std::unique_ptr<Kernel> makeKernel(const std::shared_ptr<const WVStratifiedModalRecord>& record,
    WVVariableExecutionOptions options = {}) {
    std::unique_ptr<Kernel> kernel;
    const auto status=Kernel::create(record,std::make_unique<WVReferenceFFTEngine>(),kernel,
        WVCreateScalarMatrixBackend,options);
    require(static_cast<bool>(status),status.message.c_str());
    return kernel;
}

template <typename Kernel>
void horizontalRoundTripAndDerivatives(Kernel& kernel,const WVStratifiedModalGeometry& geometry) {
    const auto volume=kernel.spatialShape();
    const WVShape2D retained{geometry.Nz,geometry.Nkl};
    const auto count=volume.elementCount();
    std::vector<double> field(count),restored(count),derivative(count);
    for (std::size_t z=0;z<geometry.Nz;++z) for (std::size_t y=0;y<geometry.Ny;++y) for (std::size_t x=0;x<geometry.Nx;++x) {
        const auto i=x+geometry.Nx*(y+geometry.Ny*z);
        field[i]=std::cos(2*pi*x/geometry.Nx)+.4*std::sin(2*pi*y/geometry.Ny);
    }
    std::vector<WVComplex64> spectrum(retained.elementCount());
    require(static_cast<bool>(kernel.horizontalForward({field.data(),volume},{spectrum.data(),retained})),"Raw horizontal forward failed.");
    require(static_cast<bool>(kernel.horizontalInverse({spectrum.data(),retained},{restored.data(),volume})),"Raw horizontal inverse failed.");
    for (std::size_t i=0;i<count;++i) require(std::abs(restored[i]-field[i])<1e-10,"Raw horizontal round trip changed values.");
    const auto persistent=kernel.persistentBytes();
    for(std::size_t z=0;z<geometry.Nz;++z) for(std::size_t y=0;y<geometry.Ny;++y) for(std::size_t x=0;x<geometry.Nx;++x)
        field[x+geometry.Nx*(y+geometry.Ny*z)]=std::cos(2*pi*x/geometry.Nx)+std::cos(pi*x)+.4*std::sin(4*pi*y/geometry.Ny);
    for (unsigned order : {1U,2U,4U}) for (bool xDerivative : {true,false}) {
        require(static_cast<bool>(kernel.differentiateHorizontal({field.data(),volume},xDerivative,order,{derivative.data(),volume})),
            "Raw horizontal derivative failed.");
        for (std::size_t z=0;z<geometry.Nz;++z) for (std::size_t y=0;y<geometry.Ny;++y) for (std::size_t x=0;x<geometry.Nx;++x) {
            const auto i=x+geometry.Nx*(y+geometry.Ny*z);
            const double coordinate=2*pi*(xDerivative ? x : y)/(xDerivative ? geometry.Nx : geometry.Ny);
            const double fundamental=xDerivative ? 2*pi/geometry.Lx : 2*pi/geometry.Ly;
            const double nyquist=pi;
            const double wave=xDerivative ? std::real(std::pow(std::complex<double>(0,fundamental),static_cast<int>(order))*std::exp(std::complex<double>(0,coordinate))) : 0;
            const double nyq=xDerivative ? std::real(std::pow(std::complex<double>(0,nyquist*geometry.Nx/geometry.Lx),static_cast<int>(order))*std::exp(std::complex<double>(0,pi*x))) : 0;
            const double yWave=!xDerivative ? .4*std::imag(std::pow(std::complex<double>(0,2*fundamental),static_cast<int>(order))*std::exp(std::complex<double>(0,2*coordinate))) : 0;
            const double expected=wave+nyq+yWave;
            require(std::abs(derivative[i]-expected)<std::pow(xDerivative?pi*geometry.Nx/geometry.Lx:4*pi/geometry.Ly,order)*1e-10,"Raw horizontal derivative disagrees with analytic DFT.");
        }
    }
    require(kernel.persistentBytes()==persistent,"Horizontal primitives changed persistent storage.");
}

template<class Kernel>
void verticalOperators(Kernel& kernel,
    const std::shared_ptr<const WVStratifiedModalRecord>& source) {
    const auto& g=source->geometry();
    const std::array<WVStratifiedModalOperator,11> operations={
        WVStratifiedModalOperator::reconstructF,WVStratifiedModalOperator::projectF,
        WVStratifiedModalOperator::reconstructG,WVStratifiedModalOperator::projectG,
        WVStratifiedModalOperator::reconstructFw,WVStratifiedModalOperator::projectFw,
        WVStratifiedModalOperator::reconstructGw,WVStratifiedModalOperator::projectGw,
        WVStratifiedModalOperator::balancedGToWaveG,WVStratifiedModalOperator::projectWaveDivergence,
        WVStratifiedModalOperator::projectWaveVerticalVelocity};
    const std::array<std::size_t,11> inputRows={g.Nj,g.Nz,g.Nj,g.Nz,g.Nj,g.Nz,g.Nj,g.Nz,g.Nj,g.Nz,g.Nz};
    const std::array<std::size_t,11> outputRows={g.Nz,g.Nj,g.Nz,g.Nj,g.Nz,g.Nj,g.Nz,g.Nj,g.Nj,g.Nj,g.Nj};
    const std::array<const char*,11> inputFamilies={"F-modal","F-grid","G-modal","G-grid","Fw-modal","F-grid","Gw-modal","G-grid","G-modal","F-grid","G-grid"};
    const std::array<const char*,11> outputFamilies={"F-grid","F-modal","G-grid","G-modal","F-grid","Fw-modal","G-grid","Gw-modal","Gw-modal","Gw-modal","Gw-modal"};
    const auto persistent=kernel.persistentBytes();
    for (std::size_t index=0;index<(g.transformClass=="WVTransformBoussinesq"?operations.size():4);++index) {
        const WVShape2D inputShape{inputRows[index],g.Nkl},outputShape{outputRows[index],g.Nkl};
        std::vector<WVComplex64> input(inputShape.elementCount()),expected(outputShape.elementCount()),actual(outputShape.elementCount());
        for (std::size_t i=0;i<input.size();++i) input[i]={std::sin(.07*i+index),std::cos(.11*i-index)};
        WVComplexLayout inputLayout{inputShape.rows,inputShape.columns,1,inputShape.rows,WVComplexRepresentation::interleaved,inputFamilies[index],source->modeSetIdentity()};
        WVComplexLayout outputLayout{outputShape.rows,outputShape.columns,1,outputShape.rows,WVComplexRepresentation::interleaved,outputFamilies[index],source->modeSetIdentity()};
        std::unique_ptr<WVPreparedVerticalOperator> prepared;
        std::unique_ptr<WVVerticalMatrixBackend> backend;
        require(static_cast<bool>(WVCreateScalarMatrixBackend(backend)),"Matrix backend creation failed.");
        require(static_cast<bool>(source->prepareVertical(operations[index],inputLayout,outputLayout,std::move(backend),prepared)),"Boussinesq operator preparation failed.");
        std::unique_ptr<WVVerticalWorkspace> workspace;
        require(static_cast<bool>(prepared->createWorkspace(workspace)),"Boussinesq operator workspace failed.");
        require(static_cast<bool>(prepared->execute(*workspace,{input.data(),nullptr,nullptr,input.size()*sizeof(WVComplex64)},{expected.data(),nullptr,nullptr,expected.size()*sizeof(WVComplex64)})),"Boussinesq reference execution failed.");
        require(static_cast<bool>(kernel.applyVertical(operations[index],{input.data(),inputShape},{actual.data(),outputShape})),"Boussinesq raw operator failed.");
        for (std::size_t i=0;i<actual.size();++i) require(std::abs(actual[i].real-expected[i].real)<1e-12 && std::abs(actual[i].imag-expected[i].imag)<1e-12,"Boussinesq raw operator differs from reference.");
        std::vector<WVComplex64> alias(std::max(input.size(),actual.size()));
        require(kernel.applyVertical(operations[index],{alias.data(),inputShape},{alias.data(),outputShape}).code==WVKernelStatusCode::overlappingArrays,"Raw operator accepted overlapping input/output.");
        for(std::size_t column=0;column<g.Nkl;++column) {
        std::vector<WVComplex64> columnInput(inputRows[index]),columnOutput(outputRows[index]);
        for (std::size_t row=0;row<inputRows[index];++row) columnInput[row]=input[row+inputRows[index]*column];
        require(static_cast<bool>(kernel.applyVerticalColumn(operations[index],column,{columnInput.data(),{inputRows[index],1}},{columnOutput.data(),{outputRows[index],1}})),"Boussinesq raw column operator failed.");
        for (std::size_t row=0;row<outputRows[index];++row) {
            const auto reference=expected[row+outputRows[index]*column];
            require(std::abs(columnOutput[row].real-reference.real)<1e-12 && std::abs(columnOutput[row].imag-reference.imag)<1e-12,"Boussinesq column differs from full operator.");
        }
        }
    }
    require(kernel.persistentBytes()==persistent,"Boussinesq raw operators changed persistent storage.");
}

template<class Kernel>
void check(const std::shared_ptr<const WVStratifiedModalRecord>& record) {
    for(bool split:{false,true}) {
        WVVariableExecutionOptions options;
        if(split) { options.spectralSchedule=WVVariableSpectralSchedule::compactSplitFusedViews; options.streamedNonlinear=true; options.horizontalSchedule=WVRetainedHorizontalSchedule::streamingPrunedTile16; }
        auto kernel=makeKernel<Kernel>(record,options);
        verticalOperators(*kernel,record); horizontalRoundTripAndDerivatives(*kernel,record->geometry());
    }
}
void families() {
    Temporary h; hydrostaticFixture(h.path); check<WVTransformHydrostaticKernel>(read(h.path));
    Temporary qg; fixture(qg.path); check<WVTransformStratifiedQGKernel>(read(qg.path));
    Temporary b; boussinesqFixture(b.path); check<WVTransformBoussinesqKernel>(read(b.path));
}
}
int main() {
    try { families(); std::cout << "raw MATLAB primitive tests passed\n"; return 0; }
    catch(const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
