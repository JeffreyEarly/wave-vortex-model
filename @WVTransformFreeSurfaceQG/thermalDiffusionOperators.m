function [nonzeroOperator,mdaOperator] = thermalDiffusionOperators(self,kappaT)
% Return homogeneous diffusion on the complete existing coefficient space.
%
% Each page of nonzeroOperator acts on [Ag_q; Ag_0] at the corresponding
% khUnique. The separate mdaOperator acts on Amda. No modes are removed and
% no endpoint QGPV samples are substituted for modal coefficients. These
% are the same rebuildable operators used by thermalCoefficientTendency;
% prescribed boundary loads are excluded. Returned arrays are value copies,
% not mutable access to the transform's cache.
%
% - Topic: Transform coefficient state
% - Declaration: [nonzeroOperator,mdaOperator] = thermalDiffusionOperators(self,kappaT)
% - Parameter kappaT: constant buoyancy diffusivity in square meters per second
% - Returns nonzeroOperator: nState-by-nState-by-length(khUnique) array in inverse seconds, with nState=apvModeCount+activeEndpointCount
% - Returns mdaOperator: mdaModeCount-by-mdaModeCount array in inverse seconds
% - Developer: true
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    kappaT (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
end
arguments (Output)
    nonzeroOperator (:,:,:) double
    mdaOperator (:,:) double
end
self.ensureThermalCoefficientOperators();
nonzeroOperator=kappaT*self.thermalDiffusionOperatorByKh_;
mdaOperator=kappaT*self.thermalMDADiffusionOperator_;
end
