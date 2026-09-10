function results = runFreeSurfaceStrongResidualStudy(levels)
% Compare total modal stage rates with instantaneous mapped strong equations.
% This authoring study does not activate nonlinear evolution or identify
% a retained constraint multiplier with collocation pressure.
arguments (Input)
    levels (1,:) double {mustBeInteger,mustBeMember(levels,[1 2 3])} = [1 2 3]
end
configuration = [65 2 3;129 4 6;257 8 12];
helper = freeSurfaceWeakStudyHelpers();
rows = cell(1,numel(levels));
referenceFingerprint = [];
if levels(1)~=1
    referenceTransform = studyTransform(configuration(1,:));
    referenceContext = helper.buildContext(referenceTransform,1);
    referenceFields = helper.sampledState(referenceTransform,mixedSeed(referenceTransform,helper),referenceContext);
    referenceFingerprint = helper.seedCheckpoints(referenceFields,referenceContext);
end
for iLevel = 1:numel(levels)
    level = levels(iLevel);
    Nz = configuration(level,1);
    balancedCount = configuration(level,2);
    waveCount = configuration(level,3);
    fprintf('Strong residual level %d: Nz=%d, balanced=%d, wave=%d\n',level,Nz,balancedCount,waveCount);
    timer = tic;
    wvt = studyTransform(configuration(level,:));
    state = mixedSeed(wvt,helper);
    context = WVInternal.freeSurfaceNonlinearStage(wvt);
    [~,stageReport,stage] = context.evaluate(state);
    derivative = struct(x=@(field)wvt.diffX(field),y=@(field)wvt.diffY(field),xi=@(field)wvt.diffZ(field));
    zero = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
    force = WVInternal.freeSurfaceMappedTendency(stage.hatted,zero,stage.thermodynamics.buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
    pressureSolver = WVInternal.freeSurfacePressureSolver(wvt);
    [pressure,pressureReport] = pressureSolver.solve(stage.hatted.ssh,force,stage.thermodynamics.pressureSurface,tolerance=1e-12,maxIterations=300);
    full = WVInternal.freeSurfaceMappedTendency(stage.hatted,wvt.rho0*pressure,stage.thermodynamics.buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
    spectral = wvt.reconstructSpectralState(state=stage.totalRate);
    for name = ["u","v","w","eta","ssh"]
        modal.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
        if name=="ssh", modal.(name)=modal.(name)(:,:,end); end
        difference.(name) = modal.(name)-full.(name);
    end
    weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
    velocityResidual = velocityNorm(difference,stage.metric,weights);
    velocityModal = velocityNorm(modal,stage.metric,weights);
    velocityStrong = velocityNorm(full,stage.metric,weights);
    velocityForce = velocityNorm(force,stage.metric,weights);
    velocityPressure = velocityNorm(pressureReport.metricGradient,stage.metric,weights);
    velocityTermScale = velocityForce+velocityPressure;
    velocityRelative = velocityResidual/velocityTermScale;
    etaResidual = scalarNorm(difference.eta,stage.metric,weights);
    etaModal = scalarNorm(modal.eta,stage.metric,weights);
    etaStrong = scalarNorm(full.eta,stage.metric,weights);
    etaVertical = scalarNorm(stage.physical.w,stage.metric,weights);
    etaTransport = scalarNorm(stage.physical.w-full.eta,stage.metric,weights);
    etaTermScale = etaVertical+etaTransport;
    etaRelative = etaResidual/etaTermScale;
    sshResidual = max(abs(difference.ssh),[],'all');
    % Independent pressure-work integration-by-parts defect, using the
    % reference gradient because R*M=I at the same sampled geometry.
    gradient = struct(u=derivative.x(pressure),v=derivative.y(pressure),w=derivative.xi(pressure),eta=zero,ssh=zeros(wvt.Nx,wvt.Ny));
    volumePressureCovector = WVInternal.freeSurfaceReconstructionAdjoint(wvt,gradient);
    gradient.w(:,:,end) = gradient.w(:,:,end)-stage.thermodynamics.pressureSurface/wvt.verticalQuadratureWeights(end);
    pressureDefect = WVInternal.freeSurfaceReconstructionAdjoint(wvt,gradient);
    surfacePressureCovector = subtract(volumePressureCovector,pressureDefect);
    strongCovector = WVInternal.freeSurfaceReconstructionAdjoint(wvt,weightedFields(full,stage.metric,wvt.g));
    projectedResidual = subtract(WVInternal.freeSurfaceWeakMassAction(wvt,stage.totalRate,stage.metric),strongCovector);
    layout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
    reference = WVInternal.freeSurfaceReferenceMass(wvt);
    boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
    reaction = boundary.adjoint(stageReport.solver.multiplier);
    pressureIBP = dualNorm(pressureDefect,layout,reference);
    pressureIBPTermScale = dualNorm(volumePressureCovector,layout,reference)+dualNorm(surfacePressureCovector,layout,reference);
    pressureIBPRelative = pressureIBP/pressureIBPTermScale;
    reactionDual = dualNorm(reaction,layout,reference);
    projectedResidualDual = dualNorm(projectedResidual,layout,reference);
    decompositionError = dualNorm(subtract(projectedResidual,subtract(pressureDefect,reaction)),layout,reference);
    decompositionScale = pressureIBP+reactionDual+projectedResidualDual;
    decompositionRelative = decompositionError/max(decompositionScale,realmin);
    independentPressureDefectError = dualNorm(subtract(subtract(stage.covector,strongCovector),pressureDefect),layout,reference);
    reactionWork = -boundary.apply(state).'*stageReport.solver.multiplier;
    retainedConstraintResidual = norm(boundary.apply(stage.totalRate)-stageReport.retainedTarget);
    discardedBoundaryTargetRMS = stageReport.discardedBoundaryTargetRMS;
    denseContext = helper.buildContext(wvt,1);
    [minimumLabel,maximumLabel] = helper.labelBounds(stage.hatted,denseContext);
    fingerprint = helper.seedCheckpoints(stage.hatted,denseContext);
    if isempty(referenceFingerprint), referenceFingerprint=fingerprint; end
    seedRelativeDifference = norm(fingerprint-referenceFingerprint)/norm(referenceFingerprint);
    stageIterations = stageReport.solver.iterations;
    pressureIterations = pressureReport.iterations;
    pressureRelativeResidual = pressureReport.scaledRelativeResidual;
    pressureInteriorDivergence = pressureReport.interiorDivergence;
    pressureBottomDivergence = pressureReport.bottomDivergence;
    pressureSurfaceDivergence = pressureReport.surfaceDivergence;
    pressureBottomAcceleration = pressureReport.bottomAcceleration;
    pressureSurfaceResidual = pressureReport.surfacePressureResidual;
    modalDivergence = derivative.x(modal.u)+derivative.y(modal.v)+derivative.xi(modal.w);
    modalInteriorDivergence = max(abs(modalDivergence(:,:,2:end-1)),[],'all');
    modalEndpointDivergence = max(abs(modalDivergence(:,:,[1 end])),[],'all');
    collocationMomentumIdentity = 0;
    for name = ["u","v","w"]
        collocationMomentumIdentity = max(collocationMomentumIdentity,max(abs(full.(name)-pressureReport.acceleration.(name)),[],'all'));
    end
    elapsedSeconds = toc(timer);
    pressureToleranceSensitivity = NaN;
    tightPressureRelativeResidual = NaN;
    if level==3
        [~,tightPressureReport] = pressureSolver.solve(stage.hatted.ssh,force,stage.thermodynamics.pressureSurface,tolerance=1e-14,maxIterations=300);
        pressureToleranceSensitivity = velocityNorm(subtract(tightPressureReport.metricGradient,pressureReport.metricGradient),stage.metric,weights);
        tightPressureRelativeResidual = tightPressureReport.scaledRelativeResidual;
        assert(pressureToleranceSensitivity<velocityResidual/100);
    end
    rows{iLevel} = table(level,Nz,balancedCount,waveCount,velocityResidual,velocityRelative,velocityTermScale,velocityModal,velocityStrong,velocityForce,velocityPressure,etaResidual,etaRelative,etaTermScale,etaModal,etaStrong,etaVertical,etaTransport,sshResidual,pressureIBP,pressureIBPRelative,pressureIBPTermScale,reactionDual,projectedResidualDual,decompositionError,decompositionRelative,independentPressureDefectError,reactionWork,retainedConstraintResidual,discardedBoundaryTargetRMS,minimumLabel,maximumLabel,seedRelativeDifference,stageIterations,pressureIterations,pressureRelativeResidual,pressureInteriorDivergence,pressureBottomDivergence,pressureSurfaceDivergence,pressureBottomAcceleration,pressureSurfaceResidual,modalInteriorDivergence,modalEndpointDivergence,collocationMomentumIdentity,elapsedSeconds,pressureToleranceSensitivity,tightPressureRelativeResidual);
    disp(rows{iLevel}(:,["level","Nz","velocityResidual","velocityRelative","etaResidual","etaRelative","pressureIBPRelative","reactionDual","decompositionRelative","elapsedSeconds"]))
    assert(minimumLabel>=-wvt.Lz && maximumLabel<=0);
    assert(collocationMomentumIdentity<1e-11);
    assert(pressureRelativeResidual<5e-12);
    assert(decompositionRelative<1e-5);
end
results = vertcat(rows{:});
end

function wvt = studyTransform(configuration)
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 configuration(1)],N2Function=@(z)1e-4+0*z,shouldAntialias=true,apvModeCount=configuration(2),mdaModeCount=configuration(2),waveModeCount=configuration(3),inertialModeCount=configuration(2),nEVP=256);
wvt.t = 0;
wvt.t0 = -17;
end

