function [covector,target,diagnostics] = freeSurfaceWeakRHS(wvt,hatted,metric,buoyancy,piSurface,derivative,boundary,options)
% Assemble the unforced mapped weak RHS and retained kinematic targets.
%
% This returns a coefficient COVECTOR, not a coefficient tendency. The
% caller supplies physical buoyancy, surface pressure divided by rho0,
% and the frozen stage metric used by freeSurfaceWeakMassAction. No density
% extension, surface-pressure approximation, or volume-pressure solve is
% chosen here. The caller owns consistency between metric and hatted state.
%
% With the total zero-pressure mapped tendency (F,d), the volume tests are
% R*F and displacementWeight*d. Surface virtual work is -w_surface*piSurface
% plus g*SSH_test*hat(w)_surface. The top w test divides by the top vertical
% quadrature weight because reconstruction's adjoint includes that weight.
%
% Endpoint targets advect eta-SSH at the surface and eta at the bottom
% using physical horizontal velocity. Derivatives act on the full mapped
% interior-displacement field before selecting endpoints. boundary provides
% the retained target coordinates and reports discarded target RMS.
% No reaction multiplier is identified with physical pressure. Optional
% tendency supplies already assembled pressure-free hatted equation rates;
% displacementSource adds only the prescribed endpoint material-label rates.
% This does not admit an independent SSH mass source.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    hatted (1,1) struct
    metric (1,1) struct
    buoyancy (:,:,:) double {mustBeReal,mustBeFinite}
    piSurface (:,:) double {mustBeReal,mustBeFinite}
    derivative (1,1) struct
    boundary (1,1) struct
    options.tendency (1,1) struct = struct()
    options.displacementSource (:,:,:) double {mustBeReal,mustBeFinite} = zeros(wvt.Nx,wvt.Ny,wvt.Nz)
end
arguments (Output)
    covector (1,1) struct
    target (:,1) double
    diagnostics (1,1) struct
end
shape = [wvt.Nx,wvt.Ny,wvt.Nz];
for name = ["u","v","w","eta","ssh"]
    expected = shape;
    if name=="ssh", expected=shape(1:2); end
    if ~isfield(hatted,name) || ~isa(hatted.(name),'double') || ~isreal(hatted.(name)) || ~isequal(size(hatted.(name)),expected) || any(~isfinite(hatted.(name)),'all')
        error('WV:WeakRHSFields','%s must be a finite real double field of shape %s.',name,mat2str(expected));
    end
end
for name = ["gamma","betaX","betaY","displacementWeight"]
    expected = shape;
    if name=="gamma", expected=shape(1:2); end
    if ~isfield(metric,name) || ~isa(metric.(name),'double') || ~isreal(metric.(name)) || ~isequal(size(metric.(name)),expected) || any(~isfinite(metric.(name)),'all')
        error('WV:WeakRHSMetric','%s must be a finite real double field of shape %s.',name,mat2str(expected));
    end
end
if ~isequal(size(buoyancy),shape) || ~isequal(size(piSurface),shape(1:2))
    error('WV:WeakRHSFields','Buoyancy must use the volume grid and piSurface the horizontal grid.');
end
if any(metric.gamma<=0,'all') || any(metric.displacementWeight<0,'all')
    error('WV:WeakRHSMetric','The stage Jacobian must be positive and displacement weight nonnegative.');
end
topWeight = wvt.verticalQuadratureWeights(end);
if ~isfinite(topWeight) || topWeight<=0
    error('WV:WeakRHSSurfaceWeight','The stored top vertical quadrature weight must be positive.');
end
if isempty(fieldnames(options.tendency))
    rhs = WVInternal.freeSurfaceMappedTendency(hatted,zeros(shape),buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
else
    rhs = options.tendency;
end
for name = ["u","v","w","eta"]
    if ~isfield(rhs,name) || ~isequal(size(rhs.(name)),shape) || ~isreal(rhs.(name)) || any(~isfinite(rhs.(name)),'all')
        error('WV:WeakRHSFields','The supplied tendency must contain finite real volume fields u,v,w,eta.');
    end
end
if ~isequal(size(options.displacementSource),shape)
    error('WV:WeakRHSFields','The displacement source must use the volume grid.');
end
vertical = rhs.w+metric.betaX.*rhs.u+metric.betaY.*rhs.v;
weighted.u = rhs.u./metric.gamma+metric.gamma.*metric.betaX.*vertical;
weighted.v = rhs.v./metric.gamma+metric.gamma.*metric.betaY.*vertical;
weighted.w = metric.gamma.*vertical;
weighted.eta = metric.displacementWeight.*rhs.eta;
weighted.w(:,:,end) = weighted.w(:,:,end)-piSurface/topWeight;
weighted.ssh = wvt.g*hatted.w(:,:,end);
covector = WVInternal.freeSurfaceReconstructionAdjoint(wvt,weighted);

alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
interiorDisplacement = hatted.eta-alpha.*hatted.ssh;
endpointAdvection = -(hatted.u.*derivative.x(interiorDisplacement)+hatted.v.*derivative.y(interiorDisplacement))./metric.gamma;
fields = struct(ssh=hatted.w(:,:,end),surface=endpointAdvection(:,:,end)+options.displacementSource(:,:,end),bottom=endpointAdvection(:,:,1)+options.displacementSource(:,:,1));
[target,discardedRMS] = boundary.projectTarget(fields);
diagnostics = struct(discardedBoundaryTargetRMS=discardedRMS,boundaryTargetFields=fields);
end
