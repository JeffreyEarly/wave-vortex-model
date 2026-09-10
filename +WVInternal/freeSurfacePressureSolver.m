function solver = freeSurfacePressureSolver(wvt)
% Build an instantaneous collocation pressure diagnostic; no modal evolution.
%
% solve(ssh,force,piSurface) solves div(M grad(pi))=div(force) at interior
% vertical nodes, (M grad(pi))_w=force.w at the bottom, and pi=piSurface
% at the top. pi is pressure divided by reference density. Boundary rows
% replace the PDE; endpoint divergence is reported but is not constrained.
% This pressure is distinct from a modal constraint multiplier. A projected
% trajectory can have additional projection/constraint reaction forces.
%
% The context snapshots the physical grid, Dxi, and domain lengths. It
% stores row-equilibrated flat Fourier-column LU factors reused at every
% solve. Rebuild after changing that geometry. No modes, EVP, global matrix,
% or reconstruction basis are used; solve never reads or changes wvt state.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    solver (1,1) struct
end
shape = [wvt.Nx,wvt.Ny,wvt.Nz];
geometry = struct(shape=shape,Lz=wvt.Lz,fraction=reshape(1+wvt.z/wvt.Lz,1,1,[]),Dxi=wvt.verticalDerivativeMatrix);
% Reuse the existing full-FFT derivative implementation on an independent
% horizontal geometry, keeping the source transform out of solve closures.
geometry.horizontal = WVGeometryDoublyPeriodic([wvt.Lx,wvt.Ly],shape(1:2));
geometry.kx = reshape(firstDerivativeWavenumbers(wvt.Nx,wvt.Lx),[],1);
geometry.ky = reshape(firstDerivativeWavenumbers(wvt.Ny,wvt.Ly),1,[]);
kh2 = geometry.kx.^2+geometry.ky.^2;
[uniqueKh2,~,pageIndex] = unique(kh2(:));
D2 = geometry.Dxi*geometry.Dxi;
rowMaximum = max(abs(D2),[],2)+max(kh2,[],'all');
rowMaximum(1) = max(abs(geometry.Dxi(1,:)));
rowMaximum(end) = 1;
if any(~isfinite(rowMaximum) | rowMaximum<=0)
    error('WV:PressureSolverGeometry','The stored derivative must define finite nonzero collocation rows.');
end
rowScale = 1./rowMaximum;
pages = cell(numel(uniqueKh2),1);
minimumRcond = inf;
for j = 1:numel(pages)
    block = D2-uniqueKh2(j)*eye(shape(3));
    block(1,:) = geometry.Dxi(1,:);
    block(end,:) = 0;
    block(end,end) = 1;
    block = rowScale.*block;
    reciprocalCondition = rcond(block);
    if ~isfinite(reciprocalCondition) || reciprocalCondition<1e-14
        error('WV:PressureSolverReferenceRank','A flat pressure block is singular or ill conditioned (scaled rcond %.3g).',reciprocalCondition);
    end
    [lower,upper,permutation] = lu(block,'vector');
    pages{j} = struct(lower=lower,upper=upper,permutation=permutation,columns=find(pageIndex==j));
    minimumRcond = min(minimumRcond,reciprocalCondition);
end
rowScale = reshape(rowScale,1,1,[]);
solver = struct(solve=@(ssh,force,piSurface,varargin)solvePressure(geometry,pages,rowScale,ssh,force,piSurface,varargin{:}),shape=shape,referenceBlockCount=numel(pages),minimumReferenceRcond=minimumRcond);
end

function [pressure,diagnostics] = solvePressure(geometry,pages,rowScale,ssh,force,piSurface,options)
arguments (Input)
    geometry (1,1) struct
    pages cell
    rowScale (1,1,:) double
    ssh (:,:) double {mustBeReal,mustBeFinite}
    force (1,1) struct
    piSurface (:,:) double {mustBeReal,mustBeFinite}
    options.tolerance (1,1) double {mustBeFinite,mustBePositive} = 1e-10
    options.maxIterations (1,1) double {mustBeInteger,mustBePositive} = 200
    options.restart (1,1) double {mustBeInteger,mustBePositive} = 30
end
shape = geometry.shape;
if ~isequal(size(ssh),shape(1:2)) || ~isequal(size(piSurface),shape(1:2))
    error('WV:PressureSolverShape','Surface height and pressure must match the snapshotted horizontal grid.');
end
for name = ["u","v","w"]
    if ~isfield(force,name) || ~isa(force.(name),'double') || ~isreal(force.(name)) || ~isequal(size(force.(name)),shape) || any(~isfinite(force.(name)),'all')
        error('WV:PressureSolverForce','Supply finite real u, v, and w force arrays on the snapshotted grid.');
    end
