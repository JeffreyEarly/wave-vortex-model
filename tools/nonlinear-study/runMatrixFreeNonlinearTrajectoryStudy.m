function summary = runMatrixFreeNonlinearTrajectoryStudy(outputDirectory,options)
% Qualify bounded trajectories of the composed full-C1 internal stage.
%
% This study uses the stored grid and all its retained horizontal modes.
% Vertical refinement changes retained vertical counts and quadrature;
% optional horizontal refinement changes both bandwidth and quadrature.
% It is not a fixed-band horizontal overintegration experiment. The dense
% earlier trajectories used a different surface-pressure approximation.
arguments (Input)
    outputDirectory (1,1) string
    options.endTime (1,1) double {mustBePositive} = 200
    options.timeSteps (1,:) double {mustBePositive} = [10,5,2.5]
    options.includeHorizontalRefinement (1,1) logical = false
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
configurations = [8,65,2,3;8,129,4,6];
labels = ["coarse","vertical"];
if options.includeHorizontalRefinement
    configurations(end+1,:) = [12,129,4,6];
    labels(end+1) = "horizontal";
end
summary = table();
history = table();
finalSamples = cell(size(configurations,1),length(options.timeSteps));
initialSamples = cell(size(configurations,1),1);
helper = freeSurfaceWeakStudyHelpers();
for configuration = 1:size(configurations,1)
    settings = configurations(configuration,:);
    timer = tic;
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5,1e5,1000],[settings(1),settings(1),settings(2)],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=settings(3),waveModeCount=settings(4),mdaModeCount=settings(3),inertialModeCount=settings(3),nEVP=256,shouldAntialias=true);
    context = WVInternal.freeSurfaceNonlinearStage(wvt);
    materialContext = helper.buildContext(wvt,1);
    layout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
    boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
    constructionSeconds = toc(timer);
    seed = helper.seedState(wvt);
    yColumn = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
    xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
    seed.Aw_p(1,yColumn) = .3*exp(.41i)*seed.Aw_p(1,xColumn);
    seed.Aw_m = .2*exp(.63i)*seed.Aw_p;
    firstSummaryRow = height(summary)+1;
    for timeStepIndex = 1:length(options.timeSteps)
        dt = options.timeSteps(timeStepIndex);
        if abs(round(options.endTime/dt)-options.endTime/dt)>1e-12
            error('WV:TrajectoryTimeStep','Every step must divide endTime.');
        end
        state = layout.pack(seed);
        wvt.t0 = -17;
        workIntegral = 0; defectIntegral = 0; solverWorkIntegral = 0; sshWorkIntegral = 0;
        maximumBudgetIdentityResidual = 0;
        maximumIterations = 0; maximumResidual = 0;
        maximumConstraint = 0; maximumDiscarded = 0;
        minimumLabel = inf; maximumLabel = -inf;
        timer = tic;
        for step = 0:round(options.endTime/dt)
            time = step*dt;
            [k1,d1] = rhs(time,state,true);
            if step==0
                initialEnergy=d1.energy;
                initialMoments=d1.moments;
                momentScales=d1.momentScales;
                maximumMomentChanges=structfun(@(value)0,initialMoments,UniformOutput=false);
            end
            row = table(labels(configuration),dt,time,d1.energy,d1.energy-initialEnergy,workIntegral,defectIntegral,d1.energy-initialEnergy-workIntegral-defectIntegral-solverWorkIntegral-sshWorkIntegral,d1.energyRate,d1.reactionWork,d1.iterations,d1.residual,d1.constraint,d1.discarded,d1.minimumLabel,d1.maximumLabel,VariableNames={'configuration','dt','time','energy','energyChange','integratedReactionWork','integratedQuadratureDefect','energyBudgetResidual','energyRate','reactionWork','iterations','stationarityResidual','constraintResidual','discardedBoundaryRMS','minimumLabel','maximumLabel'});
            row.integratedSolverWork=solverWorkIntegral;
            row.integratedSSHGeometryWork=sshWorkIntegral;
            row.independentBudgetIdentityResidual=d1.budgetIdentityResidual;
            for momentName=string(fieldnames(initialMoments)).'
                change=abs(d1.moments.(momentName)-initialMoments.(momentName));
                maximumMomentChanges.(momentName)=max(maximumMomentChanges.(momentName),change);
                row.(momentName)=d1.moments.(momentName);
                row.(momentName+"AbsoluteChange")=change;
                row.(momentName+"InitialScale")=momentScales.(momentName);
                row.(momentName+"ScaledAbsoluteChange")=change/max(momentScales.(momentName),realmin);
            end
            history = [history;row]; %#ok<AGROW>
            if step==round(options.endTime/dt), break; end
            [k2,d2] = rhs(time+dt/2,state+dt*k1/2);
            [k3,d3] = rhs(time+dt/2,state+dt*k2/2);
            [k4,d4] = rhs(time+dt,state+dt*k3);
            state = state+dt*(k1+2*k2+2*k3+k4)/6;
            workIntegral = workIntegral+dt*(d1.reactionWork+2*d2.reactionWork+2*d3.reactionWork+d4.reactionWork)/6;
            defectIntegral = defectIntegral+dt*(d1.quadratureDefect+2*d2.quadratureDefect+2*d3.quadratureDefect+d4.quadratureDefect)/6;
            solverWorkIntegral = solverWorkIntegral+dt*(d1.solverWork+2*d2.solverWork+2*d3.solverWork+d4.solverWork)/6;
            sshWorkIntegral = sshWorkIntegral+dt*(d1.sshWork+2*d2.sshWork+2*d3.sshWork+d4.sshWork)/6;
        end
        seconds = toc(timer);
        [~,~,finalStage] = context.evaluate(layout.unpack(state));
        finalSamples{configuration,timeStepIndex} = checkpoint(finalStage.hatted,wvt,helper);
        if timeStepIndex==1
            wvt.t = 0;
            [~,~,initialStage] = context.evaluate(seed);
            initialSamples{configuration} = checkpoint(initialStage.hatted,wvt,helper);
            wvt.t = options.endTime;
        end
        stepDifference = nan; verticalDifference = nan; initialDifference = nan;
        if timeStepIndex>1
            stepDifference = norm(finalSamples{configuration,timeStepIndex}-finalSamples{configuration,timeStepIndex-1})/norm(finalSamples{configuration,timeStepIndex});
        end
        if configuration>1
            verticalDifference = norm(finalSamples{configuration,timeStepIndex}-finalSamples{configuration-1,timeStepIndex})/norm(finalSamples{configuration,timeStepIndex});
            initialDifference = norm(initialSamples{configuration}-initialSamples{configuration-1})/norm(initialSamples{configuration});
        end
        row = table(labels(configuration),settings(1),settings(2),settings(3),settings(4),dt,options.endTime,constructionSeconds,seconds,d1.energy-initialEnergy,workIntegral,defectIntegral,d1.energy-initialEnergy-workIntegral-defectIntegral-solverWorkIntegral-sshWorkIntegral,maximumIterations,maximumResidual,maximumConstraint,maximumDiscarded,minimumLabel,maximumLabel,VariableNames={'configuration','Nx','Nz','balancedCount','waveCount','dt','endTime','constructionSeconds','trajectorySeconds','energyChange','integratedReactionWork','integratedQuadratureDefect','energyBudgetResidual','maximumIterations','maximumStationarityResidual','maximumConstraintResidual','maximumDiscardedBoundaryRMS','minimumLabel','maximumLabel'});
        row.integratedSolverWork = solverWorkIntegral;
        row.integratedSSHGeometryWork = sshWorkIntegral;
        row.maximumIndependentBudgetIdentityResidual = maximumBudgetIdentityResidual;
        for momentName=string(fieldnames(initialMoments)).'
            row.(momentName+"Initial")=initialMoments.(momentName);
            row.(momentName+"Final")=d1.moments.(momentName);
            row.(momentName+"AbsoluteChange")=abs(d1.moments.(momentName)-initialMoments.(momentName));
            row.(momentName+"InitialScale")=momentScales.(momentName);
            row.(momentName+"MaximumAbsoluteChange")=maximumMomentChanges.(momentName);
            row.(momentName+"ScaledAbsoluteChange")=row.(momentName+"AbsoluteChange")/max(momentScales.(momentName),realmin);
        end
        row.relativeFinalStatePreviousStepDifference = stepDifference;
        row.relativeFinalStateFinestStepDifference = NaN;
        row.relativeFinalStateResolutionDifference = verticalDifference;
        row.relativeInitialStateResolutionDifference = initialDifference;
        summary = [summary;row]; %#ok<AGROW>
        writetable(summary,fullfile(outputDirectory,'matrix-free-full-reference-summary.csv'));
        writetable(history,fullfile(outputDirectory,'matrix-free-full-reference-history.csv'));
        fprintf('%s dt=%g: %.2f s, energy change %.6g, budget residual %.3g, maximum %d iterations\n',labels(configuration),dt,seconds,row.energyChange,row.energyBudgetResidual,maximumIterations);
    end
    [~,finestIndex]=min(options.timeSteps);
    finest=finalSamples{configuration,finestIndex};
    for index=1:length(options.timeSteps)
        summary.relativeFinalStateFinestStepDifference(firstSummaryRow+index-1)=norm(finalSamples{configuration,index}-finest)/norm(finest);
    end
    writetable(summary,fullfile(outputDirectory,'matrix-free-full-reference-summary.csv'));
