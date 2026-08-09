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
require(string(packageUnderTest.ReleaseCompatibility) == ">=R2025a", ...
    "The package under test does not declare MATLAB R2025a as its compatibility floor.");
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
    "1.3.0"
    "1.0.2"
    "2.2.0"
    options.expectedVersion
    "5.7.0"
    ];
expectedSnapshotFolders = [
    "ClassAnnotations-1.2.1"
    "Distributions-2.0.0"
    "InternalModes-1.3.0"
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
for symbol = ["TestDivergence" "WVTestForcing" "RunAllUnitTests"]
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

consumer = exerciseInstalledPackage();
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
require(all(isfinite(variableWvt.F),"all") && all(isfinite(variableWvt.G),"all"), ...
    "The installed variable-stratification transform did not construct finite modes.");

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
    "variableModeCount",size(variableWvt.F,2));
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
