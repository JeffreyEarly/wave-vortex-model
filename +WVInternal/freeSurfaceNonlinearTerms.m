function terms = freeSurfaceNonlinearTerms(hatted,pressure,xi,D,f,rho0,N2,buoyancyRemainder,derivative)
% Evaluate Appendix C terms before applying any modal source projector.
%
% Literal transcription of eq:projection-ready-nonlinear-advection-terms,
% eq:projection-ready-nonlinear-pressure-terms and
% eq:projection-ready-displacement-advection. pressure is supplied in Pa;
% buoyancyRemainder is the directly evaluated integral of N_+^2-N2(xi)
% from z-eta to z, with the caller's endpoint label convention.
% The caller selects pressure/reference approximations and label validity.
% There is no pressure solve, projection, metric solve or constraint repair.
% H includes pressure before entering N_w. Derivatives hold xi fixed.
% H is unforced: the caller separately maps prescribed physical sources
% into hatted accelerations, including their vertical coordinate coupling.
arguments (Input)
    hatted (1,1) struct
    pressure (:,:,:) double {mustBeReal,mustBeFinite}
    xi (:,1) double
    D (1,1) double {mustBePositive}
    f (1,1) double
    rho0 (1,1) double {mustBePositive}
    N2 (:,1) double {mustBePositive}
    buoyancyRemainder (:,:,:) double {mustBeReal,mustBeFinite}
    derivative (1,1) struct
end
alpha = reshape(1+xi/D,1,1,[]);
depth = D*alpha;
gamma = 1+hatted.ssh/D;
if any(gamma<=0,'all')
    error('WV:FreeSurfaceGeometry','The manuscript map requires positive gamma.')
end
sshX = derivative.x(hatted.ssh);
sshY = derivative.y(hatted.ssh);
logGammaX = sshX./(D*gamma);
logGammaY = sshY./(D*gamma);
surfaceW = hatted.w(:,:,end);
transportW = hatted.w-alpha.*surfaceW;
physicalW = hatted.w+depth.*(hatted.u.*logGammaX+hatted.v.*logGammaY);
pressureX = derivative.x(pressure);
pressureY = derivative.y(pressure);
pressureXi = derivative.xi(pressure);

N.u = divergence(hatted.u./gamma);
N.v = divergence(hatted.v./gamma);
P.u = ((hatted.ssh/D).*pressureX-alpha.*sshX.*pressureXi)/rho0;
P.v = ((hatted.ssh/D).*pressureY-alpha.*sshY.*pressureXi)/rho0;
H.u = -N.u+f*hatted.v-pressureX/rho0-P.u;
H.v = -N.v-f*hatted.u-pressureY/rho0-P.v;
N.w = (divergence(physicalW)+(surfaceW/D).*physicalW)./gamma ...
    +depth.*(H.u.*logGammaX+H.v.*logGammaY+hatted.u.*derivative.x(surfaceW./(D*gamma))+hatted.v.*derivative.y(surfaceW./(D*gamma)));
P.w = (-hatted.ssh./(D+hatted.ssh)).*pressureXi/rho0+buoyancyRemainder;
N.eta = divergence(hatted.eta)./gamma+(surfaceW./(D*gamma)).*hatted.eta-alpha.*(hatted.u.*sshX+hatted.v.*sshY)./gamma;
P.eta = zeros(size(N.eta));
linear = struct(u=f*hatted.v-pressureX/rho0,v=-f*hatted.u-pressureY/rho0,w=-reshape(N2,1,1,[]).*hatted.eta-pressureXi/rho0,eta=hatted.w);
source = struct(); total = struct();
for name = ["u","v","w","eta"]
    source.(name) = -N.(name)-P.(name);
    total.(name) = linear.(name)+source.(name);
end
total.ssh = surfaceW;
physical = struct(u=hatted.u./gamma,v=hatted.v./gamma,w=physicalW,z=reshape(xi,1,1,[])+alpha.*hatted.ssh,gamma=gamma);
terms = struct(N=N,P=P,H=H,source=source,linear=linear,total=total,physical=physical,transportW=transportW);

    function value = divergence(field)
        value = derivative.x(hatted.u.*field)+derivative.y(hatted.v.*field)+derivative.xi(transportW.*field);
    end
end
