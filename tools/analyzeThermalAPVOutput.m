function analysis = analyzeThermalAPVOutput(inputPath,apv,options)
% Diagnose a bounded selection of committed thermal records read-only.
%
% Restores the source scientific arrays once, then loads each selected record
% into a private analysis transform. The supplied APV transform is unchanged.
% The returned history contains modal coefficients and physical accounting;
% it never retains reconstructed physical volumes or evaluates forcing.
%
% Only the finite committed prefix of the unique complete coefficient stream
% is eligible. By default, analyze its first `maximumRecords` records. Use
% `indices` for a different bounded selection; scalar `Inf` selects its last
% committed record. Scalar snapshots accept only index 1 or Inf. The source
% SHA-256 is checked before and after analysis, including uncommitted bytes.
% Provenance also fingerprints the numerical diagnostic basis and sampled
% stratification, independently of its coefficient state or physical clock.
% Keep a separate saved diagnostic transform to reproduce those arrays; an
% unavailable transient constructor report is reported explicitly.
%
% - Topic: Developer utilities
% - Parameter inputPath: thermal snapshot or model-output NetCDF file
% - Parameter apv: separately constructed or restored diagnostic APV transform
% - Parameter options.indices: distinct committed record indices in requested order
% - Parameter options.maximumRecords: positive history bound; default 100
% - Parameter options.quadratureCount: optional physical quadrature count
% - Returns analysis: compact history, provenance and separate I/O/analysis timings
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    apv (1,1) WVTransformFreeSurfaceQG
    options.indices (1,:) double {mustBeReal,mustBePositive} = []
    options.maximumRecords (1,1) double {mustBeInteger,mustBeFinite,mustBePositive} = 100
    options.quadratureCount (1,:) double {mustBeInteger,mustBeFinite,mustBePositive} = []
end
arguments (Output)
    analysis (1,1) struct
end
if numel(options.quadratureCount)>1
    error('WV:APVOutputQuadrature','quadratureCount must be empty or scalar.');
end
sourcePath=string(java.io.File(char(inputPath)).getCanonicalPath());
clock=tic;
sourceHash=sha256File(sourcePath);
hashSeconds=toc(clock);
clock=tic;
[thermal,file]=WVTransform.waveVortexTransformFromFile(char(sourcePath),iTime=Inf,shouldReadOnly=true);
cleanup=onCleanup(@()file.close());
restoreSeconds=toc(clock);
if ~isa(thermal,'WVTransformFreeSurfaceThermalQG')
    error('WV:APVOutputTransform','The source must store a WVTransformFreeSurfaceThermalQG.');
end
[group,found]=WVInternal.groupContainingCompleteVariableSet(file,thermal.coefficientStateVariableNamesForPersistence());
if ~found
    error('WVTransform:MissingRestartCoefficients','The file must contain one complete canonical coefficient state.');
end
isTimeStream=group.hasDimensionWithName('t') && group.hasVariableWithName('t');
if isTimeStream
    committedCount=WVModelOutputGroup.committedRecordCountForGroup(group);
else
    committedCount=1;
end
indices=selectedIndices(options.indices,committedCount,isTimeStream,options.maximumRecords);
decompositionOptions=struct();
if ~isempty(options.quadratureCount), decompositionOptions.quadratureCount=options.quadratureCount; end
args=namedargs2cell(decompositionOptions);
readSeconds=zeros(size(indices));
analysisSeconds=zeros(size(indices));
for iRecord=1:numel(indices)
    clock=tic;
    thermal.initFromNetCDFFile(file,iTime=indices(iRecord),shouldRequireCoefficientState=true);
    readSeconds(iRecord)=toc(clock);
    clock=tic;
    diagnosis=thermal.apvDecomposition(apv,args{:});
    analysisSeconds(iRecord)=toc(clock);
    if iRecord==1, history=repmat(diagnosis,size(indices)); else, history(iRecord)=diagnosis; end
