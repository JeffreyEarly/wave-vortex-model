function report = qualifyCapturedDensity(inputPath,outputDirectory,options)
% Qualify the current moment solver on one captured density state.
% The weighted empirical distribution is a discrete quadrature reference,
% not an exact continuous no-motion profile or an interpolation prescription.
arguments (Input)
    inputPath (1,1) string {mustBeFile}
    outputDirectory (1,1) string
    options.solvers (1,:) string {mustBeMember(options.solvers,["lsqnonlin","fminsearch"])} = ["lsqnonlin","fminsearch"]
end
arguments (Output)
    report (1,1) struct
end

if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
[~,name] = fileparts(inputPath);
prefix = fullfile(outputDirectory,name);
report = struct(schema="wave-vortex-captured-density-qualification-v1",inputPath=inputPath);
report.matlabRelease = string(version("-release"));
report.platform = string(computer);
report.input = fileProvenance(inputPath);
report.solverSource = fileProvenance(fullfile(root,"Operations","WVNoMotionProfileOperation.m"));
report.qualificationSource = fileProvenance(string(mfilename("fullpath"))+".m");
[status,commit] = system("git -C " + shellQuote(root) + " rev-parse HEAD");
assert(status==0,"Cannot read the source revision.");
report.sourceCommit = string(strtrim(commit));
fprintf("CAPTURED_DENSITY_BEGIN %s\n",inputPath);
started = tic;
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile(char(inputPath),iTime=Inf,shouldReadOnly=true);
fileCleanup = onCleanup(@()ncfile.close());
rho_total = wvt.rho_total;
report.loadSeconds = toc(started);
z = wvt.z(:);
z_int = wvt.z_int(:);
Lz = wvt.Lz;
rho_nm0 = wvt.rho_nm0(:);
report.transform = string(class(wvt));
report.grid = size(rho_total);
report.time = wvt.t;
report.Lz = Lz;
report.weightSum = sum(z_int)/Lz;
report.densityRange = [min(rho_total,[],"all"),max(rho_total,[],"all")];
report.referenceRange = [rho_nm0(end),rho_nm0(1)];
report.initialMeanProfileMaximumDifference = max(abs(squeeze(mean(rho_total,[1,2]))-rho_nm0));
clear fileCleanup ncfile wvt

rho0 = rho_nm0(end);
rhoD = rho_nm0(1);
started = tic;
% Call the production full-density moment extraction exactly once. Both
% optimizers below consume these identical moments and production kernels.
moments = WVNoMotionProfileOperation.moments_from_rho_tot(rho_total,rho0,rhoD,z_int,Lz);
report.momentExtractionSeconds = toc(started);
weights = flip(z_int/Lz);
u0 = WVNoMotionProfileOperation.rho_to_u(rho_nm0,rho0,rhoD);
report.original = profileMetrics(rho_nm0,u0,weights,moments,rho0,rhoD);
save(prefix+"-compact.mat","z","z_int","Lz","rho_nm0","moments","u0");
fprintf("CAPTURED_DENSITY_EXTRACTED %s load=%.6g moments=%.6g\n",name,report.loadSeconds,report.momentExtractionSeconds);

template = struct(solver="",status="not-run",solveSeconds=0,exitflag=0,output=struct(),metrics=struct(),rho=[],u=[]);
report.solvers = repmat(template,0,1);
profiles = {rho_nm0};
for solver = options.solvers
    result = template;
    result.solver = solver;
    if solver=="lsqnonlin" && ~WVNoMotionProfileOperation.hasOptimizationToolboxSupport()
        result.status = "unavailable";
        report.solvers(end+1) = result;
        continue
    end
    started = tic;
    [u,exitflag,output] = solveCurrentMoments(solver,u0,weights,moments);
    result.solveSeconds = toc(started);
    rho = WVNoMotionProfileOperation.u_to_rho(u,rho0,rhoD);
    result.status = "returned";
    result.exitflag = exitflag;
    result.output = output;
    result.metrics = profileMetrics(rho,u,weights,moments,rho0,rhoD);
    result.rho = rho;
    result.u = u;
    report.solvers(end+1) = result;
    profiles{end+1} = rho; %#ok<AGROW>
    writeJson(prefix+"-report.json",report);
    fprintf("CAPTURED_DENSITY_SOLVED %s solver=%s seconds=%.6g exitflag=%g residual=%.6g\n",name,solver,result.solveSeconds,exitflag,result.metrics.maximumMomentResidual);
end

