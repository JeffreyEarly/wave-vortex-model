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
candidatePlan=preparePlan(candidate,candidatePages,z,options.candidateNEVP);
referencePlan=preparePlan(reference,referencePages,z,options.referenceNEVP);
for firstPage=1:options.pageChunkSize:numel(kappa)
    positions=firstPage:min(numel(kappa),firstPage+options.pageChunkSize-1);
    candidateChunk=prepareChunk(candidate,candidatePlan,candidatePages(positions),z,kappa(positions),options.candidateNEVP,options.nQuadrature);
    referenceChunk=prepareChunk(reference,referencePlan,referencePages(positions),z,kappa(positions),options.referenceNEVP,options.nQuadrature);
    consumer(candidateChunk,referenceChunk,positions,candidatePages(positions),referencePages(positions));
end
end

function validateKappa(collection,pages,kappa,role)
if ~isempty(collection.kappa) && any(collection.kappa(pages)~=kappa)
    error('WVInternal:WaveModePreparationKappaMismatch','The %s collection page kappa values must match the requested identities.',role)
end
end

function plan=preparePlan(collection,pages,z,nEVP)
indices=unique(collection.basisIndex(pages),"stable");
plan.factors=cell(size(collection.bases));
plan.basisGroup=zeros(size(collection.bases));
plan.groups={};
for iBasis=indices
    basis=collection.bases{iBasis};
    plan.factors{iBasis}=basis.normalizationFactors(basis.normalization);
    sourcePages=unique(collection.sourcePage(pages(collection.basisIndex(pages)==iBasis)));
    if ~isFastWaveBasis(basis,sourcePages,nEVP), continue; end
    nPolynomials=size(basis.nativeModes,1);
    iGroup=find(cellfun(@(group) group.nPolynomials==nPolynomials && isequal(group.solver,basis.solver),plan.groups),1);
    if isempty(iGroup)
        % Public solver evaluation on identity columns exposes reusable
        % physical operators without duplicating coordinate-map formulas.
        identity=eye(nPolynomials);
        operators=struct(value=basis.solver.evaluateNativeModes(identity,z), ...
            first=basis.solver.evaluatePhysicalDerivative(identity,z,1), ...
            second=basis.solver.evaluatePhysicalDerivative(identity,z,2));
        plan.groups{end+1}=struct(solver=basis.solver,nPolynomials=nPolynomials,operators=operators);
        iGroup=numel(plan.groups);
    end
    plan.basisGroup(iBasis)=iGroup;
end
end

function tf=isFastWaveBasis(basis,sourcePages,nEVP)
% Exact classes preserve custom subclass evaluation and recovery dispatch.
tf=string(class(basis))=="IMInternalModesBasis" && string(class(basis.solver))=="IMSolverSpectral" && ...
    string(class(basis.evp))=="IMInternalModes" && basis.evp.formulation=="G" && basis.evp.name=="waveModesAtWavenumber" && ...
    basis.solver.coordinateKind=="wkb" && basis.solver.nEVP==nEVP && isequal(sourcePages,1);
end

function prepared=prepareChunk(collection,plan,pages,z,kappa,nEVP,nQuadrature)
prepared=cell(1,numel(pages));
storedIndices=unique(collection.basisIndex(pages),"stable");
for iGroup=unique(plan.basisGroup(storedIndices))
    if iGroup==0, continue; end
    members=storedIndices(plan.basisGroup(storedIndices)==iGroup);
    memberCounts=arrayfun(@(iBasis) size(collection.bases{iBasis}.nativeModes,2),members);
    native=cell(1,numel(members));
    for iMember=1:numel(members)
        native{iMember}=collection.bases{members(iMember)}.nativeModes;
    end
    native=cat(2,native{:});
    firstColumn=[1 cumsum(memberCounts(1:end-1))+1];
    lastColumn=cumsum(memberCounts);
    raw=plan.groups{iGroup}.operators.value*native;
    for iMember=1:numel(members)
        iBasis=members(iMember);
        columns=firstColumn(iMember):lastColumn(iMember);
        basis=collection.bases{iBasis};
        factors=plan.factors{iBasis};
        value=basePreparation(basis,kappa(find(collection.basisIndex(pages)==iBasis,1)),nEVP,nQuadrature);
        value.values.G=raw(:,columns)./factors;
        selected=collection.basisIndex(pages)==iBasis;
        prepared(selected)=repmat({value},1,nnz(selected));
    end
    raw=plan.groups{iGroup}.operators.first*native;
    for iMember=1:numel(members)
        iBasis=members(iMember);
        columns=firstColumn(iMember):lastColumn(iMember);
        basis=collection.bases{iBasis};
        factors=plan.factors{iBasis};
        context=basis.evp.contextForSolver(basis.solver);
        value=prepared{find(collection.basisIndex(pages)==iBasis,1)};
        % Recover raw F through the EVP before normalization. The same raw
        % first derivative supplies normalized dG.
        value.values.F=basis.evp.FfromGz(z,raw(:,columns),basis.h,context)./factors;
        value.derivatives.G=raw(:,columns)./factors;
        selected=collection.basisIndex(pages)==iBasis;
        prepared(selected)=repmat({value},1,nnz(selected));
    end
    raw=plan.groups{iGroup}.operators.second*native;
    for iMember=1:numel(members)
        iBasis=members(iMember);
        columns=firstColumn(iMember):lastColumn(iMember);
        basis=collection.bases{iBasis};
        value=prepared{find(collection.basisIndex(pages)==iBasis,1)};
        value.derivatives.F=raw(:,columns)./plan.factors{iBasis}.*basis.h(:).';
        selected=collection.basisIndex(pages)==iBasis;
        prepared(selected)=repmat({value},1,nnz(selected));
    end
end
for position=find(plan.basisGroup(collection.basisIndex(pages))==0)
    iBasis=collection.basisIndex(pages(position));
    prepared{position}=prepareScalar(collection.bases{iBasis},plan.factors{iBasis},z,kappa(position),nEVP,nQuadrature);
end
end

function prepared=prepareScalar(basis,factors,z,kappa,nEVP,nQuadrature)
dG=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
dF=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors.*basis.h(:).';
prepared=basePreparation(basis,kappa,nEVP,nQuadrature);
% Subclasses must retain their overridden F/G methods in the scalar path.
if string(class(basis))=="IMInternalModesBasis"
    prepared.values=struct(F=basis.rawVariable("F",z)./factors,G=basis.rawVariable("G",z)./factors);
else
    prepared.values=struct(F=basis.F(z),G=basis.G(z));
end
prepared.derivatives=struct(F=dF,G=dG);
end

function prepared=basePreparation(basis,kappa,nEVP,nQuadrature)
identity=struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
provenance=struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=nEVP,quadratureCount=nQuadrature,source="explicit construction basis");
prepared=struct(identity=identity,values=struct(F=[],G=[]),derivatives=struct(F=[],G=[]),equivalentDepths=basis.h,provenance=provenance);
end
