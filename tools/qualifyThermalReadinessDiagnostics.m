function results = qualifyThermalReadinessDiagnostics(thermal,records,outputDirectory,options)
% Qualify a fixed offline APV band on caller-supplied thermal records.
%
% Starts with 129 stored depths against 257, then tries 257 against 513 only
% if needed. The band and all runtime construction tolerances stay fixed.
% Scientific APV arrays are saved as annotated NetCDF, with construction
% assessments and a byte hash in a companion MAT file. A matching stored
% basis restores without InternalModes; an incomplete or changed cache fails
% visibly rather than silently replacing the evidence.
% The diagnostic QG basis uses quadraticDealiasing="none" so its explicit
% band is checked against the complete accepted linear prefix.
%
% Each row of records names caseId, recordId, state, time, forcingMultiplier,
% seasonalPhase and regime. Regime is cold, developed-zero, developed-peak,
% mixed-mean or capacity-only. Phase is the caller's seasonal angle in radians.
% State is a complete thermal coefficientState. Caller labels describe the
% provenance; this function does not infer developed flow from a snapshot.
% Empty records qualify only basis capacity, with incomplete regime coverage.
% Reports preserve every failed candidate. Large converged projection
% residuals describe coverage and do not reject diagnostic sampling.
%
% - Topic: Developer utilities
% - Parameter thermal: source scientific configuration; its state is unchanged
% - Parameter records: row structs of named states and seasonal provenance
% - Parameter outputDirectory: destination for incremental CSV and MAT evidence
% - Parameter options.apvModeCount: fixed diagnostic band; default 64
% - Parameter options.quadratureCount: Q, compared against 2Q; default 513
% - Parameter options.samplingTolerance: fixed reporting allowance; default 1%
% - Parameter options.diagnosticBasisDirectory: reusable annotated basis cache
% - Parameter options.shouldConstructMissingBases: false makes basis reuse read-only
% - Returns results: construction, mode, record, observable and regime ledgers
arguments (Input)
    thermal (1,1) WVTransformFreeSurfaceThermalQG
    records (1,:) struct
    outputDirectory (1,1) string
    options.apvModeCount (1,1) double {mustBeInteger,mustBePositive} = 64
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 513
    options.samplingTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-2
    options.diagnosticBasisDirectory (1,1) string = ""
    options.shouldConstructMissingBases (1,1) logical = true
end
arguments (Output)
    results (1,1) struct
end
validateRecords(thermal,records);
if options.samplingTolerance>1e-2
    error('WV:ReadinessDiagnosticTolerance','The predeclared sampling allowance cannot exceed 1%%.');
end
if options.quadratureCount<max(513,thermal.Nz)
    error('WV:ReadinessDiagnosticQuadrature','Q must be at least 513 and the source stored depth count.');
end
if isfile(fullfile(outputDirectory,'records.mat'))
    error('WV:ReadinessDiagnosticEvidence','Choose a new report directory to preserve earlier record evidence; the basis cache may be reused.');
