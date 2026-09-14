function report = verifyWaveVortexModelPackage(packageRoot,oceanKitRoot,options)
%VERIFYWAVEVORTEXMODELPACKAGE Install and exercise a packaged distribution.
arguments
    packageRoot (1,1) string {mustBeFolder}
    oceanKitRoot (1,1) string {mustBeFolder}
    options.expectedVersion (1,1) string = ""
end

sourceManifest = readManifest(fullfile(packageRoot,"resources","mpackage.json"));
if options.expectedVersion == ""
    options.expectedVersion = string(sourceManifest.version);
end
require(string(sourceManifest.name) == "WaveVortexModel", ...
    "The package under test is not WaveVortexModel.");
require(string(sourceManifest.version) == options.expectedVersion, ...
    "The source manifest version does not match the expected version.");

configureIsolatedMPMRepository(oceanKitRoot);
packageUnderTest = matlab.mpm.Package(packageRoot);
require(string(packageUnderTest.ReleaseCompatibility) == ">=R2025b", ...
    "The package under test does not declare MATLAB R2025b as its compatibility floor.");
mpminstall(packageRoot,Prompt=false,Temporary=true,Verbosity="detailed");
packages = mpmlist;

expectedNames = [
    "ClassAnnotations"
    "Distributions"
    "InternalModes"
    "NetCDF"
    "SplineCore"
    "WaveVortexModel"
    "chebfun"
    ];
expectedVersions = [
    "1.2.1"
    "2.0.0"
    "2.0.0-beta.4"
    "1.0.2"
    "2.2.0"
    options.expectedVersion
    "5.7.0"
    ];
expectedSnapshotFolders = [
    "ClassAnnotations-1.2.1"
    "Distributions-2.0.0"
    "InternalModes-2.0.0-beta.4"
    "NetCDF-1.0.2"
    "SplineCore-2.2.0"
    ""
    "chebfun-5.7.0"
    ];
expectedIDs = strings(numel(expectedNames),1);
for iPackage = 1:numel(expectedNames)
    if expectedNames(iPackage) == "WaveVortexModel"
        expectedIDs(iPackage) = string(sourceManifest.id);
    else
        dependencyManifest = readManifest(fullfile(oceanKitRoot,expectedSnapshotFolders(iPackage), ...
            "resources","mpackage.json"));
        require(string(dependencyManifest.name) == expectedNames(iPackage) && ...
            string(dependencyManifest.version) == expectedVersions(iPackage), ...
            "The pinned OceanKit snapshot does not contain the expected " + expectedNames(iPackage) + ".");
        expectedIDs(iPackage) = string(dependencyManifest.id);
    end
end
actualNames = reshape(string([packages.Name]),[],1);
actualVersions = reshape(string([packages.Version]),[],1);
[actualNames,order] = sort(actualNames);
actualVersions = actualVersions(order);
packages = packages(order);
require(isequal(actualNames,expectedNames), ...
    "The installed dependency graph does not contain the expected packages.");
require(isequal(actualVersions,expectedVersions), ...
    "The installed dependency graph does not contain the expected versions.");

packageRoots = strings(numel(expectedNames),1);
for iPackage = 1:numel(expectedNames)
    installed = packages(iPackage);
    require(string(installed.ID) == expectedIDs(iPackage), ...
        "The installed package identity does not match " + expectedNames(iPackage) + ".");
    packageRoots(iPackage) = canonicalPath(string(installed.PackageRoot));
    require(isfolder(packageRoots(iPackage)), ...
        "The installed package root does not exist for " + expectedNames(iPackage) + ".");
    require(~startsWith(packageRoots(iPackage),canonicalPath(fileparts(packageRoot)) + filesep), ...
        expectedNames(iPackage) + " resolved from a sibling authoring repository.");
end

wvmRoot = packageRoots(expectedNames == "WaveVortexModel");
pathEntries = string(strsplit(path,pathsep));
unitTestRoot = canonicalPath(fullfile(wvmRoot,"UnitTests"));
require(~any(startsWith(canonicalExistingPaths(pathEntries),unitTestRoot)), ...
    "UnitTests is present on the installed WaveVortexModel path.");
for symbol = ["TestDivergence" "WVTestForcing" "RunAllUnitTests" "TestThermalOutputRestart" "thermalManufacturedState" "ThermalStageBoundForcing"]
    require(string(which(symbol)) == "", ...
        symbol + " is unexpectedly available from the installed package.");
