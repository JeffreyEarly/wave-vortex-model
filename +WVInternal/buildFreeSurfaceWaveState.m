function [state,bases] = buildFreeSurfaceWaveState(state,options)
% Evaluate the resolved wave candidates without modifying their physical duals.
f=2*options.rotationRate*sind(options.latitude);
Lxyz=state.Lxyz;
state.waveMode = (1:max([state.waveModeCountByKh;0])).';
state.inertialMode = (1:options.inertialModeCount).';
nz = length(state.z); nw = length(state.waveMode); np = length(state.khUnique);
state.waveF = zeros(nz,nw,np); state.waveG = zeros(nz,nw,np);
state.waveGForward = zeros(nw,nz,np); state.waveEquivalentDepth = zeros(nw,np);
state.waveFrequency = zeros(nw,np); state.waveGramError = zeros(np,1);
solver = IMSolverSpectral(nEVP=options.nEVP,coordinateKind="wkb");
% Share coordinate preparation across the exact requested wave pencils.
% Zero wavenumber has its own count and must be evaluated separately.
activePages = find(state.waveModeCountByKh > 0);
bases = solver.solveWaveModesAtWavenumbers([0 state.khUnique(activePages).'],N2=state.N2Function,zDomain=[-Lxyz(3) 0],f0=f,g=options.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=state.waveModeCountByKh(activePages).',nInertialModes=options.inertialModeCount);
for iPage = 1:numel(activePages)+1
    if iPage == 1, p = 0; else, p = activePages(iPage-1); end
    basis = bases.bases{bases.basisIndex(iPage)};
    h = basis.h(:);
    if p == 0, count = options.inertialModeCount; else, count = state.waveModeCountByKh(p); end
    if any(h<=0) || length(h)~=count
        error('WVTransformFreeSurfaceBoussinesq:InvalidWaveBand','The requested wave/inertial prefix must contain only finite positive equivalent depths.')
    end
    if p == 0
        state.inertialEquivalentDepth = h;
        state.inertialModeNumber = basis.modeNumber(:);
    else
        state.waveEquivalentDepth(1:count,p) = h;
        state.waveFrequency(1:count,p) = sqrt(f^2+options.g*h*state.khUnique(p)^2);
        if count == nw, state.waveModeNumber = basis.modeNumber(:); end
    end
end
state.inertialF = bases.evaluate(state.z,variable="F",pages=1);
state.inertialFForward = (state.inertialF'.*state.verticalQuadratureWeights.')./state.inertialEquivalentDepth;
state.inertialGramError = norm(state.inertialFForward*state.inertialF-eye(options.inertialModeCount),2);
% Homogeneous count groups share evaluation while preserving exact prefixes.
for count = unique(state.waveModeCountByKh(activePages)).'
    collectionPages = find(state.waveModeCountByKh(activePages) == count).'+1;
    bases.evaluateChunks(state.z,@acceptWaveF,variable="F",pages=collectionPages);
    bases.evaluateChunks(state.z,@acceptWaveG,variable="G",pages=collectionPages);
end
% Preserve the prescribed physical pairing, including the surface term.
for p = 1:np
    count = state.waveModeCountByKh(p);
    if count == 0, continue; end
    G = state.waveG(:,1:count,p);
    forward = G'.*(state.verticalQuadratureWeights.*((state.N2Function(state.z)-f^2)/options.g)).';
    forward(:,end) = forward(:,end)+G(end,:).';
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