started = tic;
% Sorting pairs each physical sample with its original positive quadrature
% volume. The fit is also compared as a discrete weighted distribution.
rhoSorted = (rho_total(:)-rho0)/(rhoD-rho0);
clear rho_total
[rhoSorted,order] = sort(rhoSorted,"ascend");
horizontalCount = prod(report.grid(1:2));
sortedWeights = (z_int(ceil(order/horizontalCount))/Lz)/horizontalCount;
clear order
volume = cumsum(sortedWeights);
densityIntegral = cumsum(sortedWeights.*rhoSorted);
clear sortedWeights
report.sortedVolume = volume(end);
report.sortingSeconds = toc(started);
probabilities = linspace(0,1,4097)';
quantiles = zeros(size(probabilities));
for index = 1:numel(probabilities)
    quantiles(index) = rhoSorted(firstAtLeast(volume,probabilities(index)))*(rhoD-rho0)+rho0;
end
densityThresholds = linspace(0,1,4097)';
empiricalCDF = zeros(size(densityThresholds));
for index = 1:numel(densityThresholds)
    empiricalCDF(index) = cumulativeAtDensity(rhoSorted,volume,densityThresholds(index),true);
end
referenceBinMeans = zeros(size(weights));
edges = [0;cumsum(weights)];
for index = 1:numel(weights)
    integral = integralAtVolume(volume,densityIntegral,edges(index+1))-integralAtVolume(volume,densityIntegral,edges(index));
    referenceBinMeans(index) = rho0+(rhoD-rho0)*integral/weights(index);
end
referenceBinMeans = flip(referenceBinMeans);
report.distributionInterpretation = "Exact weighted empirical sample distribution; fitted nodes use the same z_int masses. Bin means and quantiles are discrete parcel summaries, not nodal continuous-profile truth. Linear inverse comparisons include sampling and interpolation error.";
report.referenceBinMeans = referenceBinMeans;
report.original.distribution = distributionMetrics(profiles{1},z,weights,rhoSorted,volume,densityIntegral,densityThresholds,empiricalCDF,rho0,rhoD,Lz);
profileIndex = 2;
for index = 1:numel(report.solvers)
    if report.solvers(index).status=="returned"
        report.solvers(index).metrics.distribution = distributionMetrics(profiles{profileIndex},z,weights,rhoSorted,volume,densityIntegral,densityThresholds,empiricalCDF,rho0,rhoD,Lz);
        profileIndex = profileIndex+1;
    end
end
save(prefix+"-compact.mat","probabilities","quantiles","densityThresholds","empiricalCDF","referenceBinMeans","report","-append");
writeJson(prefix+"-report.json",report);
fprintf("CAPTURED_DENSITY_COMPLETE %s sorting=%.6g output=%s\n",name,report.sortingSeconds,prefix+"-report.json");
end

function [u,exitflag,output] = solveCurrentMoments(solver,u0,weights,moments)
% These options intentionally reproduce find_rho_nm without repeating its
% expensive moment extraction. The production residual and Jacobian own all
% scientific arithmetic; report.solverSource binds the comparison revision.
if solver=="lsqnonlin"
    solverOptions = optimoptions("lsqnonlin","Display","none","Algorithm","trust-region-reflective", ...
        "SpecifyObjectiveGradient",true,"FunctionTolerance",1e-12,"StepTolerance",1e-12, ...
        "OptimalityTolerance",1e-12,"MaxFunctionEvaluations",5e4,"MaxIterations",2e3);
    fun = @(u) WVNoMotionProfileOperation.residual_and_jacobian(u,weights,moments);
    [u,~,~,exitflag,output] = lsqnonlin(fun,u0,[],[],solverOptions);
else
    solverOptions = optimset("Display","notify","TolFun",1e-12,"TolX",1e-5,"MaxIter",10e3,"MaxFunEvals",5e4);
    fun = @(u) sum(WVNoMotionProfileOperation.residual(u,weights,moments).^2);
    [u,~,exitflag,output] = fminsearch(fun,u0,solverOptions);
end
end

