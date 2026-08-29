function manifest = exportSpectralFluxFixture(outputDirectory,options)
% Export one deterministic 15-to-4 spectral-flux fixture.
%
% This benchmark helper evaluates the issue #19 operator with WVM's
% production Fourier layout and variable-stratification wave F/G vertical
% operators. It exports ready modal inputs and the four projected modal
% targets; it does not export model state or reimplement the complete WVM
% nonlinear-flux calculation.
arguments (Input)
    outputDirectory (1,1) string {mustBeNonzeroLengthText}
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [256 256 129]
    options.Lxyz (1,3) double {mustBePositive} = [15e3 15e3 1300]
    options.latitude (1,1) double = 45
    options.seed (1,1) double {mustBeInteger,mustBeNonnegative} = 19019
    options.fixtureId (1,1) string = ""
end
arguments (Output)
    manifest (1,1) struct
end

if options.Nxyz(1) ~= options.Nxyz(2) || options.Lxyz(1) ~= options.Lxyz(2)
    error("WaveVortexBenchmark:SpectralFluxFixtureRequiresSquareDomain","The spectral-flux fixture requires equal horizontal grid counts and domain lengths so integer K-squared groups identify the WVM operator family exactly.")
end
if mod(options.Nxyz(1),2) ~= 0 || options.Nxyz(3) < 4
    error("WaveVortexBenchmark:InvalidSpectralFluxFixtureSize","The spectral-flux fixture requires an even horizontal grid and Nz >= 4.")
end
if isfolder(outputDirectory)
    existing = dir(outputDirectory);
    names = string({existing.name});
    existing = existing(~ismember(names,["." ".."]));
    if ~isempty(existing)
        error("WaveVortexBenchmark:SpectralFluxFixtureExists","The output directory must not contain existing files: %s.",outputDirectory)
    end
end
if ~isfolder(outputDirectory)
    mkdir(outputDirectory);
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalPath = path;
originalRng = rng;
stateCleanup = onCleanup(@()restoreState(originalPath,originalRng));
addpath(repositoryRoot,benchmarkFolder);
rng(options.seed,"twister");

wvt = WVTransformBoussinesq(options.Lxyz,options.Nxyz,N2=@spectralFluxFixtureN2,latitude=options.latitude,shouldAntialias=true);
Nx = wvt.Nx;
Ny = wvt.Ny;
Nz = wvt.Nz;
Nj = wvt.Nj;
Nkl = wvt.Nkl;
if Nj ~= floor(2*(Nz-1)/3)
    error("WaveVortexBenchmark:SpectralFluxFixtureVerticalRetention","WVM retained %d vertical modes; issue #19 requires floor(2*(Nz-1)/3) = %d.",Nj,floor(2*(Nz-1)/3))
end

modeKeys = int32([wvt.kMode_wv(:).';wvt.lMode_wv(:).']);
groupIndices = uint32(wvt.iK2unique(:)-1);
groupCount = wvt.nK2unique;
groupKeys = zeros(1,groupCount,"uint64");
for iGroup = 1:groupCount
    iMode = find(groupIndices == iGroup-1,1);
    kMode = int64(modeKeys(1,iMode));
    lMode = int64(modeKeys(2,iMode));
    groupKeys(iGroup) = uint64(kMode*kMode+lMode*lMode);
