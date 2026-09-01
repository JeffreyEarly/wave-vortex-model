function tendency = thermalCoefficientTendency(self,kappaT,options)
% Project weak vertical buoyancy diffusion and endpoint fluxes.
%
% The complete interior displacement and buoyancy are
%
% $$
% \eta_i(z)=\eta(z)-\left(1+\frac{z}{D}\right)\frac{f}{g}\psi(0),
% \qquad \mathfrak b=-N^2\eta_i.
% $$
%
% On unconstrained grid rows the weak update is
%
% $$
% W\mathcal T_{\mathfrak b}
% =-D_z^T W\kappa_TD_z\mathfrak b
% +e_0\mathcal Q_{\mathfrak b,0}
% +e_d\mathcal Q_{\mathfrak b,d}.
% $$
%
% Positive endpoint flux is inward. Inactive endpoint rows are constrained
% to zero and reject nonzero imposed flux. The resulting displacement and
% QGPV tendencies are projected into `Ag_q`, residual `Ag_0`, and `Amda`.
%
% - Topic: Transform coefficient state
% - Declaration: tendency = thermalCoefficientTendency(self,kappaT,options)
% - Parameter kappaT: constant vertical diffusivity in square meters per second
% - Parameter options.surfaceBuoyancyFlux: inward surface buoyancy flux on the horizontal grid
% - Parameter options.bottomBuoyancyFlux: inward bottom buoyancy flux on the horizontal grid
% - Returns tendency: scalar structure with `Ag_q`, `Ag_0`, and `Amda` tendencies
% - Developer: true
arguments
    self (1,1) WVTransformFreeSurfaceQG
    kappaT (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
    options.surfaceBuoyancyFlux double = []
    options.bottomBuoyancyFlux double = []
end

surfaceFlux = validateFlux(options.surfaceBuoyancyFlux,self,"surfaceBuoyancyFlux");
bottomFlux = validateFlux(options.bottomBuoyancyFlux,self,"bottomBuoyancyFlux");
surfaceIsActive = any(self.activeEndpoint == 1);
bottomIsActive = any(self.activeEndpoint == 2);
if ~surfaceIsActive && any(surfaceFlux ~= 0,"all")
    error('WVTransformFreeSurfaceQG:InactiveSurfaceFlux','A nonzero surface buoyancy flux requires an active surface endpoint.');
end
if ~bottomIsActive && any(bottomFlux ~= 0,"all")
    error('WVTransformFreeSurfaceQG:InactiveBottomFlux','A nonzero bottom buoyancy flux requires an active bottom endpoint.');
end

[psiHat,etaHat] = self.reconstructSpectralState();
surfacePsiHat = psiHat(end,:);
surfaceTaper = 1+self.z/self.Lz;
etaInteriorHat = etaHat-(self.f/self.g)*surfaceTaper*surfacePsiHat;
N2 = reshape(self.N2,[],1);
buoyancyHat = -N2.*etaInteriorHat;

Dz = self.verticalDerivativeMatrix;
weights = self.verticalQuadratureWeights;
weakTendency = -Dz.'*(weights.*(kappaT*(Dz*buoyancyHat)));
if surfaceIsActive
    weakTendency(end,:) = weakTendency(end,:)+horizontalTransform(self,surfaceFlux);
end
if bottomIsActive
    weakTendency(1,:) = weakTendency(1,:)+horizontalTransform(self,bottomFlux);
end
buoyancyTendencyHat = weakTendency./weights;
if ~surfaceIsActive
    buoyancyTendencyHat(end,:) = 0;
end
if ~bottomIsActive
    buoyancyTendencyHat(1,:) = 0;
end

etaTendencyHat = -buoyancyTendencyHat./N2;
qTendencyHat = -self.f*(Dz*etaTendencyHat);
endpointRows = self.Nz-(self.activeEndpoint-1)*(self.Nz-1);
endpointTendencyHat = etaTendencyHat(endpointRows,:);
[Ag_q,Ag_0] = self.transformStateForward(qTendencyHat(:,self.klNonzero),endpointTendencyHat(:,self.klNonzero));

meanIndex = find(hypot(self.k,self.l) == 0,1);
if isempty(meanIndex)
    Amda = zeros(size(self.Amda));
else
    Amda = real(self.transformMDAForward(etaTendencyHat(:,meanIndex)));
end
tendency = struct('Ag_q',Ag_q,'Ag_0',Ag_0,'Amda',Amda);
end

function flux = validateFlux(flux,wvt,name)
if isempty(flux)
    flux = zeros(wvt.Nx,wvt.Ny);
end
if ~isa(flux,'double') || ~isreal(flux) || any(~isfinite(flux),"all") || ~isequal(size(flux),[wvt.Nx wvt.Ny])
    error('WVTransformFreeSurfaceQG:InvalidBuoyancyFlux','%s must be a finite real double array with shape Nx x Ny.',name);
end
end

function spectralFlux = horizontalTransform(wvt,flux)
padded = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
padded(:,:,1) = flux;
spectralFlux = wvt.transformFromSpatialDomainWithFourier(padded);
spectralFlux = spectralFlux(1,:);
end