function result = profileMetrics(rho,u,weights,moments,rho0,rhoD)
[residual,jacobian] = WVNoMotionProfileOperation.residual_and_jacobian(u,weights,moments);
singularValues = svd(jacobian);
normalized = flip((rho-rho0)/(rhoD-rho0));
powers = (1:numel(weights)).';
directMoments = (normalized.'.^powers)*weights;
result = struct(allFinite=all(isfinite(rho)),strictlyDecreasing=all(diff(rho)<0));
result.maximumMomentResidual = max(abs(residual));
result.sumSquaredMomentResidual = sum(residual.^2);
result.firstFourMomentResiduals = residual(1:min(4,end));
result.directMomentAgreement = max(abs(directMoments-moments-residual));
result.jacobianRank = rank(jacobian);
result.jacobianColumns = size(jacobian,2);
result.jacobianSingularValues = singularValues;
result.jacobianConditionNumber = singularValues(1)/singularValues(end);
end

function result = distributionMetrics(rho,z,weights,sorted,volume,densityIntegral,thresholds,empiricalCDF,rho0,rhoD,Lz)
nodes = flip((rho-rho0)/(rhoD-rho0));
edges = [0;cumsum(weights)];
cdfMaximum = 0;
wasserstein = 0;
for index = 1:numel(nodes)
    below = cumulativeAtDensity(sorted,volume,nodes(index),false);
    through = cumulativeAtDensity(sorted,volume,nodes(index),true);
    cdfMaximum = max([cdfMaximum,abs(below-edges(index)),abs(through-edges(index+1))]);
    crossing = min(max(through,edges(index)),edges(index+1));
    wasserstein = wasserstein + nodes(index)*(2*crossing-edges(index)-edges(index+1)) ...
        + integralAtVolume(volume,densityIntegral,edges(index)) ...
        + integralAtVolume(volume,densityIntegral,edges(index+1)) ...
        - 2*integralAtVolume(volume,densityIntegral,crossing);
end
result = struct(discreteCDFMaximumDifference=cdfMaximum,discreteWassersteinDensity=wasserstein*(rhoD-rho0));
if all(diff(nodes)>0)
    linearInverse = interp1(nodes,flip(z),thresholds,"linear");
    inverseDifference = linearInverse + Lz*empiricalCDF;
    result.linearInverseEmpiricalHeightMaximumInterior = max(abs(inverseDifference(2:end-1)));
    result.linearInverseEmpiricalHeightRMSInterior = sqrt(mean(inverseDifference(2:end-1).^2));
    heights = flip(z);
    inverseMean = 0;
    for index = 1:numel(nodes)-1
        lowVolume = cumulativeAtDensity(sorted,volume,nodes(index),true);
        highVolume = cumulativeAtDensity(sorted,volume,nodes(index+1),true);
        mass = highVolume-lowVolume;
        moment = integralAtVolume(volume,densityIntegral,highVolume)-integralAtVolume(volume,densityIntegral,lowVolume);
        slope = (heights(index+1)-heights(index))/(nodes(index+1)-nodes(index));
        inverseMean = inverseMean + heights(index)*mass+slope*(moment-nodes(index)*mass);
    end
    % The minimum-density atoms lie at the upper endpoint, z = 0, so their
    % inverse contribution vanishes. Unsupported density lies outside this
    % integral and is reported explicitly rather than clamped.
    result.densityVolumeOutsideFittedSupport = cumulativeAtDensity(sorted,volume,nodes(1),false) ...
        + volume(end)-cumulativeAtDensity(sorted,volume,nodes(end),true);
    result.linearInverseMeanDisplacement = sum(z.*flip(weights))-inverseMean;
end
end

function index = firstAtLeast(values,target)
low = 1;
high = numel(values);
while low<high
    middle = floor((low+high)/2);
    if values(middle)<target
        low = middle+1;
    else
        high = middle;
    end
end
index = low;
end

function value = cumulativeAtDensity(sorted,volume,target,inclusive)
low = 0;
high = numel(sorted);
while low<high
    middle = ceil((low+high)/2);
    if sorted(middle)<target || (inclusive && sorted(middle)==target)
        low = middle;
    else
        high = middle-1;
    end
end
if low==0
    value = 0;
else
    value = volume(low);
end
end

function value = integralAtVolume(volume,densityIntegral,target)
if target<=0
    value = 0;
    return
end
index = firstAtLeast(volume,target);
if index==1
    value = densityIntegral(1)*target/volume(1);
else
    fraction = (min(target,volume(end))-volume(index-1))/(volume(index)-volume(index-1));
    value = densityIntegral(index-1)+fraction*(densityIntegral(index)-densityIntegral(index-1));
end
end

function value = fileProvenance(path)
information = dir(path);
[status,digest] = system("shasum -a 256 " + shellQuote(path));
assert(status==0,"Cannot hash %s.",path);
value = struct(path=path,bytes=information.bytes,sha256=string(extractBefore(digest," ")));
end

function quoted = shellQuote(value)
quote = string(char(39));
quoted = quote+replace(value,quote,string(char([39,34,39,34,39])))+quote;
end

function writeJson(path,value)
fid = fopen(path,"w");
assert(fid>=0,"Cannot create %s.",path);
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,"%s\n",jsonencode(value,PrettyPrint=true));
end