end
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
if options.diagnosticBasisDirectory=="",options.diagnosticBasisDirectory=fullfile(outputDirectory,"diagnostic-bases");end
if ~isfolder(options.diagnosticBasisDirectory),mkdir(options.diagnosticBasisDirectory);end
manifest=recordManifest(records);
writetable(manifest,fullfile(outputDirectory,'records.csv'));
save(fullfile(outputDirectory,'records.mat'),'records','-v7.3');
results=struct(capacity=table(),modeComparisons=table(),comparisons=table(),observables=table(),inventories=table(),records=manifest);
bases=cell(1,3); attempted=false(1,3); counts=[129 257 513]; selectedNz=NaN;
for pair=1:2
    for index=pair:pair+1
        if attempted(index),continue;end
        attempted(index)=true;
        [bases{index},row]=storedBasis(thermal,counts(index),options);
        results.capacity=[results.capacity;struct2table(row)];
        writetable(results.capacity,fullfile(outputDirectory,'capacity.csv'));
    end
    if isempty(bases{pair}) || isempty(bases{pair+1}),continue;end
    candidate=bases{pair}; reference=bases{pair+1};
    mode=struct(diagnosticNz=candidate.Nz,referenceNz=reference.Nz,apvCount=options.apvModeCount, ...
        shapeQuadratureCount=max(2*options.quadratureCount,2*reference.Nz+1),maximumModeShapeError=NaN, ...
        allRetainedRadii=nnz(candidate.khUnique>0),seconds=NaN,status="failed",failureIdentifier="",failureMessage="");
    try
        clock=tic;
        [alignment,assessment]=coefficientAlignment(candidate,reference,mode.shapeQuadratureCount,options.samplingTolerance);
        mode.seconds=toc(clock); mode.maximumModeShapeError=assessment.maximumModeShapeError;mode.status="accepted";
    catch exception
        mode.failureIdentifier=string(exception.identifier);mode.failureMessage=string(exception.message);
    end
    results.modeComparisons=[results.modeComparisons;struct2table(mode)];
    writetable(results.modeComparisons,fullfile(outputDirectory,'mode-comparisons.csv'));
    if mode.status~="accepted",continue;end
    pairAccepted=true;
    for iRecord=1:numel(records)
        record=records(iRecord);
        row=struct(caseId=string(record.caseId),recordId=string(record.recordId),diagnosticNz=candidate.Nz,referenceNz=reference.Nz, ...
            quadratureCount=options.quadratureCount,quadratureCoefficientChange=NaN,gridCoefficientChange=NaN, ...
            quadratureResidualChangeOverSource=NaN,gridResidualChangeOverSource=NaN,quadratureSourceNormChange=NaN,gridSourceNormChange=NaN, ...
            algebraicRecompositionError=NaN,maximumGramError=NaN,minimumQRCondition=NaN, ...
            candidateSeconds=NaN,quadratureRefinementSeconds=NaN,gridRefinementSeconds=NaN,status="failed",failureIdentifier="",failureMessage="");
        try
            clock=tic;d=thermal.apvDecomposition(candidate,state=record.state,time=record.time,quadratureCount=options.quadratureCount);row.candidateSeconds=toc(clock);
            clock=tic;q=thermal.apvDecomposition(candidate,state=record.state,time=record.time,quadratureCount=2*options.quadratureCount);row.quadratureRefinementSeconds=toc(clock);
            clock=tic;f=thermal.apvDecomposition(reference,state=record.state,time=record.time,quadratureCount=2*options.quadratureCount);row.gridRefinementSeconds=toc(clock);
            [qc,qo]=compareThermalReadinessDiagnostics(d,q,samplingTolerance=options.samplingTolerance);
            aligned=q;aligned.metadata.apvModeNumber=f.metadata.apvModeNumber;aligned.metadata.activeEndpoint=f.metadata.activeEndpoint;
            for name=["Ag_q","Ag_0"]
                aligned.coefficients.(name)=q.coefficients.(name)(alignment.(name).sourceRows,:).*alignment.(name).scale;
            end
            [gc,go]=compareThermalReadinessDiagnostics(aligned,f,samplingTolerance=options.samplingTolerance);
            row.quadratureCoefficientChange=qc.coefficientChange;row.gridCoefficientChange=gc.coefficientChange;
            row.quadratureResidualChangeOverSource=qc.residualChangeOverSource;row.gridResidualChangeOverSource=gc.residualChangeOverSource;
            row.quadratureSourceNormChange=qc.sourceNormChange;row.gridSourceNormChange=gc.sourceNormChange;
            row.algebraicRecompositionError=max([recompositionError(d),recompositionError(q),recompositionError(f)]);
            row.maximumGramError=max([d.metadata.gramError,q.metadata.gramError,f.metadata.gramError],[],'all');
            row.minimumQRCondition=min([d.metadata.reciprocalQRCondition,q.metadata.reciprocalQRCondition,f.metadata.reciprocalQRCondition],[],'all');
            row.status="sampling-limit";
            if qc.accepted && gc.accepted && row.algebraicRecompositionError<=5e-12,row.status="accepted";end
            qo=labelRows(qo,record,candidate.Nz,reference.Nz,"quadrature");go=labelRows(go,record,candidate.Nz,reference.Nz,"stored-grid");
            results.observables=[results.observables;qo;go];
            results.inventories=[results.inventories;inventoryRows(d,record,candidate.Nz,options.quadratureCount);inventoryRows(q,record,candidate.Nz,2*options.quadratureCount);inventoryRows(f,record,reference.Nz,2*options.quadratureCount)];
            diagnosis=struct(candidate=d,quadratureReference=q,storedGridReference=f,modeAlignment=alignment);
            save(fullfile(outputDirectory,sprintf('diagnosis-record%d-Nz%d.mat',iRecord,candidate.Nz)),'diagnosis','-v7.3');
        catch exception
            row.failureIdentifier=string(exception.identifier);row.failureMessage=string(exception.message);
        end
        pairAccepted=pairAccepted && row.status=="accepted";
        results.comparisons=[results.comparisons;struct2table(row)];
        for name=["comparisons","observables","inventories"],writetable(results.(name),fullfile(outputDirectory,name+".csv"));end
    end
    if pairAccepted,selectedNz=candidate.Nz;break;end
