function prepareWaveModeConvergenceBatches(candidate,reference,z,kappa,consumer,options)
% Stream paired wave-mode convergence inputs in bounded page batches.
% Calls consumer(candidatePrepared,referencePrepared,positions,
% candidatePages,referencePages). Prepared outputs are cell rows because
% selected pages may retain different numbers of scientific columns.
arguments (Input)
    candidate (1,1) IMBasisCollection
    reference (1,1) IMBasisCollection
    z (:,1) double {mustBeReal,mustBeFinite}
    kappa (1,:) double {mustBeReal,mustBeFinite,mustBeNonnegative}
    consumer (1,1) function_handle
    options.candidateNEVP (1,1) double {mustBeInteger,mustBePositive,mustBeFinite}
    options.referenceNEVP (1,1) double {mustBeInteger,mustBePositive,mustBeFinite}
    options.nQuadrature (1,1) double {mustBeInteger,mustBePositive,mustBeFinite}
    options.candidatePages (1,:) double {mustBeInteger,mustBePositive} = []
    options.referencePages (1,:) double {mustBeInteger,mustBePositive} = []
    options.pageChunkSize (1,1) double {mustBeInteger,mustBePositive,mustBeFinite} = 16
end
candidatePages=options.candidatePages;
if isempty(candidatePages), candidatePages=1:numel(candidate.basisIndex); end
referencePages=options.referencePages;
if isempty(referencePages), referencePages=1:numel(reference.basisIndex); end
if numel(candidatePages)~=numel(referencePages) || numel(kappa)~=numel(candidatePages)
    error('WVInternal:InvalidWaveModePreparationPages','Candidate pages, reference pages and kappa must have the same number of entries.')
end
if any(candidatePages>numel(candidate.basisIndex)) || any(referencePages>numel(reference.basisIndex))
    error('WVInternal:InvalidWaveModePreparationPage','Candidate and reference pages must select existing collection pages.')
end
validateKappa(candidate,candidatePages,kappa,"candidate");
validateKappa(reference,referencePages,kappa,"reference");
for firstPage=1:options.pageChunkSize:numel(kappa)
    positions=firstPage:min(numel(kappa),firstPage+options.pageChunkSize-1);
    candidateChunk=prepareChunk(candidate,candidatePages(positions),z,kappa(positions),options.candidateNEVP,options.nQuadrature);
    referenceChunk=prepareChunk(reference,referencePages(positions),z,kappa(positions),options.referenceNEVP,options.nQuadrature);
    consumer(candidateChunk,referenceChunk,positions,candidatePages(positions),referencePages(positions));
end
end

function validateKappa(collection,pages,kappa,role)
if ~isempty(collection.kappa) && any(collection.kappa(pages)~=kappa)
    error('WVInternal:WaveModePreparationKappaMismatch','The %s collection page kappa values must match the requested identities.',role)
end
end

function prepared=prepareChunk(collection,pages,z,kappa,nEVP,nQuadrature)
prepared=cell(1,numel(pages));
columnCounts=zeros(size(pages));
for iPage=1:numel(pages)
    basis=collection.bases{collection.basisIndex(pages(iPage))};
    value=basePreparation(basis,kappa(iPage),nEVP,nQuadrature);
    if string(class(basis))=="IMInternalModesBasis"
        columnCounts(iPage)=numel(basis.modeNumber);
    else
        % Preserve overridden evaluators for custom basis classes.
        value.values=struct(F=basis.F(z),G=basis.G(z));
        value.derivatives=struct(F=basis.Fz(z),G=basis.Gz(z));
    end
    prepared{iPage}=value;
end
for count=unique(columnCounts(columnCounts>0))
    positions=find(columnCounts==count);
    selectedPages=pages(positions);
    F=collection.evaluate(z,variable="F",pages=selectedPages);
    G=collection.evaluate(z,variable="G",pages=selectedPages);
    Fz=collection.evaluate(z,variable="F",derivativeOrder=1,pages=selectedPages);
    Gz=collection.evaluate(z,variable="G",derivativeOrder=1,pages=selectedPages);
    for iPage=1:numel(positions)
        prepared{positions(iPage)}.values=struct(F=F(:,:,iPage),G=G(:,:,iPage));
        prepared{positions(iPage)}.derivatives=struct(F=Fz(:,:,iPage),G=Gz(:,:,iPage));
    end
end
end

function prepared=basePreparation(basis,kappa,nEVP,nQuadrature)
identity=struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
provenance=struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=nEVP,quadratureCount=nQuadrature,source="explicit construction basis");
prepared=struct(identity=identity,values=struct(F=[],G=[]),derivatives=struct(F=[],G=[]),equivalentDepths=basis.h,provenance=provenance);
end
