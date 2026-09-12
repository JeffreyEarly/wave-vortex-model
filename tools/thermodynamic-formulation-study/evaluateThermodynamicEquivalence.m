function result=evaluateThermodynamicEquivalence(a,options)
% Compare independently written density RHSs and the displacement chain rule.
arguments
    a (1,1) struct
    options.numericalDerivatives (1,1) logical = false
    options.forced (1,1) logical = false
end
etax=a.etax; etaz=a.etaz; ex=a.ex; ez=a.ez; hx=a.hx; hz=a.hz; dx=a.dx; dz=a.dz;
if options.numericalDerivatives
    etax=a.derivative.x(a.eta); etaz=a.derivative.xi(a.eta);
    ex=a.derivative.x(a.e); ez=a.derivative.xi(a.e);
    hx=a.derivative.x(a.h); hz=a.derivative.xi(a.h);
    dx=a.derivative.x(a.d); dz=a.derivative.xi(a.d);
end
S=0*a.eta;
if options.forced, S=1e-4*(1+a.s).*cos(a.k*a.z); end
sigma=a.nr.*S;
etaRate=a.w-a.u.*etax-a.wi.*etaz+S;
rRate=a.zt-etaRate;
eRate=a.wi-a.e.*a.wi*a.lambda-a.u.*ex-a.wi.*ez+sigma./a.q;
hRate=a.w-(a.h-a.s.*a.zeta).*a.wi*a.lambda-a.u.*hx-a.wi.*hz+sigma./a.q;
dRate=(a.nz./a.q).*a.w-a.d.*a.wi*a.lambda-a.u.*dx-a.wi.*dz+sigma./a.q;
chainE=-a.nr.*rRate./a.q; chainH=chainE+a.zt; chainD=(a.nz.*a.zt-a.nr.*rRate)./a.q;
rhoRate=-a.rho0/a.g*a.nr.*rRate;
rhoE=a.rho0/a.g*a.q.*eRate;
rhoH=a.rho0/a.g*a.q.*(hRate-a.zt);
rhoD=a.rho0/a.g*(a.q.*dRate-a.nz.*a.zt);
rhoXi=-a.rho0/a.g*a.nr.*a.rz;
physicalRhoRate=rhoRate-a.zt.*rhoXi./a.gamma;
physicalOracle=a.rho0/a.g*(a.nr.*(a.u.*(a.rx-a.zxPhysical.*a.rz./a.gamma)+a.w.*a.rz./a.gamma)+sigma);
% Invert the profile analytically rather than round-tripping through eta.
Ir=a.I(a.xi)-a.q.*a.e;
if a.lambda==0, labelFromE=Ir/1e-4; else, labelFromE=log1p(a.lambda*Ir/1e-4)/a.lambda; end
Ir=a.I(min(a.z,0))-a.q.*a.d;
if a.lambda==0, labelFromD=Ir/1e-4; else, labelFromD=log1p(a.lambda*Ir/1e-4)/a.lambda; end
rho=a.rho0-a.rho0/a.g*a.I(a.r);
rhoFromE=a.rho0-a.rho0/a.g*a.I(a.xi)+a.rho0/a.g*a.q.*a.e;
rhoFromD=a.rho0-a.rho0/a.g*a.I(min(a.z,0))+a.rho0/a.g*a.q.*a.d;
buoyancyH=-a.q.*(a.h-a.s.*a.zeta)-(a.I(min(a.z,0))-a.I(a.xi));
buoyancyD=-a.q.*a.d;
ut=a.f*a.v-(a.px-a.zxPhysical.*a.pz./a.gamma)/a.rho0-a.u.*a.ux-a.wi.*a.uz;
vt=-a.f*a.u-a.u.*a.vx-a.wi.*a.vz;
wt=a.buoyancy-a.pz./(a.rho0*a.gamma)-a.u.*a.wx-a.wi.*a.wz;
% Transform physical acceleration back to the current hatted equations.
hatRate=struct(u=a.gamma.*ut+a.u.*a.b/a.D,v=a.gamma.*vt+a.v.*a.b/a.D,w=wt-a.s.*(ut.*a.zx+a.u.*a.bx),eta=etaRate-S);
R=-a.buoyancy-a.q.*a.eta;
terms=WVInternal.freeSurfaceNonlinearTerms(a.hatted,a.p,reshape(a.xi,[],1),a.D,a.f,a.rho0,reshape(a.q,[],1),R,a.derivative);
productionError=0;
for name=["u","v","w","eta"], productionError=max(productionError,max(abs(terms.total.(name)-hatRate.(name)),[],'all')); end
% The older pressure split requires an explicit change in excess pressure.
pReferenceOld=-a.rho0*a.g*a.xi+a.rho0*a.J(a.xi)-a.g*(a.rho0-a.rho0/a.g*a.I(a.xi)).*a.s.*a.zeta;
pReferenceCurrent=-a.rho0*a.g*a.z+a.rho0*a.J(min(a.z,0));
pOld=a.p+pReferenceCurrent-pReferenceOld;
pressureError=max(abs(pReferenceOld+pOld-(pReferenceCurrent+a.p)),[],'all');
workEta=a.eta.*a.nr.*S; workDensity=a.q.*a.eta.*(sigma./a.q);
result=struct(eRateError=max(abs(eRate-chainE),[],'all'),hRateError=max(abs(hRate-chainH),[],'all'),dRateError=max(abs(dRate-chainD),[],'all'),rhoEError=max(abs(rhoE-rhoRate),[],'all'),rhoHError=max(abs(rhoH-rhoRate),[],'all'),rhoDError=max(abs(rhoD-rhoRate),[],'all'),physicalDensityError=max(abs(physicalRhoRate-physicalOracle),[],'all'),densityReconstructionError=max([abs(rhoFromE-rho),abs(rhoFromD-rho)],[],'all'),labelInverseError=max([abs(labelFromE-a.r),abs(labelFromD-a.r)],[],'all'),buoyancyError=max([abs(buoyancyH-a.buoyancy),abs(buoyancyD-a.buoyancy)],[],'all'),pressureConversionError=pressureError,wrongPressureSplitError=max(abs(pReferenceOld-pReferenceCurrent),[],'all'),workError=max(abs(workEta-workDensity),[],'all'),productionError=productionError,hMinusEta=max(abs(a.h-a.eta),[],'all'),dMinusEta=max(abs(a.d-a.eta),[],'all'));
result.dRateRms=sqrt(mean((dRate-chainD).^2,'all'));
result.hRateRms=sqrt(mean((hRate-chainH).^2,'all'));
end