end
results.regimes=regimeCoverage(records,results.comparisons,selectedNz);
results.summary=table(thermal.Nx,thermal.Ny,thermal.thermalModeCount,thermal.Nz,options.apvModeCount,options.quadratureCount,selectedNz, ...
    thermal.Nx==64 && thermal.Ny==64,~isnan(selectedNz),numel(records),"CONDITIONAL", ...
    VariableNames={'Nx','Ny','thermalCount','thermalNz','apvCount','quadratureCount','selectedDiagnosticNz','isActual64Grid','basisAccepted','recordCount','status'});
if results.summary.isActual64Grid && results.summary.basisAccepted && all(results.regimes.accepted)
    results.summary.status="PASS";
elseif isnan(selectedNz)
    results.summary.status="FAIL";
end
for name=["regimes","summary"],writetable(results.(name),fullfile(outputDirectory,name+".csv"));end
environment=struct(matlab=string(version),platform=string(computer),maximumThreads=maxNumCompThreads,providerPath=string(which('IMInternalModes')), ...
    geometry=[thermal.Lx thermal.Ly thermal.Lz],latitude=thermal.latitude,g=thermal.g,rho0=thermal.rho0, ...
    N20=thermal.N20,inverseScale=thermal.inverseScale,samplingTolerance=options.samplingTolerance,options=options);
environment.algebraicAbsoluteInventoryFloor=1e-24;
results.environment=environment;
save(fullfile(outputDirectory,'results.mat'),'results','-v7.3');
end

function validateRecords(thermal,records)
required=["caseId","recordId","state","time","forcingMultiplier","seasonalPhase","regime"];
state=thermal.coefficientState();
identifiers=strings(size(records));
for index=1:numel(records)
    record=records(index);
    if ~all(isfield(record,required)) || ~isscalar(record.state) || ~isstruct(record.state)
        error('WV:ReadinessDiagnosticRecords','Each record must contain caseId, recordId, state, time, forcingMultiplier, seasonalPhase and regime.');
    end
    for name=["caseId","recordId","regime"]
        value=string(record.(name));
        if ~isscalar(value) || ismissing(value) || strlength(value)==0,error('WV:ReadinessDiagnosticRecords','Record labels must be nonempty scalar text.');end
    end
    if ~ismember(string(record.regime),["cold","developed-zero","developed-peak","mixed-mean","capacity-only"])
        error('WV:ReadinessDiagnosticRecords','Unknown regime; use the documented cold, developed, mean or capacity labels.');
    end
    for name=["time","forcingMultiplier","seasonalPhase"]
        value=record.(name);
        if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value),error('WV:ReadinessDiagnosticRecords','Time, multiplier and phase must be finite real scalars.');end
    end
    if ~isequal(sort(fieldnames(record.state)),sort(fieldnames(state))),error('WV:ReadinessDiagnosticRecords','Supply every canonical coefficient family exactly once.');end
    for name=string(fieldnames(state)).'
        value=record.state.(name);
        if ~isnumeric(value) || ~isequal(size(value),size(state.(name))) || any(~isfinite(value),'all'),error('WV:ReadinessDiagnosticRecords','Each coefficient family must have its canonical finite shape.');end
    end
    if ~isreal(record.state.Amda),error('WV:ReadinessDiagnosticRecords','Horizontal-mean coefficients must be real.');end
    identifiers(index)=string(record.caseId)+"/"+string(record.recordId);
end
if numel(unique(identifiers))~=numel(records),error('WV:ReadinessDiagnosticRecords','caseId/recordId pairs must be unique.');end
end

function rows=recordManifest(records)
rows=table();
for record=records
    row=struct(caseId=string(record.caseId),recordId=string(record.recordId),time=record.time,forcingMultiplier=record.forcingMultiplier, ...
        seasonalPhase=record.seasonalPhase,regime=string(record.regime),hasNonzeroMean=any(record.state.Amda~=0),stateSHA256=thermalReadinessIdentity(record.state));
    rows=[rows;struct2table(row)]; %#ok<AGROW>
end
end

function [apv,row]=storedBasis(thermal,Nz,options)
row=struct(diagnosticNz=Nz,requestedCount=options.apvModeCount,selectedCount=NaN,maximumKh=NaN,retainedRadiusCount=NaN, ...
    boundaryPageCount=NaN,boundaryGridError=NaN,selectedGramError=NaN,minimumMuSeparation=NaN,minimumZeroAPVCondition=NaN, ...
    constructionSeconds=NaN,restoreSeconds=NaN,source="",basisPath="",basisSHA256="",status="failed",failureIdentifier="",failureMessage="");
