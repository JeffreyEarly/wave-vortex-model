function mexPath = buildCompiledKernelTransformMex(options)
% Build the authoring-only compiled transform diagnostic gateway.
arguments
    options.outputDirectory (1,1) string = fullfile(fileparts(mfilename("fullpath")),"build")
    options.schedule (1,1) string {mustBeMember(options.schedule,["sequential" "paired"])} = "sequential"
    options.outputName (1,1) string = ""
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
sourceDirectory = fullfile(repositoryRoot,"CompiledKernel","src");
includeDirectory = fullfile(repositoryRoot,"CompiledKernel","include");
gatewayDirectory = fullfile(repositoryRoot,"Benchmarks","compiled-kernel");
gateway = fullfile(gatewayDirectory,"wv_compiled_transform_mex.cpp");
fftwInclude = fullfile(matlabroot,"extern","include");
fftwLibrary = fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib");
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
if options.outputName == ""
    options.outputName = "wv_compiled_transform_mex";
end
compilerFlags = "CXXFLAGS=$CXXFLAGS -std=c++17";
if options.schedule == "paired"
    compilerFlags = compilerFlags + " -DWV_KERNEL_PAIRED_SCHEDULE=1";
end
mex("-R2018a",compilerFlags,gateway, ...
    fullfile(sourceDirectory,"WVKernelTypes.cpp"), ...
    fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"), ...
    fullfile(gatewayDirectory,"WVFFTWEngine.cpp"), ...
    "-I"+includeDirectory,"-I"+gatewayDirectory,"-I"+fftwInclude,fftwLibrary, ...
    "-outdir",options.outputDirectory,"-output",options.outputName);
mexPath = fullfile(options.outputDirectory,options.outputName+"."+mexext);
end
