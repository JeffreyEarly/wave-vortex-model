function [APV,endpointAnomalies] = transformStateBack(self,Ag_q,Ag_0)
% Reconstruct sampled APV and active endpoint anomalies.
%
% - Topic: Transform coefficient state
% - Declaration: [APV,endpointAnomalies] = transformStateBack(self,Ag_q,Ag_0)
% - Parameter Ag_q: APV coefficients with shape `apvModeCount × NklNonzero`
% - Parameter Ag_0: zero-APV coefficients with shape `Ne × NklNonzero`
% - Returns APV: sampled APV pages
% - Returns endpointAnomalies: active endpoint-anomaly pages
arguments
    self (1,1) WVTransformFreeSurfaceQG
    Ag_q double
    Ag_0 double
end

WVTransformFreeSurfaceQG.validateCoefficient(Ag_q,[length(self.apvMode),length(self.klNonzero)],false,'Ag_q');
WVTransformFreeSurfaceQG.validateCoefficient(Ag_0,[self.activeEndpointCount,length(self.klNonzero)],false,'Ag_0');
APV = self.apvF*Ag_q;
endpointAnomalies = complex(zeros(self.activeEndpointCount,length(self.klNonzero)));
if self.activeEndpointCount > 0
    nNonzero = length(self.klNonzero);
    responsePages = pagemtimes(self.apvEndpointResponse(:,:,self.klNonzeroKhUniqueIndex), ...
        reshape(Ag_q,length(self.apvMode),1,nNonzero));
    endpointAnomalies = reshape(responsePages,self.activeEndpointCount,nNonzero) ...
        -(self.f/self.g)*Ag_0./reshape(self.khNonzero.^2,1,[]);
end
end
