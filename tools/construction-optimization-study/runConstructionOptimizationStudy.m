function report = runConstructionOptimizationStudy(wvmRoot,internalModesRoot,outputFolder)
% Measure and profile one pinned free-surface construction in a fresh process.
% The repositories and released supporting packages share an OceanKit workspace.
arguments (Input)
    wvmRoot (1,1) string
    internalModesRoot (1,1) string
    outputFolder (1,1) string
end
% The provider may be a released snapshot nested below the workspace.
workspace = fileparts(wvmRoot);
studyFolder = fileparts(mfilename('fullpath'));
restoredefaultpath;
packageRoots = [fullfile(workspace,["OceanKit/ClassAnnotations-1.2.1","OceanKit/Distributions-2.0.0","OceanKit/SplineCore-2.2.0","chebfun","OceanKit/NetCDF-1.0.2"]),internalModesRoot,wvmRoot];
for root = packageRoots
    manifest = jsondecode(fileread(fullfile(root,"resources","mpackage.json")));
    folders = strings(1,0);
    for index = 1:numel(manifest.folders)
        folders(end+1) = fullfile(root,manifest.folders(index).path);
    end
    folderArguments = cellstr([folders(isfolder(folders)),root]);
    addpath(folderArguments{:});
end
profilingRoot = fullfile(workspace,"OceanKit","tools","profiling");
addpath(profilingRoot,studyFolder);
if ~isfolder(outputFolder), mkdir(outputFolder); end
resolved = string(which('WVTransformFreeSurfaceBoussinesq'));
assert(startsWith(resolved,wvmRoot+filesep),'The benchmark resolved a different WVM checkout.');
assert(startsWith(string(which('IMSolverSpectral')),internalModesRoot+filesep),'The benchmark resolved a different InternalModes checkout.');
fprintf('WVM: %s\nInternalModes: %s\nMATLAB: %s\n',resolved,which('IMSolverSpectral'),version);
N2 = @(z) 1e-4*exp(2*z/700);
construct = @() WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[128 128 65],N2Function=N2,nEVP=104,shouldAntialias=true,shouldCheckQuadraticAliasing=false);
% Warm the complete workload so compilation for larger arrays precedes timing.
construct();
seconds = zeros(3,1); waveSeconds = seconds;
for repetition = 1:3
    started = tic;
    [wvt,assessment] = construct();
    seconds(repetition) = toc(started);
    waveSeconds(repetition) = assessment.cost.waveConstructionSeconds;
    fprintf('Repetition %d: %.6f s; wave construction %.6f s\n',repetition,seconds(repetition),waveSeconds(repetition));
end
report = struct(matlabVersion=version,wvmRoot=wvmRoot,internalModesRoot=internalModesRoot,seconds=seconds,waveSeconds=waveSeconds,medianSeconds=median(seconds),medianWaveSeconds=median(waveSeconds),nEVP=wvt.nEVP,referenceNEVP=assessment.referenceNEVP,distinctPositiveKappa=numel(wvt.khUnique),waveEigensolves=assessment.cost.waveEigensolves,waveModeCountByKh=wvt.waveModeCountByKh);
writelines(jsonencode(report,PrettyPrint=true),fullfile(outputFolder,"timing.json"));
state = rmfield(wvt.scientificState(),{'N2Function','rhoFunction'});
save(fullfile(outputFolder,"scientific-result.mat"),'state','assessment','-v7.3');
analysis = profileCodeHotspots(construct,projectRoots=[wvmRoot,internalModesRoot],shouldPrintReport=false,maxFunctions=40,maxLines=40,label=outputFolder);
save(fullfile(outputFolder,"profile.mat"),'analysis','-v7.3');
writetable(analysis.functionMetrics,fullfile(outputFolder,"profile-functions.csv"));
writetable(analysis.topActionableLines,fullfile(outputFolder,"profile-lines.csv"));
fprintf('Profile elapsed time: %.6f s\n',analysis.elapsedTime);
end
