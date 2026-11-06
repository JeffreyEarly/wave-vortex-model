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
% integral(conj(U)*Su+conj(V)*Sv+conj(W)*Sw+N2*conj(Eta)*Seta)/(2*D).
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
weights = self.verticalQuadratureWeights;
displacement = spectral.eta(:,indices);
weightedN2 = weights.*self.N2;
pvDisplacement = self.apvG'*(weightedN2.*displacement)/self.g ...
    +self.apvF(end,:).'*displacement(end,:)-self.apvF(1,:).'*displacement(1,:);
tendency.Ag_q = (self.apvF'*(weights.*curl)-self.f*pvDisplacement)/self.Lz;
tendency.Ag_0 = complex(zeros(length(self.activeEndpoint),length(indices)));
tendency.Aw_p = complex(zeros(length(self.waveMode),length(indices)));
tendency.Aw_m = tendency.Aw_p;
g0 = self.g0; if isinf(g0), g0=0; end
gd = self.gd; if isinf(gd), gd=0; end
for p = 1:length(self.khUnique)
    columns = find(self.klNonzeroKhUniqueIndex==p);
    if ~isempty(self.activeEndpoint)
        F = self.zeroAPVF(:,:,p);
        G = self.zeroAPVG(:,:,p);
        B = G(end,:)-F(end,:);
        % The continuous boundary-buoyancy Gram reduces to endpoint traces.
        form = -F(end,:).'*B+F(1,:).'*G(1,:) ...
            +(g0/self.g)*(B.'*B)+(gd/self.g)*(G(1,:).'*G(1,:));
        gram = (self.f^2/(self.g*self.khUnique(p)^2))*(form+form.')/2;
        b = displacement(:,columns);
        pair = F'*(weights.*curl(:,columns))-(self.f/self.g)* ...
            (G'*(weightedN2.*b)+g0*B.'*b(end,:)+gd*G(1,:).'*b(1,:));
        tendency.Ag_0(:,columns) = gram\pair;
    end
    count = self.waveModeCountByKh(p);
    if count == 0, continue; end
    modes = 1:count;
    phase = exp(1i*self.waveFrequency(modes,p)*(self.t-self.t0));
    for j = columns.'
        index = indices(j);
        pol = fullBoussinesqWaveReference(self.waveF(:,modes,p),self.waveG(:,modes,p),self.waveEquivalentDepth(modes,p),self.Lz,self.kNonzero(j),self.lNonzero(j),f=self.f,g=self.g,rho0=self.rho0);
        pair = complex(zeros(2*count,1));
        for name = ["u","v","w","eta"]
            metric = weights;
            if name=="eta", metric=metric.*self.N2; end
            pair = pair+reshape(pol.(name),self.Nz,[])'*(metric.*spectral.(name)(:,index));
        end
        pair = reshape(pair,[],2)/(2*self.Lz);
        tendency.Aw_p(modes,j) = pair(:,1)./phase;
        tendency.Aw_m(modes,j) = pair(:,2).*phase;
    end
end
meanIndex = find(self.k==0 & self.l==0,1);
meanVelocity = spectral.u(:,meanIndex)-1i*spectral.v(:,meanIndex);
tendency.Aio = exp(-1i*self.f*(self.t-self.t0))*(self.inertialF'*(weights.*meanVelocity))/(2*self.Lz);
measure = weightedN2;
measure(end) = measure(end)+g0;
measure(1) = measure(1)+gd;
signature = sign(self.mdaModeNumber);
signature(signature==0) = sign(integral(self.N2Function,-self.Lz,0)+g0+gd);
tendency.Amda = real(signature.*(self.mdaG'*(measure.*spectral.eta(:,meanIndex)))/self.g);
end
