function context = freeSurfaceBoundarySchur(wvt,boundary,referenceMass)
% Factor the retained-boundary reference Schur operator by Fourier page.
%
% solve maps real packed trace covectors through (K*H_ref^(-1)*K*)^(-1).
% Here K* denotes the real coefficient adjoint. Nonzero trace coordinates
% concatenate sqrt(2)*real and sqrt(2)*imaginary Fourier amplitudes, followed
% by the active endpoint means, exactly as freeSurfaceBoundaryOperator.
%
% On one page, S=2*(C*T)*(C*T)' where T'*H0*T=I. Solving S on the packed
% complex real+i*imag coordinates includes any real/imaginary coupling.
% The real mean block is (C_mean*T_mda)*(C_mean*T_mda)'. Reference-time
% phases cancel between K=K0*D and H_ref^(-1)=D'*H0^(-1)*D, so neither
% advancing clock requires rebuilding these factors.
%
% This factory snapshots its boundary and reference-mass metadata. Rebuild
% all three contexts together after changing modes, counts or geometry.
% A nonpositive or poorly conditioned normalized block is rejected; no
% trace, family or mode is discarded. No global Schur matrix is stored.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    boundary (1,1) struct
    referenceMass (1,1) struct
end
arguments (Output)
    context (1,1) struct
end
nTrace = length(boundary.names);
nColumn = length(wvt.klNonzero);
nMean = size(boundary.meanBlock,1);
dimension = 2*nTrace*nColumn+nMean;
if dimension~=boundary.dimension || length(boundary.blocks)~=length(referenceMass.pages) || size(boundary.meanBlock,2)~=size(referenceMass.meanMDA.whitening,1)
    error('WV:BoundarySchurMetadata','Boundary and reference-mass contexts must describe the same retained coefficient and trace layouts.');
end
minimumReciprocalCondition = 1e-12;
pages = cell(length(referenceMass.pages),1);
for page = 1:length(pages)
    reference = referenceMass.pages{page};
    trace = boundary.blocks{page};
    if ~isequal(size(trace),[nTrace,size(reference.whitening,1)])
        error('WV:BoundarySchurMetadata','Boundary page %d does not match the reference coefficient block.',page);
    end
    weightedTrace = trace*reference.whitening;
    block = factorSchur(2*(weightedTrace*weightedTrace'),minimumReciprocalCondition,"wavenumber page "+page);
    block.kh = reference.kh;
    block.columns = reference.columns;
    pages{page} = block;
end
weightedMean = boundary.meanBlock*referenceMass.meanMDA.whitening;
meanBlock = factorSchur(weightedMean*weightedMean',minimumReciprocalCondition,"horizontal mean");
context = struct(dimension=dimension,pages={pages},meanBlock=meanBlock,traceNames=boundary.names,minimumReciprocalCondition=minimumReciprocalCondition);
context.solve = @(vector)solveTrace(vector,pages,meanBlock,nTrace,nColumn,dimension);
end

function block = factorSchur(matrix,threshold,label)
matrix = (matrix+matrix')/2;
scale = sqrt(real(diag(matrix)));
if isempty(matrix)
    block = struct(diagonalScale=zeros(0,1),upperFactor=zeros(0),reciprocalCondition=1);
    return
end
if any(~isfinite(matrix),'all') || any(scale<=0)
    error('WV:BoundarySchurRank','The %s Schur block has an unsupported or nonfinite trace. Retain an independent supported trace inventory before solving.',label);
end
normalized = matrix./(scale*scale.');
[upper,flag] = chol(normalized);
reciprocalCondition = rcond(normalized);
if flag~=0 || reciprocalCondition<threshold
    error('WV:BoundarySchurRank','The %s Schur block is rank deficient or ill conditioned (normalized rcond %.3g; required %.3g). No constraints were removed.',label,reciprocalCondition,threshold);
end
block = struct(diagonalScale=scale,upperFactor=upper,reciprocalCondition=reciprocalCondition);
end

function result = solveTrace(vector,pages,meanBlock,nTrace,nColumn,dimension)
if ~isa(vector,'double') || ~isreal(vector) || ~isequal(size(vector),[dimension,1]) || any(~isfinite(vector))
    error('WV:BoundarySchurCoordinates','Supply a finite real trace column with %d entries.',dimension);
end
number = nTrace*nColumn;
values = reshape(complex(vector(1:number),vector(number+(1:number))),nTrace,nColumn);
solution = complex(zeros(size(values)));
for page = 1:length(pages)
    block = pages{page};
    solution(:,block.columns) = solveBlock(block,values(:,block.columns));
end
means = real(solveBlock(meanBlock,vector(2*number+1:end)));
result = [real(solution(:));imag(solution(:));means];
end

function value = solveBlock(block,value)
if isempty(value), return; end
value = (block.upperFactor\(block.upperFactor'\(value./block.diagonalScale)))./block.diagonalScale;
end
