function [state,bases,solveCount] = buildFreeSurfaceWaveState(state,options,background,bases)
% Evaluate the resolved wave candidates without modifying their physical duals.
% A complete independent reference may supply the next candidate collection.
if nargin < 4, bases = []; end
f = background.f0;
D = background.D;
state.waveMode = (1:max([state.waveModeCountByKh;0])).';
state.inertialMode = (1:options.inertialModeCount).';
nz = length(state.z); nw = length(state.waveMode); np = length(state.khUnique);
state.waveF = zeros(nz,nw,np); state.waveG = zeros(nz,nw,np);
state.waveGForward = zeros(nw,nz,np); state.waveEquivalentDepth = zeros(nw,np);
state.waveFrequency = zeros(nw,np); state.waveGramError = zeros(np,1);
% Share coordinate preparation across the exact requested wave pencils.
% Zero wavenumber has its own count and must be evaluated separately.
activePages = find(state.waveModeCountByKh > 0);
kappa = [0 state.khUnique(activePages).'];
counts = [options.inertialModeCount state.waveModeCountByKh(activePages).'];
solveCount = 0;
if isempty(bases)
    solver = IMSolverSpectral(nEVP=options.nEVP,coordinateKind="wkb");
    bases = solver.solveWaveModesAtWavenumbers(background,kappa,nModes=counts,normalization="waveEnergy");
    solveCount = numel(kappa);
else
    surface = IMBoundaryCondition(a=0,b=1,c=1,d=0);
    if ~isa(bases,'IMBasisCollection') || ~isscalar(bases) || ~isequal(bases.kappa,kappa)
        error('WV:IncompatibleWaveReference','The reused reference must cover the exact candidate wavenumber pages.')
    end
    for page = 1:numel(kappa)
        basis = bases.bases{bases.basisIndex(page)};
        if ~isa(basis,'IMBasisSet') || ~isa(basis.evp,'IMInternalModes')
            error('WV:IncompatibleWaveReference','The reused reference must contain spectral internal-mode bases.')
        end
        evp = basis.evp;
        compatible = isa(basis.solver,'IMSolverSpectral') && basis.solver.nEVP==options.nEVP && basis.solver.coordinateKind=="wkb" ...
            && numel(basis.h)==counts(page) && string(basis.normalization)=="waveEnergy" ...
            && string(evp.name)=="waveModesAtWavenumber" && isequal(evp.N2,background.N2) ...
            && isequal(evp.zDomain,background.zDomain) && evp.g==background.g ...
            && evp.rotationRate==background.rotationRate && evp.latitude==background.latitude ...
            && evp.parameters.k==kappa(page) && isequal(evp.surfaceBoundary,surface) ...
            && isequal(evp.bottomBoundary,IMBoundaryCondition.dirichlet());
        if ~compatible
            error('WV:IncompatibleWaveReference','The reused reference must match candidate resolution, counts, normalization, stratification and boundary configuration.')
        end
    end
end
for iPage = 1:numel(activePages)+1
    if iPage == 1, p = 0; else, p = activePages(iPage-1); end
    basis = bases.bases{bases.basisIndex(iPage)};
    h = basis.h(:);
    if p == 0, count = options.inertialModeCount; else, count = state.waveModeCountByKh(p); end
    if any(~isfinite(h) | h<=0) || length(h)~=count
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveBand','The requested wave/inertial prefix must contain only finite positive equivalent depths.')
    end
    if p == 0
        state.inertialEquivalentDepth = h;
        state.inertialModeNumber = basis.modeNumber(:);
    else
        state.waveEquivalentDepth(1:count,p) = h;
        state.waveFrequency(1:count,p) = sqrt(f^2+background.g*h*state.khUnique(p)^2);
        if count == nw, state.waveModeNumber = basis.modeNumber(:); end
    end
end
state.inertialF = bases.evaluate(state.z,variable="F",pages=1);
state.inertialFForward = (state.inertialF'.*state.verticalQuadratureWeights.')/D;
state.inertialGramError = norm(state.inertialFForward*state.inertialF-eye(options.inertialModeCount),2);
% Homogeneous count groups share evaluation while preserving exact prefixes.
for count = unique(state.waveModeCountByKh(activePages)).'
    collectionPages = find(state.waveModeCountByKh(activePages) == count).'+1;
    bases.evaluateChunks(state.z,@acceptWaveF,variable="F",pages=collectionPages);
    bases.evaluateChunks(state.z,@acceptWaveG,variable="G",pages=collectionPages);
end
% The weak wave equation gives this G pairing norm h/D under waveEnergy
% normalization. The dual recovers G coefficients on the prescribed grid.
weightedN2 = state.verticalQuadratureWeights.*((background.N2(state.z)-f^2)/background.g);
for p = 1:np
    count = state.waveModeCountByKh(p);
    if count == 0, continue; end
    G = state.waveG(:,1:count,p);
    forward = G'.*weightedN2.';
    forward(:,end) = forward(:,end)+G(end,:).';
    forward = (D./state.waveEquivalentDepth(1:count,p)).*forward;
    state.waveGForward(1:count,:,p) = forward;
    state.waveGramError(p) = norm(forward*G-eye(count),2);
end
if nw == 0, state.waveModeNumber = state.waveMode; end
    function acceptWaveF(values,rows,~,pages)
        state.waveF(rows,1:size(values,2),activePages(pages-1)) = values;
    end

    function acceptWaveG(values,rows,~,pages)
        state.waveG(rows,1:size(values,2),activePages(pages-1)) = values;
    end
end
