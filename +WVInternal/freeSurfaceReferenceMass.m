function context = freeSurfaceReferenceMass(wvt)
% Factor the positive reference-geometry weak mass by Fourier wavenumber.
%
% The returned solve maps coefficient covectors to coefficient variations.
% Each nonzero compact column carries factor 2, including all balanced/wave
% cross terms. Mean inertial coefficients carry factor 4; real MDA carries
% factor 1 and its actual SSH trace. No continuous projection dual is used.
%
% At time tau=t-t0, reconstruction is R0*D(tau), so H(tau)=D'*H0*D and
% H(tau)^(-1)=D'*H0^(-1)*D. solve reads the transform's current clocks.
% Modes, counts, quadrature, f, g, and reference N2 are frozen at construction;
% rebuild this context if any of those dependencies change. The context
% neither changes transform state nor stores a global reconstruction basis.
%
% All orientations on one kh page share a factor: balanced horizontal
% velocity is i*kh*psi*e_perp, while a wave is
% F*(e_parallel+i*sigma*f/omega*e_perp). Rotation preserves every horizontal
% inner product; vertical/displacement/SSH columns depend only on kh.
%
% pages expose familyOrder, familySizes, columns, frequency, diagonalScale,
% upperFactor, and whitening. In raw family order, T=whitening satisfies
% T'*H0*T=I. Mean factors have the same convention. These small matrices
% are internal solver metadata, not a modal-coordinate API or persistence.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    context (1,1) struct
end
weights = wvt.verticalQuadratureWeights;
displacementWeights = weights.*wvt.N2;
template = structfun(@(value)zeros(size(value)),wvt.coefficientState(),UniformOutput=false);
familyOrder = ["Ag_q","Ag_0","Aw_p","Aw_m"];
pages = cell(length(wvt.khUnique),1);
for page = 1:length(pages)
    kh = wvt.khUnique(page);
    count = wvt.waveModeCountByKh(page);
    psi = [-wvt.apvF./wvt.apvMu(:,page).',-wvt.zeroAPVF(:,:,page)/kh^2];
    balancedCount = size(psi,2);
    totalCount = balancedCount+2*count;
    u = complex(zeros(wvt.Nz,totalCount)); v = u; w = u; eta = u;
    ssh = complex(zeros(1,totalCount));
    v(:,1:balancedCount) = 1i*kh*psi;
    eta(:,1:balancedCount) = -(wvt.f/wvt.g)*[wvt.apvG./wvt.apvMu(:,page).',wvt.zeroAPVG(:,:,page)/kh^2];
    ssh(:,1:balancedCount) = (wvt.f/wvt.g)*psi(end,:);
    if count>0
        modes = 1:count;
        wave = WVInternal.freeSurfaceWavePolarization(wvt.waveF(:,modes,page),wvt.waveG(:,modes,page),wvt.waveEquivalentDepth(modes,page),kh,0,f=wvt.f,g=wvt.g,rho0=wvt.rho0);
        waveColumns = balancedCount+(1:2*count);
        u(:,waveColumns) = reshape(wave.u,wvt.Nz,[]);
        v(:,waveColumns) = reshape(wave.v,wvt.Nz,[]);
        w(:,waveColumns) = reshape(wave.w,wvt.Nz,[]);
        eta(:,waveColumns) = reshape(wave.eta,wvt.Nz,[]);
        ssh(:,waveColumns) = reshape(wave.ssh,1,[]);
    end
    gram = 2*(u'*(weights.*u)+v'*(weights.*v)+w'*(weights.*w)+eta'*(displacementWeights.*eta)+wvt.g*(ssh'*ssh));
    block = factorBlock(gram);
    block.kh = kh;
    block.columns = find(wvt.klNonzeroKhUniqueIndex==page);
    block.familyOrder = familyOrder;
    block.familySizes = [size(template.Ag_q,1),size(template.Ag_0,1),count,count];
    block.frequency = wvt.waveFrequency(1:count,page);
    pages{page} = block;
end
inertial = factorBlock(4*(wvt.inertialF'*(weights.*wvt.inertialF)));
mdaSSH = wvt.mdaPressureMode(end,:)/wvt.g;
mda = factorBlock(wvt.mdaG'*(displacementWeights.*wvt.mdaG)+wvt.g*(mdaSSH'*mdaSSH));
activeWaves = wvt.activeWaveModes;
context = struct(pages={pages},meanInertial=inertial,meanMDA=mda,familyOrder=familyOrder);
context.solve = @(covector)solveCovector(covector,template,pages,inertial,mda,activeWaves,wvt.f,wvt.t-wvt.t0);
context.factorCount = length(pages)+2;
context.nonzeroColumnCount = length(wvt.klNonzero);
context.maximumBlockSize = max([size(inertial.whitening,1),size(mda.whitening,1),cellfun(@(block)size(block.whitening,1),pages).']);
end

function block = factorBlock(gram)
gram = (gram+gram')/2;
scale = sqrt(real(diag(gram)));
if any(~isfinite(scale) | scale<=0)
    error('WV:ReferenceMassNotPositive','Reference mass has a nonpositive or nonfinite diagonal; inspect the retained modes and quadrature.');
end
[upper,flag] = chol(gram./(scale*scale.'));
if flag~=0
    error('WV:ReferenceMassNotPositive','Reference mass is not positive definite; inspect retained-family independence and quadrature.');
end
block = struct(diagonalScale=scale,upperFactor=upper,whitening=diag(1./scale)/upper);
end

function result = solveCovector(covector,template,pages,inertial,mda,activeWaves,f,tau)
names = string(fieldnames(template)).';
if ~isstruct(covector) || ~isscalar(covector) || ~isequal(sort(string(fieldnames(covector))),sort(names.'))
    error('WV:ReferenceMassCovector','Supply exactly the six canonical coefficient covector families.');
end
for name = names
    value = covector.(name);
    if ~isa(value,'double') || ~isequal(size(value),size(template.(name))) || any(~isfinite(value),'all') || (name=="Amda" && ~isreal(value))
        error('WV:ReferenceMassCovector','%s must be a finite double array of shape %s; Amda must be real.',name,mat2str(size(template.(name))));
    end
end
if any(covector.Aw_p(~activeWaves)~=0) || any(covector.Aw_m(~activeWaves)~=0)
    error('WV:ReferenceMassCovector','Wave covectors must vanish outside the active per-kh prefixes.');
end
result = template;
for page = 1:length(pages)
    block = pages{page}; columns = block.columns;
    count = block.familySizes(3);
    phase = exp(1i*block.frequency*tau);
    diagonal = [ones(sum(block.familySizes(1:2)),1);phase;conj(phase)];
    rhs = [covector.Ag_q(:,columns);covector.Ag_0(:,columns);covector.Aw_p(1:count,columns);covector.Aw_m(1:count,columns)];
    solution = conj(diagonal).*solveBlock(block,diagonal.*rhs);
    offset = 0;
    for index = 1:4
        rows = offset+(1:block.familySizes(index));
        result.(block.familyOrder(index))(1:block.familySizes(index),columns) = solution(rows,:);
        offset = offset+block.familySizes(index);
    end
end
phase = exp(1i*f*tau);
result.Aio = conj(phase)*solveBlock(inertial,phase*covector.Aio);
result.Amda = real(solveBlock(mda,covector.Amda));
end

function value = solveBlock(block,value)
value = (block.upperFactor\(block.upperFactor'\(value./block.diagonalScale)))./block.diagonalScale;
end
