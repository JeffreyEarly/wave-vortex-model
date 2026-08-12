function [mexPath,build] = buildCompiledKernelFFTWPlusPlusPrototype(options)
% Build the pinned issue #128 FFTW++ experimental MEX gateway.
arguments
    options.outputDirectory (1,1) string
    options.outputName (1,1) string = "wv_compiled_transform_mex_fftwpp"
    options.provider (1,1) struct
    options.fftwppSourceRoot (1,1) string
    options.openMPIncludeDirectory (1,1) string
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
sourceDirectory = fullfile(repositoryRoot,"CompiledKernel","src");
includeDirectory = fullfile(repositoryRoot,"CompiledKernel","include");
gatewayDirectory = fullfile(repositoryRoot,"Benchmarks","compiled-kernel");
requiredSourceCommit = "1a185f41800cd0e9d4df4ddf93e16e362d4e2c45";
if ~isfolder(options.fftwppSourceRoot), error("WaveVortexModel:FFTWPlusPlusSourceMissing","Pinned FFTW++ source root is missing: %s",options.fftwppSourceRoot); end
[status,commit] = system("git -C "+shellQuote(options.fftwppSourceRoot)+" rev-parse HEAD");
if status ~= 0 || string(strtrim(commit)) ~= requiredSourceCommit, error("WaveVortexModel:FFTWPlusPlusSourceIdentity","FFTW++ must resolve to pinned commit %s.",requiredSourceCommit); end
if ~isfolder(options.openMPIncludeDirectory), error("WaveVortexModel:FFTWPlusPlusOpenMPHeaders","Pinned LLVM OpenMP headers are missing: %s",options.openMPIncludeDirectory); end
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end

compilerFlags = "CXXFLAGS=$CXXFLAGS -std=c++17 -pthread -O3 -mcpu=native" + ...
    " -DWV_KERNEL_NATIVE_OPTIMIZATION=1 -DWV_KERNEL_COEFFICIENT_WORKERS=1" + ...
    " -DWV_KERNEL_HAS_FFTWPP=1 -Xpreprocessor -fopenmp" + ...
    " -I"+options.openMPIncludeDirectory;
rpaths = unique([string(options.provider.rpathDirectories) string(fileparts(options.provider.runtimeLibrary))],"stable");
linkerFlags = "LDFLAGS=$LDFLAGS -pthread "+join("-Wl,-rpath,"+rpaths," ");
mexArguments = {"-R2018a",compilerFlags, ...
    fullfile(gatewayDirectory,"wv_compiled_transform_mex.cpp"), ...
    fullfile(gatewayDirectory,"WVFFTWPlusPlusConvolution.cpp"), ...
    fullfile(sourceDirectory,"WVKernelTypes.cpp"), ...
    fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"), ...
    fullfile(gatewayDirectory,"WVFFTWEngine.cpp"), ...
    fullfile(options.fftwppSourceRoot,"fftw++.cc"), ...
    fullfile(options.fftwppSourceRoot,"parallel.cc"), ...
    fullfile(options.fftwppSourceRoot,"convolve.cc"), ...
    "-I"+includeDirectory,"-I"+gatewayDirectory,"-I"+options.provider.includeDirectory,"-I"+options.fftwppSourceRoot,linkerFlags};
mexArguments = [mexArguments reshape(cellstr(options.provider.linkLibraries),1,[]) {char(options.provider.runtimeLibrary),"-outdir",char(options.outputDirectory),"-output",char(options.outputName)}];
mex(mexArguments{:});
mexPath = fullfile(options.outputDirectory,options.outputName+"."+mexext);
build = struct("module",options.outputName,"mexPath",string(mexPath),"mexSha256",sha256File(mexPath),"fftwppCommit",requiredSourceCommit,"fftwppTree",gitValue(options.fftwppSourceRoot,"rev-parse HEAD^{tree}"));
end

function value = gitValue(root,arguments)
[status,output] = system("git -C "+shellQuote(root)+" "+arguments);
if status ~= 0, error("WaveVortexModel:FFTWPlusPlusSourceIdentity","Unable to inspect FFTW++ source identity."); end
value = string(strtrim(output));
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end
