root="/Users/jearly/Documents/OceanKitRepositories/wvm-v4-cpp-adoption-audit";
cd(root); addpath(fullfile(root,"tools"));
configureCIEnvironment(root,"/Users/jearly/Documents/OceanKitRepositories/OceanKit",documentationPackageSpecifier="ClassDocumentation@1.3.2");
addpath(fullfile(root,"UnitTests"),"-begin");
for provider=["reference","native-fftw"]
    report=collectPortableForwardIntegrationQualification("/private/tmp/wvm391-density-event-forward-refresh-evidence",provider,repositoryRoot=root);
    fprintf("COLLECTED provider=%s cases=%d source=%s\n",provider,numel(report.cases),report.sourceCommit);
end
suite=testsuite(fullfile(root,"UnitTests","TestPortableForwardIntegrationCatalog.m"));
suite=suite(contains(string({suite.Name}),"committedReceiptsEstablishExecutedQualification"));
assert(numel(suite)==1);
results=run(suite); disp(results);
file=fopen('/private/tmp/wvm391-density-event-forward-catalog-results.json','w');
fwrite(file,jsonencode(struct(name={results.Name},passed={results.Passed},failed={results.Failed},incomplete={results.Incomplete},duration={results.Duration}),PrettyPrint=true));
fclose(file);
assertSuccess(results);
