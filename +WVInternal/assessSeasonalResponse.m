function result = assessSeasonalResponse(closure,forcing,times,options)
% Assess a specified seasonal linear response within resolved modal spaces.
% - Topic: Developer utilities
arguments (Input)
    closure (1,1) WVVerticalDiffusivity
    forcing (1,1) WVSeasonalSurfaceAnomalyForcing
    times (1,:) double
    options (1,1) struct
end
arguments (Output)
    result (1,1) struct
end
w = closure.wvt;
transforms = [{w},options.referenceTransforms];
validateTransforms(transforms,forcing);
names = {'qgpv','buoyancy','ssh','surfaceAnomaly','bottomAnomaly', ...
    'energy','enstrophy','energyTendency','enstrophyTendency'};
for name = ["absoluteTolerance","relativeTolerance","referenceAbsoluteTolerance","referenceRelativeTolerance"]
    validateTolerance(options.(name),names);
end
count = options.quadratureCount;
if count==0
    count = max(129,2*transforms{3}.Nz+1);
elseif count<2*transforms{3}.Nz+1
    error('WV:ResponseQuadrature','quadratureCount must be at least 2*finestNz+1.');
end
rule = WVInternal.qgVerticalOperators(transforms{3}.z,count);
z = rule.zQuadrature;
weights = rule.quadratureWeights;
P = cell(1,3);
N2 = cell(1,3);
operators = cell(1,3);
for j = 1:3
    P{j} = WVInternal.qgVerticalInterpolation(transforms{j}.z,z);
    N2{j} = P{j}*transforms{j}.N2;
end
profileDifference = cellfun(@(n)max(abs(n-N2{3})./N2{3}),N2);
if any(N2{3}<=0) || any(profileDifference>options.stratificationTolerance)
    error('WV:ResponseStratification','Reference N2 profiles disagree beyond stratificationTolerance on the common grid.');
end
geometry = WVGeometryDoublyPeriodic([w.Lx w.Ly],[w.Nx w.Ny],Nz=1, ...
    shouldAntialias=w.shouldAntialias,shouldExcludeNyquist=w.shouldExcludeNyquist, ...
    shouldExcludeConjugates=w.shouldExcludeConjugates,conjugateDimension=w.conjugateDimension);
hat = geometry.transformFromSpatialDomainWithFourier(forcing.pattern);
represented = geometry.transformToSpatialDomainWithFourier(hat);
if norm(represented(:)-forcing.pattern(:))>1e-12*norm(forcing.pattern(:))
    error('WV:ResponseHorizontalResolution','The forcing pattern must lie in the resolved horizontal space.');
end
hat = forcing.amplitude*hat(w.klNonzero);
for j = 1:3
    operators{j} = WVInternal.densityDiffusionOperators(transforms{j},closure.kappa_z,shouldForceMeanDensityAnomaly=false);
end
% Five nonnegative squared field norms, then four signed inventories/rates.
values = zeros(length(times),9,4,length(w.khUnique));
differences = zeros(size(values));
perWavenumber = cell(length(w.khUnique),1);
for p = 1:length(w.khUnique)
    power = sum(abs(hat(w.klNonzeroKhUniqueIndex==p)).^2);
    recon = cell(1,3);
    for j = 1:3
        recon{j} = reconstruction(transforms{j},P{j},N2{3},z,weights,p);
    end
    % Continuous APV L2 projection, with exact endpoint retention.
    F = recon{1}.q(:,1:w.apvModeCount);
    projectionQ = (sqrt(weights).*F)\(sqrt(weights).*recon{3}.q);
    projection = [projectionQ;-(w.g/w.f)*w.khUnique(p)^2* ...
        (recon{3}.endpoint-w.apvEndpointResponse(:,:,p)*projectionQ)];
    for it = 1:length(times)
        c = cell(1,4);
        dc = cell(1,4);
        for j = 1:3
            [c{j},dc{j}] = response(operators{j}.pages{p},transforms{j},p,forcing,times(it));
        end
        c{4} = projection*c{3};
        dc{4} = projection*dc{3};
        r = [recon,recon(1)];
        fields = cell(1,4);
        for j = 1:4
            fields{j} = observe(r{j},c{j},dc{j},weights,w.Lz);
            values(it,:,j,p) = power*fields{j}.values;
        end
        % Representation, evolution, total, and reference refinement.
        pairs = [4 3;1 4;1 3;2 3];
        for j = 1:4
            a = fields{pairs(j,1)};
            b = fields{pairs(j,2)};
            differences(it,:,j,p) = power*[sum(abs(a.field-b.field).^2,1),a.values(6:9)-b.values(6:9)];
        end
    end
    perWavenumber{p} = comparisons(values(:,:,:,p),differences(:,:,:,p),times,names);
    perWavenumber{p}.kh = w.khUnique(p);
    perWavenumber{p}.forcingPower = power;
