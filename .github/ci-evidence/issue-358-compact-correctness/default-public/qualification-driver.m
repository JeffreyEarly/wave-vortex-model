root = "/Users/jearly/Documents/OceanKitRepositories/wvm-v4-cpp-adoption-audit";
addpath(fullfile(root,"tools"));
configureCIEnvironment(root,"/Users/jearly/Documents/OceanKitRepositories/OceanKit",documentationPackageSpecifier="ClassDocumentation@1.3.2");
exportRoot = "/private/tmp/wvm358-public-default-export";
addpath(exportRoot,"-begin");clear WVCompiledBackend
assert(startsWith(string(which("WVCompiledBackend")),exportRoot));
capabilities = WVCompiledBackend.buildForTesting(struct(PackageRoot=exportRoot,CommandFunction=@rejectProviderMutation));
writeJSON("/private/tmp/wvm358-default-public-capabilities.json",capabilities);
assert(capabilities.status=="available",capabilities.failure.message);
assert(string(capabilities.module.nonlinearFluxSchedule)=="streamed-target-three-channel");
assert(capabilities.contract.planCount==17 && capabilities.contract.version==4);
fprintf("DEFAULT_PUBLIC_BUILD_PASS error=%.17g schedule=%s\n",capabilities.featureValidation.maximumRelativeError,capabilities.module.nonlinearFluxSchedule);
function [status,output] = rejectProviderMutation(command,logPath)
    error("WaveVortexModel:QualificationProviderMutation","Prepared provider unexpectedly requested a command: %s; log %s",command,logPath);
    status = 1; output = ""; %#ok<UNRCH>
end
function writeJSON(path,value)
    f = fopen(path,"w");assert(f>=0);cleanup = onCleanup(@()fclose(f));fwrite(f,jsonencode(value,PrettyPrint=true));
end