end
coefficientGroup=string(group.groupPath);
clear cleanup
clock=tic;
finalHash=sha256File(sourcePath);
diagnosticIdentity=diagnosticFingerprint(apv,history(1).metadata.quadratureCount);
hashSeconds=hashSeconds+toc(clock);
if finalHash~=sourceHash
    error('WV:APVOutputSourceChanged','The source file changed during analysis; discard this result and analyze a stable copy.');
end
provenance=struct(sourcePath=sourcePath,sourceSHA256=sourceHash,coefficientGroup=coefficientGroup, ...
    committedRecordCount=committedCount,selectedIndices=indices,times=[history.time], ...
    isScalarSnapshot=~isTimeStream,didAnalyzeAllCommittedRecords=numel(indices)==committedCount, ...
    sourceClass=string(class(thermal)),diagnosticClass=string(class(apv)), ...
    diagnosticMetadata=history(1).metadata,diagnosticIdentity=diagnosticIdentity, ...
    diagnosticConstructionAssessment=apv.constructionAssessment, ...
    isDiagnosticConstructionAssessmentAvailable=~isempty(fieldnames(apv.constructionAssessment)), ...
    rateSource="none",matlabVersion=string(version));
timing=struct(hashSeconds=hashSeconds,restoreSeconds=restoreSeconds,recordReadSeconds=readSeconds,recordAnalysisSeconds=analysisSeconds);
analysis=struct(history=history,provenance=provenance,timing=timing);
end

function indices=selectedIndices(requested,count,isTimeStream,maximumRecords)
if isempty(requested)
    indices=1:min(count,maximumRecords);
elseif isequal(requested,Inf)
    indices=count;
else
    if any(~isfinite(requested) | requested~=fix(requested)) || numel(unique(requested))~=numel(requested)
        error('WV:APVOutputIndices','indices must be distinct positive integers, or scalar Inf.');
    end
    if ~isTimeStream && ~isequal(requested,1)
        error('WVTransform:SnapshotTimeIndex','A scalar snapshot accepts only index 1 or Inf.');
    end
    if any(requested>count)
        error('WV:APVOutputIndices','The source contains only %d committed records.',count);
    end
    indices=requested;
end
if isempty(indices) || count==0
    error('WVTransform:NoCommittedRestartRecord','The selected output group contains no committed records.');
end
if numel(indices)>maximumRecords
    error('WV:APVOutputRecordLimit','The requested selection exceeds maximumRecords=%d; select a bounded batch or increase the explicit bound.',maximumRecords);
end
end

function hash=sha256File(path)
[fid,message]=fopen(path,'rb');
if fid<0, error('WV:APVOutputHash','Unable to read source bytes: %s',message); end
cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    digest.update(bytes);
end
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end

function identity=diagnosticFingerprint(apv,quadratureCount)
% Named, shaped, little-endian doubles for the arrays used by this diagnosis.
names=["Lx","Ly","Lz","Nx","Ny","f","g","rho0","g0","gd","z", ...
    "activeEndpoint","apvModeNumber","kNonzero","lNonzero","klNonzeroKhUniqueIndex", ...
    "apvF","apvG","apvMu","apvEndpointResponse","zeroAPVF","zeroAPVG"];
digest=java.security.MessageDigest.getInstance('SHA-256');
for name=names, updateArrayDigest(digest,name,apv.(name)); end
[nodes,~]=legpts(quadratureCount); depths=(nodes-1)*apv.Lz/2;
updateArrayDigest(digest,"projectionDepths",depths);
updateArrayDigest(digest,"N2AtProjectionDepths",apv.N2Function(depths));
hash=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
identity=struct(sha256=hash,encoding="APV diagnostic arrays v1: UTF-8 name/shape headers, real then imaginary column-major little-endian float64", ...
    propertyNames=[names,"projectionDepths","N2AtProjectionDepths"],quadratureCount=quadratureCount);
end

function updateArrayDigest(digest,name,value)
header=name+":"+join(string(size(value)),",")+";";
digest.update(unicode2native(char(header),'UTF-8'));
[~,~,endian]=computer;
parts={real(double(value)),imag(double(value))};
for i=1:2
    part=parts{i}; if endian=='B', part=swapbytes(part); end
    digest.update(typecast(part(:),'uint8'));
end
end
