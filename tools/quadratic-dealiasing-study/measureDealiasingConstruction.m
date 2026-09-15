function summary = measureDealiasingConstruction(outputFolder,options)
% Measure filtering and full construction separately on a pinned workload.
arguments (Input)
    outputFolder (1,1) string
    options.wvmRoot (1,1) string
    options.internalModesRoot (1,1) string
    options.dependencyRoot (1,1) string
    options.chebfunRoot (1,1) string
    options.policies (1,:) string = ["none","fixedFraction","effectiveBandwidth"]
    options.repetitions (1,1) double {mustBeInteger,mustBePositive} = 3
    options.shouldProfile (1,1) logical = true
    options.sourceRevision (1,1) string = "uncommitted study candidate"
    options.providerRevision (1,1) string = "uncommitted study candidate"
    options.gridSize (1,3) double {mustBeInteger,mustBePositive} = [128 128 65]
    options.nEVP (1,1) double {mustBeInteger,mustBePositive} = 104
end
environment = setupDealiasingStudy(options.wvmRoot,options.internalModesRoot,options.dependencyRoot,options.chebfunRoot);
maxNumCompThreads(1);
profile off
profile clear
if ~isfolder(outputFolder), mkdir(outputFolder); end
N2 = @(z) 1e-4*exp(2*z/700);
policies = options.policies;
summary = struct(environment=environment,sourceRevision=options.sourceRevision,providerRevision=options.providerRevision,threads=1,gridSize=options.gridSize,nEVP=options.nEVP,policies=struct([]));
for policy = policies
    rows = struct([]);
    record = struct(policy=policy,status="constructed",errorIdentifier="",errorMessage="",medianSeconds=NaN,medianFilteringSeconds=NaN,trials=rows,profileSeconds=NaN);
    for repetition = 0:options.repetitions
        started = tic;
        try
            [wvt,assessment] = construct(policy);
        catch exception
            if ~ismember(string(exception.identifier),["WV:NoResolvedAPVModes","WV:NoResolvedInertialModes"])
                rethrow(exception)
            end
            record.status = "rejected";
            record.errorIdentifier = string(exception.identifier);
            record.errorMessage = string(exception.message);
            fprintf('%s rejected: %s\n',policy,exception.identifier);
            break
        end
        elapsed = toc(started);
        filteringSeconds = NaN;
        if isfield(assessment.cost,'quadraticDealiasingSeconds'), filteringSeconds=assessment.cost.quadraticDealiasingSeconds; end
        row = struct(repetition=repetition,seconds=elapsed,filteringSeconds=filteringSeconds,apvCount=numel(wvt.apvMode),waveCountRange=[min(wvt.waveModeCountByKh),max(wvt.waveModeCountByKh)],waveEigensolves=assessment.cost.waveEigensolves);
        rows = [rows;row]; %#ok<AGROW>
        fprintf('%s repetition %d: %.6f s, filter %.6f s, APV %d, waves %d..%d\n',policy,repetition,elapsed,filteringSeconds,row.apvCount,row.waveCountRange);
        writelines(jsonencode(rows,PrettyPrint=true),fullfile(outputFolder,policy+"-trials.json"));
    end
    record.trials = rows;
    if record.status=="rejected"
        summary.policies = [summary.policies;record];
        writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));
        continue
    end
    counts = table(wvt.khUnique(:),wvt.waveModeCountByKh(:),repmat(numel(wvt.apvMode),numel(wvt.khUnique),1),VariableNames={'kappa','waveCount','apvCount'});
    writetable(counts,fullfile(outputFolder,policy+"-counts.csv"));
    save(fullfile(outputFolder,policy+"-assessment.mat"),'assessment');
    record.medianSeconds = median([rows(2:end).seconds]);
    record.medianFilteringSeconds = median([rows(2:end).filteringSeconds]);
    summary.policies = [summary.policies;record];
    writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));
end
% Profiling can leave the active caller instrumented. Complete every
% unprofiled timing before the first profiler pass.
if options.shouldProfile
    for policyIndex = 1:numel(summary.policies)
        if summary.policies(policyIndex).status~="constructed", continue; end
        policy = summary.policies(policyIndex).policy;
        hotspots = profileCodeHotspots(@() construct(policy),projectRoots=[options.wvmRoot,options.internalModesRoot],shouldPrintReport=false,maxFunctions=40,maxLines=40,label="quadratic-dealiasing-"+policy);
        summary.policies(policyIndex).profileSeconds = hotspots.elapsedTime;
        writetable(hotspots.functionMetrics,fullfile(outputFolder,policy+"-profile-functions.csv"));
        writetable(hotspots.topActionableLines,fullfile(outputFolder,policy+"-profile-lines.csv"));
        writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));
    end
end

    function [wvt,assessment] = construct(policy)
        [wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],options.gridSize,N2Function=N2,nEVP=options.nEVP,shouldAntialias=true,quadraticDealiasing=policy);
    end
end
