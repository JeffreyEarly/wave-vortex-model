function [state,assessment] = projectFields(self,fields)
% Project an admissible instantaneous state into stored reference-time modes.
%
% Invert the moving-mesh map for physical u/v/w using the supplied SSH.
% Recover APV from hatted curl(u,v)-f*d(eta)/dz, then residual endpoint density
% anomalies, and finally waves from w and the remaining displacement.
% Balanced families reuse the provider's signed Galerkin matrices on the
% qualified fixed quadrature. Wave and inertial families use the sampled
% continuous functionals without Gram correction. Every projection retains
% the original resolved modes. This is not a generic source projector.
%
% - Topic: Reconstruct and project fields
% - Declaration: [state,assessment] = projectFields(fields)
% - Parameter fields: real physical u,v,w and total-displacement eta arrays Nx by Ny by Nz and ssh Nx by Ny; eta is total displacement
% - Returns state: reference-time Aw_p,Aw_m,Ag_q,Ag_0,Aio,Amda coefficients without mutation
% - Returns assessment: positive quadratic hatted-field energy residual and reference boundary/continuity diagnostics; continuity uses the Frobenius residual divided by the sum of individual derivative-term norms
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    fields (1,1) struct
end
arguments (Output)
    state (1,1) struct
    assessment (1,1) struct
end
for name = ["u","v","w","eta","ssh"]
    if ~isfield(fields,name) || ~isa(fields.(name),'double') || ~isreal(fields.(name)) || any(~isfinite(fields.(name)),'all')
        error('WVTransformFreeSurfaceBoussinesq:InvalidFields','Supply finite real u,v,w,eta,ssh fields; eta is total displacement.')
    end
    if name=="ssh", shape=[self.Nx self.Ny]; else, shape=[self.Nx self.Ny self.Nz]; end
    if ~isequal(size(fields.(name)),shape)
        error('WVTransformFreeSurfaceBoussinesq:InvalidFields','%s must have shape %s.',name,mat2str(shape))
    end
end
gamma = 1+fields.ssh/self.Lz;
if any(gamma<=0,'all')
    error('WV:InvalidFreeSurfaceGeometry','Physical column depth must be positive.');
end
alpha = reshape(1+self.z/self.Lz,1,1,[]);
fields.w = fields.w-alpha.*(fields.u.*self.diffX(fields.ssh)+fields.v.*self.diffY(fields.ssh));
fields.u = gamma.*fields.u;
fields.v = gamma.*fields.v;
for name = ["u","v","w","eta"], spectral.(name) = self.transformFromSpatialDomainWithFourier(fields.(name)); end
sshVolume = repmat(fields.ssh,1,1,self.Nz);
sshSpectral = self.transformFromSpatialDomainWithFourier(sshVolume);
indices = self.klNonzero;
curl = 1i*self.kNonzero.'.*spectral.v(:,indices)-1i*self.lNonzero.'.*spectral.u(:,indices);
apv = curl-self.f*self.verticalDerivativeMatrix*spectral.eta(:,indices);
state.Ag_q = self.apvFForward*apv;
endpointValues = [spectral.eta(end,indices)-sshSpectral(end,indices);spectral.eta(1,indices)];
state.Ag_0 = complex(zeros(length(self.activeEndpoint),length(indices)));
state.Aw_p = complex(zeros(length(self.waveMode),length(indices)));
state.Aw_m = state.Aw_p;
for p = 1:length(self.khUnique)
    columns = find(self.klNonzeroKhUniqueIndex==p); index = indices(columns);
    endpointResidual = endpointValues(self.activeEndpoint,columns)-self.apvEndpointResponse(:,:,p)*state.Ag_q(:,columns);
    state.Ag_0(:,columns) = -(self.g/self.f)*self.khUnique(p)^2*endpointResidual;
    aq = -state.Ag_q(:,columns)./self.apvMu(:,p);
    a0 = -state.Ag_0(:,columns)/self.khUnique(p)^2;
    etaBalanced = (self.f/self.g)*(self.apvG*aq+self.zeroAPVG(:,:,p)*a0);
    count = self.waveModeCountByKh(p);
    if count == 0, continue; end
    modes = 1:count;
    projectedW = self.waveGForward(modes,:,p)*spectral.w(:,index);
    projectedEta = self.waveGForward(modes,:,p)*(spectral.eta(:,index)-etaBalanced);
    omega = self.waveFrequency(modes,p); h = self.waveEquivalentDepth(modes,p);
    phase = exp(1i*omega*(self.t-self.t0));
    state.Aw_p(modes,columns) = (1i*projectedW-omega.*projectedEta)./(2*self.khUnique(p)*h)./phase;
    state.Aw_m(modes,columns) = (1i*projectedW+omega.*projectedEta)./(2*self.khUnique(p)*h).*phase;
end
meanIndex = find(self.k==0 & self.l==0,1);
state.Aio = .5*exp(-1i*self.f*(self.t-self.t0))*self.inertialFForward*(spectral.u(:,meanIndex)-1i*spectral.v(:,meanIndex));
state.Amda = real(self.mdaGForward*spectral.eta(:,meanIndex));
if nargout < 2, return; end
reconstructed = self.reconstructSpectralState(state=state);
weights = reshape(self.verticalQuadratureWeights,1,1,[]);
N2 = reshape(self.N2,1,1,[]);
inputEnergy = 0; residualEnergy = 0;
for name = ["u","v","w","eta"]
    projected = self.transformToSpatialDomainWithFourier(reconstructed.(name));
    if name=="eta", metric=weights.*N2; else, metric=weights; end
    inputEnergy = inputEnergy+sum(metric.*fields.(name).^2,'all')/(2*self.Nx*self.Ny);
    residualEnergy = residualEnergy+sum(metric.*(projected-fields.(name)).^2,'all')/(2*self.Nx*self.Ny);
end
projectedSSH = self.transformToSpatialDomainWithFourier(reconstructed.ssh);
inputEnergy = inputEnergy+.5*self.g*mean(fields.ssh.^2,'all');
residualEnergy = residualEnergy+.5*self.g*mean((projectedSSH(:,:,end)-fields.ssh).^2,'all');
divergence = 1i*self.k.'.*spectral.u+1i*self.l.'.*spectral.v;
continuity = divergence+self.verticalDerivativeMatrix*spectral.w;
assessment = struct(relativeFieldEnergyError=sqrt(residualEnergy/max(inputEnergy,realmin)),inputEnergy=inputEnergy,residualEnergy=residualEnergy,continuityResidual=norm(continuity,'fro')/max(norm(1i*self.k.'.*spectral.u,'fro')+norm(1i*self.l.'.*spectral.v,'fro')+norm(self.verticalDerivativeMatrix*spectral.w,'fro'),realmin),meanSSH=mean(fields.ssh,'all'),bottomVerticalVelocity=max(abs(fields.w(:,:,1)),[],'all'),waveGramError=max(self.waveGramError),apvGramError=self.apvGramError,mdaGramError=self.mdaGramError,inertialGramError=self.inertialGramError);
end
