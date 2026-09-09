function report = benchmarkCapturedNoMotionRecovery(inputPath,executable,outputPath)
% Compare bounded current-distribution recovery on one captured density field.
% Configure dependencies first and run without other timing workloads.
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    executable (1,1) string {mustBeFile}
    outputPath (1,1) string
end
arguments (Output)
    report (1,1) struct
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
folder = string(tempname);
mkdir(folder);
folderCleanup = onCleanup(@()rmdir(folder,'s'));
report = struct(schema="wave-vortex-captured-no-motion-recovery-v1",status="incomplete");
report.scope = "Current full-density moment extraction and bounded raw-moment recovery. Three warmed alternating trials per stage; C++ elapsedSeconds excludes request parsing, binary input I/O and process startup. No integrations or concurrent timing workloads.";
report.input = provenance(inputPath);
report.executionBinary = provenance(executable);
report.matlabRelease = string(version('-release'));
report.platform = string(computer);
paths = ["Operations/WVNoMotionProfileOperation.m","Operations/@WVNoMotionProfile/WVNoMotionProfile.m", ...
    "PortableRuntime/include/WaveVortexRuntime/WVNoMotionProfileRecovery.hpp","PortableRuntime/src/WVNoMotionProfileRecovery.cpp", ...
    "PortableRuntime/src/WVNoMotionDensityMoments.cpp", ...
    "PortableRuntime/tests/WVNoMotionRecoveryDump.cpp","tools/density-diagnostics/benchmarkCapturedNoMotionRecovery.m"];
report.sourceSHA256 = sources(root,paths);
fprintf("RECOVERY_BENCHMARK_BEGIN %s\n",inputPath);
started = tic;
[wvt,file] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
fileCleanup = onCleanup(@()file.close());
density = wvt.rho_total;
report.loadAndDensitySeconds = toc(started);
report.grid = size(density);
minimum = min(density,[],"all");
maximum = max(density,[],"all");
report.densityRange = [minimum maximum];
report.weightSum = sum(wvt.z_int/wvt.Lz);
densityPath = fullfile(folder,"density.bin");
stream = fopen(densityPath,'w');
assert(stream>=0,"Cannot write the temporary native-double density input.");
count = fwrite(stream,density,'double');
fclose(stream);
assert(count==numel(density));
momentRequest = struct(mode="moments",zInt=wvt.z_int,Lz=wvt.Lz,shape=size(density),densityFile=densityPath);
matlabMoments = WVNoMotionProfileOperation.moments_from_rho_tot(density,minimum,maximum,wvt.z_int,wvt.Lz);
cppMoments = runProbe(executable,folder,momentRequest);
assert(string(cppMoments.status)=="complete");
u0 = WVNoMotionProfileOperation.rho_to_u(wvt.rho_nm0,wvt.rho_nm0(end),wvt.rho_nm0(1));
weights = flip(wvt.z_int/wvt.Lz);
fitRequest = struct(mode="fitMoments",zInt=wvt.z_int,Lz=wvt.Lz,rhoNM0=wvt.rho_nm0, ...
    minimumDensity=minimum,maximumDensity=maximum,targetMoments=matlabMoments);
WVNoMotionProfileOperation.solveMoments(u0,weights,matlabMoments);
warmFit = runProbe(executable,folder,fitRequest);
assert(string(warmFit.status)=="complete","C++ warmup recovery failed: %s",warmFit.message);
orders = [1 2;2 1;1 2];
momentSeconds = zeros(3,2);
fitSeconds = zeros(3,2);
for trial = 1:3
    for implementation = orders(trial,:)
        if implementation==1
            started = tic;
            trialMinimum = min(density,[],"all");
            trialMaximum = max(density,[],"all");
            matlabMoments = WVNoMotionProfileOperation.moments_from_rho_tot(density,trialMinimum,trialMaximum,wvt.z_int,wvt.Lz);
            momentSeconds(trial,1) = toc(started);
        else
            cppMoments = runProbe(executable,folder,momentRequest);
            assert(string(cppMoments.status)=="complete");
            momentSeconds(trial,2) = cppMoments.elapsedSeconds;
        end
    end
end
assert(isequal(matlabMoments,fitRequest.targetMoments),"MATLAB moment targets changed across repeated extraction.");
for trial = 1:3
    for implementation = orders(trial,:)
        if implementation==1
            started = tic;
            [matlabU,matlabExit,matlabFit] = WVNoMotionProfileOperation.solveMoments(u0,weights,matlabMoments);
            fitSeconds(trial,1) = toc(started);
            assert(matlabExit>0 && matlabFit.maximumResidual<=1e-8);
        else
            sameMomentFit = runProbe(executable,folder,fitRequest);
            assert(string(sameMomentFit.status)=="complete");
            fitSeconds(trial,2) = sameMomentFit.elapsedSeconds;
        end
    end
