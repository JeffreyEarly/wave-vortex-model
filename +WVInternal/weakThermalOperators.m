function operators = weakThermalOperators(self,kappaT,options)
% Build developmental weak diffusion on the complete canonical modal state.
%
% Both endpoints must be active. No mode is added or removed. Only stored
% modal arrays and spectral grid operations are used, including on restart.
% Existing thermalDiffusionOperators and WVVerticalDiffusivity are unchanged.
%
% - Topic: Thermal forcing
% - Developer: true
arguments
    self WVTransformFreeSurfaceQG
    kappaT (1,1) double {mustBeNonnegative,mustBeFinite}
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = max(129,2*self.Nz+1)
end
if self.activeEndpointCount~=2
    error('WV:WeakThermalEndpoints','The developmental weak thermal path requires both active endpoints.');
end
rule=WVInternal.qgVerticalOperators(self.z,options.quadratureCount);
P=rule.phiToQuadrature; weights=rule.quadratureWeights; z=rule.zQuadrature;
N2=P*self.N2; N2z=P*(self.verticalDerivativeMatrix*self.N2);
if any(N2<=0)
    error('WV:WeakThermalStratification','Spectral reconstruction must preserve positive N2.');
end
F=P*self.apvF; G=P*self.apvG;
f=self.f; g=self.g; D=self.Lz; a=1+z/D;
pages=cell(length(self.khUnique),1); reconstruction=cell(size(pages));
for p=1:length(pages)
    kh=self.khUnique(p); mu=self.apvMu(:,p).';
    ZF=P*self.zeroAPVF(:,:,p); ZG=P*self.zeroAPVG(:,:,p);
    phi=[-F./mu,-ZF/kh^2];
    phiSurface=[-self.apvF(end,:)./mu,-self.zeroAPVF(end,:,p)/kh^2];
    eta=(f/g)*[-G./mu,-ZG/kh^2];
    etaZ=[-(f/g)*F./(self.apvEquivalentDepth(:).'.*mu),ZF/f];
    interiorEta=eta-(f/g)*a*phiSurface;
    interiorEtaZ=etaZ-(f/(g*D))*phiSurface;
    buoyancy=-N2.*interiorEta;
    buoyancyZ=-N2z.*interiorEta-N2.*interiorEtaZ;
    pages{p}=WVInternal.weakThermalPage(phi,eta,etaZ,buoyancyZ,phiSurface,weights,N2,kh,f,g,kappaT);
    endpoint=self.apvEndpointResponse(:,:,p);
    reconstruction{p}=struct(phi=phi,eta=eta,buoyancy=buoyancy,q=[F,zeros(size(ZF))],endpoint=[endpoint,-(f/g)*eye(2)/kh^2],phiSurface=phiSurface);
end
MG=P*self.mdaG;
% G''=-N2*G/(g*h), F'=-N2*G/g, and G'(0)=g0*G(0)/(g*h).
MGz=P*((self.mdaF+(self.g0/g)*self.mdaG(end,:))./self.mdaEquivalentDepth(:).');
MB=-N2.*MG; MBz=-N2z.*MG-N2.*MGz;
mda=WVInternal.weakThermalMDA(MB,MBz,weights,kappaT);
mda.reconstruction=struct(eta=MG,buoyancy=MB,q=-f*MGz,endpoint=self.mdaG([end 1],:));
operators=struct(kappaT=kappaT,pages={pages},mda=mda,reconstruction={reconstruction}, ...
    z=z,weights=weights,N2=N2,quadratureCount=options.quadratureCount);
end
