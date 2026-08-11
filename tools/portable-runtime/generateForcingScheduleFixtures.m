function manifest = generateForcingScheduleFixtures(options)
% Generate deterministic WaveVortexModel 4.x forcing-schedule fixtures.
arguments (Input)
    options.outputDirectory (1,1) string = fullfile(fileparts(mfilename("fullpath")),"fixtures")
end
arguments (Output)
    manifest (1,1) struct
end

outputDirectory = options.outputDirectory;
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

cases = {
    "forcing-nonlinear.nc", false, "nonlinear"
    "forcing-adaptive-damping.nc", false, "adaptive"
    "forcing-fixed-amplitude.nc", false, "fixed"
    "forcing-quadratic-bottom-friction.nc", false, "quadratic"
    "forcing-pseudo-topographic.nc", false, "pseudo"
    "forcing-beta-plane.nc", false, "beta"
    "forcing-mixed-hydrostatic.nc", true, "mixed"
    "forcing-mixed-nonhydrostatic.nc", false, "mixed"
    };

records = repmat(struct("name","","isHydrostatic",false,"forcingClasses",strings(0,1),"forcingNames",strings(0,1)),size(cases,1),1);
for iCase = 1:size(cases,1)
    fileName = cases{iCase,1};
    isHydrostatic = cases{iCase,2};
    kind = cases{iCase,3};
    wvt = newFixtureTransform(isHydrostatic);
    [Ap,Am,A0] = deterministicCoefficients(wvt,700+iCase);
    wvt.Ap = Ap;
    wvt.Am = Am;
    wvt.A0 = A0;
    wvt.t0 = -2.5;
    wvt.t = 8.25+iCase/10;
    wvt.setForcing(forcingForKind(wvt,kind));

    path = fullfile(outputDirectory,fileName);
    closeAndDeleteIfPresent(path);
    ncfile = wvt.writeToFile(path,shouldOverwriteExisting=true);
    normalizeFixtureMetadata(ncfile);
    ncfile.close();

    forcing = wvt.forcing;
    classes = strings(numel(forcing),1);
    names = strings(numel(forcing),1);
    for iForcing = 1:numel(forcing)
        classes(iForcing) = class(forcing(iForcing));
        names(iForcing) = string(forcing(iForcing).name);
    end
    records(iCase) = struct("name",fileName,"isHydrostatic",isHydrostatic,"forcingClasses",classes,"forcingNames",names);
end

[status,sourceCommit] = system('git rev-parse HEAD');
if status ~= 0
    error("WaveVortexModel:FixtureSourceCommitUnavailable","Unable to determine the fixture source commit.")
end
manifest = struct;
manifest.schema = "wave-vortex-forcing-fixtures-v1";
manifest.checkpointProfile = "wave-vortex-4x-v1";
manifest.forcingProfile = "wave-vortex-forcing-v1";
manifest.sourceRepository = "JeffreyEarly/wave-vortex-model";
manifest.sourceCommit = strtrim(string(sourceCommit));
manifest.waveVortexModelVersion = string(wvt.version);
manifest.matlabRelease = string(version("-release"));
manifest.files = records;
writelines(jsonencode(manifest,PrettyPrint=true),fullfile(outputDirectory,"forcing-fixture-manifest.json"));
end

function forcing = forcingForKind(wvt,kind)
switch kind
    case "nonlinear"
        forcing = WVNonlinearAdvection(wvt);
    case "adaptive"
        forcing = WVAdaptiveDamping(wvt);
    case "fixed"
        forcing = fixedAmplitudeForcing(wvt);
    case "quadratic"
        forcing = WVBottomFrictionQuadratic(wvt,Cd=1.7e-3);
    case "pseudo"
        forcing = pseudoTopographicForcing(wvt);
    case "beta"
        forcing = WVBetaPlanePVAdvection(wvt);
    case "mixed"
        forcing = WVForcing.empty(1,0);
        forcing(end+1) = fixedAmplitudeForcing(wvt);
        forcing(end+1) = pseudoTopographicForcing(wvt);
        forcing(end+1) = WVAdaptiveDamping(wvt);
        forcing(end+1) = WVBottomFrictionQuadratic(wvt,Cd=1.7e-3);
        forcing(end+1) = WVNonlinearAdvection(wvt);
        forcing(end+1) = WVBetaPlanePVAdvection(wvt);
    otherwise
        error("WaveVortexModel:UnknownForcingFixture","Unknown forcing fixture kind '%s'.",kind)
end
end

function forcing = fixedAmplitudeForcing(wvt)
forcing = WVFixedAmplitudeForcing(wvt,name="fixed-amplitude fixture",Ap_indices=uint64([1;6]),Apbar=complex([1.25;-0.5],[0.125;0.75]),Am_indices=uint64([2;9]),Ambar=complex([-2;0.75],[0.25;-0.125]),A0_indices=uint64([3;12]),A0bar=complex([0.4;-1.1],[-0.2;0.6]));
end

function forcing = pseudoTopographicForcing(wvt)
[i,j] = ndgrid(0:wvt.Nx-1,0:wvt.Ny-1);
topographicHeight = 7*cos(2*pi*i/wvt.Nx)+3*sin(2*pi*j/wvt.Ny)+cos(2*pi*(i/wvt.Nx+j/wvt.Ny));
forcing = WVPseudoTopographicWaveGeneration(wvt,topographicHeight=topographicHeight,barotropicVelocityAmplitude=complex([0.12;-0.04],[0.03;0.02]),darwinSymbol="M2",rampDuration=900,startTime=-50,shouldAvoidAdaptiveDamping=true,maximumForcedHorizontalWavenumber=2*wvt.dk,maximumForcedVerticalMode=2,name="pseudo-topographic fixture");
end

function wvt = newFixtureTransform(isHydrostatic)
wvt = WVTransformConstantStratification([15000 12000 1300],[8 6 7],N0=5.2e-3,rho0=1027,planetaryRadius=6.3712e6,rotationRate=7.292115e-5,latitude=33,g=9.80665,isHydrostatic=isHydrostatic,shouldAntialias=true);
end

function [Ap,Am,A0] = deterministicCoefficients(wvt,offset)
indices = reshape(1:prod(wvt.spectralMatrixSize),wvt.spectralMatrixSize);
Ap = complex(offset+indices/1000,-offset-indices/2000);
Am = complex(-2*offset+indices/1500,3*offset-indices/2500);
A0 = complex(4*offset-indices/3000,-5*offset+indices/3500);
end

function closeAndDeleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function normalizeFixtureMetadata(ncfile)
ncfile.addAttribute("date_created","2000-01-01 00:00:00 UTC");
ncfile.addAttribute("history","Deterministic portable forcing-schedule compatibility fixture.");
end
