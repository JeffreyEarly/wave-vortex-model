function results = runManuscriptTrajectoryStudy(outputFolder,options)
% Advance direct manuscript interaction coefficients with the existing RK4.
% All output times are step endpoints; no dense-output interpolation is used.
arguments (Input)
    outputFolder (1,1) string
    options.profile (1,1) string {mustBeMember(options.profile,["constant","exponential"])} = "exponential"
    options.scenario (1,1) string {mustBeMember(options.scenario,["waves","waveBalanced","mixed","balanced"])} = "mixed"
    options.configurations (1,:) double {mustBeMember(options.configurations,[1 2 3 4])} = [3 2 1]
    options.deltaT (1,:) double {mustBePositive} = [40 20 10]
    options.duration (1,1) double {mustBePositive} = 2000
    options.outputInterval (1,1) double {mustBePositive} = 80
    options.Nz (1,1) double {mustBeInteger,mustBePositive} = 129
    options.Nxy (1,1) double {mustBeMember(options.Nxy,[8 12 16])} = 8
    options.padding (1,1) double {mustBeMember(options.padding,[1 2 4])} = 2
    options.amplitude (1,1) double {mustBePositive} = 1
    options.shouldUseRaggedWaves (1,1) logical = false
end
assert(all(mod(options.outputInterval,options.deltaT)==0) && mod(options.duration,options.outputInterval)==0,'Steps must divide outputInterval, which must divide duration.');
if ~isfolder(outputFolder), mkdir(outputFolder); end
counts=[2 3 2 2;4 6 4 4;8 12 8 8;16 24 16 16]; rows={}; history={};
referenceInitial=[]; referenceFinal=[]; tStart=327;
for configuration=options.configurations
    c=counts(configuration,:);
    N2=@(z)1e-4+0*z; if options.profile=="exponential", N2=@(z)1e-4*exp(z/650); end
    constructor=struct(N2Function=N2,apvModeCount=c(1),waveModeCount=c(2),mdaModeCount=c(3),inertialModeCount=c(4),nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    clock=tic; args=namedargs2cell(constructor);
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[options.Nxy options.Nxy options.Nz],args{:});
    if options.shouldUseRaggedWaves
        keys=w.khUnique; pattern=[c(2);max(2,floor(c(2)/2));0];
        constructor.waveModeCount=pattern(1+mod((0:numel(keys)-1).',3));
        constructor.waveModeKappa=keys; args=namedargs2cell(constructor);
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[options.Nxy options.Nxy options.Nz],args{:});
    end
    constructionSeconds=toc(clock); w.t0=-17;
    study=manuscriptEvolutionOperators(w,options.profile,padding=options.padding);
    seed=study.seed(options.scenario,options.amplitude); names=fieldnames(seed);
    [initialVector,~,~]=study.checkpoint(tStart,seed);
    if isempty(referenceInitial), referenceInitial=initialVector; end
    seedDifference=norm(initialVector-referenceInitial)/norm(referenceInitial);
    assert(seedDifference<1e-7,'The physical initial state changed under refinement.');
    dA=study.rhs(tStart,seed); initial=study.observe(tStart,seed,dA);
    omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
    excited=abs(seed.Aw_p)+abs(seed.Aw_m)>0;
    periods=2*pi./omega(excited);
    wavePeriodMinimum=min(periods,[],'all'); wavePeriodMaximum=max(periods,[],'all');
    if isempty(periods), wavePeriodMinimum=NaN; wavePeriodMaximum=NaN; end
    steps=sort(options.deltaT,'ascend'); finest=[]; previous=[];
    for deltaT=steps
        limits=initial; phaseIdentityMaximum=0; lastDiagnostic=initial;
        outputTime=tStart:options.outputInterval:tStart+options.duration;
        clock=tic;
        integrator=WVArrayIntegrator(@stage,outputTime,[struct2cell(seed);{zeros(9,1)}],deltaT,OutputFcn=@record);
        trajectorySeconds=toc(clock);
        finalState=cell2struct(integrator.currentY(1:numel(names)),names,1);
        finalVector=study.checkpoint(tStart+options.duration,finalState);
        if isempty(finest), finest=finalVector; end
        if isempty(referenceFinal), referenceFinal=finest; end
        finalToFinestStep=norm(finalVector-finest)/norm(finest);
        finalToFirstInventory=norm(finalVector-referenceFinal)/norm(referenceFinal);
        successiveStepDifference=NaN;
        if ~isempty(previous), successiveStepDifference=norm(finalVector-previous)/norm(finest); end
        previous=finalVector;
        integral=integrator.currentY{end};
        d=lastDiagnostic;
        row=struct(profile=options.profile,scenario=options.scenario,configuration=configuration,apvCount=c(1),waveCount=c(2),mdaCount=c(3),inertialCount=c(4),ragged=options.shouldUseRaggedWaves,Nz=options.Nz,Nxy=options.Nxy,padding=options.padding,amplitude=options.amplitude,duration=options.duration,deltaT=deltaT,seedDifference=seedDifference,finalToFinestStep=finalToFinestStep,successiveStepDifference=successiveStepDifference,finalToFirstInventory=finalToFirstInventory,energyChange=d.energy-initial.energy,relativeEnergyChange=(d.energy-initial.energy)/initial.energy,energyRateIntegral=integral(1),energyWorkIntegral=integral(7),energyIntegrationResidual=d.energy-initial.energy-integral(1),energyWorkResidual=d.energy-initial.energy-integral(7),label2Change=d.label2-initial.label2,label2RateIntegral=integral(2),label2WorkIntegral=integral(8),apv2Change=d.apv2-initial.apv2,relativeAPV2Change=(d.apv2-initial.apv2)/initial.apv2,apv2RateIntegral=integral(3),apv2WorkIntegral=integral(9),accumulatedSSH=integral(4),accumulatedSurface=integral(5),accumulatedBottom=integral(6),maximumSSHResidual=limits.sshResidual,maximumSurfaceResidual=limits.surfaceResidual,maximumBottomResidual=limits.bottomResidual,minimumLabel=limits.minimumLabel,maximumLabel=limits.maximumLabel,phaseIdentityMaximum=phaseIdentityMaximum,initialSSHScale=initial.sshRMS,initialSurfaceScale=initial.surfaceRMS,initialBottomScale=initial.bottomRMS,wavePeriodMinimum=wavePeriodMinimum,wavePeriodMaximum=wavePeriodMaximum,advectiveTime=w.Lx/initial.maximumSpeed,constructionSeconds=constructionSeconds,trajectorySeconds=trajectorySeconds);
        rows{end+1,1}=struct2table(row); %#ok<AGROW>
        fprintf('%s %s config%d dt%g: dE/E %.3g, dAPV2/APV2 %.3g, accumulated boundaries [%.3g %.3g %.3g]m, %gs\n',options.profile,options.scenario,configuration,deltaT,row.relativeEnergyChange,row.relativeAPV2Change,integral(4:6),trajectorySeconds);
        writetable(vertcat(rows{:}),fullfile(outputFolder,'manuscript-trajectories.csv'));
        writetable(vertcat(history{:}),fullfile(outputFolder,'manuscript-trajectories-history.csv'));
        save(fullfile(outputFolder,sprintf('checkpoint-config%d-dt%g.mat',configuration,deltaT)),'initialVector','finalVector','finalState','row');
    end
end
results=vertcat(rows{:});

    function value = stage(time,cellState)
        state=cell2struct(cellState(1:numel(names)),names,1);
        rate=study.rhs(time,state); d=study.observe(time,state,rate);
        [~,mn,mx]=study.checkpoint(time,state);
        assert(mn>=-w.Lz-32*eps(w.Lz) && mx<=32*eps(w.Lz),'A stage left the parcel-label domain on the common grid.');
        limits.minimumLabel=min([limits.minimumLabel,d.minimumLabel,mn]);
        limits.maximumLabel=max([limits.maximumLabel,d.maximumLabel,mx]);
        for name=["sshResidual","surfaceResidual","bottomResidual"]
            limits.(name)=max(limits.(name),d.(name));
        end
        phaseIdentityMaximum=max(phaseIdentityMaximum,d.sshIdentityError);
        work=[d.energyRate;d.label2Rate;d.apv2Rate;d.sshResidual;d.surfaceResidual;d.bottomResidual;d.energyWork;d.label2Work;d.apv2Work];
        value=[struct2cell(orderfields(rate,names));{work}];
    end

    function record(time,cellState,flag)
        if strcmp(flag,'done'), return; end
        state=cell2struct(cellState(1:numel(names)),names,1);
        rate=study.rhs(time,state); d=study.observe(time,state,rate);
        lastDiagnostic=d;
        integral=cellState{end};
        d.profile=options.profile; d.scenario=options.scenario; d.configuration=configuration; d.deltaT=deltaT;
        d.accumulatedSSH=integral(4); d.accumulatedSurface=integral(5); d.accumulatedBottom=integral(6);
        d.energyRateIntegral=integral(1); d.apv2RateIntegral=integral(3);
        history{end+1,1}=struct2table(d);
    end
end