end
gamma = 1+ssh/geometry.Lz;
if any(gamma<=0,'all')
    error('WV:InvalidFreeSurfaceGeometry','The physical column depth must be positive.');
end
betaX = geometry.fraction.*diffX(ssh)./gamma;
betaY = geometry.fraction.*diffY(ssh)./gamma;
rhs = divergence(force);
rhs(:,:,1) = force.w(:,:,1);
rhs(:,:,end) = piSurface;
scaledRhs = rowScale.*rhs;
b = scaledRhs(:);
scale = norm(b);
preconditionedCoordinates = zeros(size(b));
iterations = 0;
flag = 0;
residualHistory = scale;
relativeResidual = double(scale>0);
while relativeResidual>options.tolerance && iterations<options.maxIterations
    count = min([options.restart,options.maxIterations-iterations,numel(b)]);
    [preconditionedCoordinates,flag,~,~,history] = gmres(@rightPreconditionedEquation,b,count,options.tolerance,1,[],[],preconditionedCoordinates);
    iterations = iterations+numel(history)-1;
    residualHistory = [residualHistory;history(2:end)]; %#ok<AGROW>
    relativeResidual = norm(rightPreconditionedEquation(preconditionedCoordinates)-b)/scale;
    if flag~=0 && flag~=1
        break
    end
    if numel(history)<=1
        break
    end
end
pressure = inverseFlat(preconditionedCoordinates);
gradient = metricGradient(pressure);
acceleration = struct(u=force.u-gradient.u,v=force.v-gradient.v,w=force.w-gradient.w);
accelerationDivergence = divergence(acceleration);
residual = equation(pressure)-rhs;
if scale>0
    relativeResidual = norm(reshape(rowScale.*residual,[],1))/scale;
else
    relativeResidual = norm(residual(:));
end
if ~isfinite(relativeResidual) || relativeResidual>5*options.tolerance
    error('WV:PressureSolverConvergence','Instantaneous collocation pressure did not converge in %d iterations (scaled relative residual %.3g, GMRES flag %d).',iterations,relativeResidual,flag);
end
diagnostics = struct(iterations=iterations,gmresFlag=flag,scaledRelativeResidual=relativeResidual,linearSystemResidual=max(abs(residual),[],'all'),residualHistory=residualHistory,interiorDivergence=max(abs(accelerationDivergence(:,:,2:end-1)),[],'all'),endpointDivergence=max(abs(accelerationDivergence(:,:,[1 end])),[],'all'),bottomDivergence=max(abs(accelerationDivergence(:,:,1)),[],'all'),surfaceDivergence=max(abs(accelerationDivergence(:,:,end)),[],'all'),bottomAcceleration=max(abs(acceleration.w(:,:,1)),[],'all'),surfacePressureResidual=max(abs(pressure(:,:,end)-piSurface),[],'all'),metricGradient=gradient,acceleration=acceleration);

    function value = rightPreconditionedEquation(vector)
        value = rowScale.*equation(inverseFlat(vector));
        value = value(:);
    end

    function value = inverseFlat(vector)
        field = reshape(vector,shape);
        transformed = reshape(fft(fft(field,[],1),[],2),[],shape(3)).';
        solved = complex(zeros(size(transformed)));
        for page = 1:numel(pages)
            block = pages{page};
            solved(:,block.columns) = block.upper\(block.lower\transformed(block.permutation,block.columns));
        end
        value = real(ifft(ifft(reshape(solved.',shape),[],1),[],2));
    end

    function value = equation(trial)
        gradientValue = metricGradient(trial);
        value = divergence(gradientValue);
        value(:,:,1) = gradientValue.w(:,:,1);
        value(:,:,end) = trial(:,:,end);
    end

    function value = metricGradient(trial)
        px = diffX(trial);
        py = diffY(trial);
        pxi = diffXi(trial);
        value.u = gamma.*(px-betaX.*pxi);
        value.v = gamma.*(py-betaY.*pxi);
        value.w = -gamma.*(betaX.*px+betaY.*py)+(1./gamma+gamma.*(betaX.^2+betaY.^2)).*pxi;
    end

    function value = divergence(vector)
        value = diffX(vector.u)+diffY(vector.v)+diffXi(vector.w);
    end

    function value = diffX(field)
        value = geometry.horizontal.diffX(field);
    end

    function value = diffY(field)
        value = geometry.horizontal.diffY(field);
    end

    function value = diffXi(field)
        value = reshape(reshape(field,[],shape(3))*geometry.Dxi.',size(field));
    end
end

function k = firstDerivativeWavenumbers(n,L)
k = (2*pi/L)*[0:floor((n-1)/2),-floor(n/2):-1];
if mod(n,2)==0
    k(n/2+1) = 0;
end
end
