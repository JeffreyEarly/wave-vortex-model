function adjoint = freeSurfaceReconstructionAdjoint(wvt,fields)
% Apply the quadrature adjoint of hatted reconstruction on its resolved span.
%
% For real test fields d and canonical reference-time coefficients a,
%
% mean_xy integral_xi sum(R(a).*d) + mean_xy SSH(a).*d.ssh
%     = sum_families real(sum(conj(a).*adjoint(d))).
%
% The four volume fields are u,v,w,eta. Vertical quadrature is included;
% N2, g, and nonlinear metric factors are not. Callers apply those physical
% weights before this adjoint. The result is a coefficient covector, not a
% projected source or a coefficient tendency. No modal Gram inverse or
% continuous generalized-energy dual is applied here.
%
% This internal primitive permits weak mass and constraint actions without
% forming a global realified reconstruction matrix. It preserves the stored
% per-kappa active wave prefixes and current reference-time phase convention.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    fields (1,1) struct
end
arguments (Output)
    adjoint (1,1) struct
end
names = ["u","v","w","eta","ssh"];
if ~isequal(sort(string(fieldnames(fields))),sort(names.'))
    error('WV:AdjointFields','Supply exactly u, v, w, eta and ssh test fields.');
end
for name = names
    expected = [wvt.Nx,wvt.Ny,wvt.Nz];
    if name=="ssh", expected=expected(1:2); end
    value = fields.(name);
    if ~isa(value,'double') || ~isreal(value) || any(~isfinite(value),'all') || ~isequal(size(value),expected)
        error('WV:AdjointFields','%s must be a finite real double array of shape %s.',name,mat2str(expected));
    end
    % Use the existing volume Fourier layout, including its compact-column
    % convention, for the surface pairing as in projectFields.
    if name=="ssh", value=repmat(value,1,1,wvt.Nz); end
    spectral.(name) = wvt.transformFromSpatialDomainWithFourier(value);
end
surface = spectral.ssh(1,:);
weights = wvt.verticalQuadratureWeights;
adjoint = structfun(@(value)zeros(size(value)),wvt.coefficientState(),UniformOutput=false);
for page = 1:length(wvt.khUnique)
    columns = find(wvt.klNonzeroKhUniqueIndex==page);
    indices = wvt.klNonzero(columns);
    curl = 1i*wvt.kNonzero(columns).'.*spectral.v(:,indices)-1i*wvt.lNonzero(columns).'.*spectral.u(:,indices);
    eta = weights.*spectral.eta(:,indices);
    weightedCurl = weights.*curl;
    adjoint.Ag_q(:,columns) = 2*(wvt.apvF'*weightedCurl-(wvt.f/wvt.g)*(wvt.apvG'*eta+wvt.apvF(end,:)'*surface(indices)))./wvt.apvMu(:,page);
    adjoint.Ag_0(:,columns) = 2*(wvt.zeroAPVF(:,:,page)'*weightedCurl-(wvt.f/wvt.g)*(wvt.zeroAPVG(:,:,page)'*eta+wvt.zeroAPVF(end,:,page)'*surface(indices)))/wvt.khUnique(page)^2;
    count = wvt.waveModeCountByKh(page);
    if count==0, continue; end
    modes = 1:count;
    phase = exp(1i*wvt.waveFrequency(modes,page)*(wvt.t-wvt.t0));
    for column = columns.'
        index = wvt.klNonzero(column);
        polarization = WVInternal.freeSurfaceWavePolarization(wvt.waveF(:,modes,page),wvt.waveG(:,modes,page),wvt.waveEquivalentDepth(modes,page),wvt.kNonzero(column),wvt.lNonzero(column),f=wvt.f,g=wvt.g,rho0=wvt.rho0);
        pair = reshape(polarization.ssh,1,[])'*surface(index);
        for name = ["u","v","w","eta"]
            pair = pair+reshape(polarization.(name),wvt.Nz,[])'*(weights.*spectral.(name)(:,index));
        end
        pair = 2*reshape(pair,count,2);
        adjoint.Aw_p(modes,column) = pair(:,1).*conj(phase);
        adjoint.Aw_m(modes,column) = pair(:,2).*phase;
    end
end
meanIndex = find(wvt.k==0 & wvt.l==0,1);
adjoint.Aio = 2*exp(-1i*wvt.f*(wvt.t-wvt.t0))*(wvt.inertialF'*(weights.*(spectral.u(:,meanIndex)-1i*spectral.v(:,meanIndex))));
adjoint.Amda = real(wvt.mdaG'*(weights.*spectral.eta(:,meanIndex))+(wvt.mdaPressureMode(end,:)'/wvt.g)*surface(meanIndex));
end
