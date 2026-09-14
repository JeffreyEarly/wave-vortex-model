function [state,residual]=projectState(self,qgpv,endpointAnomalies,options)
% Fit QGPV in physical-depth least squares with exact endpoint constraints.
% This state fit is distinct from the weak physical tendency projector.
% - Topic: Project physical states and sources
% - Parameter qgpv: real Nx-by-Ny-by-Nz QGPV in inverse seconds
% - Parameter endpointAnomalies: real Nx-by-Ny-by-2 displacement in m
% - Parameter options.meanDisplacement: sampled horizontal-mean displacement in m
% - Returns state: Ath and Amda arrays without modifying this transform
% - Returns residual: physical RMS QGPV and separate endpoint fit residuals
arguments
    self (1,1) WVTransformFreeSurfaceThermalQG
    qgpv double {mustBeReal,mustBeFinite}
    endpointAnomalies double {mustBeReal,mustBeFinite}
    options.meanDisplacement (:,1) double {mustBeReal,mustBeFinite} = zeros(self.Nz,1)
end
if ~isequal(size(qgpv),[self.Nx self.Ny self.Nz]) || ~isequal(size(endpointAnomalies),[self.Nx self.Ny 2]) || numel(options.meanDisplacement)~=self.Nz
    error('WV:ThermalFieldShape','Supply the native physical-grid QGPV, both endpoints, and Nz mean samples.');
end
qhat=self.transformFromSpatialDomainWithFourier(qgpv);
bhat=self.endpointGeometry().transformFromSpatialDomainWithFourier(endpointAnomalies);
meanIndex=find(hypot(self.k,self.l)==0,1);
meanState=real(self.mdaGForward*options.meanDisplacement);
expectedMeanQ=-self.f*self.mdaGZ*meanState;
expectedMeanB=self.mdaG([end 1],:)*meanState;
if norm(qhat(:,meanIndex)-expectedMeanQ)>1e-13+1e-10*norm(expectedMeanQ) || norm(bhat(:,meanIndex)-expectedMeanB)>1e-10+1e-10*norm(expectedMeanB)
    error('WV:ThermalMeanState','QGPV/endpoint means must match the supplied resolved mean displacement.');
end
state=struct(Ath=complex(zeros(size(self.Ath))),Amda=meanState);
r=WVInternal.thermalPolynomialFields(self.z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
weights=self.verticalQuadratureWeights/self.Lz;
qFit=complex(zeros(size(qhat))); bFit=complex(zeros(size(bhat)));
qFit(:,meanIndex)=expectedMeanQ; bFit(:,meanIndex)=expectedMeanB;
for p=1:numel(self.khUnique)
    columns=find(self.klNonzeroKhUniqueIndex==p); horizontal=self.klNonzero(columns);
    C=self.thermalToPolynomial(:,:,p);
    A=(r.qgpv-self.khUnique(p)^2*r.psi)*C;
    B=r.eta_i([end 1],:)*C;
    amplitude=WVInternal.thermalConstrainedFit(A,qhat(:,horizontal),B,bhat(:,horizontal),weights);
    if norm(B*amplitude-bhat(:,horizontal),'fro')>1e-8*max(1,norm(bhat(:,horizontal),'fro'))
        error('WV:ThermalEndpointFit','Unable to satisfy the represented endpoint constraints.');
    end
    state.Ath(:,columns)=amplitude;
    qFit(:,horizontal)=A*amplitude; bFit(:,horizontal)=B*amplitude;
end
qError=self.transformToSpatialDomainWithFourier(qFit)-qgpv;
bError=self.endpointGeometry().transformToSpatialDomainWithFourier(bFit)-endpointAnomalies;
residual=struct(qgpvRMS=sqrt(sum(self.verticalQuadratureWeights.*squeeze(mean(qError.^2,[1 2])))/self.Lz),endpointRMS=reshape(sqrt(mean(bError.^2,[1 2])),2,1),meanDisplacementRMS=sqrt(sum(self.verticalQuadratureWeights.*(self.mdaG*meanState-options.meanDisplacement).^2)/self.Lz));
end
