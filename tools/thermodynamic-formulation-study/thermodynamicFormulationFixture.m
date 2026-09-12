function a=thermodynamicFormulationFixture(profile,amplitude,Nx,Nz)
% Smooth common physical state with analytic reference-coordinate derivatives.
arguments
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    amplitude (1,1) double {mustBePositive}
    Nx (1,1) double
    Nz (1,1) double
end
D=1000; Lx=1e5; k=2*pi/Lx; g=9.81; rho0=1025; f=1e-4;
if profile=="constant", lambda=0; else, lambda=1/650; end
xi=reshape(-D*(1+cos(pi*(0:Nz-1)/(Nz-1)))/2,1,1,[]);
s=1+xi/D; theta=2*pi*((0:Nx-1)'+.137)/Nx;
S=5; U=.02; V=.01; R=3; margin=20;
zeta=amplitude*S*cos(theta); zx=-amplitude*S*k*sin(theta); zxx=-k^2*zeta;
gamma=1+zeta/D;
F=1+.3*cos(pi*s); Fx=-.3*pi*sin(pi*s)/D;
G=D*(s+.3*sin(pi*s)/pi);
uh=amplitude*U*cos(theta).*F; uhx=-amplitude*U*k*sin(theta).*F; uhz=amplitude*U*cos(theta).*Fx;
vh=amplitude*V*sin(2*theta).*sin(pi*s); vhx=2*k*amplitude*V*cos(2*theta).*sin(pi*s); vhz=amplitude*V*sin(2*theta).*pi.*cos(pi*s)/D;
wh=amplitude*U*k*sin(theta).*G; whx=amplitude*U*k^2*cos(theta).*G; whz=amplitude*U*k*sin(theta).*F;
b=wh(:,:,end); bx=whx(:,:,end);
u=uh./gamma; v=vh./gamma;
ux=uhx./gamma-uh.*zx./(D*gamma.^2); uz=uhz./gamma;
vx=vhx./gamma-vh.*zx./(D*gamma.^2); vz=vhz./gamma;
w=wh+s.*u.*zx;
wx=whx+s.*(ux.*zx+u.*zxx); wz=whz+u.*zx/D+s.*uz.*zx;
wi=(wh-s.*b)./gamma;
z=xi+s.*zeta; zt=s.*b; z_x=s.*zx;
r=xi+amplitude*(-margin*(2*s-1)+R*sin(theta).*s.*(1-s));
rx=amplitude*R*k*cos(theta).*s.*(1-s);
rz=1+amplitude*(-2*margin+R*sin(theta).*(1-2*s))/D;
eta=z-r; etax=z_x-rx; etaz=gamma-rz;
q=1e-4*exp(lambda*xi); nr=1e-4*exp(lambda*r); nz=1e-4*exp(lambda*min(z,0)).*(z<0);
I=@(x)primitive(x,lambda); J=@(x)secondPrimitive(x,lambda);
% Signed interval integrals use expm1, independently of production quadrature.
e=integralN2(r,xi,lambda)./q;
h=e+s.*zeta;
d=integralN2(r,min(z,0),lambda)./q;
ex=-nr.*rx./q; ez=1-nr.*rz./q-lambda*e;
hx=ex+s.*zx; hz=ez+zeta/D;
dx=(nz.*z_x-nr.*rx)./q; dz=(nz.*gamma-nr.*rz)./q-lambda*d;
p=rho0*g*zeta.*s+amplitude*rho0*.03*sin(2*theta).*s.*(1-s);
px=rho0*g*zx.*s+amplitude*rho0*.06*k*cos(2*theta).*s.*(1-s);
pz=rho0*g*zeta/D+amplitude*rho0*.03*sin(2*theta).*(1-2*s)/D;
buoyancy=-integralN2(r,min(z,0),lambda);
a=struct(D=D,Lx=Lx,k=k,g=g,rho0=rho0,f=f,lambda=lambda,xi=xi, ...
    s=s,zeta=zeta,zx=zx,b=b,bx=bx,gamma=gamma,z=z,zt=zt, ...
    zxPhysical=z_x,r=r,rx=rx,rz=rz,eta=eta,etax=etax,etaz=etaz,q=q, ...
    nr=nr,nz=nz,e=e,h=h,ex=ex,ez=ez,hx=hx,hz=hz, ...
    dx=dx,dz=dz,u=u,v=v,w=w,wi=wi,ux=ux,uz=uz, ...
    vx=vx,vz=vz,wx=wx,wz=wz,p=p,px=px,pz=pz,buoyancy=buoyancy, ...
    I=I,J=J);
a.d=d;
a.hatted=struct(u=uh,v=vh,w=wh,eta=eta,ssh=zeta,p=p);
a.continuity=uhx+whz;
points=reshape(xi,[],1); weights=(-1).^(0:Nz-1)'; weights([1 end])=weights([1 end])/2;
distance=points-points'; distance(1:Nz+1:end)=1;
Dz=(weights'./weights)./distance; Dz(1:Nz+1:end)=0; Dz(1:Nz+1:end)=-sum(Dz,2);
a.derivative=struct(x=@(value)dxFourier(value,Lx),y=@(value)zeros(size(value)),xi=@(value)reshape(reshape(value,Nx,Nz)*Dz.',size(value)));
end
function value=integralN2(lower,upper,lambda)
if lambda==0, value=1e-4*(upper-lower); else, value=1e-4*exp(lambda*lower).*expm1(lambda*(upper-lower))/lambda; end
end
function value=primitive(x,lambda)
if lambda==0, value=1e-4*x; else, value=1e-4*expm1(lambda*x)/lambda; end
end
function value=secondPrimitive(x,lambda)
if lambda==0, value=.5e-4*x.^2; else, value=1e-4*(expm1(lambda*x)-lambda*x)/lambda^2; end
end
function value=dxFourier(field,Lx)
N=size(field,1); k=(2*pi/Lx)*[0:N/2-1,0,-N/2+1:-1]';
value=ifft(1i*k.*fft(field,[],1),[],1,'symmetric');
end
