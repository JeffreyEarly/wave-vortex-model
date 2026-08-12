function results = runCompiledKernelIssue128Screening(options)
% Run the issue #128 explicit controls and FFTW++ candidates in fresh processes.
arguments
    options.nativeBuildPath (1,1) string = "/private/tmp/issue128-native-build.mat"
    options.fftwppBuildPath (1,1) string = "/private/tmp/issue128-fftwpp-build.mat"
    options.outputDirectory (1,1) string
    options.sizes (:,3) double = [128 128 33; 256 256 65]
    options.warmupCount (1,1) double = 2
    options.mediumSampleCount (1,1) double = 3
    options.largeSampleCount (1,1) double = 1
    options.threadCount (1,1) double = 1
    options.samplingIntervalSeconds (1,1) double = 0.01
    options.plateauSeconds (1,1) double = 0.12
end
repositoryRoot = string(fileparts(fileparts(mfilename("fullpath")))); benchmarkFolder = fullfile(repositoryRoot,"Benchmarks");
if isfolder(options.outputDirectory), error("WaveVortexModel:Issue128OutputExists","Output exists: %s",options.outputDirectory); end
mkdir(options.outputDirectory);
native = load(options.nativeBuildPath); native = native.result;
prototype = load(options.fftwppBuildPath);
pthreads = native.providers(string({native.providers.id})=="native-neon-pthreads");
openmp = native.providers(string({native.providers.id})=="native-neon-openmp");
definitions = [configuration("native-pthreads-explicit",pthreads,"explicit",""),configuration("native-openmp-explicit",openmp,"explicit",""),configuration("fftwpp-implicit",prototype.p,"convolution","fftwpp-implicit"),configuration("fftwpp-hybrid",prototype.p,"convolution","fftwpp-hybrid")];
definitions(3).module = "wv_compiled_transform_mex_fftwpp"; definitions(3).mexPath = string(prototype.mexPath);
definitions(4).module = "wv_compiled_transform_mex_fftwpp"; definitions(4).mexPath = string(prototype.mexPath);
cases = caseDefinitions(options);
runs = repmat(struct(),0,1);
for iDefinition = 1:numel(definitions)
    definition = definitions(iDefinition); configPath = string(tempname)+".json"; outputPath = fullfile(options.outputDirectory,definition.id+".json"); cleanup = onCleanup(@()deleteIfPresent(configPath));
    config = struct("configurationId",definition.id,"processIndex",1,"threadCount",options.threadCount,"module",definition.module,"mexDirectory",string(fileparts(definition.mexPath)),"runtimeLibrary",definition.runtimeLibrary,"creationMode",definition.creationMode,"variant",definition.variant,"cases",cases,"repositoryRoot",repositoryRoot,"matlabPath",path,"samplerPath",fullfile(benchmarkFolder,"sampleProcessRSS.sh"),"samplingIntervalSeconds",options.samplingIntervalSeconds,"plateauSeconds",options.plateauSeconds);
    writeText(configPath,jsonencode(config));
    statement = "addpath('"+replace(benchmarkFolder,"'","''")+"'); compiledKernelIssue128Worker('"+replace(configPath,"'","''")+"','"+replace(outputPath,"'","''")+"')";
    command = sprintf('"%s" -batch "%s"',fullfile(matlabroot,"bin","matlab"),replace(statement,'"','\"'));
    fprintf("Issue #128 screening: %s\n",definition.id); [exitCode,commandOutput] = system(command);
    if exitCode ~= 0 || ~isfile(outputPath), error("WaveVortexModel:Issue128WorkerFailed","%s failed:\n%s",definition.id,commandOutput); end
    decoded = jsondecode(fileread(outputPath)); decoded.configuration = definition;
    if isempty(runs), runs = decoded; else, runs(end+1,1) = decoded; end %#ok<AGROW>
    clear cleanup
end
results = struct("status",conditional(all(string({runs.status})=="complete"),"complete","failed"),"sizes",options.sizes,"threadCount",options.threadCount,"runs",runs);
writeText(fullfile(options.outputDirectory,"screening.json"),jsonencode(results,PrettyPrint=true));
end

function value = configuration(id,provider,creationMode,variant)
value = struct("id",id,"providerId",string(provider.id),"threadBackend",string(provider.threadBackend),"module",string(provider.module),"mexPath",string(provider.mexPath),"baseLibrary",string(provider.baseLibrary),"threadLibrary",string(provider.threadLibrary),"runtimeLibrary",string(provider.runtimeLibrary),"creationMode",creationMode,"variant",variant);
end

function cases = caseDefinitions(options)
cases = repmat(struct("id","","Nxyz",[],"isHydrostatic",false,"seed",0,"warmupCount",options.warmupCount,"sampleCount",0),0,1);
for iSize = 1:size(options.sizes,1)
    samples = options.mediumSampleCount; if iSize == size(options.sizes,1), samples = options.largeSampleCount; end
    for hydrostatic = [true false]
        Nxyz = options.sizes(iSize,:); id = sprintf("%s-%dx%dx%d",conditional(hydrostatic,"hydrostatic","nonhydrostatic"),Nxyz(1),Nxyz(2),Nxyz(3));
        cases(end+1,1) = struct("id",id,"Nxyz",Nxyz,"isHydrostatic",hydrostatic,"seed",128000+sum(Nxyz)+100*hydrostatic,"warmupCount",options.warmupCount,"sampleCount",samples); %#ok<AGROW>
    end
end
end

function writeText(pathname,contents)
fileId = fopen(pathname,"w"); if fileId < 0, error("WaveVortexModel:Issue128Artifact","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",contents); clear cleanup
end

function deleteIfPresent(pathname)
if isfile(pathname), delete(pathname); end
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
