function [mexPath,build] = buildCompiledKernelTransformMex(options)
% Build the authoring-only compiled transform diagnostic gateway.
arguments
    options.outputDirectory (1,1) string = fullfile(fileparts(mfilename("fullpath")),"build")
    options.outputName (1,1) string = ""
    options.provider (1,1) struct = struct()
    options.issue130Variant (1,1) double {mustBeMember(options.issue130Variant,[0 2 3 4])} = 0
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
sourceDirectory = fullfile(repositoryRoot,"CompiledKernel","src");
includeDirectory = fullfile(repositoryRoot,"CompiledKernel","include");
gatewayDirectory = fullfile(repositoryRoot,"Benchmarks","compiled-kernel");
gateway = fullfile(gatewayDirectory,"wv_compiled_transform_mex.cpp");
provider = normalizedProvider(options.provider);
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
if options.outputName == ""
    options.outputName = "wv_compiled_transform_mex";
end
compilerFlags = "CXXFLAGS=$CXXFLAGS -std=c++17 -pthread -O3 -mcpu=native" + ...
    " -DWV_KERNEL_NATIVE_OPTIMIZATION=1" + ...
    " -DWV_KERNEL_COEFFICIENT_WORKERS=2" + ...
    " -DWV_KERNEL_ISSUE130_VARIANT="+options.issue130Variant;
mexArguments = {"-R2018a",compilerFlags,gateway, ...
    fullfile(sourceDirectory,"WVKernelTypes.cpp"), ...
    fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"), ...
    fullfile(gatewayDirectory,"WVFFTWEngine.cpp"), ...
    "-I"+includeDirectory,"-I"+gatewayDirectory,"-I"+provider.includeDirectory};
if ~isempty(provider.rpathDirectories)
    mexArguments{end+1} = "LDFLAGS=$LDFLAGS -pthread " + join("-Wl,-rpath,"+provider.rpathDirectories," ");
else
    mexArguments{end+1} = "LDFLAGS=$LDFLAGS -pthread";
end
mexArguments = [mexArguments reshape(cellstr(provider.linkLibraries),1,[])];
mexArguments = [mexArguments {"-outdir",options.outputDirectory,"-output",options.outputName}];
mex(mexArguments{:});
mexPath = fullfile(options.outputDirectory,options.outputName+"."+mexext);
build = provider;
build.module = options.outputName;
build.mexPath = string(mexPath);
build.mexSha256 = sha256File(mexPath);
end

function provider = normalizedProvider(provider)
if isempty(fieldnames(provider))
    provider = struct( ...
        "id","matlab-bundled", ...
        "version","3.3.8", ...
        "threadBackend","pthreads", ...
        "includeDirectory",string(fullfile(matlabroot,"extern","include")), ...
        "linkLibraries",string(fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib")), ...
        "rpathDirectories",strings(1,0));
    return
end
required = ["id" "version" "threadBackend" "includeDirectory" "linkLibraries" "rpathDirectories"];
for name = required
    if ~isfield(provider,name), error("WaveVortexModel:CompiledKernelProvider","Provider descriptor is missing %s.",name); end
end
provider.id = string(provider.id);
provider.version = string(provider.version);
provider.threadBackend = string(provider.threadBackend);
provider.includeDirectory = string(provider.includeDirectory);
provider.linkLibraries = string(provider.linkLibraries);
provider.rpathDirectories = string(provider.rpathDirectories);
if ~isfolder(provider.includeDirectory), error("WaveVortexModel:CompiledKernelProvider","Provider include directory does not exist: %s",provider.includeDirectory); end
if any(~isfile(provider.linkLibraries)), error("WaveVortexModel:CompiledKernelProvider","A provider link library is missing: %s",strjoin(provider.linkLibraries(~isfile(provider.linkLibraries)),", ")); end
end

function hash = sha256File(pathname)
[status,output] = system(sprintf('/usr/bin/shasum -a 256 "%s"',pathname));
if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end
