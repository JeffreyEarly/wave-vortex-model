function runReferenceRefinements(outputRoot)
% Requalify unresolved references and run the declared resolution follow-up.
arguments
    outputRoot (1,1) string
end
root=fileparts(mfilename('fullpath'));
refinement=jsondecode(fileread(fullfile(root,'reference-refinements.json')));
ids=[string({refinement.cases.id}),string(refinement.followup.id)];
for id=ids
    config=resolveStudyCase(id); destination=fullfile(outputRoot,id);
    if ~isfile(fullfile(destination,'summary.json')), runSourceSurvey(config,destination); end
    scoreDirectory=fullfile(outputRoot,id+"-scores");
    if ~isfile(fullfile(scoreDirectory,'scores.csv')), scoreSourcePolicies(destination,scoreDirectory); end
    diagnosticFile=fullfile(scoreDirectory,'quadratic-diagnostics.csv');
    if ~isfile(diagnosticFile), scoreQuadraticDiagnostics(destination,scoreDirectory,diagnosticFile); end
end
end