try
    if thermal.inverseScale==0,integralN2=thermal.N20*thermal.Lz;else,integralN2=thermal.N20*(-expm1(-2*thermal.inverseScale*thermal.Lz))/(2*thermal.inverseScale);end
    request=struct(schemaVersion=1,Lxyz=[thermal.Lx thermal.Ly thermal.Lz],Nxyz=[thermal.Nx thermal.Ny Nz], ...
        N20=thermal.N20,inverseScale=thermal.inverseScale,g=thermal.g,rho0=thermal.rho0,latitude=thermal.latitude, ...
        rotationRate=thermal.rotationRate,planetaryRadius=thermal.planetaryRadius,g0=-integralN2,gd=integralN2, ...
        shouldAntialias=thermal.shouldAntialias,apvModeCount=options.apvModeCount);
    stem="apv-"+extractBefore(thermalReadinessIdentity(request),17)+"-Nz"+Nz+"-count"+options.apvModeCount;
    basisPath=fullfile(options.diagnosticBasisDirectory,stem+".nc");metadataPath=fullfile(options.diagnosticBasisDirectory,stem+".mat");row.basisPath=basisPath;
    if isfile(basisPath) || isfile(metadataPath)
        if ~isfile(basisPath) || ~isfile(metadataPath),error('WV:ReadinessDiagnosticCache','The stored basis is incomplete; preserve it and select a separate cache directory.');end
        metadata=load(metadataPath,'request','basisSHA256','assessment','constructionSeconds');
        if ~isequaln(metadata.request,request) || hashFile(basisPath)~=metadata.basisSHA256
            error('WV:ReadinessDiagnosticCache','Stored basis identity or bytes changed; preserve this evidence and use a separate cache directory.');
        end
        clock=tic;[apv,file]=WVTransform.waveVortexTransformFromFile(char(basisPath),shouldReadOnly=true);file.close();row.restoreSeconds=toc(clock);
        assessment=metadata.assessment;row.constructionSeconds=metadata.constructionSeconds;row.source="restored";
    else
        if ~options.shouldConstructMissingBases,error('WV:ReadinessDiagnosticMissingBasis','The requested basis is absent and scientific construction is disabled.');end
        fprintf('T10 diagnostic basis: %dx%d, Nz=%d, APV=%d.\n',thermal.Nx,thermal.Ny,Nz,options.apvModeCount);
        clock=tic;
        apv=WVTransformFreeSurfaceQG(request.Lxyz,request.Nxyz,N2Function=thermal.N2Function,g=request.g,latitude=request.latitude,rho0=request.rho0, ...
            rotationRate=request.rotationRate,planetaryRadius=request.planetaryRadius,g0=request.g0,gd=request.gd, ...
            apvModeCount=request.apvModeCount,mdaModeCount=1,shouldAntialias=request.shouldAntialias,quadraticDealiasing="none");
        constructionSeconds=toc(clock);assessment=apv.constructionAssessment;
        file=apv.writeToFile(char(basisPath));file.close();basisSHA256=hashFile(basisPath);
        save(metadataPath,'request','basisSHA256','assessment','constructionSeconds');
        metadata=struct(basisSHA256=basisSHA256);row.constructionSeconds=constructionSeconds;row.source="constructed";
    end
    if ~isa(apv,'WVTransformFreeSurfaceQG') || ~isequal(apv.activeEndpoint,[1;2]) || apv.apvModeCount~=options.apvModeCount
        error('WV:ReadinessDiagnosticBasis','The diagnostic must retain the requested band and both active endpoints.');
    end
    row.selectedCount=apv.apvModeCount;row.maximumKh=max(apv.khUnique);radii=apv.khUnique(apv.khUnique>0);row.retainedRadiusCount=numel(radii);
    row.minimumMuSeparation=apv.minimumRelativeMuSeparation;row.minimumZeroAPVCondition=min(apv.zeroAPVGramReciprocalCondition,[],'all');
    row.basisSHA256=metadata.basisSHA256;
    pages=assessment.boundary.pages;prefix=assessment.apv.prefixDiagnostics;
    row.boundaryPageCount=height(pages);row.boundaryGridError=max(pages.gridError);row.selectedGramError=prefix.gramError(prefix.modeCount==apv.apvModeCount);
    if row.source=="constructed"
        writetable(pages,fullfile(options.diagnosticBasisDirectory,stem+"-boundary.csv"));
        writetable(prefix,fullfile(options.diagnosticBasisDirectory,stem+"-prefix.csv"));
        writetable(assessment.apv.convergence.measurements,fullfile(options.diagnosticBasisDirectory,stem+"-convergence.csv"));
    end
    if row.boundaryPageCount~=2*row.retainedRadiusCount,error('WV:ReadinessDiagnosticBoundary','Boundary qualification must cover both endpoints at every retained nonzero radius.');end
    for radius=radii.'
        selected=abs(pages.kappa-radius)<=32*eps(radius);
        if ~isequal(sort(string(pages.endpoint(selected))),["bottom";"surface"])
            error('WV:ReadinessDiagnosticBoundary','Every retained radius needs distinct surface and bottom qualification rows.');
        end
    end
    row.status="accepted";