end
report.trialOrders = orders;
report.trialColumns = ["matlab","cpp"];
report.momentTiming = timingSummary(momentSeconds);
report.momentTimingInterpretation = "Both stages include current-density extrema and raw moments; the C++ distribution pass also identifies an exact stable-rest profile. Inputs are already resident in each process.";
report.fitTiming = timingSummary(fitSeconds);
report.fitTimingInterpretation = "Both implementations receive identical MATLAB target moments; moment-accumulation effects are assessed separately by full recovery below.";
report.momentMaximumDifference = max(abs(cppMoments.distribution.moments-matlabMoments));
report.firstFourMomentDifferences = cppMoments.distribution.moments(1:4)-matlabMoments(1:4);
report.distribution = cppMoments.distribution;
report.matlabFit = matlabFit;
report.cppSameMomentFit = sameMomentFit.report;
matlabNodes = WVNoMotionProfileOperation.u_to_rho(matlabU,minimum,maximum);
report.sameMomentProfileMaximumDifference = max(abs(sameMomentFit.profile-matlabNodes));
recoverRequest = momentRequest;
recoverRequest.mode = "recover";
recoverRequest.rhoNM0 = wvt.rho_nm0;
recovery = runProbe(executable,folder,recoverRequest);
report.cppRecovery = recovery;
assert(string(recovery.status)=="complete" && recovery.report.qualified,"C++ full-state recovery did not qualify.");
[publicNodes,publicExit,publicFit] = WVNoMotionProfileOperation.find_rho_nm(wvt.z_int,wvt.Lz,density,wvt.rho_nm0);
assert(publicExit>0 && publicFit.maximumResidual<=1e-8);
report.matlabDirectProfileMaximumDifference = max(abs(publicNodes-matlabNodes));
report.profileMaximumDifference = max(abs(recovery.profile-publicNodes));
matlabProfile = WVNoMotionProfile(wvt.z,publicNodes);
cppProfile = WVNoMotionProfile(wvt.z,recovery.profile);
matlabHeight = matlabProfile.inverse(density);
cppHeight = cppProfile.inverse(density);
heightDifference = cppHeight-matlabHeight;
report.physical = struct(inverseHeightMaximumDifference=max(abs(heightDifference),[],"all"), ...
    inverseHeightRMSDifference=sqrt(volumeMean(heightDifference.^2,wvt.z_int,wvt.Lz)), ...
    meanEtaMatlab=volumeMean(wvt.Z-matlabHeight,wvt.z_int,wvt.Lz), ...
    meanEtaCpp=volumeMean(wvt.Z-cppHeight,wvt.z_int,wvt.Lz), ...
    densityClosureMatlab=max(abs(matlabProfile.density(matlabHeight)-density),[],"all"), ...
    densityClosureCpp=max(abs(cppProfile.density(cppHeight)-density),[],"all"));
matlabAPE = matlabProfile.availablePotentialEnergy(wvt.Z,matlabHeight,wvt.g,wvt.rho0);
cppAPE = cppProfile.availablePotentialEnergy(wvt.Z,cppHeight,wvt.g,wvt.rho0);
report.physical.meanAPEMatlab = volumeMean(matlabAPE,wvt.z_int,wvt.Lz);
report.physical.meanAPECpp = volumeMean(cppAPE,wvt.z_int,wvt.Lz);
report.physical.apeMaximumDifference = max(abs(cppAPE-matlabAPE),[],"all");
report.physical.negativeAPECounts = [nnz(matlabAPE<0),nnz(cppAPE<0)];
report.physical.meanEtaDifference = abs(report.physical.meanEtaCpp-report.physical.meanEtaMatlab);
report.physical.meanAPERelativeDifference = abs(report.physical.meanAPECpp-report.physical.meanAPEMatlab)/abs(report.physical.meanAPEMatlab);
report.physical.cppMaterialHeightRange = [min(cppHeight,[],"all"),max(cppHeight,[],"all")];
report.physical.allFinite = all(isfinite(cppHeight),"all") && all(isfinite(cppAPE),"all");
report.physicalInterpretation = "Both recovered nodal profiles use the same qualified MATLAB inverse/APE primitive to isolate recovery differences. Supplied-profile C++ primitive parity is separately qualified; these comparisons do not establish an exact continuous sorted-state truth.";
[~,name] = fileparts(inputPath);
day = extractAfter(name,"day");
fixturePath = fullfile(root,"UnitTests","fixtures","density-run18-day"+day+".json");
fixture = jsondecode(fileread(fixturePath));
assert(string(fixture.source.sha256)==report.input.sha256);
report.retainedFixture = provenance(fixturePath);
report.retainedMomentMaximumDifference = max(abs(matlabMoments-fixture.moments));
report.retainedNormalizationEndpointsMatch = minimum==fixture.rho_nm0(end) && maximum==fixture.rho_nm0(1);
assert(isequal(report.sourceSHA256,sources(root,paths)),"Recovery sources changed during qualification.");
assert(isequal(report.executionBinary,provenance(executable)),"Recovery executable changed during qualification.");
report.acceptance = struct(profileMaximumDifference=1e-6*(maximum-minimum),inverseHeightMaximumDifference=1e-6*wvt.Lz, ...
    meanEtaDifference=1e-8*wvt.Lz,meanAPERelativeDifference=1e-5,densityClosure=8*eps(max(abs(density),[],"all")));
