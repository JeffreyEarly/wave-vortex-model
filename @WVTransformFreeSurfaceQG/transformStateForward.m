function [Ag_q,Ag_0] = transformStateForward(self,APV,endpointAnomalies)
% Recover coefficients from sampled APV and endpoint anomalies.
%
% This sampled inversion uses the APV F inversion matrix. The physical
% QGPV projection functional is used by `projectQuasigeostrophicSpatialTendency`.
%
% - Topic: Transform coefficient state
% - Declaration: [Ag_q,Ag_0] = transformStateForward(self,APV,endpointAnomalies)
% - Parameter APV: sampled APV array with shape `Nz × NklNonzero`
% - Parameter endpointAnomalies: active endpoint anomalies with shape `Ne × NklNonzero`
% - Returns Ag_q: generalized-energy APV coefficients
% - Returns Ag_0: boundary-normalized zero-APV coefficients
arguments
    self (1,1) WVTransformFreeSurfaceQG
    APV double
    endpointAnomalies double
end

if ~isequal(size(APV),[length(self.z),length(self.klNonzero)])
    error('WVTransformFreeSurfaceQG:InvalidAPVShape','APV must have shape Nz x NklNonzero.');
end
expectedEndpointSize = [self.activeEndpointCount,length(self.klNonzero)];
if self.activeEndpointCount == 0
    isExpectedEndpointShape = isempty(endpointAnomalies) && size(endpointAnomalies,1) == 0 && size(endpointAnomalies,2) == expectedEndpointSize(2);
else
    isExpectedEndpointShape = isequal(size(endpointAnomalies),expectedEndpointSize);
end
if ~isExpectedEndpointShape
    error('WVTransformFreeSurfaceQG:InvalidEndpointShape','endpointAnomalies must have shape %s.',mat2str(expectedEndpointSize));
end

Ag_q = self.apvFForward*APV;
Ag_0 = self.zeroAPVCoefficientsFromEndpoints(Ag_q,endpointAnomalies);
end
