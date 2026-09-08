#pragma once
#include "WVForcingTendency.hpp"
#include "WVForcingEngine.hpp"
#include "WaveVortexKernel/WVTransformHydrostaticKernel.hpp"
namespace wavevortex::runtime {
// Reuses the resolved WVForcing services; scientific operators are supplied by
// the immutable Hydrostatic source and prepared once at construction.
class WVHydrostaticForcingEngine final {
public:
    // Indices refer to the already resolved stage/priority order.
    std::size_t forcingCount() const noexcept { return forcing_.size(); }
    const WVForcing* forcingInstance(std::size_t index) const noexcept {
        return index<forcing_.size() ? forcing_[index].get() : nullptr;
    }
    WVKernelStatus evaluateForcingTendencies(const WVState&,
        const WVForcingTendencyOutput*,std::size_t);
    const WVForcingTendencyMetrics& tendencyMetrics() const noexcept { return tendencyMetrics_; }

    static WVKernelStatus validateSchedule(const WVStratifiedModalGeometry&,const WVFrozenForcingSchedule&,WVShape2D,const WVExtensionCatalog&);
    static WVKernelStatus create(std::shared_ptr<const WVStratifiedModalSource>,const WVFrozenForcingSchedule&,std::shared_ptr<const WVExtensionCatalog>,std::unique_ptr<WVFFTEngine>,std::unique_ptr<WVHydrostaticForcingEngine>&);
    WVKernelStatus nonlinearFlux(const WVState&,WVFlux&);
    WVKernelStatus physicalFields(const WVState&,WVRealFieldBundleConstView&);
    WVStateConstraintResult restoreForcingAmplitudes(WVMutableCoefficients&);
    WVKernelStatus createErrorPolicy(double,std::unique_ptr<WVIntegrationErrorPolicy>&) const;
    WVTransformHydrostaticKernel& kernel() noexcept { return *kernel_; }
    const WVTransformHydrostaticKernel& kernel() const noexcept { return *kernel_; }
    const WVForcingPreparation& preparation() const noexcept { return preparation_; }
    const WVForcingEngineMetrics& metrics() const noexcept { return metrics_; }
    const std::string& scheduleIdentifier() const noexcept { return scheduleIdentifier_; }
    std::size_t persistentBytes() const noexcept;
    WVKernelStatus speedMaxima(const WVState&,double& uv,double& w);
private:
    WVHydrostaticForcingEngine()=default;
    WVKernelStatus initialize(const WVFrozenForcingSchedule&);
    WVKernelStatus addNonlinearFlux(const WVState&,WVFlux&);
    WVKernelStatus addProjectedSpatialTendency(const WVState&,WVRealFieldBundleConstView,WVFlux&);
    WVRealFieldBundleView clearedSpatialTendency();
    WVKernelStatus addLaplacianDamping(const WVState&,double,double,WVLaplacianDirection,WVFlux&);
    WVKernelStatus addVerticalDiffusivity(const WVState&,double,bool,WVFlux&);
    WVKernelStatus addAdaptiveDamping(const WVState&,const std::vector<double>&,WVFlux&);
    WVKernelStatus addPseudoTopographicGeneration(const WVState&,const WVPseudoTopographicOperators&,WVFlux&);
    std::unique_ptr<WVTransformHydrostaticKernel> kernel_;
    std::shared_ptr<const WVExtensionCatalog> catalog_;
    std::vector<std::unique_ptr<WVForcing>> forcing_;
    std::vector<double> physical_,spatial_,derivative_;
    std::vector<WVComplex64> temporary_;
    WVForcingPreparation preparation_;
    WVForcingEngineMetrics metrics_;
    std::string scheduleIdentifier_;
    bool physicalValid_=false,executing_=false;
    detail::WVForcingDiagnosticWorkspace* diagnosticWorkspace_=nullptr;
    WVForcingTendencyMetrics tendencyMetrics_;
    friend class WVForcingExecutionContext;
};
}
