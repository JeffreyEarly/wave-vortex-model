function report = qualifyPortableHydrostatic(outputPath,options)
% Qualify Hydrostatic continuation and write measured, catalog-linked JSON evidence.
% Run after configureCIEnvironment. A supplied runner must have the matching
% test probes beside it. This tool never changes the compatibility inventory.
arguments (Input)
    outputPath (1,1) string
    options.runner (1,1) string = string(getenv("WV_STABLE_FORCING_RUNNER"))
    options.native (1,1) logical = getenv("WV_STABLE_FORCING_NATIVE") == "1"
    options.scope (1,1) string {mustBeMember(options.scope,["complete","contracts"])} = "complete"
end
arguments (Output)
    report (1,1) struct
end
if options.scope=="contracts" && options.native
    error("WaveVortexModel:QualificationScope","Contract-only reports use the reference provider; native qualification requires complete scope.");
end
schemaIdentifier = "wave-vortex-hydrostatic-qualification-v1";
if options.scope=="contracts", schemaIdentifier="wave-vortex-hydrostatic-contracts-v1"; end
root = string(fileparts(fileparts(mfilename("fullpath"))));
folder = string(tempname); mkdir(folder); folderCleanup = onCleanup(@()rmdir(folder,"s"));
originalPath = path; pathCleanup = onCleanup(@()path(originalPath)); addpath(fullfile(root,"UnitTests"));
environmentNames = ["WV_STABLE_FORCING_RUNNER","WV_STABLE_FORCING_DUMP","WV_STABLE_FORCING_NATIVE","WV_HYDRO_EVIDENCE_FOLDER","WV_MODAL_DUMP_EXECUTABLE","WV_HYDRO_KERNEL_DUMP","WV_HYDRO_TEST_NATIVE"];
originalEnvironment = arrayfun(@(name)string(getenv(name)),environmentNames);
environmentCleanup = onCleanup(@()restoreEnvironment(environmentNames,originalEnvironment));
runner = options.runner;
if runner == ""
    if options.native, error("WaveVortexModel:QualificationProvider","Native qualification requires an explicitly built native runner."); end
    build = fullfile(folder,"build");
    runCommand("cmake -S "+shellQuote(fullfile(root,"PortableRuntime"))+" -B "+shellQuote(build)+" -DCMAKE_BUILD_TYPE=Release -DWV_ENABLE_ACCELERATE=OFF");
    runCommand("cmake --build "+shellQuote(build)+" --parallel 4 --target wave-vortex-run WVStableForcingDump WVStratifiedQGFieldDump WVHydrostaticLifecycleProbe WVStratifiedQGLifecycleProbe WVStratifiedModalDump WVHydrostaticKernelDump");
    runner = fullfile(build,"wave-vortex-run");
end
for name = ["wave-vortex-run","WVStableForcingDump","WVStratifiedQGFieldDump","WVHydrostaticLifecycleProbe","WVStratifiedQGLifecycleProbe","WVStratifiedModalDump","WVHydrostaticKernelDump"]
    if ~isfile(fullfile(fileparts(runner),name)), error("WaveVortexModel:QualificationAsset","Missing qualification executable: %s",fullfile(fileparts(runner),name)); end
end
setenv("WV_STABLE_FORCING_RUNNER",runner);
setenv("WV_STABLE_FORCING_DUMP",fullfile(fileparts(runner),"WVStableForcingDump"));
setenv("WV_MODAL_DUMP_EXECUTABLE",fullfile(fileparts(runner),"WVStratifiedModalDump"));
setenv("WV_STABLE_FORCING_NATIVE",string(double(options.native)));
setenv("WV_HYDRO_EVIDENCE_FOLDER",folder);
setenv("WV_HYDRO_KERNEL_DUMP",fullfile(fileparts(runner),"WVHydrostaticKernelDump"));
setenv("WV_HYDRO_TEST_NATIVE",string(double(options.native)));
classes = ["TestPortableHydrostatic","TestPortableHydrostaticQualification","TestPortableStableForcing","TestPortableForcingCompatibility","TestCompiledKernelIntegration","TestStratifiedModalRecord","TestHydrostaticCompiledKernel"];
parts = arrayfun(@testsuite,classes,UniformOutput=false);
suite = [parts{:}];
if options.scope=="contracts"
    suite = suite(string({suite.Name})~="TestPortableHydrostaticQualification/longerContinuationMatchesMatlab");
