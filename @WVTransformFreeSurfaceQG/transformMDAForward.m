function Amda = transformMDAForward(self,etaMean)
% Project horizontal-mean displacement onto the MDA family.
%
% - Topic: Transform coefficient state
% - Declaration: Amda = transformMDAForward(self,etaMean)
% - Parameter etaMean: real displacement sampled on z
% - Returns Amda: real MDA coefficients
arguments
    self (1,1) WVTransformFreeSurfaceQG
    etaMean (:,1) double {mustBeReal,mustBeFinite}
end
if length(etaMean) ~= length(self.z)
    error('WVTransformFreeSurfaceQG:InvalidMDAShape','etaMean must contain one value per z point.');
end
Amda = self.mdaGForward*etaMean;
end
