function Ag_0 = zeroAPVCoefficientsFromEndpoints(self,Ag_q,endpointAnomalies)
% Recover the zero-APV response after subtracting the interior APV response.
nNonzero = length(self.klNonzero);
Ag_0 = complex(zeros(self.activeEndpointCount,nNonzero));
if self.activeEndpointCount > 0
    responsePages = pagemtimes(self.apvEndpointResponse(:,:,self.klNonzeroKhUniqueIndex), ...
        reshape(Ag_q,length(self.apvMode),1,nNonzero));
    residual = endpointAnomalies-reshape(responsePages,self.activeEndpointCount,nNonzero);
    Ag_0 = -(self.g/self.f)*reshape(self.khNonzero.^2,1,[]).*residual;
end
end
