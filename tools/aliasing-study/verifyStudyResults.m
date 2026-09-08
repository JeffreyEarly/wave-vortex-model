function verifyStudyResults()
% Verify each measured sparse replay and run the focused scientific controls.
studyRoot=string(fileparts(mfilename('fullpath')));
inventory=jsondecode(fileread(fullfile(studyRoot,'case-inventory.json')));
refinements=jsondecode(fileread(fullfile(studyRoot,'reference-refinements.json')));
caseIds=[string({inventory.calibration.id}),string({inventory.withheld.id}),string(refinements.followup.id)];
for caseId=caseIds
    if startsWith(caseId,"cal-")
        root="calibration-v1"; suffix="-scores-v2";
    elseif contains(caseId,"pycnocline")
        root="withheld-refined-v1"; suffix="-scores";
    else
        root="withheld-v1"; suffix="-scores";
    end
    dense=fullfile(studyRoot,'results',root,caseId);
    scores=fullfile(studyRoot,'results',root,caseId+suffix);
    for policy=["fixed","targeted"]
        replay=fullfile(studyRoot,'results','cost-matrix-v1',caseId+"--"+policy);
        verifySparseReplay(dense,replay,scores);
    end
end
repositoryRoot=fileparts(fileparts(studyRoot));
tests=[fullfile(studyRoot,"TestProductProjection.m"),fullfile(studyRoot,"TestSourceProjection.m"),fullfile(studyRoot,"TestSparseStudyPolicies.m"),fullfile(repositoryRoot,"UnitTests","TestFreeSurfaceWaveModes.m")];
results=runtests(tests);
disp(results);
plotStudyComparison();
files=dir(fullfile(studyRoot,'*.m'));
findings=cell(numel(files),1);
for i=1:numel(files)
    findings{i}=struct(file=string(files(i).name),messages=checkcode(fullfile(files(i).folder,files(i).name),'-id'));
end
report=struct(replayCount=2*numel(caseIds),testCount=numel(results),testsPassed=all([results.Passed]),codeAnalyzer={findings});
fid=fopen(fullfile(studyRoot,'results','final-verification.json'),'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
assertSuccess(results);
end