end
if any(diff(double(groupIndices)) < 0) || ~isequal(unique(double(groupIndices),"stable").',0:groupCount-1)
    error("WaveVortexBenchmark:SpectralFluxFixtureGroupOrder","WVM K-squared groups must be contiguous in radial mode order.")
end

familyIds = ["wave-f" "wave-g"];
inputFieldNames = ["U" "V" "W" "q0_x" "q0_y" "q0_z" "q1_x" "q1_y" "q1_z" "q2_x" "q2_y" "q2_z" "q3_x" "q3_y" "q3_z"];
targetNames = ["Fu" "Fv" "Fw" "Feta"];
inputFieldFamilies = uint32([0 0 1 0 0 1 0 0 1 1 1 0 1 1 0]);
targetFieldFamilies = uint32([0 0 1 1]);

inverseOperators = zeros(Nz,Nj,numel(familyIds),groupCount);
forwardOperators = zeros(Nj,Nz,numel(familyIds),groupCount);
for iGroup = 1:groupCount
    iMode = find(groupIndices == iGroup-1,1);
    kMode = double(modeKeys(1,iMode));
    lMode = double(modeKeys(2,iMode));
    inverseOperators(:,:,1,iGroup) = wvt.FwInvMatrix(kMode,lMode);
    inverseOperators(:,:,2,iGroup) = wvt.GwInvMatrix(kMode,lMode);
    forwardOperators(:,:,1,iGroup) = wvt.FwMatrix(kMode,lMode);
    forwardOperators(:,:,2,iGroup) = wvt.GwMatrix(kMode,lMode);
end

modalInputs = complex(2*rand(Nj,numel(inputFieldNames),Nkl)-1,2*rand(Nj,numel(inputFieldNames),Nkl)-1)/8;
dcMode = find(modeKeys(1,:) == 0 & modeKeys(2,:) == 0,1);
modalInputs(:,:,dcMode) = real(modalInputs(:,:,dcMode));
horizontalPointCount = Nx*Ny;
physicalInputs = zeros(Nx,Ny,Nz,numel(inputFieldNames));
for iField = 1:numel(inputFieldNames)
    spectrum = reconstructSpectrum(modalInputs,iField,inputFieldFamilies(iField),inverseOperators,groupIndices);
    physicalInputs(:,:,:,iField) = wvt.transformToSpatialDomainWithFourier(spectrum);
end

U = physicalInputs(:,:,:,1);
V = physicalInputs(:,:,:,2);
W = physicalInputs(:,:,:,3);
modalTargets = complex(zeros(Nj,numel(targetNames),Nkl));
inverseScale = 1/(horizontalPointCount*horizontalPointCount);
for iTarget = 1:numel(targetNames)
    firstDerivative = 4+3*(iTarget-1);
    qx = physicalInputs(:,:,:,firstDerivative);
    qy = physicalInputs(:,:,:,firstDerivative+1);
    qz = physicalInputs(:,:,:,firstDerivative+2);
    target = -inverseScale*(U.*qx+V.*qy+W.*qz);
    rawSpectrum = horizontalPointCount*wvt.transformFromSpatialDomainWithFourier(target);
    modalTargets(:,iTarget,:) = projectSpectrum(rawSpectrum,targetFieldFamilies(iTarget),forwardOperators,groupIndices);
end

payloads = repmat(emptyPayloadRecord(),0,1);
payloads(end+1) = writePayload(outputDirectory,"horizontal-mode-keys.i32le",modeKeys,"int32-le",["coordinate" "mode"],[2 Nkl]);
payloads(end+1) = writePayload(outputDirectory,"vertical-mode-keys.i32le",int32(wvt.j(:)),"int32-le","j",Nj);
payloads(end+1) = writePayload(outputDirectory,"mode-group-indices.u32le",groupIndices,"uint32-le","mode",Nkl);
payloads(end+1) = writePayload(outputDirectory,"group-keys.u64le",groupKeys,"uint64-le","group",groupCount);
payloads(end+1) = writePayload(outputDirectory,"inverse-operators.f64le",inverseOperators,"float64-le",["z" "j" "operatorFamily" "group"],[Nz Nj numel(familyIds) groupCount]);
payloads(end+1) = writePayload(outputDirectory,"forward-operators.f64le",forwardOperators,"float64-le",["j" "z" "operatorFamily" "group"],[Nj Nz numel(familyIds) groupCount]);
payloads(end+1) = writeComplexPayload(outputDirectory,"modal-inputs.c128le",modalInputs,["j" "inputField" "mode"],[Nj numel(inputFieldNames) Nkl]);
payloads(end+1) = writeComplexPayload(outputDirectory,"expected-modal-targets.c128le",modalTargets,["j" "target" "mode"],[Nj numel(targetNames) Nkl]);

source = sourceRecord(repositoryRoot);
if options.fixtureId == ""
    options.fixtureId = sprintf("wvm-variable-stratification-%dx%d-nz%d-f4-seed%d",Nx,Ny,Nz,options.seed);
end
status = "authoritative-wvm-export";
if source.dirtyTree
    status = "invalid";
end
manifest = struct( ...
    "schema","spectral-flux-fixture-v1", ...
    "fixtureId",options.fixtureId, ...
    "status",status, ...
    "authoritative",~source.dirtyTree, ...
    "createdAtUtc",string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
    "numericType","float64", ...
    "byteOrder","little-endian", ...
    "provenance",source, ...
    "generator",struct("path","Benchmarks/exportSpectralFluxFixture.m","command",sprintf("exportSpectralFluxFixture(outputDirectory,Nxyz=[%d %d %d],Lxyz=[%.17g %.17g %.17g],latitude=%.17g,seed=%d)",options.Nxyz,options.Lxyz,options.latitude,options.seed)), ...
    "workload",struct("Nx",Nx,"Ny",Ny,"Nz",Nz,"H",(Nx/2+1)*Ny,"Nkl",Nkl,"Nj",Nj,"fields",4,"Lxyz",options.Lxyz,"latitude",options.latitude), ...
    "retention",struct("horizontalPolicy","radial-two-thirds","horizontalCutoffFraction",2/3,"verticalPolicy","floor(2*(Nz-1)/3)","verticalRetainedFraction",Nj/(Nz-1)), ...
    "modeOrder",struct("logicalAxes",["k" "l" "j" "field"],"horizontal","WVM radial magnitude then k then l","vertical","j ascending from zero"), ...
    "normalization",struct("horizontalForward","raw FFT coefficients","horizontalInverse","raw inverse FFT followed by division by Nx*Ny before each physical factor","pointwiseScale",inverseScale), ...
    "operatorContract",struct("familyIds",familyIds,"inputFieldNames",inputFieldNames,"inputFieldFamilies",inputFieldFamilies,"targetNames",targetNames,"targetFieldFamilies",targetFieldFamilies,"groupCount",groupCount,"groupRule","exact integer k^2+l^2 on a square horizontal domain"), ...
    "derivativeConvention","Input slots 0..2 are U,V,W; slots 3+3*t..5+3*t are q[t].x,q[t].y,q[t].z. q[3].z denotes the complete eta vertical-advection factor, including eta*dLnN2 when assembled by WVM.", ...
    "oracle",struct("identity","WVM MATLAB Fourier transforms plus WVM Fw/Gw projection matrices and direct -(U*qx+V*qy+W*qz) evaluation","maximumScaleNormalizedErrorTolerance",1e-12,"relativeL2ErrorTolerance",1e-12), ...
    "payloads",payloads);

manifestPath = fullfile(outputDirectory,"manifest.json");
writeText(manifestPath,string(jsonencode(manifest,PrettyPrint=true))+newline);
clear stateCleanup
end

function spectrum = reconstructSpectrum(modalInputs,iField,familyIndex,inverseOperators,groupIndices)
Nz = size(inverseOperators,1);
Nkl = size(modalInputs,3);
spectrum = complex(zeros(Nz,Nkl));
for iGroup = 1:size(inverseOperators,4)
    indices = find(groupIndices == iGroup-1);
    spectrum(:,indices) = inverseOperators(:,:,double(familyIndex)+1,iGroup)*reshape(modalInputs(:,iField,indices),size(modalInputs,1),[]);
end
end

function modalTarget = projectSpectrum(spectrum,familyIndex,forwardOperators,groupIndices)
Nj = size(forwardOperators,1);
Nkl = size(spectrum,2);
modalTarget = complex(zeros(Nj,1,Nkl));
for iGroup = 1:size(forwardOperators,4)
    indices = find(groupIndices == iGroup-1);
    modalTarget(:,1,indices) = reshape(forwardOperators(:,:,double(familyIndex)+1,iGroup)*spectrum(:,indices),Nj,1,[]);
end
end

function payload = writePayload(outputDirectory,fileName,value,elementType,axes,shape)
pathname = fullfile(outputDirectory,fileName);
fileId = fopen(pathname,"w","ieee-le");
if fileId < 0
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Unable to write %s.",pathname)
end
cleanup = onCleanup(@()fclose(fileId));
precision = precisionForElementType(elementType);
written = fwrite(fileId,value,precision);
if written ~= numel(value)
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Expected to write %d elements to %s but wrote %d.",numel(value),pathname,written)
end
clear cleanup
payload = payloadRecord(pathname,fileName,elementType,axes,shape,false);
end

function payload = writeComplexPayload(outputDirectory,fileName,value,axes,shape)
pathname = fullfile(outputDirectory,fileName);
fileId = fopen(pathname,"w","ieee-le");
if fileId < 0
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Unable to write %s.",pathname)
end
cleanup = onCleanup(@()fclose(fileId));
interleaved = zeros(2,numel(value));
interleaved(1,:) = real(value(:));
interleaved(2,:) = imag(value(:));
written = fwrite(fileId,interleaved,"double");
if written ~= 2*numel(value)
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Expected to write %d scalar elements to %s but wrote %d.",2*numel(value),pathname,written)
end
clear cleanup
payload = payloadRecord(pathname,fileName,"complex-float64-interleaved-le",axes,shape,true);
end

function payload = payloadRecord(pathname,fileName,elementType,axes,shape,isComplex)
information = dir(pathname);
strides = ones(size(shape));
for iDimension = 2:numel(shape)
    strides(iDimension) = strides(iDimension-1)*shape(iDimension-1);
end
payload = struct("path",string(fileName),"byteCount",information.bytes,"elementType",string(elementType),"logicalAxes",string(axes),"shape",double(shape),"stridesElements",double(strides),"isComplex",logical(isComplex),"sha256",sha256File(pathname));
end

function payload = emptyPayloadRecord()
payload = struct("path","","byteCount",0,"elementType","","logicalAxes",strings(1,0),"shape",zeros(1,0),"stridesElements",zeros(1,0),"isComplex",false,"sha256","");
end

function precision = precisionForElementType(elementType)
switch elementType
    case "int32-le"
        precision = "int32";
    case "uint32-le"
        precision = "uint32";
    case "uint64-le"
        precision = "uint64";
    case "float64-le"
        precision = "double";
    otherwise
        error("WaveVortexBenchmark:UnknownSpectralFluxFixtureType","Unknown fixture element type %s.",elementType)
end
end

function source = sourceRecord(repositoryRoot)
[commitStatus,commit] = system("git -C " + shellQuote(repositoryRoot) + " rev-parse HEAD");
[treeStatus,tree] = system("git -C " + shellQuote(repositoryRoot) + " rev-parse HEAD^{tree}");
[dirtyStatus,dirty] = system("git -C " + shellQuote(repositoryRoot) + " status --porcelain --untracked-files=normal");
if commitStatus ~= 0 || treeStatus ~= 0 || dirtyStatus ~= 0
    error("WaveVortexBenchmark:SpectralFluxFixtureGitProvenance","Unable to read WVM git provenance.")
end
source = struct("repository","JeffreyEarly/wave-vortex-model","commit",strtrim(string(commit)),"tree",strtrim(string(tree)),"dirtyTree",strlength(strtrim(string(dirty))) > 0,"matlabVersion",string(version),"matlabRelease",string(version("-release")),"architecture",string(computer("arch")));
end

function hash = sha256File(pathname)
fileId = fopen(pathname,"r");
if fileId < 0
    error("WaveVortexBenchmark:SpectralFluxFixtureHashFailed","Unable to read %s.",pathname)
end
cleanup = onCleanup(@()fclose(fileId));
bytes = fread(fileId,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance("SHA-256");
digest.update(bytes);
hashBytes = typecast(digest.digest(),"uint8");
hash = lower(string(reshape(dec2hex(hashBytes,2).',1,[])));
clear cleanup
end

function writeText(pathname,text)
fileId = fopen(pathname,"w");
if fileId < 0
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Unable to write %s.",pathname)
end
cleanup = onCleanup(@()fclose(fileId));
fprintf(fileId,"%s",text);
clear cleanup
end

function value = shellQuote(value)
value = "'" + replace(string(value),"'","'\\''") + "'";
end

function N2 = spectralFluxFixtureN2(z)
N2 = 2e-5*exp(z/4000);
end

function restoreState(originalPath,originalRng)
path(originalPath);
rng(originalRng);
end
