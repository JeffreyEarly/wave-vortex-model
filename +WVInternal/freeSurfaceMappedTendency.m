function tendency = freeSurfaceMappedTendency(hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative)
% Evaluate the unforced mapped equations with supplied diagnostic pressure.
%
% This is the full instantaneous RHS from the projection-ready appendix,
% eq:projection-ready-horizontal-momentum-tendency,
% eq:projection-ready-exact-vertical-momentum, and
% eq:projection-ready-potential-density-evolution. Pressure is the complete
% hatted pressure anomaly in Pa, including its nonlinear contribution; any
% prescribed surface pressure load has already been removed. Buoyancy is
% the exact physical acceleration B, not its linear -N2*eta approximation.
%
% The caller supplies a state satisfying hatted continuity and bottom
% impermeability, and is responsible for the pressure closure and its
% boundary conditions. This helper neither solves that closure nor projects
% tendencies onto modes. All derivatives act at fixed reference coordinates.
% No independent surface mass source or physical forcing is included.
%
% - Topic: Developer utilities
% - Declaration: tendency = freeSurfaceMappedTendency(hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative)
% - Parameter hatted: real Nx by Ny by Nz fields u,v,w,eta and Nx by Ny ssh
% - Parameter pressure: full hatted diagnostic pressure on the reference grid, Pa
% - Parameter buoyancy: supplied exact buoyancy on the reference grid, m s-2
% - Parameter xi: increasing bottom-to-surface reference coordinate, m
% - Parameter Lz: positive reference depth, m
% - Parameter f: Coriolis frequency, s-1
% - Parameter rho0: positive reference density, kg m-3
% - Parameter derivative: function handles x,y,xi for reference-grid derivatives
% - Returns tendency: total hatted u,v,w accelerations and eta,ssh rates
% - Developer: true
arguments (Input)
    hatted (1,1) struct
    pressure (:,:,:) double {mustBeReal,mustBeFinite}
    buoyancy (:,:,:) double {mustBeReal,mustBeFinite}
    xi (:,1) double
    Lz (1,1) double {mustBePositive}
    f (1,1) double {mustBeReal,mustBeFinite}
    rho0 (1,1) double {mustBePositive}
    derivative (1,1) struct
end
arguments (Output)
    tendency (1,1) struct
end
sshX = derivative.x(hatted.ssh);
sshY = derivative.y(hatted.ssh);
physical = WVInternal.freeSurfacePhysicalFields(hatted,xi,Lz,sshX,sshY);
gamma = physical.gamma;
depth = reshape(Lz+xi,1,1,[]);
gammaT = hatted.w(:,:,end)/Lz;
logGammaX = sshX./(Lz*gamma);
logGammaY = sshY./(Lz*gamma);
transportW = gamma.*physical.w_i;
pressureXi = derivative.xi(pressure);

% H includes the complete pressure response before it enters vertical advection.
tendency.u = -fluxDivergence(physical.u)+f*hatted.v-(gamma/rho0).*(derivative.x(pressure)-depth.*logGammaX.*pressureXi);
tendency.v = -fluxDivergence(physical.v)-f*hatted.u-(gamma/rho0).*(derivative.y(pressure)-depth.*logGammaY.*pressureXi);
verticalAdvection = (fluxDivergence(physical.w)+gammaT.*physical.w)./gamma+depth.*(tendency.u.*logGammaX+tendency.v.*logGammaY+hatted.u.*derivative.x(gammaT./gamma)+hatted.v.*derivative.y(gammaT./gamma));
tendency.w = -verticalAdvection-pressureXi./(rho0*gamma)+buoyancy;
tendency.eta = physical.w-(fluxDivergence(hatted.eta)+gammaT.*hatted.eta)./gamma;
tendency.ssh = hatted.w(:,:,end);

    function value = fluxDivergence(field)
        value = derivative.x(hatted.u.*field)+derivative.y(hatted.v.*field)+derivative.xi(transportW.*field);
    end
end
