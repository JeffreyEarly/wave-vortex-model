function [fields,omega] = freeSurfaceWavePolarization(F,G,h,D,k,l,options)
% Reconstruct linear free-surface wave polarizations from stored resolved modes.
%
% Columns of F and G are paired modes on an increasing bottom-to-surface
% physical grid. They obey $$F=DG_z$$, $$G(-D)=0$$, and $$DG(0)=hF(0)$$.
% The caller supplies modes in the wave-energy normalization.
%
% Pages are ordered sigma=[+1,-1], with time dependence exp(i*sigma*omega*t).
% A physical real field is A*field*exp(i*(k*x+l*y))+its complex conjugate.
% Eta is total displacement. The interior displacement is eta-(1+z/D)*ssh.
% With $$D^{-1}\int_{-D}^0[F_iF_j+(\kappa D)^2G_iG_j] \, dz=\delta_{ij}$$,
% the physical energy of a real conjugate pair per unit reference density is
% $$2D|A|^2$$.
%
% - Topic: Developer utilities
% - Declaration: [fields,omega] = freeSurfaceWavePolarization(F,G,h,D,k,l,options)
% - Parameter F: real Nz-by-Nmode velocity/pressure mode matrix
% - Parameter G: real Nz-by-Nmode vertical-velocity/displacement mode matrix
% - Parameter h: positive Nmode-by-1 equivalent depths in meters
% - Parameter D: positive column depth in meters
% - Parameter k: zonal wavenumber in radians per meter
% - Parameter l: meridional wavenumber in radians per meter
% - Parameter options.f: nonzero Coriolis parameter in inverse seconds
% - Parameter options.g: gravitational acceleration in meters per second squared
% - Parameter options.rho0: reference density in kilograms per cubic meter
% - Returns fields: u,v,w,eta,p matrices of size Nz-by-Nmode-by-2 and ssh of size 1-by-Nmode-by-2, per unit velocity amplitude
% - Returns omega: positive 1-by-Nmode angular frequencies in inverse seconds
% - Developer: true
arguments (Input)
    F (:,:) double {mustBeReal,mustBeFinite,mustBeNonempty}
    G (:,:) double {mustBeReal,mustBeFinite,mustBeNonempty}
    h (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
    D (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    k (1,1) double {mustBeReal,mustBeFinite}
    l (1,1) double {mustBeReal,mustBeFinite}
    options.f (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
    options.g (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 9.81
    options.rho0 (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1025
    options.variables (1,:) string = ["u","v","w","eta","p","ssh"]
end
arguments (Output)
    fields (1,1) struct
    omega (1,:) double
end
if ~isequal(size(F),size(G)) || size(F,2) ~= length(h)
    error('WV:WaveModeShape','F and G must have one matching column per equivalent depth.')
end
kh = hypot(k,l);
if kh == 0
    error('WV:ZeroWaveWavenumber','Use the separate inertial-oscillation family at zero horizontal wavenumber.')
end
h = h.';
omega = sqrt(options.f^2+options.g*h*kh^2);
sigma = reshape([1 -1],1,1,2);
fields = struct();
selected = any(options.variables.'==["u","v","w","eta","p","ssh"],1);
if selected(1), fields.u = F.*(k*omega-1i*sigma*options.f*l)./(omega*kh); end
if selected(2), fields.v = F.*(l*omega+1i*sigma*options.f*k)./(omega*kh); end
if selected(3), fields.w = repmat(-1i*kh*D.*G,1,1,2); end
if selected(4), fields.eta = -sigma.*(kh*D./omega).*G; end
if any(selected(5:6))
    pressure = -sigma.*(options.rho0*options.g*kh*h./omega).*F;
    if selected(5), fields.p=pressure; end
    if selected(6), fields.ssh=pressure(end,:,:)/(options.rho0*options.g); end
end
end