end

    function [value,diagnostic] = rhs(time,vector,measureMaterial)
        if nargin<3, measureMaterial=false; end
        wvt.t = time;
        coefficients = layout.unpack(vector);
        [rate,report,stage] = context.evaluate(coefficients);
        value = layout.pack(rate);
        fieldRate = wvt.reconstructSpectralState(state=stage.totalRate);
        for name = ["u","v","w","eta","ssh"]
            fieldRate.(name) = wvt.transformToSpatialDomainWithFourier(fieldRate.(name));
        end
        sshRate = fieldRate.ssh(:,:,end);
        gammaRate = sshRate/wvt.Lz;
        physical = stage.physical;
        hatted = stage.hatted;
        alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
        uRate = (fieldRate.u-physical.u.*gammaRate)./physical.gamma;
        vRate = (fieldRate.v-physical.v.*gammaRate)./physical.gamma;
        wRate = fieldRate.w+alpha.*(uRate.*wvt.diffX(hatted.ssh)+vRate.*wvt.diffY(hatted.ssh)+physical.u.*wvt.diffX(sshRate)+physical.v.*wvt.diffY(sshRate));
        thermal = stage.thermodynamics;
        energyDensityRate = .5*gammaRate.*(physical.u.^2+physical.v.^2+physical.w.^2)+physical.gamma.*(physical.u.*uRate+physical.v.*vRate+physical.w.*wRate)+gammaRate.*thermal.ape+physical.gamma.*(thermal.apeEta.*fieldRate.eta+thermal.apeZ.*alpha.*sshRate);
        weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
        energyRate = sum(weights.*energyDensityRate,'all')+mean(thermal.pressureSurface.*sshRate,'all');
        reactionWork = -boundary.apply(coefficients).'*report.solver.multiplier;
        % Independently evaluate the weak energy-production defect from the
        % RHS covector and geometry gradient, without using the solved rate.
        volumeWeights = reshape(wvt.verticalQuadratureWeights,1,1,[]);
        verticalIntegral = @(field)sum(volumeWeights.*field,3);
        speedSquared = physical.u.^2+physical.v.^2+physical.w.^2;
        geometry = (physical.w.*hatted.w-.5*speedSquared)/wvt.Lz+thermal.ape/wvt.Lz+physical.gamma.*alpha.*thermal.apeZ;
        psi = verticalIntegral(geometry)-wvt.diffX(verticalIntegral(alpha.*physical.w.*hatted.u))-wvt.diffY(verticalIntegral(alpha.*physical.w.*hatted.v));
        surfaceJ = wvt.g*hatted.ssh-thermal.pressureSurface;
        quadratureDefect = vector.'*layout.pack(stage.covector)+mean((psi-surfaceJ).*hatted.w(:,:,end),'all');
        sshWork = mean((psi-surfaceJ).*(sshRate-hatted.w(:,:,end)),'all');
        massRate = WVInternal.freeSurfaceWeakMassAction(wvt,stage.totalRate,stage.metric);
        reactionCovector = boundary.adjoint(report.solver.multiplier);
        solverResidual = layout.pack(massRate)+layout.pack(reactionCovector)-layout.pack(stage.covector);
        solverWork = vector.'*solverResidual;
        budgetIdentityResidual = energyRate-quadratureDefect-reactionWork-solverWork-sshWork;
        diagnostic = struct(solverWork=solverWork,sshWork=sshWork,budgetIdentityResidual=budgetIdentityResidual,energy=report.totalEnergy,energyRate=energyRate,reactionWork=reactionWork,quadratureDefect=quadratureDefect,iterations=report.solver.iterations,residual=report.solver.relativeResidual,constraint=norm(report.solver.constraintResidual),discarded=report.discardedBoundaryTargetRMS,minimumLabel=report.minimumLabel,maximumLabel=report.maximumLabel);
        if measureMaterial
            [diagnostic.moments,diagnostic.momentScales]=helper.materialInvariants(hatted,materialContext);
        end
        maximumBudgetIdentityResidual=max(maximumBudgetIdentityResidual,abs(budgetIdentityResidual));
        maximumIterations = max(maximumIterations,diagnostic.iterations);
        maximumResidual = max(maximumResidual,diagnostic.residual);
        maximumConstraint = max(maximumConstraint,diagnostic.constraint);
        maximumDiscarded = max(maximumDiscarded,diagnostic.discarded);
        minimumLabel = min(minimumLabel,diagnostic.minimumLabel);
        maximumLabel = max(maximumLabel,diagnostic.maximumLabel);
    end
end

function vector = checkpoint(hatted,wvt,helper)
% A common 24-by-24-by-257 reference grid, with trapezoidal vertical
% integration, provides a fixed positive norm for the constant-N study.
% The existing study's barycentric matrix is valid on this constant-N
% Chebyshev column; no variable-stratification interpolation is claimed.
context = helper.buildContext(wvt,1);
number = 24*24;
Nz = length(context.labelXi);
weights = ones(1,Nz)*wvt.Lz/(Nz-1);
weights([1,end]) = weights([1,end])/2;
vector = zeros(4*number*Nz+number,1);
offset = 0;
for name = ["u","v","w","eta"]
    field = real(interpft(interpft(hatted.(name),24,1),24,2));
    field = reshape(field,[],wvt.Nz)*context.labelInterpolation.';
    factor = 1;
    if name=="eta", factor=1e-4; end
    field = sqrt(factor*weights/number).*field;
    vector(offset+(1:numel(field))) = field(:);
    offset = offset+numel(field);
end
ssh = real(interpft(interpft(hatted.ssh,24,1),24,2));
vector(offset+1:end) = sqrt(wvt.g/number)*ssh(:);
end