end

representativeSymbols = [
    "CAAnnotatedClass"
    "NormalDistribution"
    "InternalModesWKBSpectral"
    "NetCDFFile"
    "BSpline"
    "WVTransform"
    "chebfun"
    ];
representativePackages = [
    "ClassAnnotations"
    "Distributions"
    "InternalModes"
    "NetCDF"
    "SplineCore"
    "WaveVortexModel"
    "chebfun"
    ];
for iSymbol = 1:numel(representativeSymbols)
    resolvedPath = string(which(representativeSymbols(iSymbol)));
    expectedRoot = packageRoots(expectedNames == representativePackages(iSymbol));
    require(resolvedPath ~= "" && startsWith(canonicalPath(resolvedPath),expectedRoot + filesep), ...
        representativeSymbols(iSymbol) + " did not resolve from the installed package graph.");
end

for symbol = ["WVTransformFreeSurfaceThermalQG","WVThermalAPVDamping","WVInternal.qgEvolutionAdapter","WVInternal.thermalNonlinearKernel","WVInternal.thermalConstrainedFit"]
    resolvedPath=string(which(symbol));
    require(resolvedPath~="" && startsWith(canonicalPath(resolvedPath),wvmRoot+filesep),symbol+" did not resolve from the installed WaveVortexModel root.");
end

consumer = exerciseInstalledPackage();
consumer.thermal = exerciseInstalledThermalPackage();
report = struct( ...
    "packageName","WaveVortexModel", ...
    "version",options.expectedVersion, ...
    "releaseCompatibility",string(packageUnderTest.ReleaseCompatibility), ...
    "packageNames",expectedNames, ...
    "packageVersions",expectedVersions, ...
    "packageIDs",expectedIDs, ...
    "packageRoots",packageRoots, ...
    "consumer",consumer);
fprintf("Verified installed WaveVortexModel %s and its six-package dependency graph.\n",options.expectedVersion);
end

function report = exerciseInstalledPackage()
Lxyz = [4000 3000 1000];
Nxyz = [8 6 5];
wvt = WVTransformConstantStratification(Lxyz,Nxyz,N0=5.2e-3,latitude=45, ...
    isHydrostatic=false,shouldAntialias=false);
wvt.initWithWaveModes(kMode=1,lMode=1,j=1,phi=0,u=0.01,sign=1);
[u,v,w] = wvt.variableWithName("u","v","w");
require(any(abs(u)>0,"all") && all(isfinite(u),"all") && ...
    all(isfinite(v),"all") && all(isfinite(w),"all"), ...
    "The installed constant-stratification transform did not evaluate finite wave fields.");

model = WVModel(wvt,shouldUseLinearDynamics=true);
model.integrateToTime(60,shouldShowIntegrationDiagnostics=false);
require(model.t == 60,"The installed linear model did not advance to the requested time.");

N2 = @(z) 2e-5*exp(z/4000);
variableWvt = WVTransformHydrostatic(Lxyz,Nxyz,N2Function=N2,latitude=45,shouldAntialias=false);
variableWvt.initWithWaveModes(kMode=1,lMode=1,j=1,phi=0,u=0.01,sign=1);
[variableU,variableEta] = variableWvt.variableWithName("u","eta");
require(all(isfinite(variableWvt.N2),"all") && any(abs(variableU)>0,"all") && ...
    all(isfinite(variableU),"all") && all(isfinite(variableEta),"all"), ...
    "The installed variable-stratification transform did not evaluate finite wave fields.");

statePath = string(tempname) + ".nc";
fileCleanup = onCleanup(@()deleteIfPresent(statePath));
ncfile = wvt.writeToFile(char(statePath),shouldOverwriteExisting=true);
handleCleanup = onCleanup(@()closeIfOpen(ncfile));
ncfile.close();
clear handleCleanup

restored = WVTransform.waveVortexTransformFromFile(char(statePath));
require(restored.t == wvt.t,"The restored transform time does not match the written state.");
require(isequal(restored.Ap,wvt.Ap) && isequal(restored.Am,wvt.Am) && isequal(restored.A0,wvt.A0), ...
    "The restored wave-vortex coefficients do not match the written state.");
reader = NetCDFFile(statePath,shouldReadOnly=true);
readerCleanup = onCleanup(@()closeIfOpen(reader));
reader.close();
clear readerCleanup
delete(statePath);
clear fileCleanup

