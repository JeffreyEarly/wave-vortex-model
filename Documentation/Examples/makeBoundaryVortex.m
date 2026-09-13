function [wvt,scale] = makeBoundaryVortex(options)
% Construct a zero-APV elliptical surface anomaly with a prescribed Rossby number.
arguments (Input)
    options.gridSize (1,3) double = [64 64 65]
    options.stationaryControl (1,1) logical = false
end
arguments (Output)
    wvt (1,1) WVTransformFreeSurfaceQG
    scale (1,1) struct
end
L = 10e3;
wvt = WVTransformFreeSurfaceQG([8*L 8*L 1000],options.gridSize,N2Function=@(z)1e-4+0*z,latitude=30,g0=-.1,gd=Inf,apvModeCount=4,mdaModeCount=2,shouldAntialias=true);
[X,Y] = ndgrid(wvt.x-4*L,wvt.y-4*L);
anomaly = zeros(wvt.Nx,wvt.Ny);
for ix=-1:1
    for iy=-1:1
        anomaly = anomaly+exp(-((X+ix*wvt.Lx)/L).^2-((Y+iy*wvt.Ly)/(L/2)).^2);
    end
end
if options.stationaryControl, anomaly=cos(2*pi*X/wvt.Lx); end
anomaly=anomaly-mean(anomaly,'all');
field=zeros(wvt.spatialMatrixSize); field(:,:,1)=anomaly;
spectral=wvt.transformFromSpatialDomainWithFourier(field);
wvt.Ag_0=-(wvt.g/wvt.f)*reshape(wvt.khNonzero,1,[]).^2.*spectral(1,wvt.klNonzero);
speed=.05*abs(wvt.f)*L;
wvt.Ag_0=wvt.Ag_0*speed/wvt.uvMax;
wvt.removeAllForcing();
wvt.addForcing(WVNonlinearAdvection(wvt));
scale=struct(radius=L,speed=speed,time=L/speed,rossbyNumber=.05);
end
