function endpointAnomalies = reconstructEndpointAnomalies(self,Ag_q,Ag_0)
% Reconstruct endpoints without forming the full APV field.
endpointAnomalies = complex(zeros(self.activeEndpointCount,length(self.klNonzero)));
if self.activeEndpointCount > 0
    nNonzero = length(self.klNonzero);
    responsePages = pagemtimes(self.apvEndpointResponse(:,:,self.klNonzeroKhUniqueIndex), ...
        reshape(Ag_q,length(self.apvMode),1,nNonzero));
    endpointAnomalies = reshape(responsePages,self.activeEndpointCount,nNonzero) ...
        -(self.f/self.g)*Ag_0./reshape(self.khNonzero.^2,1,[]);
end
end
