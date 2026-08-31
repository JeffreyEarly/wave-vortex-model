function [Ag_q,Ag_0] = transformStateForward(self,APV,endpointAnomalies)
% Project sampled APV first and residual endpoint anomalies second.
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
Ag_0 = complex(zeros(expectedEndpointSize));
for iKl = 1:length(self.klNonzero)
    iKh = self.klNonzeroKhUniqueIndex(iKl);
    if self.activeEndpointCount > 0
        residual = endpointAnomalies(:,iKl)-self.apvEndpointResponse(:,:,iKh)*Ag_q(:,iKl);
        Ag_0(:,iKl) = -(self.g*self.khNonzero(iKl)^2/self.f)*residual;
    end
end
end
