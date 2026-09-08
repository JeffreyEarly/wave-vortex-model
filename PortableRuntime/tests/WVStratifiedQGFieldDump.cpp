#include "WaveVortexRuntime/WVCheckpointReader.hpp"
#include "WaveVortexRuntime/WVStratifiedModalRecord.hpp"
#include "WaveVortexRuntime/WVFieldEvaluationService.hpp"
#include "WaveVortexRuntime/WVExtensionCatalog.hpp"
#include "WVReferenceFFTEngine.hpp"
#include "nlohmann/json.hpp"
#include "../../tools/compiled-kernel/tests/WVAllocationProbe.hpp"
#if WV_TEST_NATIVE_FFTW
#include "WVNativeFFTWEngine.hpp"
#endif
#include <fstream>
#include <iostream>
using namespace wavevortex;
using namespace wavevortex::runtime;
using nlohmann::json;
namespace {template<class T> void require(T status) {if(!status) throw std::runtime_error(status.message);}}
int main(int argc,char** argv) {
  try {
    if(argc!=5) throw std::runtime_error("Usage: WVStratifiedQGFieldDump model.nc positions.json output.json reference|native");
    WVExtensionCatalogBuilder builder;require(addBuiltInExtensions(builder));std::shared_ptr<const WVExtensionCatalog> catalog;require(builder.freeze(catalog));
    WVCheckpoint checkpoint;require(WVCheckpointReader::read(argv[1],*catalog,checkpoint));
    std::ifstream requestFile(argv[2]);json request;requestFile>>request;
    auto x=request.at("x").get<std::vector<double>>(),y=request.at("y").get<std::vector<double>>(),z=request.at("z").get<std::vector<double>>();
    const auto names=request.at("fields").get<std::vector<std::string>>();
    std::unique_ptr<WVFFTEngine> fft;
    if(std::string(argv[4])=="reference") fft=std::make_unique<WVReferenceFFTEngine>();
    else {
#if WV_TEST_NATIVE_FFTW
      require(WVFFTWEngine::create(1,fft));
#else
      throw std::runtime_error("Native provider not built.");
#endif
    }
    std::unique_ptr<WVFieldEvaluationService> fields;require(WVFieldEvaluationService::create(checkpoint.stratifiedModalSource,std::move(fft),fields));
    WVIntegrationStateLayout layout;require(WVIntegrationStateLayout::createCoefficientOnly(checkpoint.stateDescription,layout));
    std::vector<WVCoefficientFamilyConstView> families;
    for (std::size_t i=0;i<layout.coefficientFamilyCount();++i) families.push_back({&layout.coefficientFamilies()[i],checkpoint.transformState.coefficientFamilies[i].values.data()});
    WVIntegrationState state;state.coefficientFamilies=families.data();state.coefficientFamilyCount=families.size();state.waveVortex.t=checkpoint.state.t;state.waveVortex.t0=checkpoint.state.t0;
    json result;
    for(auto interpolation:{WVPositionInterpolation::linear,WVPositionInterpolation::spline}) {
      const std::string method=interpolation==WVPositionInterpolation::linear?"linear":"spline";
      std::vector<WVFieldRequest> requests;
      std::vector<WVMovingFieldRequest> movingRequests;
      std::vector<WVEventFieldRequest> eventRequests;
      for(const auto& name:names) {
        WVFieldSamplingRequest sampling;sampling.kind=WVFieldSamplingKind::positions;sampling.interpolation=interpolation;sampling.x=x;sampling.y=y;sampling.z=z;
        requests.push_back({name,name,sampling});
        movingRequests.push_back({name,name,0,x.size(),interpolation});
        eventRequests.push_back({name,name,0,interpolation});
      }
      WVFieldEvaluationPlan plan;require(fields->createPlan(requests,plan));
      std::vector<std::vector<double>> storage(names.size(),std::vector<double>(x.size()));std::vector<WVFieldOutputView> output;
      for(auto& values:storage) output.push_back({values.data(),values.size()});
      require(fields->evaluate(plan,state,output.data(),output.size()));
      for(std::size_t i=0;i<names.size();++i) result[method]["fixed"][names[i]]=storage[i];
      WVMovingFieldEvaluationPlan moving;require(fields->createMovingPlan(movingRequests,moving));
      allocationProbe::calls=0;allocationProbe::counting=true;
      auto status=fields->evaluateMoving(moving,state,{x.data(),y.data(),z.data(),x.size()},output.data(),output.size());
      allocationProbe::counting=false;require(status);
      result[method]["allocations"]=allocationProbe::calls.load();
      for(std::size_t i=0;i<names.size();++i) result[method]["moving"][names[i]]=storage[i];
      WVEventFieldEvaluationPlan event;require(fields->createEventPlan(eventRequests,event));
      WVEventPositionSetView positions{x.data(),y.data(),z.data(),x.size(),nullptr,0};WVPreparedFieldGeometry geometry;
      require(fields->prepareEventGeometry(event,&positions,1,geometry));
      WVEventFieldEvaluationBatchEntry occurrence{&event,&geometry,output.data(),output.size()};
      require(fields->evaluateEventBatch(state,&occurrence,1));
      for(std::size_t i=0;i<names.size();++i) result[method]["event"][names[i]]=storage[i];
      WVEventFieldEvaluationPlan otherEvent;require(fields->createEventPlan(eventRequests,otherEvent));
      occurrence.plan=&otherEvent;
      if(fields->evaluateEventBatch(state,&occurrence,1)) throw std::runtime_error("Mismatched event geometry was accepted.");
      auto invalidPositions=positions;invalidPositions.extentCount=1;invalidPositions.extents=nullptr;
      if(fields->prepareEventGeometry(event,&invalidPositions,1,geometry)) throw std::runtime_error("Null event extents were accepted.");
    }
    std::ofstream out(argv[3]);out<<result.dump()<<'\n';
  } catch(const std::exception& e) {allocationProbe::counting=false;std::cerr<<e.what()<<'\n';return 1;}
}
