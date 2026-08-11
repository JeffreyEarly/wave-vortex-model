function manifest = generateCheckpointFixtures(options)
% Generate deterministic WaveVortexModel 4.x checkpoint-reader fixtures.
%
% The fixtures are written exclusively through the production MATLAB
% persistence and NetCDF APIs. They cover both transform-level scalar state
% and model-style time-series state without defining a second file format.
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

fileRecords = repmat(struct("name","","isHydrostatic",false,"stateGroupPath","","stateCount",0,"times",[],"t0",0,"Nj",0,"Nkl",0),4,1);
recordIndex = 0;
for isHydrostatic = [false true]
    wvt = newFixtureTransform(isHydrostatic);
    [Ap,Am,A0] = deterministicCoefficients(wvt,10+20*double(isHydrostatic));
    wvt.Ap = Ap;
    wvt.Am = Am;
    wvt.A0 = A0;
    wvt.t0 = -3.25;
    wvt.t = 4.5+double(isHydrostatic);

    rootName = fixtureName("root",isHydrostatic);
    rootPath = fullfile(outputDirectory,rootName);
    closeAndDeleteIfPresent(rootPath);
    ncfile = wvt.writeToFile(rootPath,shouldOverwriteExisting=true);
    normalizeFixtureMetadata(ncfile);
    ncfile.close();
    recordIndex = recordIndex+1;
    fileRecords(recordIndex) = fixtureRecord(rootName,isHydrostatic,"/",wvt.t,wvt.t0,wvt);

    timeSeriesName = fixtureName("time-series",isHydrostatic);
    timeSeriesPath = fullfile(outputDirectory,timeSeriesName);
    closeAndDeleteIfPresent(timeSeriesPath);
    requiredProperties = setdiff(wvt.requiredProperties,{'Ap','Am','A0','t'},'stable');
    ncfile = wvt.writeToFile(timeSeriesPath,requiredProperties{:},shouldOverwriteExisting=true,shouldAddRequiredProperties=false);
    cleanup = onCleanup(@()closeIfOpen(ncfile));
    stateGroup = ncfile.addGroup("wave-vortex");
    stateGroup.addAttribute("AnnotatedClass","WVModelOutputGroupEvenlySpaced");
    stateGroup.addAttribute("name","wave-vortex");
    stateGroup.addDimension("j",wvt.j);
    timeAttributes = containers.Map(KeyType="char",ValueType="any");
    timeAttributes("standard_name") = "time";
    timeAttributes("axis") = "T";
    [~,timeVariable] = stateGroup.addDimension("t",length=Inf,type="double",attributes=timeAttributes);
    coefficientNames = ["Ap" "Am" "A0"];
    coefficientVariables = cell(size(coefficientNames));
    for iCoefficient = 1:numel(coefficientNames)
        name = coefficientNames(iCoefficient);
        annotation = wvt.propertyAnnotationWithName(char(name));
        attributes = annotation.attributes;
        attributes("units") = annotation.units;
        attributes("long_name") = annotation.description;
        coefficientVariables{iCoefficient} = stateGroup.addVariable(name,{"j","kl","t"},type="double",isComplex=true,attributes=attributes);
    end
    times = [0.5 1.75 3.25];
    for iTime = 1:numel(times)
        [Ap,Am,A0] = deterministicCoefficients(wvt,100*iTime+20*double(isHydrostatic));
        timeVariable.setValueAlongDimensionAtIndex(times(iTime),"t",iTime);
        coefficientVariables{1}.setValueAlongDimensionAtIndex(Ap,"t",iTime);
        coefficientVariables{2}.setValueAlongDimensionAtIndex(Am,"t",iTime);
        coefficientVariables{3}.setValueAlongDimensionAtIndex(A0,"t",iTime);
    end
    normalizeFixtureMetadata(ncfile);
    ncfile.close();
    clear cleanup
    recordIndex = recordIndex+1;
    fileRecords(recordIndex) = fixtureRecord(timeSeriesName,isHydrostatic,"/wave-vortex",times,wvt.t0,wvt);
end

manifest = struct;
manifest.schema = "wave-vortex-checkpoint-fixtures-v1";
manifest.profile = "wave-vortex-4x-v1";
manifest.sourceRepository = "JeffreyEarly/wave-vortex-model";
manifest.sourceCommit = "52de16195c6817c6f107b6147c1f7e46922e8983";
manifest.waveVortexModelVersion = string(wvt.version);
manifest.matlabRelease = string(version("-release"));
manifest.files = fileRecords;
writelines(jsonencode(manifest,PrettyPrint=true),fullfile(outputDirectory,"fixture-manifest.json"));
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

function name = fixtureName(kind,isHydrostatic)
if isHydrostatic
    approximation = "hydrostatic";
else
    approximation = "nonhydrostatic";
end
name = kind+"-"+approximation+".nc";
end

function record = fixtureRecord(name,isHydrostatic,stateGroupPath,times,t0,wvt)
record = struct("name",name,"isHydrostatic",isHydrostatic,"stateGroupPath",stateGroupPath,"stateCount",numel(times),"times",times,"t0",t0,"Nj",wvt.Nj,"Nkl",wvt.Nkl);
end

function closeAndDeleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function normalizeFixtureMetadata(ncfile)
ncfile.addAttribute("date_created","2000-01-01 00:00:00 UTC");
ncfile.addAttribute("history","Deterministic portable-checkpoint compatibility fixture.");
end

function closeIfOpen(ncfile)
if ~isempty(ncfile) && isvalid(ncfile) && ~isempty(ncfile.id)
    ncfile.close();
end
end
