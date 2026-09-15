function report=runWaveModePreparationStudy(scientificResultPath,outputJSON,options)
% Compare scalar and batched convergence preparation for the issue-32 workload.
arguments (Input)
    scientificResultPath (1,1) string
    outputJSON (1,1) string
    options.repetitions (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 3
    options.pageChunkSize (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 16
end
loaded=load(scientificResultPath,"assessment");
if ~isfield(loaded,'assessment') || ~isfield(loaded.assessment,'pages') || ~ismember('kappa',loaded.assessment.pages.Properties.VariableNames)
    error('WVStudy:InvalidScientificResult','The saved result must contain assessment.pages.kappa.')
end
positiveKappa=reshape(loaded.assessment.pages.kappa,1,[]);
if numel(positiveKappa)~=569 || any(positiveKappa<=0)
    error('WVStudy:UnexpectedWaveModeWorkload','Expected the 569 positive wavenumbers from the pinned construction workload.')
end
candidateNEVP=104;
referenceNEVP=156;
nModes=64;
nQuadrature=2*referenceNEVP+1;
N2=@(z) 1e-4*exp(2*z/700);
f0=2*7.2921e-5*sind(30);
surface=IMBoundaryCondition(a=0,b=1,c=1,d=0);
solveOptions={"N2",N2,"zDomain",[-1000 0],"f0",f0,"g",9.81,"surfaceBoundary",surface,"nModes",nModes,"nInertialModes",nModes};
requestedKappa=[0 positiveKappa];
candidate=IMSolverSpectral(nEVP=candidateNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers(requestedKappa,solveOptions{:});
reference=IMSolverSpectral(nEVP=referenceNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers(requestedKappa,solveOptions{:});
rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(candidate.bases{candidate.basisIndex(1)}.evp);
[z,~]=rule.nativeQuadratureRule([-1000 0]);
pages=1:numel(requestedKappa);

% Warm both complete preparation paths before alternating timed trials.
scalarChecksum=prepareScalarPages(candidate,reference,z,requestedKappa,candidateNEVP,referenceNEVP,nQuadrature,pages);
batchedChecksum=prepareBatchedPages(candidate,reference,z,requestedKappa,candidateNEVP,referenceNEVP,nQuadrature,pages,options.pageChunkSize);
checksumScale=max([1 abs(scalarChecksum) abs(batchedChecksum)]);
if abs(scalarChecksum-batchedChecksum)>1e-9*checksumScale
    error('WVStudy:PreparationChecksumMismatch','Scalar and batched preparation checksums differ beyond the study tolerance.')
end
seconds=zeros(options.repetitions,2);
checksums=zeros(options.repetitions,2);
for repetition=1:options.repetitions
    if mod(repetition,2)==1, order=[1 2]; else, order=[2 1]; end
    for variant=order
        started=tic;
        if variant==1
            checksums(repetition,variant)=prepareScalarPages(candidate,reference,z,requestedKappa,candidateNEVP,referenceNEVP,nQuadrature,pages);
        else
            checksums(repetition,variant)=prepareBatchedPages(candidate,reference,z,requestedKappa,candidateNEVP,referenceNEVP,nQuadrature,pages,options.pageChunkSize);
        end
        seconds(repetition,variant)=toc(started);
    end
    fprintf('Repetition %d: scalar %.6f s; batched %.6f s\n',repetition,seconds(repetition,1),seconds(repetition,2));
end
if any(abs(checksums(:,1)-scalarChecksum)>1e-10*max(1,abs(scalarChecksum))) || any(abs(checksums(:,2)-batchedChecksum)>1e-10*max(1,abs(batchedChecksum)))
    error('WVStudy:UnstablePreparationChecksum','A timed preparation checksum changed after warmup.')
end
allocation=allocationEstimate(numel(z),nModes,numel(pages),candidateNEVP,referenceNEVP,options.pageChunkSize);
report=struct(matlabVersion=version,scientificResultPath=scientificResultPath, ...
    resolvedWVM=string(which('WVTransformFreeSurfaceBoussinesq')),resolvedInternalModes=string(which('IMSolverSpectral')), ...
    workload=struct(nPositiveKappa=numel(positiveKappa),nPages=numel(pages),nModes=nModes,candidateNEVP=candidateNEVP,referenceNEVP=referenceNEVP,nQuadrature=nQuadrature,nSamples=numel(z),pageChunkSize=options.pageChunkSize), ...
    timingScope="Complete candidate/reference preparation after eigensolves and common quadrature: normalization, value/derivative evaluation, physical recovery, struct assembly and streaming callback checksum. Excludes eigensolves, convergence assessment and full construction.", ...
    scalarSeconds=seconds(:,1),batchedSeconds=seconds(:,2),scalarMedianSeconds=median(seconds(:,1)),batchedMedianSeconds=median(seconds(:,2)), ...
    secondsSaved=median(seconds(:,1))-median(seconds(:,2)),speedup=median(seconds(:,1))/median(seconds(:,2)),checksums=checksums,allocationEstimate=allocation);
outputFolder=fileparts(outputJSON);
if outputFolder~="" && ~isfolder(outputFolder), mkdir(outputFolder); end
writelines(jsonencode(report,PrettyPrint=true),outputJSON);
end

function checksum=prepareScalarPages(candidate,reference,z,kappa,candidateNEVP,referenceNEVP,nQuadrature,pages)
checksum=0;
for position=1:numel(pages)
    candidateBasis=candidate.bases{candidate.basisIndex(pages(position))};
    referenceBasis=reference.bases{reference.basisIndex(pages(position))};
    candidatePrepared=scalarPreparation(candidateBasis,z,kappa(position),candidateNEVP,nQuadrature);
    referencePrepared=scalarPreparation(referenceBasis,z,kappa(position),referenceNEVP,nQuadrature);
    checksum=checksum+preparationChecksum(candidatePrepared)+preparationChecksum(referencePrepared);
end
end

function checksum=prepareBatchedPages(candidate,reference,z,kappa,candidateNEVP,referenceNEVP,nQuadrature,pages,pageChunkSize)
checksum=0;
WVInternal.prepareWaveModeConvergenceBatches(candidate,reference,z,kappa,@consume,candidatePages=pages,referencePages=pages, ...
    candidateNEVP=candidateNEVP,referenceNEVP=referenceNEVP,nQuadrature=nQuadrature,pageChunkSize=pageChunkSize);
    function consume(candidatePrepared,referencePrepared,varargin)
        for position=1:numel(candidatePrepared)
            checksum=checksum+preparationChecksum(candidatePrepared{position})+preparationChecksum(referencePrepared{position});
        end
    end
end

function prepared=scalarPreparation(basis,z,kappa,nEVP,nQuadrature)
factors=basis.normalizationFactors(basis.normalization);
dG=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
dF=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors.*basis.h(:).';
identity=struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
provenance=struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=nEVP,quadratureCount=nQuadrature,source="explicit construction basis");
prepared=struct(identity=identity,values=struct(F=basis.F(z),G=basis.G(z)),derivatives=struct(F=dF,G=dG),equivalentDepths=basis.h,provenance=provenance);
end

function checksum=preparationChecksum(prepared)
checksum=sum(prepared.values.F,"all")+sum(prepared.values.G,"all")+sum(prepared.derivatives.F,"all")+sum(prepared.derivatives.G,"all")+sum(prepared.equivalentDepths,"all");
end

function allocation=allocationEstimate(nSamples,nModes,nPages,candidateNEVP,referenceNEVP,pageChunkSize)
bytesPerDouble=8;
batchPages=min(pageChunkSize,nPages);
operatorBytes=3*nSamples*(candidateNEVP+referenceNEVP)*bytesPerDouble;
preparedFieldBytes=3*4*nSamples*nModes*batchPages*bytesPerDouble;
currentRawBatchBytes=2*nSamples*nModes*batchPages*bytesPerDouble;
currentNativeBatchBytes=max(candidateNEVP,referenceNEVP)*nModes*batchPages*bytesPerDouble;
factorBytes=2*nPages*nModes*bytesPerDouble;
estimatedModeledBytes=operatorBytes+preparedFieldBytes+currentRawBatchBytes+currentNativeBatchBytes+factorBytes;
allocation=struct(kind="modeled array allocation estimate; not measured peak memory or RSS",bytesPerDouble=bytesPerDouble,operatorBytes=operatorBytes, ...
    preparedFieldBytes=preparedFieldBytes,currentRawBatchBytes=currentRawBatchBytes,currentNativeBatchBytes=currentNativeBatchBytes, ...
    factorBytes=factorBytes,estimatedModeledBytes=estimatedModeledBytes,estimatedModeledMiB=estimatedModeledBytes/1024^2, ...
    scope="Call-local value/first/second operators for both resolutions, up to three four-field page-batch outputs across MATLAB assignment RHS evaluation, up to two sampled raw batches across raw reassignment, one current native batch and all per-basis factors.", ...
    exclusions="Existing basis/native-mode storage, convergence reports, MATLAB object/cell bookkeeping, allocator overhead, BLAS workspace and short-lived elementwise expression temporaries.");
end