end
result = comparisons(sum(values,4),sum(differences,4),times,names);
result.perWavenumber = vertcat(perWavenumber{:});
result.acceptance = acceptance(result.total,options.absoluteTolerance,options.relativeTolerance);
result.reference.acceptance = acceptance(result.reference.convergence,options.referenceAbsoluteTolerance,options.referenceRelativeTolerance);
result.units = cell2struct({'s^-1','m s^-2','m','m','m','m^3 s^-2','m s^-2','m^3 s^-3','m s^-3'},names,2);
result.configuration = struct(times=times,kappa_z=closure.kappa_z, ...
    amplitude=forcing.amplitude,period=forcing.period,phase=forcing.phase,pattern=forcing.pattern, ...
    Lxyz=[w.Lx w.Ly w.Lz],Nxy=[w.Nx w.Ny],f=w.f,g=w.g,g0=w.g0,gd=w.gd, ...
    Nz=cellfun(@(t)t.Nz,transforms),apvModeCount=cellfun(@(t)t.apvModeCount,transforms), ...
    quadratureCount=count,stratificationRelativeDifference=profileDifference, ...
    stratificationTolerance=options.stratificationTolerance,initialCondition="rest",meanDensityAnomaly="zero");
result.configuration.verticalGrids = cellfun(@(t)t.z,transforms,UniformOutput=false);
result.configuration.N2Profiles = cellfun(@(t)t.N2,transforms,UniformOutput=false);
result.configuration.verticalGridCoordinates = cellfun(@(t)t.verticalGridCoordinate,transforms,UniformOutput=false);
end

function validateTransforms(transforms,forcing)
w = transforms{1};
if ~isa(w,'WVTransformFreeSurfaceQG') || ~isequal(forcing.wvt,w)
    error('WV:ResponseTransform','The forcing and diffusivity must share a free-surface QG transform.');
end
for j = 1:3
    t = transforms{j};
    if ~isa(t,'WVTransformFreeSurfaceQG') || ~isscalar(t) || t.activeEndpointCount~=2
        error('WV:ResponseReferences','Each transform must have two active endpoints.');
    end
    for name = ["Lx","Ly","Lz","Nx","Ny","f","g","g0","gd","k","l","klNonzero","khUnique","klNonzeroKhUniqueIndex"]
        if ~isequal(t.(name),w.(name))
            error('WV:ResponseCompatibility','Transforms must share %s.',name);
        end
    end
    if ~t.shouldExcludeConjugates || ~t.shouldExcludeNyquist
        error('WV:ResponseHorizontalLayout','The assessment requires the compact Fourier layout without Nyquist modes.');
    end
    if j>1 && (t.Nz<=transforms{j-1}.Nz || t.apvModeCount<=transforms{j-1}.apvModeCount)
        error('WV:ResponseReferences','References must have progressively larger grids and APV mode counts.');
    end
end
end

