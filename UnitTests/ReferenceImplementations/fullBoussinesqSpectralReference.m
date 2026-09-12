function fields = fullBoussinesqSpectralReference(self,options)
% Frozen 1353067a reference for selective-reconstruction qualification.
% Reconstruct current-time physical fields on the compact Fourier grid.
%
% Each nonzero column represents the half-complex amplitude plus its
% conjugate. The horizontal mean is already real, including both signs of
% each inertial oscillation. Pressure includes the MDA hydrostatic gauge.
%
% - Topic: Reconstruct and project fields
% - Declaration: fields = reconstructSpectralState(options)
% - Parameter options.flowComponent: component of this transform; empty selects all
% - Parameter options.state: complete reference-time family structure; default current state
% - Returns fields: u,v,w,eta,p,ssh,qgpv arrays of shape Nz by Nkl; ssh is vertically repeated
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
    options.state (1,1) struct = struct()
end
arguments (Output)
    fields (1,1) struct
end
state = options.state;
if isempty(fieldnames(state))
    state = self.coefficientState(flowComponent=options.flowComponent);
elseif ~isempty(options.flowComponent)
    error('WVTransformFreeSurfaceBoussinesq:AmbiguousState','Supply either explicit state or a component selector.')
else
    for annotation = self.coefficientStateAnnotations()
        if ~isfield(state,annotation.name), error('WVTransformFreeSurfaceBoussinesq:InvalidCoefficient','Supply every canonical coefficient family.'); end
        % Frozen reference fixtures supply validated states.
    end
end
for name = ["u","v","w","eta","p","ssh","qgpv"], fields.(name) = complex(zeros(self.Nz,self.Nkl)); end
for p = 1:length(self.khUnique)
    columns = find(self.klNonzeroKhUniqueIndex==p);
    indices = self.klNonzero(columns);
    aq = -state.Ag_q(:,columns)./self.apvMu(:,p);
    a0 = -state.Ag_0(:,columns)/self.khUnique(p)^2;
    psi = self.apvF*aq+self.zeroAPVF(:,:,p)*a0;
    fields.u(:,indices) = -1i*self.lNonzero(columns).'.*psi;
    fields.v(:,indices) = 1i*self.kNonzero(columns).'.*psi;
    fields.eta(:,indices) = (self.f/self.g)*(self.apvG*aq+self.zeroAPVG(:,:,p)*a0);
    fields.p(:,indices) = self.rho0*self.f*psi;
    fields.qgpv(:,indices) = self.apvF*state.Ag_q(:,columns);
    count = self.waveModeCountByKh(p);
    if count == 0, continue; end
    modes = 1:count;
    phase = exp(1i*self.waveFrequency(modes,p)*(self.t-self.t0));
    for c = 1:length(columns)
        j = columns(c); index = indices(c);
        polarizations = fullBoussinesqWaveReference(self.waveF(:,modes,p),self.waveG(:,modes,p),self.waveEquivalentDepth(modes,p),self.kNonzero(j),self.lNonzero(j),f=self.f,g=self.g,rho0=self.rho0);
        a = [state.Aw_p(modes,j).*phase;state.Aw_m(modes,j).*conj(phase)];
        for name = ["u","v","w","eta","p"]
            fields.(name)(:,index) = fields.(name)(:,index)+reshape(polarizations.(name),self.Nz,[])*a;
        end
    end
end
meanIndex = find(self.k==0 & self.l==0,1);
io = self.inertialF*(state.Aio*exp(1i*self.f*(self.t-self.t0)));
fields.u(:,meanIndex) = 2*real(io); fields.v(:,meanIndex) = 2*real(1i*io);
fields.eta(:,meanIndex) = self.mdaG*state.Amda;
fields.p(:,meanIndex) = self.rho0*self.mdaPressureMode*state.Amda;
fields.qgpv(:,meanIndex) = -self.f*self.verticalDerivativeMatrix*fields.eta(:,meanIndex);
fields.ssh = repmat(fields.p(end,:)/(self.rho0*self.g),self.Nz,1);
end
