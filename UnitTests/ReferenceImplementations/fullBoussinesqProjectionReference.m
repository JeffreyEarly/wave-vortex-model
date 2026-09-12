function tendency = fullBoussinesqProjectionReference(self,sources)
% Project volume acceleration and total-displacement sources into resolved modes.
%
% This is the linear hatted-equation source projector. Inputs are reference
% equation accelerations, not physical acceleration on the moving mesh.
% Nonlinear physical forcing enters coefficientTendency after its coordinate
% map before projection. Sources need not satisfy continuity or ocean-state boundary constraints.
% The input is the manuscript source vector (Su,Sv,Sw,Seta,0): momentum
% acceleration in m/s^2 and total-displacement rate in m/s. No independent
% surface mass flux or boundary sheet source is included. Surface pressure
% loading may be supplied through its horizontal acceleration.
%
% Wave projection uses the continuous generalized-energy dual directly:
% integral(conj(U)*Su+conj(V)*Sv+conj(W)*Sw+N2*conj(Eta)*Seta)/(2*h).
% The wave endpoint density anomalies vanish. This form avoids subtracting
% an incomplete retained balanced expansion in the equivalent G formula.
% APV and zero-APV source pairings preserve the existing signed balanced
% normalization. All oscillating tendencies are returned at reference t0.
%
% - Topic: Project physical sources
% - Declaration: tendency = projectSources(sources)
% - Parameter sources: scalar structure with real finite u,v,w,eta arrays Nx by Ny by Nz
% - Returns tendency: six independently shaped reference-time coefficient tendencies
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    sources (1,1) struct
end
arguments (Output)
    tendency (1,1) struct
end
if ~isequal(sort(string(fieldnames(sources))),sort(["u";"v";"w";"eta"]))
    error('WVTransformFreeSurfaceBoussinesq:InvalidSources','Supply exactly u,v,w,eta volume sources; independent surface mass flux and boundary sheets are not supported.')
end
for name = ["u","v","w","eta"]
    value = sources.(name);
    if ~isa(value,'double') || ~isreal(value) || any(~isfinite(value),'all') || ~isequal(size(value),[self.Nx self.Ny self.Nz])
        error('WVTransformFreeSurfaceBoussinesq:InvalidSources','%s must be a finite real double array of shape Nx by Ny by Nz.',name)
    end
    spectral.(name) = self.transformFromSpatialDomainWithFourier(value);
end
indices = self.klNonzero;
curl = 1i*self.kNonzero.'.*spectral.v(:,indices)-1i*self.lNonzero.'.*spectral.u(:,indices);
tendency.Ag_q = self.apvFSourcePairing*curl-(self.f/self.Lz)*self.apvGSourcePairing*spectral.eta(:,indices);
tendency.Ag_0 = complex(zeros(length(self.activeEndpoint),length(indices)));
tendency.Aw_p = complex(zeros(length(self.waveMode),length(indices)));
tendency.Aw_m = tendency.Aw_p;
weights = self.verticalQuadratureWeights;
for p = 1:length(self.khUnique)
    columns = find(self.klNonzeroKhUniqueIndex==p);
    tendency.Ag_0(:,columns) = self.zeroAPVSourceSolve(:,:,p)*(self.zeroAPVFPairing(:,:,p)*curl(:,columns)-(self.f/self.Lz)*self.zeroAPVGPairing(:,:,p)*spectral.eta(:,indices(columns)));
    count = self.waveModeCountByKh(p);
    if count == 0, continue; end
    modes = 1:count;
    phase = exp(1i*self.waveFrequency(modes,p)*(self.t-self.t0));
    for j = columns.'
        index = indices(j);
        pol = WVInternal.freeSurfaceWavePolarization(self.waveF(:,modes,p),self.waveG(:,modes,p),self.waveEquivalentDepth(modes,p),self.kNonzero(j),self.lNonzero(j),f=self.f,g=self.g,rho0=self.rho0);
        pair = complex(zeros(2*count,1));
        for name = ["u","v","w","eta"]
            metric = weights;
            if name=="eta", metric=metric.*self.N2; end
            pair = pair+reshape(pol.(name),self.Nz,[])'*(metric.*spectral.(name)(:,index));
        end
        pair = reshape(pair,[],2)./(2*self.waveEquivalentDepth(modes,p));
        tendency.Aw_p(modes,j) = pair(:,1)./phase;
        tendency.Aw_m(modes,j) = pair(:,2).*phase;
    end
end
meanIndex = find(self.k==0 & self.l==0,1);
tendency.Aio = .5*exp(-1i*self.f*(self.t-self.t0))*self.inertialFForward*(spectral.u(:,meanIndex)-1i*spectral.v(:,meanIndex));
tendency.Amda = real(self.mdaGForward*spectral.eta(:,meanIndex));
end
