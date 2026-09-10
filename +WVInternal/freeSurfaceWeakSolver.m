function solver = freeSurfaceWeakSolver(wvt)
% Solve the mapped weak mass and retained boundary constraints together.
%
% The stage problem is H*v + K'*lambda = rhs, K*v = target. H is applied
% through reconstruction and its adjoint. Independent reference-geometry
% Fourier blocks precondition projected conjugate gradients in ker(K).
% No global mass matrix, reconstruction basis, or new modes are constructed.
% lambda is a coefficient-space constraint reaction, not physical pressure.
% Positivity checks cover encountered Krylov directions; a zero-RHS result
% alone is not a certificate of uniqueness for a semidefinite stage metric.
%
% This internal context snapshots the retained inventory and reference mass;
% its operators read current transform phase clocks. Rebuild after changing
% modes or reference parameters. solve never changes the prognostic state.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
layout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
reference = WVInternal.freeSurfaceReferenceMass(wvt);
schur = WVInternal.freeSurfaceBoundarySchur(wvt,boundary,reference);
solver = struct(solve=@(rhs,target,metric,varargin)solveStage(wvt,layout,boundary,reference,schur,rhs,target,metric,varargin{:}),layout=layout,boundary=boundary,referenceMass=reference);
end

function [state,report] = solveStage(wvt,layout,boundary,reference,schur,rhs,target,metric,options)
    arguments (Input)
        wvt (1,1) WVTransformFreeSurfaceBoussinesq
        layout (1,1) struct
        boundary (1,1) struct
        reference (1,1) struct
        schur (1,1) struct
        rhs (1,1) struct
        target (:,1) double {mustBeReal,mustBeFinite}
        metric (1,1) struct
        options.tolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-10
        options.maxIterations (1,1) double {mustBeInteger,mustBePositive} = 200
    end
    if numel(target)~=boundary.dimension
        error('WV:WeakSolverTarget','Supply a target with %d retained real traces.',boundary.dimension);
    end
    r = layout.pack(rhs);
    applyH = @(vector)layout.pack(WVInternal.freeSurfaceWeakMassAction(wvt,layout.unpack(vector),metric));
    % The reference-mass minimum-norm lift exactly satisfies K*x=target.
    x = applyB(applyKT(schur.solve(target)));
    hx = applyH(x);
    scale = max(dualNorm(r),dualNorm(hx));
    d = r-hx;
    q = projectCovector(d);
    z = applyB(q);
    rz = positiveNormSquared(q,z);
    p = z;
    iteration = 0;
    while sqrt(rz)>options.tolerance*scale && iteration<options.maxIterations
        hp = applyH(p);
        curvature = real(p.'*hp);
        if ~isfinite(curvature) || curvature<=0 || ~isfinite(rz) || rz<0
            error('WV:WeakSolverNotPositive','The constrained weak mass is not positive definite at this stage.');
        end
        alpha = rz/curvature;
        x = x+alpha*p;
        d = d-alpha*hp;
        q = projectCovector(d);
        z = applyB(q);
        nextRZ = positiveNormSquared(q,z);
        p = z+(nextRZ/rz)*p;
        % Remove accumulated roundoff outside the constraint nullspace.
        p = p-applyB(applyKT(schur.solve(applyK(p))));
        rz = nextRZ;
        iteration = iteration+1;
    end
    x = x+applyB(applyKT(schur.solve(target-applyK(x))));
    d = r-applyH(x);
    multiplier = schur.solve(applyK(applyB(d)));
    residual = d-applyKT(multiplier);
    absoluteResidual = dualNorm(residual);
    if scale==0
        relativeResidual = absoluteResidual;
    else
        relativeResidual = absoluteResidual/scale;
    end
    if ~isfinite(relativeResidual) || relativeResidual>5*options.tolerance
        error('WV:WeakSolverConvergence','Coupled weak solve did not converge in %d iterations (relative stationarity residual %.3g).',iteration,relativeResidual);
    end
    constraintResidual = applyK(x)-target;
    absoluteConstraintResidual = sqrt(positiveNormSquared(constraintResidual,schur.solve(constraintResidual)));
    constraintScale = max(scale,sqrt(positiveNormSquared(target,schur.solve(target))));
    relativeConstraintResidual = absoluteConstraintResidual;
    if constraintScale>0, relativeConstraintResidual=absoluteConstraintResidual/constraintScale; end
    if relativeConstraintResidual>5*options.tolerance
        error('WV:WeakSolverConvergence','Coupled weak solve left a relative constraint residual of %.3g.',relativeConstraintResidual);
    end
    state = layout.unpack(x);
    report = struct(iterations=iteration,relativeResidual=relativeResidual,absoluteResidual=absoluteResidual,constraintResidual=constraintResidual,relativeConstraintResidual=relativeConstraintResidual,multiplier=multiplier);

    function vector = applyB(vector)
        vector = layout.pack(reference.solve(layout.unpack(vector)));
    end

    function vector = applyK(vector)
        vector = boundary.apply(layout.unpack(vector));
    end

    function vector = applyKT(vector)
        vector = layout.pack(boundary.adjoint(vector));
    end

    function vector = projectCovector(vector)
        vector = vector-applyKT(schur.solve(applyK(applyB(vector))));
    end

    function value = dualNorm(vector)
        value = sqrt(positiveNormSquared(vector,applyB(vector)));
    end
end

function value = positiveNormSquared(vector,inverseAction)
value = real(vector.'*inverseAction);
if ~isfinite(value) || value<0
    error('WV:WeakSolverNotPositive','A solver preconditioner produced a nonfinite or negative squared norm.');
end
end
