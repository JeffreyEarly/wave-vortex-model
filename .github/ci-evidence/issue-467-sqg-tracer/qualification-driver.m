root = "/Users/jearly/Documents/OceanKitRepositories/wvm-v4-issue467-tracer";
oceanKitRoot = "/Users/jearly/Documents/OceanKitRepositories/OceanKit";
logPath = "/private/tmp/wvm467-final-qualification.log";
receiptPath = "/private/tmp/wvm467-final-qualification.json";
if isfile(logPath)
    delete(logPath);
end
diary(logPath);
cleanup = onCleanup(@()diary("off"));
addpath(fullfile(root,"tools"));
configureCIEnvironment(root,oceanKitRoot);
cd(root);
assert(startsWith(which("WVModel"),root));
assert(startsWith(which("WVNonlinearAdvection"),root));
[status,head] = system("git -C '"+root+"' rev-parse HEAD");
assert(status == 0);
head = strip(string(head));
assert(head == "9641226c206342712b5df871ee3bfb37a44469fa");

suite = [testsuite(fullfile(root,"UnitTests","TestSQGTracerConvenience.m")),testsuite(fullfile(root,"UnitTests","TestObservingSystems.m"),Name="*particleAndTracerFacadesExposeCurrentState"),testsuite(fullfile(root,"UnitTests","TestWVModelOutputPersistence.m"),Name="*barotropicParticlesAndTracerRoundTrip")];
results = run(suite);
disp(table(results));

testRecords = repmat(struct("name","","passed",false,"failed",false,"incomplete",false,"duration",0),numel(results),1);
for index = 1:numel(results)
    testRecords(index).name = string(results(index).Name);
    testRecords(index).passed = results(index).Passed;
    testRecords(index).failed = results(index).Failed;
    testRecords(index).incomplete = results(index).Incomplete;
    testRecords(index).duration = seconds(results(index).Duration);
end

analyzerPaths = [
    fullfile(root,"@WVModel","WVModel.m")
    fullfile(root,"UnitTests","TestSQGTracerConvenience.m")
    ];
analyzerRecords = repmat(struct("path","","findingCount",0,"findings",struct([])),numel(analyzerPaths),1);
for index = 1:numel(analyzerPaths)
    findings = checkcode(analyzerPaths(index),"-id");
    analyzerRecords(index).path = erase(analyzerPaths(index),root+filesep);
    analyzerRecords(index).findingCount = numel(findings);
    analyzerRecords(index).findings = findings;
    fprintf("CODE_ANALYZER file=%s findings=%d\n",analyzerRecords(index).path,numel(findings));
end

receipt = struct;
receipt.schema = "wvm-sqg-tracer-convenience-qualification-v1";
receipt.issue = 467;
receipt.sourceCommit = head;
receipt.sourceRoot = root;
receipt.matlabRelease = string(version("-release"));
receipt.platform = string(computer);
receipt.pathResolution = struct("WVModel",string(which("WVModel")),"WVNonlinearAdvection",string(which("WVNonlinearAdvection")));
receipt.tests = testRecords;
receipt.analyzer = analyzerRecords;
receipt.scientificRerunAfterQualification = false;
encoded = jsonencode(receipt,PrettyPrint=true);
file = fopen(receiptPath,"w");
assert(file >= 0);
fileCleanup = onCleanup(@()fclose(file));
fprintf(file,"%s\n",encoded);
clear fileCleanup;
assertSuccess(results);
