function etaMean = transformMDABack(self,Amda)
% Reconstruct horizontal-mean displacement from the MDA family.
%
% - Topic: Transform coefficient state
% - Declaration: etaMean = transformMDABack(self,Amda)
% - Parameter Amda: real MDA coefficient vector
% - Returns etaMean: real displacement sampled on z
arguments
    self (1,1) WVTransformFreeSurfaceQG
    Amda (:,1) double {mustBeReal,mustBeFinite}
end
if length(Amda) ~= length(self.mdaMode)
    error('WVTransformFreeSurfaceQG:InvalidMDAShape','Amda must contain one value per MDA mode.');
end
etaMean = self.mdaG*Amda;
end
