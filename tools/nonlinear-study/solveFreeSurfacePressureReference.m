function [pressure,diagnostics] = solveFreeSurfacePressureReference(ssh,force,surfacePressure,xi,Lz,derivative)
% Assemble a tiny dense collocation oracle for instantaneous mapped pressure.
%
% Pressure is divided by reference density (m2 s-2). Given the pressure-free
% hatted acceleration F, solve div(M grad pressure)=div(F), with prescribed
% surface pressure and (M grad pressure)_w=F_w at the bottom. M includes the
% pressure response hidden in the mapped vertical acceleration. The interior
% equations use all nonendpoint vertical nodes; boundary divergence defects
% are reported separately and are not constrained by the collocation solve.
%
% This authoring-only oracle is deliberately dense and is restricted to small
% grids. It supplies no modal projection, projected surface-kinematic closure,
% or time evolution. A production implementation must not call this routine.
arguments (Input)
    ssh (:,:) double {mustBeReal,mustBeFinite}
    force (1,1) struct
    surfacePressure (:,:) double {mustBeReal,mustBeFinite}
    xi (:,1) double
    Lz (1,1) double {mustBePositive}
    derivative (1,1) struct
end
arguments (Output)
    pressure (:,:,:) double
    diagnostics (1,1) struct
end
shape = [size(ssh,1),size(ssh,2),numel(xi)];
n = prod(shape);
if n>1500
    error('WV:PressureReferenceSize','The dense diagnostic is limited to 1500 grid samples.');
end
gamma = 1+ssh/Lz;
if any(gamma<=0,'all')
    error('WV:InvalidFreeSurfaceGeometry','The physical column depth must be positive.');
end
fraction = reshape(1+xi/Lz,1,1,[]);
betaX = fraction.*derivative.x(ssh)./gamma;
betaY = fraction.*derivative.y(ssh)./gamma;
rhs = derivative.x(force.u)+derivative.y(force.v)+derivative.xi(force.w);
rhs(:,:,1) = force.w(:,:,1);
rhs(:,:,end) = surfacePressure;
matrix = zeros(n,n);
for column = 1:n
    trial = zeros(shape);
    trial(column) = 1;
    value = equation(trial);
    matrix(:,column) = value(:);
end
% Balance the derivative and Dirichlet rows before the dense solve.
rowScale = max(abs(matrix),[],2);
scaledMatrix = matrix./rowScale;
pressure = reshape(scaledMatrix\(rhs(:)./rowScale),shape);
gradient = metricGradient(pressure);
acceleration.u = force.u-gradient.u;
acceleration.v = force.v-gradient.v;
acceleration.w = force.w-gradient.w;
divergence = derivative.x(acceleration.u)+derivative.y(acceleration.v)+derivative.xi(acceleration.w);
diagnostics = struct(scaledRcond=rcond(scaledMatrix),linearSystemResidual=max(abs(matrix*pressure(:)-rhs(:))),interiorDivergence=max(abs(divergence(:,:,2:end-1)),[],'all'),endpointDivergence=max(abs(divergence(:,:,[1 end])),[],'all'),bottomAcceleration=max(abs(acceleration.w(:,:,1)),[],'all'),surfacePressureResidual=max(abs(pressure(:,:,end)-surfacePressure),[],'all'),acceleration=acceleration);

    function value = equation(trial)
        gradient = metricGradient(trial);
        value = derivative.x(gradient.u)+derivative.y(gradient.v)+derivative.xi(gradient.w);
        value(:,:,1) = gradient.w(:,:,1);
        value(:,:,end) = trial(:,:,end);
    end

    function gradient = metricGradient(trial)
        px = derivative.x(trial);
        py = derivative.y(trial);
        pxi = derivative.xi(trial);
        gradient.u = gamma.*(px-betaX.*pxi);
        gradient.v = gamma.*(py-betaY.*pxi);
        gradient.w = -gamma.*(betaX.*px+betaY.*py)+(1./gamma+gamma.*(betaX.^2+betaY.^2)).*pxi;
    end
end
