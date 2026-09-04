function tendency = boundaryMomentumTendency(self,tauXHat,tauYHat,endpoint)
% Project an endpoint momentum stress per unit density into thermal modes.
% Inputs are compact Fourier rows in m^2 s^-2. The signed generalized-energy
% Gram solve is performed once, using all modes in this finite state space.
% No endpoint tendency is constrained beyond the transform's configuration.
% - Topic: Evolution internals
% - Developer: true
arguments
    self WVTransformFreeSurfaceQGDiffusion
    tauXHat (1,:) double {mustBeFinite}
    tauYHat (1,:) double {mustBeFinite}
    endpoint (1,1) string {mustBeMember(endpoint,["surface","bottom"])}
end
self.checkSize(tauXHat,[1 length(self.klNonzero)],'tauXHat');
self.checkSize(tauYHat,[1 length(self.klNonzero)],'tauYHat');
if isempty(self.boundaryStressProjection_)
    n=self.Nj; np=length(self.khUnique);
    response=complex(zeros(n,2,np));
    for ip=1:np
        % Work in scaled independent-data coordinates, not the possibly
        % ill-conditioned diffusion eigenvectors. Convert only the result.
        inverse=self.modesFromScaledState(:,:,ip);
        phi=self.phiModes(:,:,ip)*inverse;
        eta=self.etaModes(:,:,ip)*inverse;
        w=self.verticalQuadratureWeights;
        H=phi'*(w*self.khUnique(ip)^2.*phi)+eta'*(w.*self.N2.*eta);
        H=H+(self.f^2/self.g)*(phi(end,:)'*phi(end,:));
        endpoints=zeros(self.activeEndpointCount,n);
        endpoints(:,self.Nz-1:end)=eye(self.activeEndpointCount);
        weights=[self.g0 self.gd]; weights=weights(self.activeEndpoint);
        H=H+endpoints'*(weights(:).*endpoints);
        H=(H+H')/2;
        equilibration=1./sqrt(max(sum(abs(H),2),realmin));
        balanced=equilibration.*H.*equilibration.';
        load=-phi([end 1],:)';
        solution=equilibration.*(balanced\(equilibration.*load));
        residual=norm(H*solution-load,'fro')/max(norm(load,'fro'),realmin);
        if ~all(isfinite(solution),'all') || residual>1e-10
            error('WVTransformFreeSurfaceQGDiffusion:StressProjectionFailure','Boundary-stress Gram residual %.3g at kh %.8g.',residual,self.khUnique(ip));
        end
        % Endpoints have unit scaling, but retain the explicit coordinate map.
        response(:,:,ip)=inverse*solution;
    end
    self.boundaryStressProjection_=response;
end
whichEndpoint=1+double(endpoint=="bottom");
curl=1i*self.kNonzero.'.*tauYHat-1i*self.lNonzero.'.*tauXHat;
response=reshape(self.boundaryStressProjection_(:,whichEndpoint,:),self.Nj,[]);
tendency=struct(Ag_T=response(:,self.klNonzeroKhUniqueIndex).*curl);
end
