function context = freeSurfaceThermodynamics(wvt)
% Evaluate exact parcel buoyancy, APE and matching surface pressure/energy.
%
% Parcel labels are restricted to [-Lz,0], allowing 32 ulps of Lz for
% representational endpoint roundoff. Such labels are evaluated at the
% endpoint and the adjustment is reported; coefficients are never changed.
% Larger excursions fail. The hydrostatic reference density
% equals the stored no-motion profile there, and continues above zero with
% constant N2(0), hence linear reference density. This is an explicit C1
% reference-density convention, not extrapolation of parcel density. It is
% generally not analytic at zero when the interior N2 derivative is nonzero.
%
% For I(z)=integral_0^z N2, J'=I, K'=J with J(0)=K(0)=0, r=z-eta,
% B=I(r)-I(z), A=-eta*I(r)-J(r)+J(z), pi_s=g*ssh-J(ssh), and
% E_s=g*ssh^2/2-K(ssh). pi_s is pressure per reference density. A and E_s
% are energy per reference density per physical volume/area respectively.
% The full surface terms are necessary for invariance under this reference
% choice. They must not be replaced by g*ssh and g*ssh^2/2 in a coupled run.
%
% The factory snapshots the profile and constants without computing modes.
% Derived antiderivatives are rebuilt, not persisted as prognostic state.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
% One polynomial piece makes the precomputed Gauss rule exact for the
% represented profile, independently of global Chebfun splitting settings.
profile = chebfun(wvt.N2Function,[-wvt.Lz,0],'splitting','off');
if any(~isfinite(profile)) || min(profile)<=0
    error('WV:ThermodynamicProfile','The no-motion stratification must be finite and positive.');
end
I = cumsum(profile); I = I-I(0);
J = cumsum(I); J = J-J(0);
[nodes,weights] = legpts(max(2,ceil((length(profile)+2)/2)),[0,1]);
parameters = struct(nodes=nodes,weights=weights,Lz=wvt.Lz,g=wvt.g,rho0=wvt.rho0,profile=profile,I=I,J=J,topN2=profile(0));
context = struct(evaluate=@(z,eta,ssh)evaluate(parameters,z,eta,ssh),referenceConvention="constant-surface-N2",minimumLabel=-wvt.Lz,maximumLabel=0);
end

function fields = evaluate(parameters,z,eta,ssh)
arguments (Input)
    parameters (1,1) struct
    z (:,:,:) double {mustBeReal,mustBeFinite}
    eta (:,:,:) double {mustBeReal,mustBeFinite}
    ssh (:,:) double {mustBeReal,mustBeFinite}
end
if ~isequal(size(z),size(eta)) || ~isequal(size(ssh),[size(z,1),size(z,2)])
    error('WV:ThermodynamicShape','Physical height and displacement must share a volume grid, with SSH on its horizontal grid.');
end
rawLabel = z-eta;
labelTolerance = 32*eps(parameters.Lz);
if any(rawLabel < -parameters.Lz-labelTolerance | rawLabel > labelTolerance,'all')
    error('WV:ParcelLabelDomain','Parcel labels z-eta must remain in [-Lz,0] within the %.3g m endpoint roundoff allowance; parcel density is not extended.',labelTolerance);
end
if any(z < -parameters.Lz,'all') || any(ssh <= -parameters.Lz,'all')
    error('WV:ThermodynamicGeometry','Physical heights must remain above the reference bottom, with positive column depth.');
end
label = min(0,max(-parameters.Lz,rawLabel));
labelAdjustment = label-rawLabel;
effectiveEta = eta-labelAdjustment;
labelI = sample(parameters.I,label);

physicalI = referencePrimitive(parameters,z,1);
physicalJ = referencePrimitive(parameters,z,2);
fields = struct();
fields.label = rawLabel;
fields.densityLabel = label;
fields.maximumLabelRoundoffAdjustment = max(abs(labelAdjustment),[],'all');
fields.adjustedLabelCount = nnz(labelAdjustment);
fields.labelRoundoffTolerance = labelTolerance;
fields.N2AtLabel = sample(parameters.profile,label);
% Integrate the represented N2 polynomial over the displacement interval.
% This avoids cancellation of O(Lz^2) primitives for arbitrarily small eta.
% Split at zero, where the explicit reference continuation changes formula.
crest = max(z,0);
interval = effectiveEta-crest;
fields.buoyancy = -parameters.topN2*crest;
fields.ape = 0.5*parameters.topN2*crest.^2;
for index = 1:length(parameters.nodes)
    node = parameters.nodes(index);
    weightedN2 = parameters.weights(index)*sample(parameters.profile,label+node*interval);
    fields.buoyancy = fields.buoyancy-interval.*weightedN2;
    fields.ape = fields.ape+interval.*(effectiveEta-node*interval).*weightedN2;
end
fields.apeEta = effectiveEta.*fields.N2AtLabel;
fields.apeZ = -fields.apeEta-fields.buoyancy;
fields.pressureSurface = parameters.g*ssh-surfacePrimitive(parameters,ssh,2);
fields.energySurface = 0.5*parameters.g*ssh.^2-surfacePrimitive(parameters,ssh,3);
fields.density = parameters.rho0-(parameters.rho0/parameters.g)*labelI;
fields.referenceDensity = parameters.rho0-(parameters.rho0/parameters.g)*physicalI;
fields.referencePressure = parameters.rho0*(-parameters.g*z+physicalJ);
end

function value = referencePrimitive(parameters,z,order)
if order==1, profile=parameters.I; else, profile=parameters.J; end
value = zeros(size(z));
interior = z<=0;
value(interior) = sample(profile,z(interior));
value(~interior) = parameters.topN2*z(~interior).^order/factorial(order);
end

function value = sample(profile,z)
value = reshape(profile(z(:)),size(z));
end

function value = surfacePrimitive(parameters,ssh,order)
% Direct integral moments also preserve tiny surface corrections near zero.
value = parameters.topN2*max(ssh,0).^order/factorial(order);
negative = ssh<0;
z = ssh(negative);
for index = 1:length(parameters.nodes)
    node = parameters.nodes(index);
    value(negative) = value(negative)+z.^order.*parameters.weights(index)*(1-node)^(order-1)/factorial(order-1).*sample(parameters.profile,node*z);
end
end
