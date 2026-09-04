function tendency = boundaryBuoyancyFluxTendency(self,options)
% Project prescribed inward buoyancy fluxes onto the canonical families.
%
% Each boundary load has displacement tendency -Q/(w*N2) at its endpoint.
% Projection retains the interior APV response, residual endpoint response,
% and horizontally uniform MDA source. A nonzero load requires an active
% endpoint. These projections are independent of homogeneous diffusion.
%
% - Topic: Transform coefficient state
% - Parameter options.surfaceBuoyancyFlux: inward surface buoyancy flux on the horizontal grid
% - Parameter options.bottomBuoyancyFlux: inward bottom buoyancy flux on the horizontal grid
% - Returns tendency: structure with Ag_q, Ag_0, and Amda tendencies
% - Developer: true
arguments
    self (1,1) WVTransformFreeSurfaceQG
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

self.ensureBoundaryBuoyancyFluxOperators();
nState = self.apvModeCount+self.activeEndpointCount;
nNonzero = length(self.klNonzero);
stateTendency = complex(zeros(nState,nNonzero));
Amda = zeros(size(self.Amda));

if ~isempty(surfaceFlux) && any(surfaceFlux ~= 0,"all")
    spectralFlux = horizontalTransform(self,surfaceFlux);
    stateTendency = stateTendency+self.surfaceBuoyancyFluxOperatorByKh_(:,self.klNonzeroKhUniqueIndex).*spectralFlux(self.klNonzero);
    Amda = Amda+self.surfaceBuoyancyMDAFluxOperator_*real(spectralFlux(meanIndex(self)));
end
if ~isempty(bottomFlux) && any(bottomFlux ~= 0,"all")
    spectralFlux = horizontalTransform(self,bottomFlux);
    stateTendency = stateTendency+self.bottomBuoyancyFluxOperatorByKh_(:,self.klNonzeroKhUniqueIndex).*spectralFlux(self.klNonzero);
    Amda = Amda+self.bottomBuoyancyMDAFluxOperator_*real(spectralFlux(meanIndex(self)));
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
