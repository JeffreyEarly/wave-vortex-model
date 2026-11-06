function tendency = projectBoussinesqSpectralSources(wvt,spectral,projection,weights,N2,waveF,waveG)
% Project four independent hatted source components using fixed functionals.
indices = wvt.klNonzero;
curl = 1i*wvt.kNonzero.'.*spectral.v(:,indices)-1i*wvt.lNonzero.'.*spectral.u(:,indices);
tendency.Ag_q = projection.apvFProjection*curl ...
    -(wvt.f/wvt.Lz)*projection.apvGProjection*spectral.eta(:,indices);
tendency.Ag_0 = complex(zeros(size(wvt.Ag_0)));
tendency.Aw_p = complex(zeros(size(wvt.Aw_p)));
tendency.Aw_m = tendency.Aw_p;

for page = 1:numel(wvt.khUnique)
    columns = find(wvt.klNonzeroKhUniqueIndex==page);
    tendency.Ag_0(:,columns) = wvt.zeroAPVSourceSolve(:,:,page) * ...
        (projection.zeroAPVFProjection(:,:,page)*curl(:,columns) ...
        -(wvt.f/wvt.Lz)*projection.zeroAPVGProjection(:,:,page)*spectral.eta(:,indices(columns)));
    count = wvt.waveModeCountByKh(page);
    if count == 0, continue; end
    modes = 1:count;
    [tendency.Aw_p(modes,columns),tendency.Aw_m(modes,columns)] = WVInternal.projectFreeSurfaceWaves( ...
        wvt,page,columns,spectral,waveF(:,modes,page),waveG(:,modes,page),weights,N2);
end
meanIndex = find(wvt.k==0 & wvt.l==0,1);
tendency.Aio = .5*exp(-1i*wvt.f*(wvt.t-wvt.t0))*projection.inertialFProjection ...
    *(spectral.u(:,meanIndex)-1i*spectral.v(:,meanIndex));
tendency.Amda = real(projection.mdaGProjection*spectral.eta(:,meanIndex));
end
