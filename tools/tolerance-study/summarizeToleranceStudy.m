function summary = summarizeToleranceStudy(outputFolder)
% Extract phase and invariant diagnostics from the bounded comparison archive.
arguments (Input)
    outputFolder (1,1) string
end
summary=readtable(fullfile(outputFolder,'comparison.csv'),TextType="string");
summary.wavePhaseError=zeros(height(summary),1);
summary.energyChange=zeros(height(summary),1);
summary.boundaryVarianceChange=nan(height(summary),1);
summary.potentialEnstrophyChange=nan(height(summary),1);
for i=1:height(summary)
    row=summary(i,:);
    if row.policy=="energy-practical"
        path=fullfile(outputFolder,row.caseName+'-practical.mat');
    else
        path=fullfile(outputFolder,sprintf('%s-%s-%g.mat',row.caseName,row.policy,row.absoluteScale));
    end
    record=load(path); ref=load(fullfile(outputFolder,row.caseName+'-reference.mat'));
    a=record.actual;
    summary.energyChange(i)=(a.finalBudget.totalEnergy-a.initialBudget.totalEnergy)/a.initialBudget.totalEnergy;
    if isfield(a.initialBudget,'surfaceAnomalyVariance')
        summary.boundaryVarianceChange(i)=(a.finalBudget.surfaceAnomalyVariance-a.initialBudget.surfaceAnomalyVariance)/a.initialBudget.surfaceAnomalyVariance;
        initial=a.initialBudget.potentialEnstrophy;
        if initial>0, summary.potentialEnstrophyChange(i)=(a.finalBudget.potentialEnstrophy-initial)/initial; end
    end
    for name=["Aw_p","Aw_m"]
        if ~isfield(a.state,name), continue; end
        expected=ref.tighter.state.(name);
        significant=abs(expected)>1e-6*max(abs(expected),[],'all');
        if any(significant,'all')
            phase=angle(a.state.(name)(significant).*conj(expected(significant)));
            summary.wavePhaseError(i)=max(summary.wavePhaseError(i),max(abs(phase)));
        end
    end
end
writetable(summary,fullfile(outputFolder,'summary.csv'));
end
