function runStudyCases(split,outputRoot)
% Execute the predeclared case split, preserving each completed run.
arguments
    split (1,1) string {mustBeMember(split,["calibration","withheld"])}
    outputRoot (1,1) string
end
root=fileparts(mfilename('fullpath'));
inventory=jsondecode(fileread(fullfile(root,'case-inventory.json')));
cases=inventory.(split);
for j=1:length(cases)
    config=inventory.base;
    names=fieldnames(cases(j));
    for k=1:length(names), config.(names{k})=cases(j).(names{k}); end
    % JSON array orientation is not part of the scientific case contract.
    for name=["Lxy","Nxy","evpOrders","referenceOrders"], config.(name)=reshape(config.(name),1,[]); end
    destination=fullfile(outputRoot,config.id);
    if isfile(fullfile(destination,'summary.json'))
        fprintf('Preserving completed case %s.\n',config.id);
    else
        runSourceSurvey(config,destination);
    end
    scoreDirectory=fullfile(outputRoot,config.id+"-scores");
    if ~isfile(fullfile(scoreDirectory,'scores.csv'))
        scoreSourcePolicies(destination,scoreDirectory);
    end
    diagnosticFile=fullfile(scoreDirectory,'quadratic-diagnostics.csv');
    if ~isfile(diagnosticFile)
        scoreQuadraticDiagnostics(destination,scoreDirectory,diagnosticFile);
    end
end
end
