function plotStudyComparison()
% Plot retained-space product errors from the common saved dense survey.
studyRoot=string(fileparts(mfilename('fullpath')));
inventory=jsondecode(fileread(fullfile(studyRoot,'case-inventory.json')));
caseIds=[string({inventory.calibration.id}),string({inventory.withheld.id}),"followup-pycnocline-129"];
fig=figure(Visible='off',Position=[0 0 1350 1000],Color='white');
cleanup=onCleanup(@()close(fig));
layout=tiledlayout(fig,3,3,TileSpacing='compact',Padding='compact');
for i=1:numel(caseIds)
    caseId=caseIds(i);
    if startsWith(caseId,"cal-")
        root="calibration-v1"; suffix="-scores-v2";
    elseif contains(caseId,"pycnocline")
        root="withheld-refined-v1"; suffix="-scores";
    else
        root="withheld-v1"; suffix="-scores";
    end
    directory=fullfile(studyRoot,'results',root);
    t=readtable(fullfile(directory,caseId+suffix,'prefix-errors.csv'));
    summary=jsondecode(fileread(fullfile(directory,caseId,'summary.json')));
    nexttile(layout);
    semilogy(t.waveCount,t.denseError,'k-',LineWidth=1.5); hold on
    semilogy(t.waveCount,t.fixedError,'o--',Color=[0 0.4 0.75],MarkerSize=3);
    semilogy(t.waveCount,t.targetedError,'x:',Color=[0.85 0.35 0],MarkerSize=4);
    for tolerance=[.1 .03 .01], yline(tolerance,':',Color=[.6 .6 .6]); end
    first=find(t.gramError>1e-7,1);
    if ~isempty(first), xline(first-.5,'--',Color=[.5 .2 .6]); end
    label=replace(caseId,["cal-","withheld-","followup-"],["Cal: ","Held: ","Follow-up: "]);
    if ~summary.fixedFamiliesGramAccepted, label=label+" (fixed families reject)"; end
    title(label,FontSize=10,Interpreter='none');
    grid on; xlim([1 height(t)]); ylim([1e-8 2]);
    if mod(i,3)==1, ylabel('Normalized retained-coefficient error'); end
    if i>6, xlabel('Candidate wave count'); end
    if i==1, legend('Dense','Fixed sparse','Targeted sparse',Location='northwest'); end
end
title(layout,{'Individual-product aliasing within the bounded inventory', ...
    'Dotted horizontal lines: 0.1, 0.03, 0.01; vertical line: first failed wave Gram prefix'},FontSize=14);
exportgraphics(fig,fullfile(studyRoot,'results','prefix-comparison.png'),Resolution=150);
end
