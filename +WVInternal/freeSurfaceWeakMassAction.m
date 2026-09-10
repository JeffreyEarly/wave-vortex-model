function covector = freeSurfaceWeakMassAction(wvt,variation,metric)
% Apply the frozen-stage positive weak mass without a global basis matrix.
%
% metric.gamma is the column Jacobian; betaX and betaY are the reference
% slope factors in physical w=hat(w)+beta dot hat(u_H). displacementWeight
% is gamma*N2(parcelLabel), supplied by the stage's density evaluator. The
% surface mass is g. This is the H action in mapped-weak-evolution.md, not
% the Hessian of finite-amplitude energy: geometry-gradient terms are absent.
%
% All fields use the stored sample grid and quadrature. The metric is frozen
% while applying the action to reference-time coefficient variations. Its
% stage owner must rebuild it after changing the physical state. No cache,
% EVP, count selection, coefficient solve or nonlinear activation occurs.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    variation (1,1) struct
    metric (1,1) struct
end
arguments (Output)
    covector (1,1) struct
end
for name = ["gamma","betaX","betaY","displacementWeight"]
    expected = [wvt.Nx,wvt.Ny,wvt.Nz];
    if name=="gamma", expected=expected(1:2); end
    if ~isfield(metric,name) || ~isa(metric.(name),'double') || ~isreal(metric.(name)) || any(~isfinite(metric.(name)),'all') || ~isequal(size(metric.(name)),expected)
        error('WV:WeakMassMetric','%s must be a finite real double array of shape %s.',name,mat2str(expected));
    end
end
if any(metric.gamma<=0,'all') || any(metric.displacementWeight<0,'all')
    error('WV:WeakMassMetric','The Jacobian must be positive and the displacement weight nonnegative.');
end
spectral = wvt.reconstructSpectralState(state=variation);
for name = ["u","v","w","eta","ssh"]
    fields.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
end
vertical = fields.w+metric.betaX.*fields.u+metric.betaY.*fields.v;
weighted.u = fields.u./metric.gamma+metric.gamma.*metric.betaX.*vertical;
weighted.v = fields.v./metric.gamma+metric.gamma.*metric.betaY.*vertical;
weighted.w = metric.gamma.*vertical;
weighted.eta = metric.displacementWeight.*fields.eta;
weighted.ssh = wvt.g*fields.ssh(:,:,end);
covector = WVInternal.freeSurfaceReconstructionAdjoint(wvt,weighted);
end
