function r = thermalPolynomialFields(z,count,depth,N20,inverseScale,kh,f,g)
% Evaluate the complete Legendre trial space in the physical WKB coordinate.
% - Topic: Developer utilities
arguments
    z (:,1) double {mustBeReal,mustBeFinite}
    count (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(count,3)}
    depth (1,1) double {mustBePositive}
    N20 (1,1) double {mustBePositive}
    inverseScale (1,1) double {mustBeReal,mustBeFinite}
    kh (1,1) double {mustBeNonnegative}
    f (1,1) double
    g (1,1) double {mustBePositive}
end
if inverseScale==0
    s=1+2*z/depth; sz=2/depth*ones(size(z)); szz=zeros(size(z));
else
    denominator=-expm1(-depth*inverseScale);
    s=1+2*expm1(z*inverseScale)/denominator;
    sz=2*inverseScale*exp(z*inverseScale)/denominator;
    szz=inverseScale*sz;
end
P=zeros(numel(z),count); P1=P; P2=P;
P(:,1)=1; P(:,2)=s; P1(:,2)=1;
for j=2:count-1
    P(:,j+1)=((2*j-1)*s.*P(:,j)-(j-1)*P(:,j-1))/j;
    P1(:,j+1)=((2*j-1)*(P(:,j)+s.*P1(:,j))-(j-1)*P1(:,j-1))/j;
    P2(:,j+1)=((2*j-1)*(2*P1(:,j)+s.*P2(:,j))-(j-1)*P2(:,j-1))/j;
end
Pz=sz.*P1; Pzz=sz.^2.*P2+szz.*P1;
N2=N20*exp(2*inverseScale*z);
eta=-f./N2.*Pz; etaZ=-f./N2.*(Pzz-2*inverseScale*Pz);
ssh=f/g*ones(1,count);
etaInterior=eta-(1+z/depth).*ssh;
r=struct(psi=P,psiZ=Pz,psiZZ=Pzz,eta=eta,etaZ=etaZ,eta_i=etaInterior,buoyancy=-N2.*etaInterior,qgpv=-kh^2*P-f*etaZ,ssh=ssh);
r.buoyancyZ=f*Pzz+(N2.*(1/depth+2*inverseScale*(1+z/depth))).*ssh;
end
