function result = investigateShortWaveProductReferences(outputDirectory)
% Reproduce the short-wave reference failure and isolate its numerical cause.
%
% This bounded authoring investigation writes diagnostics and verification,
% without changing modes, count-map decisions or reference tolerances.
arguments (Input)
    outputDirectory (1,1) string
end
arguments (Output)
    result (1,1) struct
end
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('WVStudy:OutputAlreadyExists','Choose a new investigation output directory.');
end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
record=fullfile(root,'Documentation','Validation','Issue425','kappa-dependent');
p=jsondecode(fileread(fullfile(record,'provenance.json'))); config=p.configuration;
for name=["Lxy","Nxy","evpOrders","referenceOrders"], config.(name)=reshape(config.(name),1,[]); end
triads=readtable(fullfile(record,'selected-triads.csv'));
started=tic; data=prepareSourceStudy(config);
evidence=WVInternal.measureSourceProducts(data,interactionIndices=triads.interactionIndex.',policy="fixed");
failed=evidence.rows(evidence.rows.referenceStability>config.referenceAllowance | evidence.rows.eigenProductStability>config.referenceAllowance,:);
assert(~isempty(failed) && all(failed.inputA=="boundary" & failed.inputB=="boundary"),'Recheck the diagnosis if another family fails.');
allFailures=table();
for row=1:height(failed)
    diagnostic=diagnoseBoundaryProductReferences(data,failed.interaction(row),failed.channel(row));
    allFailures=[allFailures;labelRows(diagnostic,0,config)]; %#ok<AGROW>
end
same=allFailures.endpointA==allFailures.endpointB;
metrics=["normalizationChange","coefficientChange","quadratureNormalizationChange","quadratureCoefficientChange"];
assert(all(allFailures{same,metrics}<config.referenceAllowance,'all'),'The same-boundary controls must qualify independently.');
assert(all(allFailures.analyticalErrorOverFactorBound<1e-8),'The small absolute-error diagnosis needs review.');
[~,evpWorst]=max(failed.eigenProductStability); [~,quadratureWorst]=max(failed.referenceStability);
selected=failed([evpWorst quadratureWorst],:);
productRows=table(); fieldRows=table(); configurations=cell(4,1);
for trial=1:4
    cfg=config;
    if trial==2, cfg.evpOrders=[256 384]; end
    if trial==3, cfg.referenceOrders=[513 1025]; end
    if trial==4, cfg.profile="constant"; end
    configurations{trial}=cfg;
    if trial>1, data=prepareSourceStudy(cfg); end
    for row=1:height(selected)
        diagnostic=diagnoseBoundaryProductReferences(data,selected.interaction(row),selected.channel(row));
        productRows=[productRows;labelRows(diagnostic,trial,cfg)]; %#ok<AGROW>
        fieldRows=[fieldRows;table(trial,string(cfg.profile),diagnostic.interactionIndex,max(diagnostic.fieldRelativeErrors,[],'all'),diagnostic.targetGramReciprocalCondition,diagnostic.referenceStability,diagnostic.eigenProductStability,VariableNames=["trial","profile","interaction","maxRelativeModeError","targetGramRcond","quadratureDiscrepancy","eigenProductDiscrepancy"])]; %#ok<AGROW>
    end
end
assert(all(fieldRows.maxRelativeModeError<config.eigenAllowance),'The analytical mode control must pass the existing mode threshold.');
assert(all(productRows.analyticalErrorOverFactorBound<config.referenceAllowance),'The product errors must remain small on the separately reported factor scale.');
assert(all(productRows.analyticalProductNorm<=productRows.factorBound*(1+1e-12)),'The sampled product norm must obey its factor bound.');
nonBoundary=~(evidence.rows.inputA=="boundary" & evidence.rows.inputB=="boundary");
otherMax=max([evidence.rows.referenceStability(nonBoundary);evidence.rows.eigenProductStability(nonBoundary)]);
assert(otherMax<config.referenceAllowance);
verification=struct(allFailedRowsAreBoundaryPairs=true,sameBoundaryProductsPassOriginalReferenceAllowance=true,allBoundaryModeControlsPassOriginalModeAllowance=true,allProductErrorsSmallOnSeparateFactorScale=true,sampledFactorBoundHolds=true,otherFamiliesPassOriginalReferenceAllowance=true,originalReferenceAllowance=config.referenceAllowance,originalModeAllowance=config.eigenAllowance,acceptancePolicyChanged=false);
previous=pwd; cleanup=onCleanup(@()cd(previous)); cd(root);
[status,revision]=system('git rev-parse HEAD'); assert(status==0);
[status,dirty]=system('git status --porcelain --untracked-files=no'); assert(status==0);
provenance=struct(sourceRevision=strtrim(string(revision)),hasTrackedChanges=strlength(strtrim(string(dirty)))>0,configurations={configurations},baselineInteractions=triads.interactionIndex,failedRowCount=height(failed),maxOtherFamilyReferenceError=otherMax,elapsedSeconds=toc(started),matlabVersion=string(version),computer=string(computer),internalModesVersion="2.0.0-beta.4",internalModesRevision="f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51",oceanKitRevision="65d9aa2c3de941406dc6bf2cf1937ba5b3dcd1d5",interpretation="Diagnostic factor scale only; no new acceptance rule. Constant control uses independent localized exponentials; exact tails may underflow to zero.");
mkdir(outputDirectory);
writetable(evidence.rows,fullfile(outputDirectory,'baseline-row-gates.csv'));
writetable(allFailures,fullfile(outputDirectory,'all-failing-boundary-products.csv'));
writetable(productRows,fullfile(outputDirectory,'product-diagnosis.csv'));
writetable(fieldRows,fullfile(outputDirectory,'reference-refinements.csv'));
writelines(jsonencode(provenance,PrettyPrint=true),fullfile(outputDirectory,'provenance.json'));
writelines(jsonencode(verification,PrettyPrint=true),fullfile(outputDirectory,'verification.json'));
result=struct(products=productRows,refinements=fieldRows,failedProducts=allFailures,verification=verification,provenance=provenance);
disp(fieldRows); fprintf('Short-wave reference diagnosis: %s\n',outputDirectory);
end

function rows=labelRows(diagnostic,trial,config)
rows=addvars(diagnostic.rows,repmat(trial,4,1),repmat(string(config.profile),4,1),repmat(diagnostic.interactionIndex,4,1),repmat(diagnostic.channel,4,1),Before=1,NewVariableNames=["trial","profile","interaction","channel"]);
end
