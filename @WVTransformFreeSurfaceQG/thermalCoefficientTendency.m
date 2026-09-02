function tendency = thermalCoefficientTendency(self,kappaT,options)
% Apply vertical buoyancy diffusion and endpoint fluxes in coefficient space.
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
% The transform composes reconstruction, this weak update, and modal
% projection once for every distinct positive horizontal wavenumber. The
% resulting rebuildable operators act directly on `Ag_q`, `Ag_0`, and
% `Amda`; they are not persisted. Positive endpoint flux is inward.
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
if ~surfaceIsActive && ~isempty(surfaceFlux) && any(surfaceFlux ~= 0,"all")
    error('WVTransformFreeSurfaceQG:InactiveSurfaceFlux','A nonzero surface buoyancy flux requires an active surface endpoint.');
end
if ~bottomIsActive && ~isempty(bottomFlux) && any(bottomFlux ~= 0,"all")
    error('WVTransformFreeSurfaceQG:InactiveBottomFlux','A nonzero bottom buoyancy flux requires an active bottom endpoint.');
end

self.ensureThermalCoefficientOperators();
nState = self.apvModeCount+self.activeEndpointCount;
nNonzero = length(self.klNonzero);
if kappaT == 0
    stateTendency = complex(zeros(nState,nNonzero));
    Amda = zeros(size(self.Amda));
else
    state = [self.Ag_q;self.Ag_0];
    statePages = pagemtimes(self.thermalDiffusionOperatorByKl_,reshape(state,nState,1,nNonzero));
    stateTendency = kappaT*reshape(statePages,nState,nNonzero);
    Amda = kappaT*(self.thermalMDADiffusionOperator_*self.Amda);
end

if ~isempty(surfaceFlux) && any(surfaceFlux ~= 0,"all")
    spectralFlux = horizontalTransform(self,surfaceFlux);
    stateTendency = stateTendency+self.thermalSurfaceFluxOperatorByKh_(:,self.klNonzeroKhUniqueIndex).*spectralFlux(self.klNonzero);
    Amda = Amda+self.thermalSurfaceMDAFluxOperator_*real(spectralFlux(meanIndex(self)));
end
if ~isempty(bottomFlux) && any(bottomFlux ~= 0,"all")
    spectralFlux = horizontalTransform(self,bottomFlux);
    stateTendency = stateTendency+self.thermalBottomFluxOperatorByKh_(:,self.klNonzeroKhUniqueIndex).*spectralFlux(self.klNonzero);
    Amda = Amda+self.thermalBottomMDAFluxOperator_*real(spectralFlux(meanIndex(self)));
end

tendency = struct('Ag_q',stateTendency(1:self.apvModeCount,:),'Ag_0',stateTendency(self.apvModeCount+1:end,:),'Amda',real(Amda));
end

function flux = validateFlux(flux,wvt,name)
if isempty(flux)
    return
end
if ~isa(flux,'double') || ~isreal(flux) || any(~isfinite(flux),"all") || ~isequal(size(flux),[wvt.Nx wvt.Ny])
    error('WVTransformFreeSurfaceQG:InvalidBuoyancyFlux','%s must be a finite real double array with shape Nx x Ny.',name);
end
end

function index = meanIndex(wvt)
index = find(hypot(wvt.k,wvt.l) == 0,1);
end

function spectralFlux = horizontalTransform(wvt,flux)
padded = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
padded(:,:,1) = flux;
spectralFlux = wvt.transformFromSpatialDomainWithFourier(padded);
spectralFlux = spectralFlux(1,:);
end
