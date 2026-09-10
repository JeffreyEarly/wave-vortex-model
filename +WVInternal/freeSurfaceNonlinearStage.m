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
% surface pressure and energy. Parcel labels are checked on the stored
% grid with the reported thermodynamic endpoint roundoff allowance. No oversampled
% domain certification or physical pressure recovery is supplied here.
% includeForcing=true accumulates supported registered forcing through the
% existing callback vocabulary. The default remains the unforced evaluator
% for independent numerical studies. A fourth output partitions the returned
% reference-time tendency into a name-to-family-structure dictionary.
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

function [rate,diagnostics,stage,contributions] = evaluateStage(wvt,solver,thermodynamics,derivative,state,options)
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    solver (1,1) struct
    thermodynamics (1,1) struct
    derivative (1,1) struct
    state (1,1) struct = struct()
    options.includeForcing (1,1) logical = false
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
stage = struct(hatted=hatted,physical=physical,thermodynamics=thermal,metric=metric);
zero = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
source = struct(u=zero,v=zero,w=zero,eta=zero);
sourceNames = strings(0,1); sources = cell(0,1); advectionName = "";
if options.includeForcing
    % The advection callback supplies the full mapped nonlinear excess,
    % including exact buoyancy, rather than the rigid-lid velocity product.
    force = struct(u=wvt.f*hatted.v,v=-wvt.f*hatted.u,w=-reshape(wvt.N2,1,1,[]).*hatted.eta,eta=hatted.w);
    for forcing = wvt.spatialFluxForcing
        if isa(forcing,'WVNonlinearAdvection')
            [force.u,force.v,force.w,force.eta] = forcing.addNonhydrostaticSpatialForcing(wvt,force.u,force.v,force.w,force.eta,stage);
            advectionName = string(forcing.name);
        elseif isa(forcing,'WVPrescribedBoussinesqSource')
            [increment.u,increment.v,increment.w,increment.eta] = forcing.addNonhydrostaticSpatialForcing(wvt,zero,zero,zero,zero);
            if forcing.sourceCoordinates=="physical"
                increment.u=physical.gamma.*increment.u;
                increment.v=physical.gamma.*increment.v;
                increment.w=increment.w-metric.betaX.*increment.u-metric.betaY.*increment.v;
            end
            for name=["u","v","w","eta"], source.(name)=source.(name)+increment.(name); end
            sourceNames(end+1,1)=string(forcing.name); sources{end+1,1}=increment; %#ok<AGROW>
        else
            error('WVTransform:UnsupportedNonlinearForcing','The coupled stage does not support %s.',class(forcing));
        end
    end
    if advectionName==""
        error('WVTransform:NonlinearAdvectionRequired','Use the linear source path unless WVNonlinearAdvection is registered.');
    end
    for name=["u","v","w","eta"], force.(name)=force.(name)+source.(name); end
else
    force = WVInternal.freeSurfaceMappedTendency(hatted,zero,thermal.buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
end
[covector,target,rhsDiagnostics] = WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,thermal.buoyancy,thermal.pressureSurface,derivative,solver.boundary,tendency=force,displacementSource=source.eta);
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
diagnostics = struct(solver=report,retainedTarget=target,discardedBoundaryTargetRMS=rhsDiagnostics.discardedBoundaryTargetRMS,minimumLabel=min(thermal.label,[],'all'),maximumLabel=max(thermal.label,[],'all'),maximumLabelRoundoffAdjustment=thermal.maximumLabelRoundoffAdjustment,adjustedLabelCount=thermal.adjustedLabelCount,labelRoundoffTolerance=thermal.labelRoundoffTolerance,kineticEnergy=kineticEnergy,availablePotentialEnergy=availablePotentialEnergy,surfaceEnergy=surfaceEnergy,totalEnergy=kineticEnergy+availablePotentialEnergy+surfaceEnergy,referenceConvention=thermodynamics.referenceConvention);
stage.covector=covector; stage.totalRate=totalRate; stage.linearRate=linearRate;
stage.boundaryTargetFields=rhsDiagnostics.boundaryTargetFields;
stage.pressureFreeTendency=force; stage.prescribedSources=source;
physicalSourceW=source.w+metric.betaX.*source.u+metric.betaY.*source.v;
diagnostics.prescribedWork=sum(weights.*(physical.u.*source.u+physical.v.*source.v+physical.gamma.*physical.w.*physicalSourceW+physical.gamma.*thermal.apeEta.*source.eta),'all');
diagnostics.constraintReactionWork=-solver.boundary.apply(state).'*report.multiplier;
contributions=configureDictionary("string","cell");
if nargout>3 && options.includeForcing
    % A prescribed source has no SSH target. Solve its linear response at
    % the same frozen nonlinear metric, including material endpoint sources.
    sumSource=structfun(@(value)zeros(size(value)),rate,UniformOutput=false);
    emptyState=struct(u=zero,v=zero,w=zero,eta=zero,ssh=zeros(wvt.Nx,wvt.Ny));
    for index=1:numel(sources)
        increment=sources{index};
        [sourceCovector,sourceTarget]=WVInternal.freeSurfaceWeakRHS(wvt,emptyState,metric,zero,zeros(wvt.Nx,wvt.Ny),derivative,solver.boundary,tendency=increment,displacementSource=increment.eta);
        response=solver.solve(sourceCovector,sourceTarget,metric);
        contributions{sourceNames(index)}=response;
        for name=string(fieldnames(rate)).', sumSource.(name)=sumSource.(name)+response.(name); end
    end
    % Attribute the autonomous full equations and their geometric closure
    % to nonlinear advection. Linear phases have already been subtracted.
    autonomous=rate;
    for name=string(fieldnames(rate)).', autonomous.(name)=rate.(name)-sumSource.(name); end
    contributions{advectionName}=autonomous;
end
end
