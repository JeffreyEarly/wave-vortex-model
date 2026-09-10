function results = collectManuscriptTrajectoryStudies(outputFolder,runFolders,runNames)
% Collect trajectory observations and compare independent common-grid fields.
arguments (Input)
    outputFolder (1,1) string
    runFolders (:,1) string
    runNames (:,1) string
end
assert(numel(runFolders)==numel(runNames),'Supply one name per run folder.');
if ~isfolder(outputFolder), mkdir(outputFolder); end
rows=cell(numel(runFolders),1); histories=rows;
for j=1:numel(runFolders)
    path=fullfile(runFolders(j),'manuscript-trajectories.csv');
    assert(isfile(path),'Missing completed study: %s',path);
    rows{j}=readtable(path,TextType='string');
    rows{j}.run=repmat(runNames(j),height(rows{j}),1);
    histories{j}=readtable(fullfile(runFolders(j),'manuscript-trajectories-history.csv'),TextType='string');
    histories{j}.run=repmat(runNames(j),height(histories{j}),1);
end
results=vertcat(rows{:}); history=vertcat(histories{:});
% Every fixture has the explicitly prescribed mean endpoint offsets +/-2a.
% Keep that support separate from the spatially varying anomaly scale.
results.initialSurfaceVariationScale=sqrt(max(0,results.initialSurfaceScale.^2-(2*results.amplitude).^2));
results.initialBottomVariationScale=sqrt(max(0,results.initialBottomScale.^2-(2*results.amplitude).^2));
results.initialSurfaceVariationScale(results.initialSurfaceVariationScale<1e-7*results.amplitude)=NaN;
results.initialBottomVariationScale(results.initialBottomVariationScale<1e-7*results.amplitude)=NaN;
results.surfaceMismatchOverVariation=results.accumulatedSurface./results.initialSurfaceVariationScale;
results.bottomMismatchOverVariation=results.accumulatedBottom./results.initialBottomVariationScale;
results.commonSeedDifference=nan(height(results),1);
results.commonFinalDifference=nan(height(results),1);
results.commonFinalDifferenceToHorizontal16=nan(height(results),1);
for j=1:height(results)
    row=results(j,:);
    matches=find(results.profile==row.profile & results.scenario==row.scenario & results.configuration==3 & results.amplitude==1 & results.Nz==129 & results.Nxy==8 & results.padding==2 & ~results.ragged & results.deltaT==10,1);
    if isempty(matches), continue; end
    base=results(matches,:);
    folder=runFolders(runNames==row.run); baseFolder=runFolders(runNames==base.run);
    a=load(fullfile(folder,sprintf('checkpoint-config%d-dt%g.mat',row.configuration,row.deltaT)),'initialVector','finalVector');
    b=load(fullfile(baseFolder,sprintf('checkpoint-config%d-dt%g.mat',base.configuration,base.deltaT)),'initialVector','finalVector');
    results.commonSeedDifference(j)=norm(a.initialVector/row.amplitude-b.initialVector)/norm(b.initialVector);
    assert(results.commonSeedDifference(j)<1e-7,'A cross-run control changed the initial physical state.');
    if row.amplitude==1
        results.commonFinalDifference(j)=norm(a.finalVector-b.finalVector)/norm(b.finalVector);
        fineIndex=find(results.profile==row.profile & results.scenario==row.scenario & results.configuration==3 & results.amplitude==1 & results.Nxy==16 & results.deltaT==10,1);
        if ~isempty(fineIndex)
            fine=results(fineIndex,:); fineFolder=runFolders(runNames==fine.run);
            f=load(fullfile(fineFolder,sprintf('checkpoint-config%d-dt%g.mat',fine.configuration,fine.deltaT)),'finalVector');
            results.commonFinalDifferenceToHorizontal16(j)=norm(a.finalVector-f.finalVector)/norm(f.finalVector);
        end
    end
end
writetable(results,fullfile(outputFolder,'manuscript-evolution-summary.csv'));
writetable(history,fullfile(outputFolder,'manuscript-evolution-history.csv'));
end
