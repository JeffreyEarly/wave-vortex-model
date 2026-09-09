#include "WaveVortexRuntime/WVNoMotionProfileRecovery.hpp"
#include "nlohmann/json.hpp"
#include <fstream>
#include <iostream>
using namespace wavevortex::runtime;
int main(int argc,char**argv) {
 if(argc!=3) return 2;
 std::ifstream input(argv[1]); nlohmann::json f; input>>f;
 auto initial=f.at("rho_nm0").get<std::vector<double>>();
 std::vector<double> result;
 WVNoMotionRecoveryReport r;
 auto status=WVNoMotionProfileRecovery::fitMoments(f.at("z_int").get<std::vector<double>>(),f.at("Lz"),initial,initial.back(),initial.front(),f.at("moments").get<std::vector<double>>(),result,r);
 nlohmann::json out={{"status",bool(status)},{"message",status.message},{"profile",result},{"exitFlag",r.exitFlag},{"reason",r.reason},{"iterations",r.iterations},{"evaluations",r.evaluations},{"acceptedSteps",r.acceptedSteps},{"rejectedSteps",r.rejectedSteps},{"maximumResidual",r.maximumResidual},{"finalCost",r.finalCost},{"gradientNorm",r.gradientNorm},{"damping",r.damping}};
 std::ofstream stream(argv[2]); stream<<out.dump(2)<<'\n';
 return status ? 0:1;
}
