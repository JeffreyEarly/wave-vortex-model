function operators = physicalMetricOperators(self)
% Return quadrature reconstruction and positive physical quadratic metrics.
%
% These value arrays depend only on stored, immutable scientific modes. They
% are built lazily, shared by diagnostics and density diffusion, and rebuilt
% after restoration. No forcing or integrator is required. All active-endpoint
% combinations and every MDA mode are represented.
%
% For each nonzero horizontal wavenumber, `pages` contains kinetic, interior
% potential, and surface potential energy matrices. The common APV enstrophy
% matrix is `apvPotentialEnstrophy`. Compact nonzero Fourier coefficients count
% twice in physical variance; quadraticDiagnostics applies the half-integral
% convention, including the separate horizontal-mean contribution.
%
% - Topic: Inspect modes and operators
% - Returns operators: quadrature, reconstruction arrays, and quadratic metrics
% - Developer: true
arguments
    self (1,1) WVTransformFreeSurfaceQG
end
if ~isempty(self.physicalMetricOperators_)
    operators = self.physicalMetricOperators_;
    return
end
count = max(129,2*self.Nz+1);
rule = WVInternal.qgVerticalOperators(self.z,count);
P = rule.phiToQuadrature;
weights = rule.quadratureWeights;
z = rule.zQuadrature;
N2 = P*self.N2;
N2z = P*(self.verticalDerivativeMatrix*self.N2);
if any(N2<=0)
    error('WV:DiagnosticStratification','Spectral reconstruction must preserve positive N2.');
end
F = P*self.apvF;
G = P*self.apvG;
f = self.f;
g = self.g;
D = self.Lz;
a = 1+z/D;
pages = cell(length(self.khUnique),1);
reconstruction = cell(size(pages));
for p = 1:length(pages)
    kh = self.khUnique(p);
    mu = self.apvMu(:,p).';
    ZF = P*self.zeroAPVF(:,:,p);
    ZG = P*self.zeroAPVG(:,:,p);
    phi = [-F./mu,-ZF/kh^2];
    phiSurface = [-self.apvF(end,:)./mu,-self.zeroAPVF(end,:,p)/kh^2];
    eta = (f/g)*[-G./mu,-ZG/kh^2];
    etaZ = [-(f/g)*F./(self.apvEquivalentDepth(:).'.*mu),ZF/f];
    interiorEta = eta-(f/g)*a*phiSurface;
    interiorEtaZ = etaZ-(f/(g*D))*phiSurface;
    buoyancy = -N2.*interiorEta;
    buoyancyZ = -N2z.*interiorEta-N2.*interiorEtaZ;
    endpoint = [self.apvEndpointResponse(:,:,p),-(f/g)*eye(self.activeEndpointCount)/kh^2];
    reconstruction{p} = struct(phi=phi,eta=eta,etaZ=etaZ,buoyancy=buoyancy,buoyancyZ=buoyancyZ, ...
        q=[F,zeros(size(ZF))],endpoint=endpoint,phiSurface=phiSurface);
    kinetic = phi'*(weights*kh^2.*phi);
    interiorPotential = eta'*(weights.*N2.*eta);
    surfacePotential = (f^2/g)*(phiSurface'*phiSurface);
    pages{p} = struct(kineticEnergy=kinetic,interiorPotentialEnergy=interiorPotential,surfacePotentialEnergy=surfacePotential);
end
MG = P*self.mdaG;
% Inactive surface modes have G(0)=0 and finite sampled derivatives.
if isfinite(self.g0)
    MGz = P*((self.mdaF+(self.g0/g)*self.mdaG(end,:))./self.mdaEquivalentDepth(:).');
else
    MGz = P*(self.verticalDerivativeMatrix*self.mdaG);
end
MB = -N2.*MG;
MBz = -N2z.*MG-N2.*MGz;
MQ = -f*MGz;
mdaReconstruction = struct(eta=MG,buoyancy=MB,buoyancyZ=MBz,q=MQ,endpoint=self.mdaG([end 1],:));
mda = struct(reconstruction=mdaReconstruction,interiorPotentialEnergy=MG'*(weights.*N2.*MG), ...
    potentialEnstrophy=MQ'*(weights.*MQ));
operators = struct(pages={pages},reconstruction={reconstruction},apvPotentialEnstrophy=F'*(weights.*F), ...
    mda=mda,z=z,weights=weights,N2=N2,quadratureCount=count);
self.physicalMetricOperators_ = operators;
end
