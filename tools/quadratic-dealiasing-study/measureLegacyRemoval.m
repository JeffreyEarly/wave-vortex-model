function summary = measureLegacyRemoval(wvmRoot,outputFolder,options)
% Compare cleanup against the calibrated implementation in a fresh process.
arguments (Input)
    wvmRoot (1,1) string
    outputFolder (1,1) string
    options.internalModesRoot (1,1) string
    options.dependencyRoot (1,1) string
    options.chebfunRoot (1,1) string
end
studyRoot = string(fileparts(mfilename('fullpath')));
provider = options.internalModesRoot;
environment = setupDealiasingStudy(wvmRoot,provider,options.dependencyRoot,options.chebfunRoot);
addpath(studyRoot);
maxNumCompThreads(1);
profile off
profile clear
if ~isfolder(outputFolder), mkdir(outputFolder); end
summary = struct(environment=environment,threads=1,policies=struct([]));
for policy = ["none","fixedFraction","effectiveBandwidth"]
    trials = struct([]);
    for repetition = 0:3
        started = tic;
        [wvt,assessment] = construct(policy);
        elapsed = toc(started);
        row = struct(repetition=repetition,seconds=elapsed,filteringSeconds=assessment.cost.quadraticDealiasingSeconds);
        trials = [trials;row]; %#ok<AGROW>
        fprintf('%s repetition %d: %.6f s, filtering %.6f s\n',policy,repetition,elapsed,row.filteringSeconds);
    end
    state = rmfield(wvt.scientificState(),{'N2Function','rhoFunction'});
    save(fullfile(outputFolder,policy+"-scientific.mat"),'state','assessment','-v7.3');
    row = struct(policy=policy,trials=trials,medianSeconds=median([trials(2:end).seconds]),medianFilteringSeconds=median([trials(2:end).filteringSeconds]),waveEigensolves=assessment.cost.waveEigensolves,positiveWavenumbers=numel(wvt.khUnique),waveCountRange=[min(wvt.waveModeCountByKh),max(wvt.waveModeCountByKh)],apvCount=numel(wvt.apvMode));
    summary.policies = [summary.policies;row];
    writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));
end
% Every unprofiled batch finishes before any profiler instrumentation.
hotspots = profileCodeHotspots(@()construct("fixedFraction"),projectRoots=[wvmRoot,provider],shouldPrintReport=false,maxFunctions=40,maxLines=40,label="legacy-removal-default");
summary.profileSeconds = hotspots.elapsedTime;
writetable(hotspots.functionMetrics,fullfile(outputFolder,'profile-functions.csv'));
writetable(hotspots.topActionableLines,fullfile(outputFolder,'profile-lines.csv'));
writelines(jsonencode(summary,PrettyPrint=true),fullfile(outputFolder,'summary.json'));

    function [wvt,assessment] = construct(policy)
        [wvt,assessment] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65], ...
            N2Function=@(z)1e-4*exp(2*z/700),nEVP=104,shouldAntialias=true,quadraticDealiasing=policy);
    end
end
