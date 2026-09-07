#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVForcingEngine.hpp"
#include "WaveVortexRuntime/WVStratifiedQGForcingEngine.hpp"
#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexRuntime/WVBarotropicQGForcingEngine.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "nlohmann/json.hpp"
#include "../../tools/compiled-kernel/tests/WVAllocationProbe.hpp"
#if WV_TEST_NATIVE_FFTW
#include "WVNativeFFTWEngine.hpp"
#endif
#include <fstream>
#include <iostream>
#include <stdexcept>
using namespace wavevortex;
using namespace wavevortex::runtime;
using nlohmann::json;
namespace {
template<class T> void require(T status) { if (!status) throw std::runtime_error(status.message); }
json values(const std::vector<WVComplex64>& a) {
  std::vector<double> real,imag;
  for (const auto x:a) { real.push_back(x.real); imag.push_back(x.imag); }
  return {{"real",real},{"imag",imag}};
}
}
int main(int argc,char** argv) {
  try {
    if (argc != 4) throw std::runtime_error("Usage: WVStableForcingDump model.nc output.json reference|native");
    WVExtensionCatalogBuilder builder; require(addBuiltInExtensions(builder));
    std::shared_ptr<const WVExtensionCatalog> catalog; require(builder.freeze(catalog));
    WVCheckpoint checkpoint; require(WVCheckpointReader::read(argv[1],*catalog,checkpoint));
    std::unique_ptr<WVFFTEngine> fft;
    const std::string provider(argv[3]);
    if (provider == "reference") fft=std::make_unique<WVReferenceFFTEngine>();
    else if (provider == "native") {
#if WV_TEST_NATIVE_FFTW
      require(WVFFTWEngine::create(1,fft));
#else
      throw std::runtime_error("Native adapter unavailable.");
#endif
    } else throw std::runtime_error("Unknown provider.");
    json result;
    if (checkpoint.transformKind == WVPersistedTransformKind::barotropicQG) {
      std::unique_ptr<WVBarotropicQGForcingEngine> engine;
      require(WVBarotropicQGForcingEngine::create(checkpoint.barotropicQGConfiguration,checkpoint.forcingSchedule,catalog,std::move(fft),engine));
      auto& a=checkpoint.transformState.coefficientFamilies.at(0).values;
      std::vector<WVComplex64> f(a.size());
      WVComplexConstView input{a.data(),engine->kernel().descriptor().spectralShape()};
      WVComplexView output{f.data(),input.shape};
      require(engine->evaluateRightHandSide(input,output));
      allocationProbe::calls=0; allocationProbe::counting=true;
      const auto status=engine->evaluateRightHandSide(input,output);
      allocationProbe::counting=false; require(status);
      result["F0"]=values(f);
    } else if (checkpoint.transformKind==WVPersistedTransformKind::stratifiedQG) {
      std::unique_ptr<WVStratifiedQGForcingEngine> engine;
      require(WVStratifiedQGForcingEngine::create(checkpoint.stratifiedModalSource,checkpoint.forcingSchedule,catalog,std::move(fft),engine));
      auto& a=checkpoint.transformState.coefficientFamilies.at(0).values;
      std::vector<WVComplex64> f(a.size());
      WVComplexConstView input{a.data(),engine->kernel().spectralShape()}; WVComplexView output{f.data(),input.shape};
      require(engine->evaluateRightHandSide(input,output));
      allocationProbe::calls=0; allocationProbe::counting=true;
      const auto status=engine->evaluateRightHandSide(input,output);
      allocationProbe::counting=false; require(status);
      result["F0"]=values(f);
    } else {
      std::unique_ptr<WVConstantStratificationForcingEngine> engine;
      require(WVConstantStratificationForcingEngine::create(checkpoint.configuration,checkpoint.forcingSchedule,catalog,std::move(fft),engine));
      const auto shape=checkpoint.state.coefficients.shape;
      std::vector<WVComplex64> fp(shape.elementCount()),fm(fp.size()),f0(fp.size());
      WVFlux flux{{fp.data(),shape},{fm.data(),shape},{f0.data(),shape}};
      require(engine->nonlinearFlux(checkpoint.state.view(),flux));
      allocationProbe::calls=0; allocationProbe::counting=true;
      const auto status=engine->nonlinearFlux(checkpoint.state.view(),flux);
      allocationProbe::counting=false; require(status);
      result["Fp"]=values(fp); result["Fm"]=values(fm); result["F0"]=values(f0);
    }
    result["applicationAllocations"]=allocationProbe::calls.load();
    std::ofstream out(argv[2]); out<<result.dump()<<'\n';
    if (!out) throw std::runtime_error("Output write failed.");
  } catch(const std::exception& e) { std::cerr<<e.what()<<'\n'; return 1; }
}
