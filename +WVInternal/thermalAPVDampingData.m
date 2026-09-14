function data=thermalAPVDampingData(w,s)
% Build the minimum-physical-energy lift of a fixed complete APV coordinate map.
% For positive polynomial energy R'*R, L=R\pinv(P/R), with row scaling
% for units/conditioning. All diagnostic rows must be independent; none drops.
% - Topic: Developer utilities
n=w.thermalModeCount; m=numel(s.dampingAPVMode)+2;
native=WVInternal.thermalPolynomialFields(s.apvZ,n,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
endpoints=WVInternal.thermalPolynomialFields([0;-w.Lz],n,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
[x,weights]=legpts(w.assemblyQuadratureCount); z=(x-1)*w.Lz/2; weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,n,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
N2=w.N20*exp(2*w.inverseScale*z);
pages=cell(numel(w.khUnique),1); verticalRates=[s.apvVerticalRates;0;0];
maximumUnitSpeedRate=0; residuals=zeros(numel(pages),2);
kh=hypot(w.k(w.klNonzero),w.l(w.klNonzero)).';
maximum=pi/s.horizontalResolution;
filter=WVInternal.horizontalVanishingFilter(kh,s.horizontalCutoff,maximum);
horizontal=-s.horizontalResolution/pi^2*kh.^2.*filter;
for p=1:numel(pages)
    k=w.khUnique(p); mu=k^2+s.apvInverseLr2;
    if any(abs(mu)<1e-12*max(k^2+abs(s.apvInverseLr2)))
        error('WV:ThermalDampingResonance','The frozen diagnostic APV inversion is singular at this radius.');
    end
    Q=s.apvForward*(native.qgpv-k^2*native.psi);
    response=-s.apvEndpointNumerator./mu.';
    P=[Q;-(w.g/w.f)*k^2*(endpoints.eta_i-response*Q)];
    fields=[sqrt(weights)*k.*r.psi;sqrt(weights.*N2).*r.eta;sqrt(w.g)*r.ssh];
    [~,R]=qr(fields,0); A=P/R; scales=vecnorm(A,2,2);
    if any(~isfinite(scales) | scales==0)
        error('WV:ThermalDampingBand','Every frozen diagnostic coordinate must have a nonzero finite physical response.');
    end
    [U,S,V]=svd(A./scales,'econ'); singular=diag(S);
    if numel(singular)~=m || min(singular)<1e-10*max(singular)
        error('WV:ThermalDampingBand','The complete APV diagnostic band is not independently represented; reduce its fixed band or refine the thermal space.');
    end
    liftWhite=(V./singular.')*U'./scales.'; L=R\liftWhite;
    residuals(p,:)=[norm((P*L-eye(m)).*(scales.'./scales),'fro'),min(singular)/max(singular)];
    if residuals(p,1)>1e-8, error('WV:ThermalDampingInverse','Frozen APV projection/lift failed its right-inverse check.'); end
    projection=P*w.thermalToPolynomial(:,:,p); lift=w.polynomialToThermal(:,:,p)*L;
    bound=norm((liftWhite.*verticalRates.')*A,2);
    columns=w.klNonzeroKhUniqueIndex==p;
    maximumUnitSpeedRate=max(maximumUnitSpeedRate,bound+max(abs(horizontal(columns))));
    pages{p}=struct(projection=projection,lift=lift,polynomialProjection=P,polynomialLift=L,physicalVerticalNorm=bound);
end
data=struct(pages={pages},verticalRates=verticalRates,horizontalRates=horizontal,maximumUnitSpeedRate=maximumUnitSpeedRate,rightInverseResidual=max(residuals(:,1)),minimumScaledSingularRatio=min(residuals(:,2)));
end
