function report = assessQGQuadraticResolution(prepared,options)
% Assess a fixed QG product snapshot without recomputing modes or products.
arguments (Input)
    prepared (1,1) struct
    options.quadraticTolerance (1,1) double {mustBePositive,mustBeFinite} = .1
    options.boundaryTolerance (1,1) double {mustBePositive,mustBeFinite} = .01
end
if ~isfield(prepared,'kind') || prepared.kind~="qgQuadraticEvidence-v1"
    error('WVStudy:InvalidPreparation','Supply a prepareQGQuadraticAssessment snapshot.');
end
c=prepared.configuration;
if max(c.referenceAllowance,c.referenceAbsoluteAllowance)>options.quadraticTolerance/100
    error('WVStudy:ReferenceAllowanceTooLarge','Both reference allowances must be at most one percent of quadraticTolerance. Prepare stricter references.');
end
timer=tic; rows=prepared.rows;
references=all(rows.referenceFraction<=1) && prepared.modeConvergenceError<=c.eigenAllowance;
boundaries=all(prepared.boundaries.gridError<=options.boundaryTolerance);
apvGrid=prepared.apvGramError<=c.gramTolerance;
products=all(rows.samplingError<=options.quadraticTolerance);
coverage=all(ismember(find(prepared.inventory.magnitudes>0),unique(rows.outputPage)));
status="assessed";
if ~references, status="reference-inconclusive";
elseif ~boundaries || ~apvGrid || ~products, status="rejected";
elseif ~coverage, status="inconclusive";
end
[~,limiting]=max(rows.samplingError);
report=struct(status=status,accepted=status=="assessed",referencesStable=references,fixedBoundariesAccepted=boundaries,apvGridAccepted=apvGrid,sampledProductsAccepted=products,completeOutputCoverage=coverage,quadraticTolerance=options.quadraticTolerance,boundaryTolerance=options.boundaryTolerance,rows=rows,boundaries=prepared.boundaries,limitingProduct=rows(limiting,:),coverage=prepared.coverage,cost=prepared.cost);
report.cost.assessmentSeconds=toc(timer);
end
