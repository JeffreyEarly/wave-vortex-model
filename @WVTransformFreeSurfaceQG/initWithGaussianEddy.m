function initWithGaussianEddy(self,options)
% Initialize a balanced, vertically shifted Gaussian eddy.
%
% The raw streamfunction is
%
% $$
% \psi_{\mathrm{raw}}(x,y,z)
% = U\frac{L_e}{\sqrt{2}}e^{1/2}P(x,y)
% \exp\left[-\frac{(z-z_c)^2}{2H_e^2}\right],
% $$
%
% where `maximumSpeed`, `horizontalRadius`, `verticalScale`, and `zCenter`
% are $$U$$, $$L_e$$, $$H_e$$, and $$z_c$$. `P` is the periodic Gaussian
% centered at `center`. The amplitude gives maximum horizontal speed $$U$$
% for an isolated Gaussian at its vertical center. `zCenter` may lie above
% or below the modeled interval; choosing $$z_c\ne0$$ exposes a nonzero
% surface displacement and buoyancy anomaly.
%
% The initializer constructs
%
% $$
% \eta=-\frac{f}{N^2}\partial_z\psi_{\mathrm{raw}},
% \qquad
% q=\nabla_h^2\psi_{\mathrm{raw}}+
% \partial_z\left(\frac{f^2}{N^2}
% \partial_z\psi_{\mathrm{raw}}\right),
% $$
%
% and the active surface and bottom anomalies
% $$b_0=\eta(0)-(f/g)\psi_{\mathrm{raw}}(0)$$ and
% $$b_d=\eta(-D)$$. Nonzero horizontal wavenumbers are projected into
% `Ag_q` followed by the residual `Ag_0`. The raw Gaussian's discrete
% horizontal-mean displacement is projected independently into `Amda`.
% Initialization replaces all three canonical coefficient families.
%
% ```matlab
% wvt.initWithGaussianEddy(maximumSpeed=0.1,horizontalRadius=80e3, ...
%     verticalScale=300,zCenter=100,center=[wvt.Lx/2 wvt.Ly/2]);
% ```
%
% - Topic: Initialize the flow
% - Declaration: initWithGaussianEddy(options)
% - Parameter options.maximumSpeed: signed isolated-eddy velocity scale $$U$$ in meters per second
% - Parameter options.horizontalRadius: Gaussian horizontal radius $$L_e$$ in meters
% - Parameter options.verticalScale: Gaussian vertical scale $$H_e$$ in meters
% - Parameter options.zCenter: Gaussian vertical center $$z_c$$ in meters; default `0`
% - Parameter options.center: horizontal center `[xCenter yCenter]` in meters; default domain center
arguments
    self (1,1) WVTransformFreeSurfaceQG
    options.maximumSpeed (1,1) double {mustBeReal,mustBeFinite}
    options.horizontalRadius (1,1) double {mustBePositive,mustBeFinite}
    options.verticalScale (1,1) double {mustBePositive,mustBeFinite}
    options.zCenter (1,1) double {mustBeReal,mustBeFinite} = 0
    options.center (1,2) double {mustBeReal,mustBeFinite} = [self.Lx/2 self.Ly/2]
end

U = options.maximumSpeed;
Le = options.horizontalRadius;
He = options.verticalScale;
zc = options.zCenter;
xCenter = mod(options.center(1),self.Lx);
yCenter = mod(options.center(2),self.Ly);

k = reshape(self.k,1,[]);
l = reshape(self.l,1,[]);
kh2 = k.^2+l.^2;
horizontalCoefficients = (pi*Le^2/(self.Lx*self.Ly))*exp(-(Le^2/4)*kh2).*exp(-sqrt(-1)*(k*xCenter+l*yCenter));
verticalStructure = exp(-((self.z-zc).^2)/(2*He^2));
verticalDerivative = -((self.z-zc)/He^2).*verticalStructure;
streamfunctionScale = U*(Le/sqrt(2))*exp(1/2);

psiHat = streamfunctionScale*verticalStructure*horizontalCoefficients;
dPsiDzHat = streamfunctionScale*verticalDerivative*horizontalCoefficients;
etaHat = -(self.f./self.N2).*dPsiDzHat;

verticalFluxHat = (self.f^2./self.N2).*dPsiDzHat;
verticalFlux = self.transformToSpatialDomainWithFourier(verticalFluxHat);
verticalDivergenceHat = self.transformFromSpatialDomainWithFourier(self.diffZG(verticalFlux));
qHat = -kh2.*psiHat+verticalDivergenceHat;

endpointHat = complex(zeros(self.activeEndpointCount,self.Nkl));
for iEndpoint = 1:self.activeEndpointCount
    if self.activeEndpoint(iEndpoint) == 1
        endpointHat(iEndpoint,:) = etaHat(end,:)-(self.f/self.g)*psiHat(end,:);
    else
        endpointHat(iEndpoint,:) = etaHat(1,:);
    end
end

[Ag_q,Ag_0] = self.transformStateForward(qHat(:,self.klNonzero),endpointHat(:,self.klNonzero));
meanIndex = find(kh2 == 0,1);
if isempty(meanIndex)
    error('WVTransformFreeSurfaceQG:MissingHorizontalMean','The Fourier grid does not contain a horizontal-mean mode.');
end
Amda = self.transformMDAForward(real(etaHat(:,meanIndex)));

self.Ag_q = Ag_q;
self.Ag_0 = Ag_0;
self.Amda = Amda;
end
