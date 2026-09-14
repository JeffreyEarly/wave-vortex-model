function [s,assessment] = buildThermalState(domainSize,gridSize,o)
% Construct complete thermal maps and an independent resolved MDA family.
% - Topic: Developer utilities
D=domainSize(3); n=o.thermalModeCount; nz=gridSize(3); m=o.mdaModeCount;
if nz<max(n,m)
    error('WV:ThermalSampling','Use Nz >= max(thermalModeCount,mdaModeCount); sampling does not truncate the requested state.');
end
probe=linspace(-D,0,129)'; N2=o.N2Function(probe);
if numel(N2)~=numel(probe) || any(~isfinite(N2)) || any(N2<=0)
    error('WV:ThermalStratification','N2Function must return finite positive values at every depth.');
end
N20=N2(end); a=log(N2(end)/N2(1))/(2*D);
if abs(a*D)<1e-12, a=0; end
if max(abs(N2(:)./(N20*exp(2*a*probe))-1))>1e-10
    error('WV:ThermalStratification','Only constant or exponential fixed stratification is supported.');
end
f=2*7.2921e-5*sind(o.latitude);
if abs(f)<1e-12, error('WV:ThermalRotation','A nonzero f-plane Coriolis frequency is required.'); end
[sn,wn]=chebpts(nz); sn=sn(:); wn=wn(:);
if a==0
    z=D*(sn-1)/2; jacobian=2/D*ones(nz,1);
else
    denominator=-expm1(-D*a); z=log1p((sn-1)*denominator/2)/a;
    z([1 end])=[-D;0]; jacobian=2*a*exp(a*z)/denominator;
end
weights=wn./jacobian; weights=weights*(D/sum(weights));
horizontal=WVGeometryDoublyPeriodic(domainSize(1:2),gridSize(1:2),Nz=nz,shouldAntialias=o.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
kh=hypot(horizontal.k,horizontal.l); indices=find(kh>0);
[radii,~,pages]=uniquetol(kh(indices),1e-12,'DataScale',max(kh));
pages=pages(:); radii=radii(:); nr=numel(radii);
if nr==0, error('WV:ThermalHorizontalGrid','The grid must retain at least one nonzero Fourier mode.'); end
s=struct(domainAxis=(1:3)',domainSize=domainSize(:),gridSize=gridSize(:),z=z,latitude=o.latitude,g=o.g,rho0=1025,N20=N20,inverseScale=a,kappa_z=o.kappa_z,shouldAntialias=o.shouldAntialias,schemaVersion=1);
s.thermalDirection=(1:n)'; s.polynomialDegree=(0:n-1)'; s.mdaMode=(1:m)'; s.activeEndpoint=[1;2];
s.klNonzero=indices(:); s.khUnique=radii; s.klNonzeroKhUniqueIndex=pages;
s.verticalQuadratureWeights=weights;
s.thermalToPolynomial=complex(zeros(n,n,nr)); s.polynomialToThermal=s.thermalToPolynomial; s.sourceDual=s.thermalToPolynomial;
s.thermalRatesPerDiffusivity=complex(zeros(n,nr)); s.conjugateDirection=zeros(n,nr); s.sourceEndpoint=complex(zeros(n,2,nr)); s.thermalEnergyGram=s.thermalToPolynomial;
s.assemblyQuadratureCount=o.assemblyQuadratureCount;
s.gramTolerance=o.gramTolerance; s.modeConvergenceTolerance=o.modeConvergenceTolerance; s.boundaryResolutionTolerance=o.boundaryResolutionTolerance;
reports=cell(nr,1);
native=WVInternal.thermalPolynomialFields(z,n,D,N20,a,0,f,o.g);
N2Native=N20*exp(2*a*z);
for p=1:nr
    page=WVInternal.buildThermalPage(n,D,N20,a,radii(p),f,o.g,o.assemblyQuadratureCount);
    s.thermalToPolynomial(:,:,p)=page.thermalToPolynomial;
    s.polynomialToThermal(:,:,p)=page.polynomialToThermal;
    s.sourceDual(:,:,p)=page.sourceDual;
    s.sourceEndpoint(:,:,p)=page.sourceEndpoint;
    s.thermalEnergyGram(:,:,p)=page.energyGram;
    s.thermalRatesPerDiffusivity(:,p)=page.rates;
    s.conjugateDirection(:,p)=page.conjugateDirection;
    nativeField=[sqrt(weights)*radii(p).*native.psi;sqrt(weights.*N2Native).*native.eta;sqrt(o.g)*native.ssh];
    sampled=(nativeField*page.thermalToPolynomial)/sqrt(D);
    factor=chol(page.energyGram);
    gramError=norm(factor'\(sampled'*sampled-page.energyGram)/factor,2);
    endpointError=page.diagnostics.endpointSourceResidual;
    if gramError>o.gramTolerance || endpointError>o.boundaryResolutionTolerance
        error('WV:ThermalConstructionAccuracy','Radius %.6g failed native Gram %.3g or endpoint source %.3g. Increase sampling/thermal bandwidth explicitly.',radii(p),gramError,endpointError);
    end
    page.diagnostics.nativeGramError=gramError;
    reports{p}=page.diagnostics;
end
% Mean coordinates are independently normalized provider modes, not APV modes.
N2Function=@(z)N20*exp(2*a*z);
if a==0, integralN2=N20*D; else, integralN2=N20*(-expm1(-2*a*D))/(2*a); end
s.mdaSurfaceWeight=-integralN2; s.mdaBottomWeight=integralN2;
problem=IMInternalModes.meanDensityAnomalyModes(N2=N2Function,zDomain=[-D 0],g=o.g,g0=s.mdaSurfaceWeight,gd=s.mdaBottomWeight);
nEVP=max(96,3*(m+4));
basis=IMSolverSpectral(nEVP=nEVP).solveEVP(problem,nModes=m);
reference=IMSolverSpectral(nEVP=ceil(1.5*nEVP)).solveEVP(problem,nModes=m);
[mdaConvergence,modeErrors]=WVInternal.compareResolvedModes(basis,reference,N2Function,3*nEVP+1,m);
if any(modeErrors>o.modeConvergenceTolerance)
    error('WV:ThermalMeanConvergence','The requested MDA family has unresolved provider modes; no modes were removed.');
end
transform=basis.discreteTransform(z=z,weights=weights,variables="G",nModes=m,gramTolerance=o.gramTolerance);
s.mdaG=transform.inverseMatrix(variable="G"); s.mdaGForward=transform.forwardMatrix(variable="G");
F=transform.inverseMatrix(variable="F");
s.mdaGZ=(F+(s.mdaSurfaceWeight/o.g)*s.mdaG(end,:))./reshape(transform.h,1,[]);
[za,wa]=legpts(o.assemblyQuadratureCount); za=D*(za-1)/2; wa=wa(:)*D/2;
Ga=basis.G(za); Fa=basis.F(za);
Gza=(Fa+(s.mdaSurfaceWeight/o.g)*s.mdaG(end,:))./reshape(transform.h,1,[]);
N2a=N2Function(za);
meanPage=WVInternal.densityDiffusionMDA(-N2a.*Ga,-N2a.*(Gza+2*a*Ga),wa,1);
s.mdaGeneratorPerDiffusivity=real(meanPage.generator);
s.mdaEnergyGram=(Ga'*(wa.*N2a.*Ga))/D;
assessment=struct(thermal={reports},mda=meanPage.diagnostics,mdaConvergence=mdaConvergence,quadraticProducts="not-qualified-T4",samplingCount=nz,thermalCount=n,mdaCount=m,assemblyCount=o.assemblyQuadratureCount);
end
