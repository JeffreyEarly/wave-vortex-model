function report=runGramPrefixStudy(scientificResultPath,outputJSON,options)
% Compare independent and reused-identity Gram-prefix norms on saved construction data.
arguments (Input)
    scientificResultPath (1,1) string
    outputJSON (1,1) string
    options.repetitions (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 5
    options.wvmRoot (1,1) string = ""
    options.internalModesRoot (1,1) string = ""
end
loaded=load(scientificResultPath,"state","assessment");
if ~isfield(loaded,"state") || ~isfield(loaded,"assessment")
    error('WVStudy:InvalidScientificResult','The saved result must contain state and assessment.')
end
if options.wvmRoot=="", options.wvmRoot=string(fileparts(fileparts(fileparts(mfilename('fullpath'))))); end
if options.internalModesRoot==""
    options.internalModesRoot=fullfile(fileparts(options.wvmRoot),"oceankit-internal-modes-beta6","InternalModes-2.0.0-beta.6");
end
configureStudyPath(options.wvmRoot,options.internalModesRoot)
[state,savedAssessment]=rebuildFullPrefixGramState(loaded.state,loaded.assessment);
validateGramPrefixState(state)

% The normal workload restores every saved pre-selection prefix. A second
% workload derived from the same Grams exercises zero and varied counts.
variableState=withVariableAndZeroCounts(state);
validateGramPrefixState(variableState)

oldResult=independentPrefixNorms(state);
candidateResult=reusedIdentityPrefixNorms(state);
verifyEquivalentResults(oldResult,candidateResult,state.gramTolerance,"saved construction workload")
verifyReconstructedPrefixes(oldResult,loaded.assessment)
boundaryChecks=verifyBoundaryDecisions(oldResult,candidateResult,state.gramTolerance);

variableOld=independentPrefixNorms(variableState);
variableCandidate=reusedIdentityPrefixNorms(variableState);
verifyEquivalentResults(variableOld,variableCandidate,variableState.gramTolerance,"variable and zero-count workload")
variableBoundaryChecks=verifyBoundaryDecisions(variableOld,variableCandidate,variableState.gramTolerance);

% Warm each complete workload before alternating trials to avoid first-use cost.
verifyEquivalentResults(independentPrefixNorms(state),reusedIdentityPrefixNorms(state),state.gramTolerance,"warmup workload")
seconds=zeros(options.repetitions,2);
for repetition=1:options.repetitions
    if mod(repetition,2)==1, order=[1 2]; else, order=[2 1]; end
    for variant=order
        started=tic;
        if variant==1
            timed=independentPrefixNorms(state);
        else
            timed=reusedIdentityPrefixNorms(state);
        end
        seconds(repetition,variant)=toc(started);
        verifyEquivalentResults(oldResult,timed,state.gramTolerance,"timed workload")
    end
    fprintf('Repetition %d: independent %.6f s; reused identity %.6f s\n',repetition,seconds(repetition,1),seconds(repetition,2));
end

report=struct(matlabVersion=version,scientificResultPath=scientificResultPath,wvmRoot=options.wvmRoot,internalModesRoot=options.internalModesRoot, ...
    timingScope="Complete 64-column positive-page and inertial Gram-prefix assessment from rebuilt beta.6 construction factors, including state validation, Gram products, identity subtraction, leading-block spectral norms, prefix threshold decisions and zero-count handling. MAT-file loading, package path setup, beta.6 basis reconstruction, saved-assessment comparison and adjacent-float boundary verification are outside timed trials.", ...
    threadControl="Invoke maxNumCompThreads(1) before this study for the controlled comparison.", ...
    workload=workloadDescription(state),variableWorkload=workloadDescription(variableState), ...
    independentSeconds=seconds(:,1),reusedIdentitySeconds=seconds(:,2), ...
    independentMedianSeconds=median(seconds(:,1)),reusedIdentityMedianSeconds=median(seconds(:,2)), ...
    secondsSaved=median(seconds(:,1))-median(seconds(:,2)),speedup=median(seconds(:,1))/median(seconds(:,2)), ...
    exactPrefixParity=true,savedAssessment=savedAssessment,boundaryChecks=boundaryChecks,variableBoundaryChecks=variableBoundaryChecks);
outputFolder=fileparts(outputJSON);
if outputFolder~="" && ~isfolder(outputFolder), mkdir(outputFolder); end
writelines(jsonencode(report,PrettyPrint=true),outputJSON);
end

function result=independentPrefixNorms(state)
validateGramPrefixState(state)
nPages=numel(state.waveModeCountByKh);
prefixGramError=cell(nPages,1);
gridSupportedCount=zeros(nPages,1);
for p=1:nPages
    count=state.waveModeCountByKh(p);
    if count==0
        prefixGramError{p}=zeros(0,1);
        continue
    end
    gram=state.waveGForward(1:count,:,p)*state.waveG(:,1:count,p);
    errors=zeros(count,1);
    for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
    prefixGramError{p}=errors;
    gridSupportedCount(p)=sum(cumprod(errors<=state.gramTolerance));
end
count=numel(state.inertialMode);
gram=state.inertialFForward*state.inertialF;
errors=zeros(count,1);
for n=1:count, errors(n)=norm(gram(1:n,1:n)-eye(n),2); end
inertial=struct(prefixGramError=errors,gridSupportedCount=sum(cumprod(errors<=state.gramTolerance)));
result=struct(prefixGramError={prefixGramError},gridSupportedCount=gridSupportedCount,inertial=inertial);
end

function result=reusedIdentityPrefixNorms(state)
validateGramPrefixState(state)
nPages=numel(state.waveModeCountByKh);
prefixGramError=cell(nPages,1);
gridSupportedCount=zeros(nPages,1);
for p=1:nPages
    count=state.waveModeCountByKh(p);
    if count==0
        prefixGramError{p}=zeros(0,1);
        continue
    end
    gram=state.waveGForward(1:count,:,p)*state.waveG(:,1:count,p);
    gram=gram-eye(count);
    errors=zeros(count,1);
    for n=1:count, errors(n)=norm(gram(1:n,1:n),2); end
    prefixGramError{p}=errors;
    gridSupportedCount(p)=sum(cumprod(errors<=state.gramTolerance));
end
count=numel(state.inertialMode);
gram=state.inertialFForward*state.inertialF;
gram=gram-eye(count);
errors=zeros(count,1);
for n=1:count, errors(n)=norm(gram(1:n,1:n),2); end
inertial=struct(prefixGramError=errors,gridSupportedCount=sum(cumprod(errors<=state.gramTolerance)));
result=struct(prefixGramError={prefixGramError},gridSupportedCount=gridSupportedCount,inertial=inertial);
end

function validateGramPrefixState(state)
required=["waveModeCountByKh","waveG","waveGForward","inertialMode","inertialF","inertialFForward","gramTolerance"];
if ~isstruct(state) || ~all(isfield(state,required))
    error('WVStudy:InvalidGramPrefixState','The saved state lacks one or more Gram-prefix fields.')
end
counts=state.waveModeCountByKh;
if ~isnumeric(counts) || ~isvector(counts) || any(~isfinite(counts) | counts<0 | counts~=fix(counts))
    error('WVStudy:InvalidGramPrefixCounts','waveModeCountByKh must contain finite nonnegative integers.')
end
nPages=numel(counts);
if size(state.waveG,3)~=nPages || size(state.waveGForward,3)~=nPages || size(state.waveGForward,2)~=size(state.waveG,1)
    error('WVStudy:InvalidWaveGramFactors','Wave Gram factors do not match the requested pages.')
end
if any(counts>size(state.waveG,2)) || any(counts>size(state.waveGForward,1))
    error('WVStudy:InvalidWaveGramCounts','A requested wave count exceeds its saved Gram factors.')
end
inertialCount=numel(state.inertialMode);
if size(state.inertialF,2)~=inertialCount || size(state.inertialFForward,1)~=inertialCount || size(state.inertialFForward,2)~=size(state.inertialF,1)
    error('WVStudy:InvalidInertialGramFactors','Inertial Gram factors do not match inertialMode.')
end
if ~isscalar(state.gramTolerance) || ~isfinite(state.gramTolerance) || state.gramTolerance<0
    error('WVStudy:InvalidGramTolerance','gramTolerance must be one finite nonnegative scalar.')
end
end

function state=withVariableAndZeroCounts(state)
positive=find(state.waveModeCountByKh>0);
if numel(positive)<3 || max(state.waveModeCountByKh)<2
    error('WVStudy:InsufficientWavePages','The saved workload cannot exercise variable and zero wave counts.')
end
state.waveModeCountByKh(positive(1))=0;
state.waveModeCountByKh(positive(2))=1;
state.waveModeCountByKh(positive(3))=max(2,floor(state.waveModeCountByKh(positive(3))/2));
end

function verifyEquivalentResults(oldResult,candidateResult,tolerance,label)
if ~isequal(oldResult.prefixGramError,candidateResult.prefixGramError)
    error('WVStudy:PrefixMismatch','Independent and reused-identity prefix errors differ for the %s.',label)
end
if ~isequal(oldResult.gridSupportedCount,candidateResult.gridSupportedCount) || oldResult.inertial.gridSupportedCount~=candidateResult.inertial.gridSupportedCount
    error('WVStudy:SelectionMismatch','Independent and reused-identity counts differ for the %s at tolerance %.17g.',label,tolerance)
end
if ~isequal(oldResult.inertial.prefixGramError,candidateResult.inertial.prefixGramError)
    error('WVStudy:InertialPrefixMismatch','Independent and reused-identity inertial prefix errors differ for the %s.',label)
end
end

function [state,summary]=rebuildFullPrefixGramState(state,assessment)
if ~isstruct(assessment) || ~isfield(assessment,"pages") || ~isfield(assessment,"inertial")
    error('WVStudy:InvalidAssessment','The saved assessment must contain page and inertial results.')
end
pages=assessment.pages;
if ~istable(pages) || height(pages)~=numel(state.waveModeCountByKh) || ~ismember("gridSupportedCount",pages.Properties.VariableNames)
    error('WVStudy:InvalidAssessmentPages','The saved assessment does not contain its page Gram decisions.')
end
if ~isfield(assessment,"prefixGramError") || ~iscell(assessment.prefixGramError) || numel(assessment.prefixGramError)~=height(pages)
    error('WVStudy:InvalidSavedWavePrefixes','The saved assessment lacks one full prefix array per wave page.')
end
requested=cellfun(@numel,assessment.prefixGramError(:));
if numel(requested)~=569 || any(requested~=64)
    error('WVStudy:UnexpectedPrefixWorkload','Expected 569 positive pages with the original 64-column pre-selection prefix.')
end
if ~isfield(assessment.inertial,"prefixGramError") || numel(assessment.inertial.prefixGramError)~=requested(1)
    error('WVStudy:UnexpectedInertialPrefixWorkload','Expected the same full pre-selection inertial prefix length.')
end
if sum(requested)+numel(assessment.inertial.prefixGramError)~=36480
    error('WVStudy:UnexpectedTotalPrefixWorkload','Expected 36,480 wave and inertial prefixes in the pinned construction workload.')
end
if requested(1)>=state.nEVP
    error('WVStudy:InvalidPrefixLength','The reconstructed prefix length must be smaller than nEVP.')
end
if ~isequal(state.Lxyz,[1e5 1e5 1000]) || ~isequal(state.Nxyz,[128 128 65])
    error('WVStudy:UnexpectedConstructionGeometry','Expected the pinned 100 km by 100 km by 1 km, 128 by 128 by 65 construction.')
end
% scientific-result.mat intentionally omits function handles. This is the
% pinned construction profile used to create it, restored only for rebuilding.
state.N2Function=@(z)1e-4*exp(2*z/700);
state.waveModeCountByKh=requested;
buildOptions=struct(rotationRate=state.rotationRate,latitude=state.latitude,g=state.g,nEVP=state.nEVP,inertialModeCount=numel(assessment.inertial.prefixGramError));
[state,~]=WVInternal.buildFreeSurfaceWaveState(state,buildOptions);
summary=struct(reconstructedWavePrefixLength=requested(1),reconstructedInertialPrefixLength=numel(assessment.inertial.prefixGramError), ...
    totalPrefixCount=sum(requested)+numel(assessment.inertial.prefixGramError),reconstructedFromReleasedBeta6Bases=true, ...
    savedPrefixArraysUsedAsTheWorkloadDefinition=true);
end

function verifyReconstructedPrefixes(result,assessment)
if ~isfield(assessment,"prefixGramError") || ~isequal(result.prefixGramError,assessment.prefixGramError) || ~isequal(result.gridSupportedCount,assessment.pages.gridSupportedCount)
    error('WVStudy:ReconstructedWavePrefixMismatch','Rebuilt beta.6 wave factors do not reproduce the saved pre-selection Gram assessment.')
end
if ~isfield(assessment.inertial,"prefixGramError") || ~isequal(result.inertial.prefixGramError,assessment.inertial.prefixGramError) || result.inertial.gridSupportedCount~=assessment.inertial.gridSupportedCount
    error('WVStudy:ReconstructedInertialPrefixMismatch','Rebuilt beta.6 inertial factors do not reproduce the saved pre-selection Gram assessment.')
end
end

function checks=verifyBoundaryDecisions(oldResult,candidateResult,tolerance)
nPages=numel(oldResult.prefixGramError);
thresholdCount=zeros(nPages+1,1);
for p=1:nPages
    thresholds=decisionThresholds(oldResult.prefixGramError{p},tolerance);
    oldCounts=prefixCounts(oldResult.prefixGramError{p},thresholds);
    candidateCounts=prefixCounts(candidateResult.prefixGramError{p},thresholds);
    if ~isequal(oldCounts,candidateCounts)
        error('WVStudy:BoundaryDecisionMismatch','Prefix decisions differ at an adjacent-float threshold on page %d.',p)
    end
    thresholdCount(p)=numel(thresholds);
end
thresholds=decisionThresholds(oldResult.inertial.prefixGramError,tolerance);
if ~isequal(prefixCounts(oldResult.inertial.prefixGramError,thresholds),prefixCounts(candidateResult.inertial.prefixGramError,thresholds))
    error('WVStudy:InertialBoundaryDecisionMismatch','Inertial prefix decisions differ at an adjacent-float threshold.')
end
thresholdCount(end)=numel(thresholds);
checks=struct(usesAdjacentFloatingPointThresholds=true,pageThresholdCounts=thresholdCount(1:end-1),inertialThresholdCount=thresholdCount(end));
end

function thresholds=decisionThresholds(errors,tolerance)
errors=errors(:);
finiteErrors=errors(isfinite(errors) & errors>=0);
[below,above]=adjacentFloatingPointValues(finiteErrors);
thresholds=unique([tolerance;finiteErrors;below;above]);
thresholds=thresholds(isfinite(thresholds) & thresholds>=0);
end

function [below,above]=adjacentFloatingPointValues(values)
% Map IEEE-754 double encodings directly so no toolbox or newer API is needed.
values=values(:);
if ~isa(values,'double') || any(~isfinite(values) | values<0)
    error('WVStudy:InvalidBoundaryValues','Adjacent-float checks require finite nonnegative double values.')
end
bits=typecast(values,'uint64');
belowBits=bits;
positive=bits>0;
belowBits(positive)=belowBits(positive)-uint64(1);
aboveBits=bits+uint64(1);
below=reshape(typecast(belowBits,'double'),size(values));
above=reshape(typecast(aboveBits,'double'),size(values));
end

function counts=prefixCounts(errors,thresholds)
counts=zeros(numel(thresholds),1);
for index=1:numel(thresholds)
    counts(index)=sum(cumprod(errors<=thresholds(index)));
end
end

function workload=workloadDescription(state)
counts=state.waveModeCountByKh;
workload=struct(nPositivePages=nnz(counts>0),nZeroCountPages=nnz(counts==0), ...
    nWavePrefixes=sum(counts),nInertialPrefixes=numel(state.inertialMode), ...
    nTotalPrefixes=sum(counts)+numel(state.inertialMode),gramTolerance=state.gramTolerance);
end

function configureStudyPath(wvmRoot,internalModesRoot)
workspace=fileparts(wvmRoot);
if ~isfolder(wvmRoot) || ~isfolder(internalModesRoot)
    error('WVStudy:MissingPackageRoot','The WVM or released InternalModes root is unavailable.')
end
restoredefaultpath;
packageRoots=[fullfile(workspace,"OceanKit/ClassAnnotations-1.2.1"),fullfile(workspace,"OceanKit/Distributions-2.0.0"), ...
    fullfile(workspace,"OceanKit/SplineCore-2.2.0"),fullfile(workspace,"chebfun"),fullfile(workspace,"OceanKit/NetCDF-1.0.2"),internalModesRoot,wvmRoot];
for root=packageRoots
    manifest=jsondecode(fileread(fullfile(root,"resources","mpackage.json")));
    folders=strings(1,numel(manifest.folders));
    for index=1:numel(manifest.folders)
        folders(index)=fullfile(root,manifest.folders(index).path);
    end
    folderArguments=cellstr([folders(isfolder(folders)),root]);
    addpath(folderArguments{:});
end
if ~startsWith(string(which('WVInternal.buildFreeSurfaceWaveState')),wvmRoot+filesep)
    error('WVStudy:WrongWVMResolution','The study resolved WVInternal from a different WVM checkout.')
end
if ~startsWith(string(which('IMSolverSpectral')),internalModesRoot+filesep)
    error('WVStudy:WrongInternalModesResolution','The study resolved InternalModes from a different checkout.')
end
end
