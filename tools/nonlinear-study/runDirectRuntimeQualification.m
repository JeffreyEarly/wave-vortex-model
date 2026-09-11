function results = runDirectRuntimeQualification(outputFolder)
% Compare ordinary WVModel evolution with the independently padded study.
% Fixed mixed seeds and counts isolate timestep and product-grid differences.
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
rows = cell(0,1);
for profile = ["constant","exponential"]
    N2Function = @(z)1e-4+zeros(size(z));
    if profile=="exponential", N2Function=@(z)1e-4*exp(z/650); end
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[12 12 129],N2Function=N2Function,apvModeCount=8,waveModeCount=12,mdaModeCount=8,inertialModeCount=8,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    wvt.t0 = -17;
    study = manuscriptEvolutionOperators(wvt,profile,padding=2);
    nativeGridStudy = manuscriptEvolutionOperators(wvt,profile,padding=1);
    seed = study.seed("mixed",1);
    tStart = 327; tFinal = tStart+2000;
    names = fieldnames(seed);
    wvt.addForcing(WVNonlinearAdvection(wvt));
    setState(wvt,seed,tStart);
    clock = tic; rate = wvt.coefficientTendency(); firstRHSSeconds = toc(clock);
    referenceRate = nativeGridStudy.rhs(tStart,seed);
    rateDifference = coefficientDifference(rate,referenceRate);
    assert(rateDifference<1e-8,'Runtime RHS differs from the analytic-thermodynamics study on the same grid.');
    times = zeros(1,3);
    for repeat = 1:3, clock=tic; wvt.coefficientTendency(); times(repeat)=toc(clock); end
    initial = study.observe(tStart,seed,rate);
    % The independent reference uses analytic thermodynamics and twice the
    % horizontal product samples, with unchanged retained spectral inventory.
    clock = tic;
    referenceIntegrator = WVArrayIntegrator(@referenceRHS,[tStart,tFinal],struct2cell(seed),10);
    referenceSeconds = toc(clock);
    referenceState = cell2struct(referenceIntegrator.currentY,names,1);
    referenceVector = study.checkpoint(tFinal,referenceState);
    finest = []; previous = [];
    for deltaT = [10 20 40]
        setState(wvt,seed,tStart);
        model = WVModel(wvt);
        model.setupIntegrator(integratorType="fixed",deltaT=deltaT);
        clock = tic; model.integrateToTime(tFinal,shouldShowIntegrationDiagnostics=false); runtimeSeconds=toc(clock);
        state = wvt.coefficientState();
        finalVector = study.checkpoint(tFinal,state);
        if isempty(finest), finest=finalVector; end
        stepDifference = NaN;
        if ~isempty(previous), stepDifference=norm(finalVector-previous)/norm(finest); end
        previous = finalVector;
        [rate,~,diagnostics] = wvt.coefficientTendency();
        final = study.observe(tFinal,state,rate);
        energyAgreement = abs(diagnostics.totalEnergy-nativeGridStudy.observe(tFinal,state,rate).energy);
        energyRateAgreement = abs(diagnostics.energyTendency-nativeGridStudy.observe(tFinal,state,rate).energyRate);
        assert(energyAgreement<1e-9 && energyRateAgreement<1e-11,'Runtime energy semantics disagree with independent analytic diagnostics.');
        row = struct(profile=profile,Nxy=12,Nz=129,apvCount=8,waveCount=12,mdaCount=8,inertialCount=8,duration=2000,deltaT=deltaT,rhsDifference=rateDifference,firstRHSSeconds=firstRHSSeconds,warmRHSSeconds=median(times),runtimeSeconds=runtimeSeconds,paddedReferenceSeconds=referenceSeconds,finalToPaddedReference=norm(finalVector-referenceVector)/norm(referenceVector),finalToFinestStep=norm(finalVector-finest)/norm(finest),successiveStepDifference=stepDifference,relativeEnergyChange=(final.energy-initial.energy)/initial.energy,relativeAPV2Change=(final.apv2-initial.apv2)/initial.apv2,finalSSHResidual=final.sshResidual,finalSurfaceResidual=final.surfaceResidual,finalBottomResidual=final.bottomResidual,minimumLabel=final.minimumLabel,maximumLabel=final.maximumLabel,energyAgreement=energyAgreement,energyRateAgreement=energyRateAgreement);
        rows{end+1,1} = struct2table(row); %#ok<AGROW> Six qualification records.
        writetable(vertcat(rows{:}),fullfile(outputFolder,'direct-runtime-trajectories.csv'));
        save(fullfile(outputFolder,sprintf('%s-dt%g.mat',profile,deltaT)),'state','referenceState','row');
        fprintf('%s dt%g: padded-reference difference %.3g, step difference %.3g, dE/E %.3g, dAPV2/APV2 %.3g, runtime %.2fs\n',profile,deltaT,row.finalToPaddedReference,stepDifference,row.relativeEnergyChange,row.relativeAPV2Change,runtimeSeconds);
    end
end
results = vertcat(rows{:});

    function values = referenceRHS(time,cellState)
        current = cell2struct(cellState,names,1);
        value = study.rhs(time,current);
        values = struct2cell(orderfields(value,names));
    end
end

function setState(wvt,state,time)
for name = string(fieldnames(state)).', wvt.(name)=state.(name); end
wvt.t=time;
end

function value = coefficientDifference(actual,reference)
value=0;
for name = string(fieldnames(actual)).'
    a=actual.(name); b=reference.(name);
    value=max(value,norm(a(:)-b(:))/max(norm(b(:)),realmin));
end
end