catch exception
    apv=[];row.failureIdentifier=string(exception.identifier);row.failureMessage=string(exception.message);
end
end

function [alignment,assessment]=coefficientAlignment(candidate,reference,Q,tolerance)
% Both transforms are private driver-owned bases. Reuse the public transfer's
% individual mode scale/phase matching, including every zero-coefficient mode.
state=candidate.coefficientState();cleanup=onCleanup(@()restoreCoefficients(candidate,state));
candidate.Ag_q=ones(size(candidate.Ag_q));candidate.Ag_0=ones(size(candidate.Ag_0));candidate.Amda=zeros(size(candidate.Amda));
[transferred,assessment]=candidate.coefficientStateForTransform(reference,modeTolerance=tolerance,quadratureCount=Q);
alignment=struct();
for name=["Ag_q","Ag_0"]
    if name=="Ag_q",source=candidate.apvModeNumber;target=reference.apvModeNumber;else,source=candidate.activeEndpoint;target=reference.activeEndpoint;end
    [matched,sourceRows]=ismember(target,source);
    if ~all(matched) || numel(source)~=numel(target),error('WV:ReadinessDiagnosticLabels','The stored-grid comparison must retain identical physical mode labels.');end
    alignment.(name)=struct(sourceRows=sourceRows,scale=transferred.(name));
end
end

function restoreCoefficients(apv,state)
for name=string(fieldnames(state)).',apv.(name)=state.(name);end
end

function value=recompositionError(diagnosis)
value=0;
for name=string(fieldnames(diagnosis.inventories)).'
    inventory=diagnosis.inventories.(name);terms=cell2mat(struct2cell(rmfield(inventory,'total')));
    % Preserve the T9 allowance: 5e-12*sum(abs(terms)) + 1e-24.
    error=abs(inventory.total-sum(terms))/(sum(abs(terms))+1e-24/5e-12);
    if ~isfinite(error),value=Inf;else,value=max(value,error);end
end
end

function rows=labelRows(rows,record,Nz,referenceNz,comparison)
n=height(rows);rows.caseId=repmat(string(record.caseId),n,1);rows.recordId=repmat(string(record.recordId),n,1);
rows.diagnosticNz=repmat(Nz,n,1);rows.referenceNz=repmat(referenceNz,n,1);rows.comparison=repmat(comparison,n,1);
end

function rows=inventoryRows(diagnosis,record,Nz,Q)
rows=table();
for name=string(fieldnames(diagnosis.inventories)).'
    row=diagnosis.inventories.(name);row.inventory=name;row.caseId=string(record.caseId);row.recordId=string(record.recordId);row.diagnosticNz=Nz;row.quadratureCount=Q;
    rows=[rows;struct2table(row)]; %#ok<AGROW>
end
end

function rows=regimeCoverage(records,comparisons,selectedNz)
rows=table();
for multiplier=[10 100]
    for regime=["cold","developed-zero","developed-peak","nonzero-mean"]
        matched=strings(0,1);
        for record=records
            matches=record.forcingMultiplier==multiplier && (string(record.regime)==regime || (regime=="nonzero-mean" && any(record.state.Amda~=0)));
            if matches && ~isempty(comparisons)
                admitted=comparisons.caseId==string(record.caseId) & comparisons.recordId==string(record.recordId) & comparisons.diagnosticNz==selectedNz & comparisons.status=="accepted";
                if any(admitted),matched(end+1,1)=string(record.caseId)+"/"+string(record.recordId);end %#ok<AGROW>
            end
        end
        row=struct(forcingMultiplier=multiplier,regime=regime,accepted=~isempty(matched),recordIds=join(matched,";"));
        rows=[rows;struct2table(row)]; %#ok<AGROW>
    end
end
end

function hash=hashFile(filePath)
[fid,message]=fopen(filePath,'rb');
if fid<0,error('WV:ReadinessDiagnosticCache','Unable to read saved basis bytes: %s',message);end
cleanup=onCleanup(@()fclose(fid));digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid),digest.update(fread(fid,1024*1024,'*uint8'));end
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
