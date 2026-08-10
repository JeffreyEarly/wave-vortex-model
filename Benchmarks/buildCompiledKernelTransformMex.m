function mexPath = buildCompiledKernelTransformMex(options)
% Build the authoring-only compiled transform diagnostic gateway.
arguments
    options.outputDirectory (1,1) string = fullfile(fileparts(mfilename("fullpath")),"build")
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
sourceDirectory = fullfile(repositoryRoot,"CompiledKernel","src");
includeDirectory = fullfile(repositoryRoot,"CompiledKernel","include");
gateway = fullfile(repositoryRoot,"Benchmarks","compiled-kernel","wv_compiled_transform_mex.cpp");
fftwInclude = fullfile(matlabroot,"extern","include");
fftwLibrary = fullfile(matlabroot,"bin",computer("arch"),"libmwfftw3.3.dylib");
if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
mex("-R2018a","CXXFLAGS=$CXXFLAGS -std=c++17",gateway, ...
    fullfile(sourceDirectory,"WVKernelTypes.cpp"), ...
    fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"), ...
    fullfile(sourceDirectory,"WVFFTWEngine.cpp"), ...
    "-I"+includeDirectory,"-I"+fftwInclude,fftwLibrary, ...
    "-outdir",options.outputDirectory,"-output","wv_compiled_transform_mex");
mexPath = fullfile(options.outputDirectory,"wv_compiled_transform_mex."+mexext);
end
