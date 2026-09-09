function report = profileCurrentAPE(inputPath,outputPath)
% Profile one warmed production APE kernel on fixed captured-state inputs.
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    outputPath (1,1) string
end
arguments (Output)
    report (1,1) struct
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(fullfile(fileparts(root),"OceanKit","tools","profiling"));
[wvt,file] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
fileCleanup = onCleanup(@()file.close());
rho = wvt.rho_nm;
Z = wvt.Z;
materialHeight = Z-wvt.eta_true;
profile = WVNoMotionProfile(wvt.z,rho);
g = wvt.g;
rho0 = wvt.rho0;
profile.availablePotentialEnergy(Z,materialHeight,g,rho0);
analysis = profileCodeHotspots(@()profile.availablePotentialEnergy(Z,materialHeight,g,rho0), ...
    projectRoots=root,label="fixed-captured-state-production-APE",maxFunctions=15,maxLines=20,shouldPrintReport=false);
report = struct(schema="wave-vortex-ape-hotspots-v1",scope="One warmed fixed-input production APE kernel call under the MATLAB profiler; profiler overhead is not paired benchmark timing.");
report.input = fileProvenance(inputPath);
report.productionSource = fileProvenance(fullfile(root,"Operations","@WVNoMotionProfile","WVNoMotionProfile.m"));
report.driverSource = fileProvenance(string(mfilename("fullpath"))+".m");
report.grid = size(Z);
report.matlabRelease = string(version("-release"));
report.platform = string(computer);
report.elapsedSeconds = analysis.elapsedTime;
report.priorityTargets = table2struct(analysis.priorityTargets);
report.topProjectBySelfTime = table2struct(analysis.topProjectBySelfTime);
report.topProjectByNumCalls = table2struct(analysis.topProjectByNumCalls);
report.topActionableLines = table2struct(analysis.topActionableLines);
report.topCallsiteLines = table2struct(analysis.topCallsiteLines);
folder = fileparts(outputPath);
if ~isfolder(folder)
    mkdir(folder);
end
stream = fopen(outputPath,"w");
assert(stream>=0,"Cannot open the APE hotspot report.");
streamCleanup = onCleanup(@()fclose(stream));
fprintf(stream,"%s\n",jsonencode(report,PrettyPrint=true));
fprintf("APE_HOTSPOTS grid=%s seconds=%.6g output=%s\n",mat2str(size(Z)),analysis.elapsedTime,outputPath);
disp(analysis.topProjectBySelfTime(:,["selfTime","totalTime","numCalls","completeName"]));
disp(analysis.topActionableLines(:,["lineTime","lineNumber","functionName","lineText"]));
end

function result = fileProvenance(path)
quote = string(char(39));
quotedPath = quote+replace(path,quote,string(char([39,34,39,34,39])))+quote;
[status,digest] = system("shasum -a 256 "+quotedPath);
assert(status==0,"Cannot hash the APE qualification input.");
result = struct(path=path,sha256=string(extractBefore(digest," ")));
end