heightTolerance = 8*eps(max(abs(wvt.z))+wvt.Lz);
accepted = report.sameMomentProfileMaximumDifference<=report.acceptance.profileMaximumDifference ...
    && report.profileMaximumDifference<=report.acceptance.profileMaximumDifference ...
    && report.physical.inverseHeightMaximumDifference<=report.acceptance.inverseHeightMaximumDifference ...
    && report.physical.meanEtaDifference<=report.acceptance.meanEtaDifference ...
    && report.physical.meanAPERelativeDifference<=report.acceptance.meanAPERelativeDifference ...
    && report.physical.densityClosureCpp<=report.acceptance.densityClosure ...
    && report.physical.densityClosureMatlab<=report.acceptance.densityClosure ...
    && all(report.physical.negativeAPECounts==0) && report.physical.allFinite ...
    && report.physical.cppMaterialHeightRange(1)>=wvt.z(1)-heightTolerance ...
    && report.physical.cppMaterialHeightRange(2)<=wvt.z(end)+heightTolerance;
report.status = "passed";
if ~accepted, report.status="failed"; end
directory = fileparts(outputPath);
if ~isfolder(directory), mkdir(directory); end
writeJSON(outputPath,report);
fprintf("RECOVERY_BENCHMARK_COMPLETE grid=%s moments=%s fit=%s momentDifference=%.17g profileDifference=%.17g heightDifference=%.17g\n", ...
    mat2str(report.grid),mat2str(report.momentTiming.medianSeconds,6),mat2str(report.fitTiming.medianSeconds,6), ...
    report.momentMaximumDifference,report.profileMaximumDifference,report.physical.inverseHeightMaximumDifference);
assert(accepted,"Captured recovery exceeded a prospective physical acceptance bound; inspect the retained report.");
end

function result = runProbe(executable,folder,request)
input = fullfile(folder,"request.json");
output = fullfile(folder,"result.json");
writeJSON(input,request);
[status,message] = system("env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+shellQuote(executable)+" "+shellQuote(input)+" "+shellQuote(output));
assert(status==0,"Recovery probe request failed: %s",message);
result = jsondecode(fileread(output));
end
function value = volumeMean(field,weights,depth)
value = sum(squeeze(mean(field,[1,2])).*weights(:))/depth;
end
function value = timingSummary(seconds)
value = struct(trialSeconds=seconds,medianSeconds=median(seconds,1),pairedSpeedups=seconds(:,1)./seconds(:,2));
value.medianSpeedup = value.medianSeconds(1)/value.medianSeconds(2);
end
function entries = sources(root,paths)
entries = repmat(struct(path="",sha256=""),numel(paths),1);
for index = 1:numel(paths)
    entries(index) = provenance(fullfile(root,paths(index)));
    entries(index).path = paths(index);
end
end
function entry = provenance(path)
[status,digest] = system("shasum -a 256 "+shellQuote(path));
assert(status==0,"Cannot hash recovery qualification source or input.");
entry = struct(path=path,sha256=string(extractBefore(digest," ")));
end
function writeJSON(path,value)
stream = fopen(path,'w');
assert(stream>=0,"Cannot open the recovery qualification artifact.");
cleanup = onCleanup(@()fclose(stream));
fprintf(stream,"%s\n",jsonencode(value,PrettyPrint=true));
end
function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end
