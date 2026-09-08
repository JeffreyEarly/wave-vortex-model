function summary = runSourceSurvey(config,outputDirectory,options)
% Survey explicitly bounded physical products, saving errors for policy replay.
arguments
    config (1,1) struct
    outputDirectory (1,1) string
    options.interactionIndices (1,:) double = []
    options.policy (1,1) string {mustBeMember(options.policy,["dense","fixed","targeted"])} = "dense"
end
if isfolder(outputDirectory), error('WVStudy:ExistingOutput','Preserve previous results; choose a new directory: %s',outputDirectory); end
mkdir(outputDirectory);
writeJSON(fullfile(outputDirectory,'configuration.json'),config);
data=prepareSourceStudy(config);
fprintf('Source construction %.2f s; %d vector interactions.\n',data.constructionSeconds,height(data.inventory.interactions));
evidence=measureSourceProducts(data,interactionIndices=options.interactionIndices,policy=options.policy,showProgress=true);
raw=evidence.raw; inventory=evidence.inventory; summary=evidence.summary; rows=evidence.rows;
writetable(inventory.interactions,fullfile(outputDirectory,'interactions.csv'));
writetable(evidence.channels,fullfile(outputDirectory,'channels.csv'));
writetable(rows,fullfile(outputDirectory,'products.csv'));
writeJSON(fullfile(outputDirectory,'summary.json'),summary);
save(fullfile(outputDirectory,'products.mat'),'raw','inventory','summary','rows','-v7');
fprintf('Source survey: %d nonzero products in %.2f s; reference %.3g; eigen/derivatives %.3g.\n',summary.nonzeroProductEvaluations,summary.assessmentSeconds,summary.referenceStability,summary.eigenConvergence);
end

function writeJSON(file,value)
fid=fopen(file,'w'); if fid<0, error('WVStudy:OutputFailure','Cannot write %s.',file); end
cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