end
if options.native
    suite = [suite,testsuite("TestPortableStratifiedQGQualification",Name="*lifecycleAndStorageRemainBounded")];
end
started = tic; results = run(suite);
tests = struct('name',{},'passed',{},'failed',{},'incomplete',{},'seconds',{});
for result = reshape(results,1,[])
    tests(end+1) = struct(name=string(result.Name),passed=result.Passed,failed=result.Failed,incomplete=result.Incomplete,seconds=result.Duration); %#ok<AGROW>
end
catalogPath = fullfile(root,"PortableRuntime","contracts","portable-forcing-compatibility-v1.json");
catalog = jsondecode(fileread(catalogPath)); validatePortableForcingCompatibility(catalog,requireComplete=true);
providers = "reference"; if options.native, providers(end+1) = "native-fftw"; end
rows = struct('id',{},'provider',{},'acceptance',{},'rejection',{},'testNames',{},'passed',{});
for row = reshape(catalog.rows(startsWith(string({catalog.rows.configuration}),"hydrostatic")),1,[])
    if string(row.acceptance)=="supported"
        names = ["TestPortableHydrostatic/applicableForcingTendenciesMatchMatlab","TestPortableHydrostatic/orderedForcingTendenciesMatchMatlab","TestPortableHydrostatic/applicableForcingContinuationsMatchMatlab"];
        rowProviders = providers;
    else
        names = "TestPortableHydrostatic/incompatibleModelGraphsAreTransactional";
        rowProviders = "reference"; % Metadata-only preflight precedes provider construction.
    end
    for provider = rowProviders
        selected = tests(ismember(string({tests.name}),names));
        rows(end+1) = struct(id=string(row.id),provider=provider,acceptance=string(row.acceptance),rejection=string(row.matlab.rejection),testNames=names,passed=numel(selected)==numel(names) && all([selected.passed])); %#ok<AGROW>
    end
end
cases = readEvidence(folder,"hydro-continuation-*.json");
lifecycle = readEvidence(folder,"lifecycle-*.json");
[status,commit] = system("git -C "+shellQuote(root)+" rev-parse HEAD");
if status~=0, error("WaveVortexModel:QualificationSource","Cannot identify the qualification source commit."); end
[status,dirty] = system("git -C "+shellQuote(root)+" status --porcelain");
if status~=0, error("WaveVortexModel:QualificationSource","Cannot inspect qualification source status."); end
report = struct(schemaIdentifier=schemaIdentifier,schemaVersion=1,status="incomplete",sourceCommit=strtrim(string(commit)),workingTreeDirty=strlength(strtrim(string(dirty)))>0,matlabRelease=string(version("-release")),platform=string(computer),providers=providers,catalogPath="PortableRuntime/contracts/portable-forcing-compatibility-v1.json",catalogSHA256=sha256File(catalogPath),elapsedSeconds=toc(started),tests=tests,rows=rows,continuations={cases},lifecycle={lifecycle});
if all([tests.passed]) && ~any([tests.incomplete])
    report.status = "complete";
end
try
    validatePortableHydrostaticQualification(report,repositoryRoot=root);
catch exception
    report.status = "incomplete";
    writeJSON(outputPath,report);
    rethrow(exception);
end
writeJSON(outputPath,report);
assertSuccess(results);
end

function values = readEvidence(folder,pattern)
files = dir(fullfile(folder,pattern)); values = cell(1,numel(files));
for index=1:numel(files), values{index}=jsondecode(fileread(fullfile(files(index).folder,files(index).name))); end
end
function restoreEnvironment(names,values)
for index=1:numel(names), setenv(names(index),values(index)); end
end
function runCommand(command)
[status,output] = system("env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command);
if status~=0, error("WaveVortexModel:QualificationBuild","%s",output); end
end
function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end
function value = sha256File(path)
file = fopen(path,"rb"); cleanup=onCleanup(@()fclose(file)); bytes=fread(file,Inf,"*uint8");
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes); value=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
end
function writeJSON(path,value)
file=fopen(path,"w"); if file<0, error("WaveVortexModel:QualificationWrite","Unable to write %s.",path); end
cleanup=onCleanup(@()fclose(file)); fprintf(file,"%s\n",jsonencode(value,PrettyPrint=true));
end
