function mexPath = buildCompiledKernelTransformMex(options)
% Build the authoring-only compiled transform diagnostic gateway.
arguments
    options.outputDirectory (1,1) string = fullfile(fileparts(mfilename("fullpath")),"build")
    options.outputName (1,1) string = ""
    options.phaseImplementation (1,1) string {mustBeMember(options.phaseImplementation,["scalar" "accelerate"])} = defaultPhaseImplementation
    options.optimizationLevel (1,1) string {mustBeMember(options.optimizationLevel,["default" "native"])} = "default"
    options.shouldReportVectorization (1,1) logical = false
    options.modalWorkerCount (1,1) double {mustBeMember(options.modalWorkerCount,[1 2 4 8])} = 1
    options.modalCoefficientMode (1,1) string {mustBeMember(options.modalCoefficientMode,["compact" "prescaled"])} = "prescaled"
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
compilerFlags = "CXXFLAGS=$CXXFLAGS -std=c++17 -pthread -DWV_KERNEL_USE_ACCELERATE_PHASE="+string(options.phaseImplementation=="accelerate")+" -DWV_KERNEL_MODAL_WORKERS="+options.modalWorkerCount+" -DWV_KERNEL_USE_PRESCALED_MODAL_COEFFICIENTS="+string(options.modalCoefficientMode=="prescaled")+" -DWV_KERNEL_NATIVE_OPTIMIZATION="+string(options.optimizationLevel=="native");
if options.optimizationLevel=="native", compilerFlags=compilerFlags+" -O3 -mcpu=native"; end
if options.shouldReportVectorization, compilerFlags=compilerFlags+" -Rpass=loop-vectorize -Rpass-missed=loop-vectorize -Rpass-analysis=loop-vectorize"; end
linkerFlags="LDFLAGS=$LDFLAGS -pthread";
if options.phaseImplementation=="accelerate", linkerFlags=linkerFlags+" -framework Accelerate"; end
mex("-R2018a",compilerFlags,gateway, ...
    fullfile(sourceDirectory,"WVKernelTypes.cpp"), ...
    fullfile(sourceDirectory,"WVTransformConstantStratificationKernel.cpp"), ...
    fullfile(gatewayDirectory,"WVFFTWEngine.cpp"), ...
    "-I"+includeDirectory,"-I"+gatewayDirectory,"-I"+fftwInclude,fftwLibrary,linkerFlags, ...
    "-outdir",options.outputDirectory,"-output",options.outputName);
mexPath = fullfile(options.outputDirectory,options.outputName+"."+mexext);
end

function value=defaultPhaseImplementation
if ismac, value="accelerate"; else, value="scalar"; end
end
