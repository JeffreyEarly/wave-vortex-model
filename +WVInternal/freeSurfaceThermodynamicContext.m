function context = freeSurfaceThermodynamicContext(N2Function,Lz,g,rho0)
% Prepare profile-only buoyancy and APE evaluation, independently of modes.
% The transform owns and reuses this immutable derived context.
arguments (Input)
    N2Function (1,1) function_handle
    Lz (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    g (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    rho0 (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
end
% One polynomial piece supports interval recurrences independently of global
% Chebfun splitting settings.
profile = chebfun(N2Function,[-Lz,0],'splitting','off');
if any(~isfinite(profile)) || min(profile)<=0
    error('WV:ThermodynamicProfile','The no-motion stratification must be finite and positive.');
end
I = cumsum(profile); I = I-I(0);
J = cumsum(I); J = J-J(0);
% Integrate coefficients without Chebfun re-chopping the small tail terms.
integralCoefficients = integrateCoefficients(chebcoeffs(profile),Lz);
energyCoefficients = integrateCoefficients(integralCoefficients,Lz);
coefficientCount = max(length(integralCoefficients),length(energyCoefficients));
integralCoefficients(end+1:coefficientCount) = 0;
energyCoefficients(end+1:coefficientCount) = 0;
parameters = struct(integralCoefficients=integralCoefficients,energyCoefficients=energyCoefficients,Lz=Lz,g=g,rho0=rho0,profile=profile,I=I,J=J);
context = struct(evaluate=@(z,eta,ssh)evaluate(parameters,z,eta,ssh),referenceConvention="upper-constant-density",minimumLabel=-Lz,maximumLabel=0);
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
% Avoid subtraction of primitives for arbitrarily small eta.
% Split at zero, where the explicit reference continuation changes formula.
crest = max(z,0);
interval = effectiveEta-crest;
% Second divided differences remain finite as the interval tends to zero.
% Anchor the average at N2(label), preserving the small remainder directly.
[variation,energyAverage] = WVInternal.chebyshevIntervalAverages(parameters.integralCoefficients,parameters.energyCoefficients,label,interval,parameters.Lz);
averageN2 = fields.N2AtLabel+variation;
fields.buoyancy = -interval.*averageN2;
fields.ape = interval.*(crest.*averageN2+interval.*energyAverage);
if ~isempty(N2)
    referenceN2 = reshape(N2,1,1,[]);
    % Keep the original eta in the linear term after a label adjustment.
    fields.buoyancyRemainder = interval.*((fields.N2AtLabel-referenceN2)+variation)-referenceN2.*(crest+labelAdjustment);
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

function integrated = integrateCoefficients(coefficients,D)
% The arbitrary constant is irrelevant to second divided differences.
integrated = zeros(length(coefficients)+1,1);
integrated(2) = coefficients(1);
if length(coefficients)>1, integrated(3)=coefficients(2)/4; end
for degree=2:length(coefficients)-1
    integrated(degree+2)=integrated(degree+2)+coefficients(degree+1)/(2*(degree+1));
    integrated(degree)=integrated(degree)-coefficients(degree+1)/(2*(degree-1));
end
integrated = (D/2)*integrated;
end
