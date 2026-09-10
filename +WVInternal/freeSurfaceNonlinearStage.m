function context = freeSurfaceNonlinearStage(wvt)
% Compose the internal unforced full-C1 mapped weak stage evaluator.
%
% evaluate(state) returns the nonlinear reference-time coefficient rate,
% diagnostics, and sampled stage fields. Omitting state uses current
% canonical coefficients. The full weak rate v includes the analytical
% linear generator L*a; the returned rate is v-L*a because reconstruction
% already carries exp(+/-i*omega*(t-t0)) and the inertial phase.
%
% This context explicitly selects freeSurfaceThermodynamics' full C1
% constant-surface-N2 reference convention, including matching nonlinear
% surface pressure and energy. Parcel labels are checked strictly on the
% stored sample grid, without clipping or extrapolation. No oversampled
% domain certification, physical pressure recovery, forcing, integrator,
% or public nonlinear activation is supplied by this internal composition.
%
% Base coefficients are reconstructed once per evaluation. Horizontal
% derivatives use the existing diffX/diffY full-grid FFTs so product
% differentiation does not prematurely project into retained modes. diffZ
% applies the stored vertical matrix. The solver reconstructs its Krylov
% variations separately. No global basis matrix is formed.
%
% The transform is never mutated. Modes, counts and reference parameters
% are snapshot dependencies; rebuild after changing them. Phase clocks
% are read on every evaluation by reconstruction and the coupled solver.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    context (1,1) struct
end
solver = WVInternal.freeSurfaceWeakSolver(wvt);
thermodynamics = WVInternal.freeSurfaceThermodynamics(wvt);
derivative = struct(x=@(field)wvt.diffX(field),y=@(field)wvt.diffY(field),xi=@(field)wvt.diffZ(field));
context = struct(evaluate=@(varargin)evaluateStage(wvt,solver,thermodynamics,derivative,varargin{:}),referenceConvention=thermodynamics.referenceConvention);
end

function [rate,diagnostics,stage] = evaluateStage(wvt,solver,thermodynamics,derivative,state)
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    solver (1,1) struct
    thermodynamics (1,1) struct
    derivative (1,1) struct
    state (1,1) struct = struct()
end
if isempty(fieldnames(state)), state=wvt.coefficientState(); end
solver.layout.validate(state);
spectral = wvt.reconstructSpectralState(state=state);
for name = ["u","v","w","eta","ssh"]
    hatted.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
end
hatted.ssh = hatted.ssh(:,:,end);
sshX = derivative.x(hatted.ssh); sshY = derivative.y(hatted.ssh);
physical = WVInternal.freeSurfacePhysicalFields(hatted,wvt.z,wvt.Lz,sshX,sshY);
thermal = thermodynamics.evaluate(physical.z,hatted.eta,hatted.ssh);
alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
metric = struct(gamma=physical.gamma,betaX=alpha.*sshX./physical.gamma,betaY=alpha.*sshY./physical.gamma,displacementWeight=physical.gamma.*thermal.N2AtLabel);
[covector,target,rhsDiagnostics] = WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,thermal.buoyancy,thermal.pressureSurface,derivative,solver.boundary);
[totalRate,report] = solver.solve(covector,target,metric);
linearRate = structfun(@(value)zeros(size(value)),state,UniformOutput=false);
frequency = wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
linearRate.Aw_p = 1i*frequency.*state.Aw_p;
linearRate.Aw_m = -1i*frequency.*state.Aw_m;
linearRate.Aio = 1i*wvt.f*state.Aio;
rate = totalRate;
for name = string(fieldnames(rate)).'
    rate.(name) = rate.(name)-linearRate.(name);
end
weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
kineticEnergy = sum(weights.*physical.gamma.*.5.*(physical.u.^2+physical.v.^2+physical.w.^2),'all');
availablePotentialEnergy = sum(weights.*physical.gamma.*thermal.ape,'all');
surfaceEnergy = mean(thermal.energySurface,'all');
diagnostics = struct(solver=report,retainedTarget=target,discardedBoundaryTargetRMS=rhsDiagnostics.discardedBoundaryTargetRMS,minimumLabel=min(thermal.label,[],'all'),maximumLabel=max(thermal.label,[],'all'),kineticEnergy=kineticEnergy,availablePotentialEnergy=availablePotentialEnergy,surfaceEnergy=surfaceEnergy,totalEnergy=kineticEnergy+availablePotentialEnergy+surfaceEnergy,referenceConvention=thermodynamics.referenceConvention);
stage = struct(hatted=hatted,physical=physical,thermodynamics=thermal,metric=metric,covector=covector,totalRate=totalRate,linearRate=linearRate,boundaryTargetFields=rhsDiagnostics.boundaryTargetFields);
end
