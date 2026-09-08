function config = resolveStudyCase(caseId)
% Resolve a frozen case plus explicitly documented reference-only refinements.
arguments
    caseId (1,1) string
end
root=fileparts(mfilename('fullpath'));
inventory=jsondecode(fileread(fullfile(root,'case-inventory.json')));
refinement=jsondecode(fileread(fullfile(root,'reference-refinements.json')));
allCases=[inventory.calibration;inventory.withheld];
if caseId==string(inventory.larger.id)
    selected=inventory.larger;
elseif caseId==string(refinement.followup.id)
    selected=refinement.followup;
else
    ids=string({allCases.id}); index=find(ids==caseId,1);
    if isempty(index), error('WVStudy:UnknownCase','Choose a declared case id.'); end
    selected=allCases(index);
end
config=inventory.base; names=fieldnames(selected);
for j=1:length(names), config.(names{j})=selected.(names{j}); end
for j=1:length(refinement.cases)
    if caseId==string(refinement.cases(j).id)
        config.evpOrders=refinement.cases(j).evpOrders;
        config.referenceOrders=refinement.cases(j).referenceOrders;
    end
end
for name=["Lxy","Nxy","evpOrders","referenceOrders"], config.(name)=reshape(config.(name),1,[]); end
end