function validateTolerance(tolerance,names)
for name = string(fieldnames(tolerance)).'
    value = tolerance.(name);
    if ~ismember(name,names) || ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || value<0
        error('WV:ResponseTolerance','Tolerances must name an observable and contain a finite nonnegative scalar.');
    end
end
end

function r = reconstruction(w,P,N2,z,weights,p)
kh = w.khUnique(p);
F = P*w.apvF;
G = P*w.apvG;
mu = w.apvMu(:,p).';
phi = [-F./mu,-P*w.zeroAPVF(:,:,p)/kh^2];
eta = (w.f/w.g)*[-G./mu,-P*w.zeroAPVG(:,:,p)/kh^2];
phiSurface = [-w.apvF(end,:)./mu,-w.zeroAPVF(end,:,p)/kh^2];
r.q = [F,zeros(length(z),2)];
r.buoyancy = -N2.*(eta-(w.f/w.g)*(1+z/w.Lz)*phiSurface);
r.ssh = (w.f/w.g)*phiSurface;
r.endpoint = [w.apvEndpointResponse(:,:,p),-(w.f/w.g)*eye(2)/kh^2];
r.energy = [sqrt(weights)*kh.*phi;sqrt(weights.*N2).*eta;(w.f/sqrt(w.g))*phiSurface];
end

function [c,dc] = response(page,w,p,forcing,time)
source = zeros(w.apvModeCount+2,1);
source(end-1) = -(w.g/w.f)*w.khUnique(p)^2;
n = length(source);
omega = 2*pi/forcing.period;
A = [page.energyGenerator,page.toEnergy*source,zeros(n,1);zeros(1,n),0,omega;zeros(1,n),-omega,0];
initial = [zeros(n,1);sin(forcing.phase);cos(forcing.phase)];
y = expm(time*A)*initial;
c = page.fromEnergy*y(1:n);
dc = page.generator*c+source*sin(omega*time+forcing.phase);
end

function output = observe(r,c,dc,weights,D)
q = r.q*c;
b = r.buoyancy*c;
endpoint = r.endpoint*c;
% Padding places surface observables in the same array as depth RMS fields.
field = zeros(length(weights),5);
field(:,1:2) = sqrt(2*weights/D).*[q,b];
field(1,3:5) = sqrt(2)*[r.ssh*c,endpoint.'];
energy = r.energy*c;
output.field = field;
output.values = [sum(abs(field).^2,1),sum(abs(energy).^2),sum(weights.*abs(q).^2), ...
    2*real(energy'*(r.energy*dc)),2*real(q'*(weights.*(r.q*dc)))];
end

function output = comparisons(values,differences,times,names)
keys = {'representation','evolution','total','convergence'};
referenceIndex = [3 4 3 3];
for j = 1:4
    absolute = abs(differences(:,:,j));
    absolute(:,1:5) = sqrt(absolute(:,1:5));
    magnitude = abs(values(:,:,referenceIndex(j)));
    magnitude(:,1:5) = sqrt(magnitude(:,1:5));
    relative = absolute./magnitude;
    relative(absolute==0 & magnitude==0) = 0;
    comparison = struct(absolute=array2table([times(:),absolute],VariableNames=[{'time'},names]), ...
        relative=array2table([times(:),relative],VariableNames=[{'time'},names]), ...
        referenceMagnitude=array2table([times(:),magnitude],VariableNames=[{'time'},names]));
    if j==4
        output.reference.convergence = comparison;
    else
        output.(keys{j}) = comparison;
    end
end
end

function accepted = acceptance(comparison,absolute,relative)
names = union(fieldnames(absolute),fieldnames(relative),'stable');
accepted = table();
if isempty(names), return; end
accepted.time = comparison.absolute.time;
for j = 1:length(names)
    name = names{j};
    a = 0;
    r = 0;
    if isfield(absolute,name), a = absolute.(name); end
    if isfield(relative,name), r = relative.(name); end
    accepted.(name) = comparison.absolute.(name)<=a+r*comparison.referenceMagnitude.(name);
end
end