function state = mixedSeed(wvt,helper)
state = helper.seedState(wvt);
xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
yColumn = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
state.Aw_p(:,yColumn) = .3*exp(.41i)*state.Aw_p(:,xColumn);
state.Aw_m(:,yColumn) = .2*exp(.63i)*state.Aw_p(:,yColumn);
end

function value = velocityNorm(fields,metric,weights)
vertical = fields.w+metric.betaX.*fields.u+metric.betaY.*fields.v;
value = sqrt(sum(weights.*((fields.u.^2+fields.v.^2)./metric.gamma+metric.gamma.*vertical.^2),'all'));
end

function value = scalarNorm(field,metric,weights)
value = sqrt(sum(weights.*metric.displacementWeight.*field.^2,'all'));
end

function weighted = weightedFields(fields,metric,g)
vertical = fields.w+metric.betaX.*fields.u+metric.betaY.*fields.v;
weighted = struct(u=fields.u./metric.gamma+metric.gamma.*metric.betaX.*vertical,v=fields.v./metric.gamma+metric.gamma.*metric.betaY.*vertical,w=metric.gamma.*vertical,eta=metric.displacementWeight.*fields.eta,ssh=g*fields.ssh);
end

function result = subtract(left,right)
result = left;
for name = string(fieldnames(left)).'
    result.(name) = left.(name)-right.(name);
end
end

function value = dualNorm(covector,layout,reference)
value = sqrt(max(0,layout.pack(covector).'*layout.pack(reference.solve(covector))));
end
