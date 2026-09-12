function context = freeSurfaceThermodynamics(wvt)
% Evaluate parcel buoyancy and APE with upper-constant reference density.
%
% Parcel labels remain in [-Lz,0], allowing 32 ulps of endpoint roundoff.
% The hydrostatic no-motion density is constant above zero, so N_+^2=0
% there. Parcel density is never extended beyond its reference domain.
% For I(z)=integral_0^z N_+^2, J'=I, r=z-eta, buoyancy is I(r)-I(z)
% and APE is -eta*I(r)-J(r)+J(z). The manuscript surface-pressure
% approximation uses g*ssh and drops the corresponding cubic surface-energy
% correction, leaving g*ssh^2/2. This is not an all-orders pressure closure.
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
parameters = struct(nodes=nodes,weights=weights,Lz=wvt.Lz,g=wvt.g,rho0=wvt.rho0,profile=profile,I=I,J=J);
context = struct(evaluate=@(z,eta,ssh)evaluate(parameters,z,eta,ssh),referenceConvention="upper-constant-density",minimumLabel=-wvt.Lz,maximumLabel=0);
context.evaluateNonlinear = @(z,eta,ssh,N2)evaluate(parameters,z,eta,ssh,N2);
end

function fields = evaluate(parameters,z,eta,ssh,N2)
arguments (Input)
    parameters (1,1) struct
    z (:,:,:) double {mustBeReal,mustBeFinite}
    eta (:,:,:) double {mustBeReal,mustBeFinite}
    ssh (:,:) double {mustBeReal,mustBeFinite}
    N2 (:,1) double {mustBeReal,mustBeFinite,mustBePositive} = zeros(0,1)
end
if ~isequal(size(z),size(eta)) || ~isequal(size(ssh),[size(z,1),size(z,2)])
    error('WV:ThermodynamicShape','Physical height and displacement must share a volume grid, with SSH on its horizontal grid.');
end
if ~isempty(N2) && numel(N2)~=size(z,3)
    error('WV:ThermodynamicShape','Reference N2 must have one value per vertical level.');
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
fields.buoyancy = zeros(size(z));
fields.ape = zeros(size(z));
if ~isempty(N2)
    referenceN2 = reshape(N2,1,1,[]);
    % R_B integrates N_+^2-N2(xi), retaining the original eta in the
    % linear term when endpoint roundoff adjusts the density label.
    fields.buoyancyRemainder = -referenceN2.*(crest+labelAdjustment);
end
for index = 1:length(parameters.nodes)
    node = parameters.nodes(index);
    nodeN2 = sample(parameters.profile,label+node*interval);
    weightedN2 = parameters.weights(index)*nodeN2;
    if ~isempty(N2)
        fields.buoyancyRemainder = fields.buoyancyRemainder+interval.*(parameters.weights(index)*(nodeN2-referenceN2));
    end
    fields.buoyancy = fields.buoyancy-interval.*weightedN2;
    fields.ape = fields.ape+interval.*(effectiveEta-node*interval).*weightedN2;
end
fields.apeEta = effectiveEta.*fields.N2AtLabel;
fields.apeZ = -fields.apeEta-fields.buoyancy;
fields.pressureSurface = parameters.g*ssh;
fields.energySurface = 0.5*parameters.g*ssh.^2;
fields.density = parameters.rho0-(parameters.rho0/parameters.g)*labelI;
fields.referenceDensity = parameters.rho0-(parameters.rho0/parameters.g)*physicalI;
fields.referencePressure = parameters.rho0*(-parameters.g*z+physicalJ);
end

function value = referencePrimitive(parameters,z,order)
if order==1, profile=parameters.I; else, profile=parameters.J; end
value = zeros(size(z));
interior = z<=0;
value(interior) = sample(profile,z(interior));
end

function value = sample(profile,z)
value = reshape(profile(z(:)),size(z));
end
