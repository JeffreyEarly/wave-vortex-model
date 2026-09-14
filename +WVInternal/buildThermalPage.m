function page = buildThermalPage(count,depth,N20,inverseScale,kh,f,g,quadratureCount)
% Assemble every thermal direction before diagonalizing unit diffusivity.
% Public amplitudes have velocity units; eigenvectors have unit depth-mean energy norm.
% - Topic: Developer utilities
arguments
    count (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(count,3)}
    depth (1,1) double {mustBePositive}
    N20 (1,1) double {mustBePositive}
    inverseScale (1,1) double {mustBeReal,mustBeFinite}
    kh (1,1) double {mustBePositive}
    f (1,1) double {mustBeReal,mustBeFinite}
    g (1,1) double {mustBePositive}
    quadratureCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(quadratureCount,count)}
end
[x,w]=legpts(quadratureCount); z=depth*(x-1)/2; w=w(:)*depth/2;
r=WVInternal.thermalPolynomialFields(z,count,depth,N20,inverseScale,kh,f,g);
N2=N20*exp(2*inverseScale*z);
field=[sqrt(w)*kh.*r.psi;sqrt(w.*N2).*r.eta;sqrt(g)*r.ssh];
[~,R]=qr(field,0); Q=eye(count)/R;
generator=(r.etaZ*Q)'*(w.*(r.buoyancyZ*Q));
[U,rates]=eig(generator,'vector');
% Deterministic display order is not an identity between resolutions.
[~,order]=sortrows([real(rates),imag(rates)],[1 2]); rates=rates(order); U=U(:,order);
C=Q*U;
for j=1:count
    [~,pivot]=max(abs(C(:,j)));
    phase=exp(-1i*angle(C(pivot,j)));
    scale=sqrt(depth)/norm(field*C(:,j));
    U(:,j)=U(:,j)*phase*scale;
end
C=Q*U; inverse=U\R;
conjugateDirection=zeros(count,1);
for j=1:count
    errors=vecnorm(C-conj(C(:,j)))/max(norm(C(:,j)),realmin);
    [pairError,conjugateDirection(j)]=min(errors);
    if pairError>1e-8
        error('WV:ThermalConjugatePair','No accurate conjugate partner for thermal direction %d (residual %.3g).',j,pairError);
    end
end
if ~isequal(conjugateDirection(conjugateDirection),(1:count)')
    error('WV:ThermalConjugatePair','Thermal conjugacy is not an involution.');
end
roundTrip=norm(inverse*C-eye(count),'fro')/sqrt(count);
eigenResidual=norm(generator*U-U.*rates.','fro')/max(norm(generator,'fro')*norm(U,'fro'),realmin);
if ~all(isfinite(C),'all') || ~all(isfinite(inverse),'all') || roundTrip>1e-8 || eigenResidual>1e-10
    error('WV:ThermalDecomposition','Complete eigendecomposition failed: inverse residual %.3g, eigen residual %.3g, condition %.3g. Increase assembly accuracy; no directions were dropped.',roundTrip,eigenResidual,cond(U));
end
% Weak physical-source dual, not a least-squares state fit.
sourceDual=U\Q';
endpoints=WVInternal.thermalPolynomialFields([0;-depth],count,depth,N20,inverseScale,kh,f,g);
sourceEndpoint=sourceDual*[-f*ones(count,1),f*(-1).^(0:count-1)'];
page=struct(polynomialToThermal=inverse,thermalToPolynomial=C,rates=rates,sourceDual=sourceDual,sourceEndpoint=sourceEndpoint,conjugateDirection=conjugateDirection);
page.energyGram=(field*C)'*(field*C)/depth;
page.diagnostics=struct(eigenResidual=eigenResidual,roundTrip=roundTrip,condition=cond(U),maximumGrowth=max(real(rates)),endpointSourceResidual=norm(endpoints.eta_i*C*sourceEndpoint-eye(2),'fro'),sourceQGPV=sqrt(sum(w.*abs(r.qgpv*C*sourceEndpoint).^2,1)/depth));
end