report = struct("finalTime",model.t,"maximumU",max(abs(u),[],"all"), ...
    "variableModeCount",nnz(variableWvt.Ap) + nnz(variableWvt.Am));
end

function report = exerciseInstalledThermalPackage()
% Exercise the peer through public APIs; no authoring fixtures or data files.
clock=tic;
lengths=[1e5 1e5 1000]; grid=[8 8 65]; profile=@(z)1e-4+0*z;
w=WVTransformFreeSurfaceThermalQG.fromStratification(lengths,grid,N2Function=profile,thermalModeCount=17,mdaModeCount=2,kappa_z=1e-5,shouldCheckQuadraticAliasing=true);
w.Ath(2,1)=1e-4+2e-4i; w.Ath(3,2)=2e-4-1e-4i; w.Amda=[.01;-.02]; w.t=1234; w.t0=17;
w.addForcing(WVNonlinearAdvection(w));
w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7,period=1000,phase=.3));
w.addForcing(WVBottomFrictionQuadratic(w,Cd=1e-3));
apv=WVTransformFreeSurfaceQG(lengths,grid,N2Function=profile,latitude=w.latitude,apvModeCount=3,mdaModeCount=2);
closure=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5); w.addForcing(closure);
model=WVModel(w); model.setupIntegrator(integratorType="exponential",initialStep=5,maximumStep=5,exponentialAdaptive=false);
model.integrateToTime(1244,shouldShowIntegrationDiagnostics=false);
[~,~,processes]=w.coefficientTendency(); inventory=w.quadraticDiagnostics(tendency=processes.tendencies);
fields=w.reconstructFields(["u","qgpv","endpointAnomalies"]);
require(w.t==1244 && w.totalEnergy>0 && numel(processes.labels)==6 && all(isfinite(fields.qgpv),'all') && all(isfinite(fields.endpointAnomalies),'all'),"Installed thermal nonlinear/forcing/diagnostic APIs did not produce finite physical state.");
statePath=string(tempname)+".nc"; cleanup=onCleanup(@()deleteIfPresent(statePath));
file=w.writeToFile(char(statePath)); handleCleanup=onCleanup(@()closeIfOpen(file)); file.close(); clear handleCleanup
restored=WVTransform.waveVortexTransformFromFile(char(statePath),iTime=Inf);
require(isequal(restored.coefficientState(),w.coefficientState()) && restored.t==w.t && restored.t0==w.t0 && numel(restored.forcing)==4,"Installed thermal snapshot lost canonical state, clocks or forcing.");
restoredClosure=restored.forcing(arrayfun(@(force)isa(force,'WVThermalAPVDamping'),restored.forcing));
require(isscalar(restoredClosure),"Installed thermal snapshot did not restore its named closure.");
for name=string(closure.classRequiredPropertyNames())
    require(isequaln(restoredClosure.(name),closure.(name)),"Restored thermal closure changed "+name+".");
end
[state,assessment]=w.coefficientStateForTransform(restored);
require(assessment.relativeFieldError<1e-9 && norm(state.Ath-w.Ath,'fro')<1e-9,"Installed thermal physical transfer did not preserve its represented state.");
continued=WVModel(restored); continued.setupIntegrator(integratorType="exponential",initialStep=5,maximumStep=5,exponentialAdaptive=false);
continued.integrateToTime(1249,shouldShowIntegrationDiagnostics=false);
require(restored.t==1249 && isfinite(restored.totalEnergy),"Restored installed thermal transform did not reattach and continue.");
report=struct(finalTime=restored.t,energy=w.totalEnergy,inventory=inventory,processCount=numel(processes.labels),transferError=assessment.relativeFieldError,seconds=toc(clock));
end

function paths = canonicalExistingPaths(paths)
for iPath = 1:numel(paths)
    if isfolder(paths(iPath)) || isfile(paths(iPath))
        paths(iPath) = canonicalPath(paths(iPath));
    end
end
end

function manifest = readManifest(path)
if ~isfile(path)
    error("WaveVortexModel:PackageVerificationFailed","Package manifest not found at %s.",path);
end
manifest = jsondecode(fileread(path));
end

function require(condition,message)
if ~condition
    error("WaveVortexModel:PackageVerificationFailed","%s",message);
end
end

function closeIfOpen(file)
try
    file.close();
catch
end
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function path = canonicalPath(path)
path = string(java.io.File(char(path)).getCanonicalPath());
end
