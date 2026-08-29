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
    error("WaveVortexBenchmark:SpectralFluxFixtureRequiresSquareDomain","The spectral-flux fixture requires equal horizontal grid counts and domain lengths so integer k-squared-plus-l-squared keys diagnose the WVM K-squared operator groups.")
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
if any(diff(groupKeys) < 0)
    error("WaveVortexBenchmark:SpectralFluxFixtureGroupKeys","WVM K-squared diagnostic keys must be nondecreasing. Repeated integer keys are permitted when distinct floating K-squared values identify distinct WVM matrices.")
end

familyIds = ["wave-f" "wave-g"];
inputFieldNames = ["U" "V" "W" "q0_x" "q0_y" "q0_z" "q1_x" "q1_y" "q1_z" "q2_x" "q2_y" "q2_z" "q3_x" "q3_y" "q3_z"];
targetNames = ["Fu" "Fv" "Fw" "Feta"];
inputFieldFamilies = uint32([0 0 1 0 0 1 0 0 1 1 1 0 1 1 0]);
targetFieldFamilies = uint32([0 0 1 1]);

modalInputs = complex(zeros(Nj,numel(inputFieldNames),Nkl));
for iField = 1:numel(inputFieldNames)
    realPart = (2*rand(Nj,1,Nkl)-1)/8;
    imaginaryPart = (2*rand(Nj,1,Nkl)-1)/8;
    modalInputs(:,iField,:) = complex(realPart,imaginaryPart);
end
dcMode = find(modeKeys(1,:) == 0 & modeKeys(2,:) == 0,1);
modalInputs(:,:,dcMode) = real(modalInputs(:,:,dcMode));
horizontalPointCount = Nx*Ny;
sharedPhysical = zeros(Nx,Ny,Nz,3);
for iField = 1:3
    spectrum = reconstructSpectrum(wvt,modalInputs,iField,inputFieldFamilies(iField));
    sharedPhysical(:,:,:,iField) = wvt.transformToSpatialDomainWithFourier(spectrum);
end

derivativePhysical = zeros(Nx,Ny,Nz,3);
modalTargets = complex(zeros(Nj,numel(targetNames),Nkl));
inverseScale = 1/(horizontalPointCount*horizontalPointCount);
for iTarget = 1:numel(targetNames)
    firstDerivative = 4+3*(iTarget-1);
    for iDerivative = 1:3
        iField = firstDerivative+iDerivative-1;
        spectrum = reconstructSpectrum(wvt,modalInputs,iField,inputFieldFamilies(iField));
        derivativePhysical(:,:,:,iDerivative) = wvt.transformToSpatialDomainWithFourier(spectrum);
    end
    target = sharedPhysical(:,:,:,1).*derivativePhysical(:,:,:,1);
    target = target+sharedPhysical(:,:,:,2).*derivativePhysical(:,:,:,2);
    target = -inverseScale*(target+sharedPhysical(:,:,:,3).*derivativePhysical(:,:,:,3));
    rawSpectrum = horizontalPointCount*wvt.transformFromSpatialDomainWithFourier(target);
    modalTargets(:,iTarget,:) = projectSpectrum(wvt,rawSpectrum,targetFieldFamilies(iTarget));
end

payloads = repmat(emptyPayloadRecord(),0,1);
payloads(end+1) = writePayload(outputDirectory,"horizontal-mode-keys.i32le",modeKeys,"int32-le",["coordinate" "mode"],[2 Nkl]);
payloads(end+1) = writePayload(outputDirectory,"vertical-mode-keys.i32le",int32(wvt.j(:)),"int32-le","j",Nj);
payloads(end+1) = writePayload(outputDirectory,"mode-group-indices.u32le",groupIndices,"uint32-le","mode",Nkl);
payloads(end+1) = writePayload(outputDirectory,"group-keys.u64le",groupKeys,"uint64-le","group",groupCount);
payloads(end+1) = writeOperatorPayload(outputDirectory,"inverse-operators.f64le",wvt,"inverse",["z" "j" "operatorFamily" "group"],[Nz Nj numel(familyIds) groupCount]);
payloads(end+1) = writeOperatorPayload(outputDirectory,"forward-operators.f64le",wvt,"forward",["j" "z" "operatorFamily" "group"],[Nj Nz numel(familyIds) groupCount]);
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
    "operatorContract",struct("familyIds",familyIds,"inputFieldNames",inputFieldNames,"inputFieldFamilies",inputFieldFamilies,"targetNames",targetNames,"targetFieldFamilies",targetFieldFamilies,"groupCount",groupCount,"groupRule","WVM floating K^2-unique order with nondecreasing integer k^2+l^2 diagnostic keys; repeated diagnostic keys permitted"), ...
    "derivativeConvention","Input slots 0..2 are U,V,W; slots 3+3*t..5+3*t are q[t].x,q[t].y,q[t].z. q[3].z denotes the complete eta vertical-advection factor, including eta*dLnN2 when assembled by WVM.", ...
    "oracle",struct("identity","WVM MATLAB Fourier transforms plus WVM Fw/Gw projection matrices and direct -(U*qx+V*qy+W*qz) evaluation","maximumScaleNormalizedErrorTolerance",1e-12,"relativeL2ErrorTolerance",1e-12), ...
    "payloads",payloads);

manifestPath = fullfile(outputDirectory,"manifest.json");
writeText(manifestPath,string(jsonencode(manifest,PrettyPrint=true))+newline);
clear stateCleanup
end

function spectrum = reconstructSpectrum(wvt,modalInputs,iField,familyIndex)
Nz = wvt.Nz;
Nkl = size(modalInputs,3);
spectrum = complex(zeros(Nz,Nkl));
for iGroup = 1:wvt.nK2unique
    indices = wvt.K2uniqueK2Map{iGroup};
    spectrum(:,indices) = inverseOperator(wvt,familyIndex,iGroup)*reshape(modalInputs(:,iField,indices),size(modalInputs,1),[]);
end
end

function modalTarget = projectSpectrum(wvt,spectrum,familyIndex)
Nj = wvt.Nj;
Nkl = size(spectrum,2);
modalTarget = complex(zeros(Nj,1,Nkl));
for iGroup = 1:wvt.nK2unique
    indices = wvt.K2uniqueK2Map{iGroup};
    modalTarget(:,1,indices) = reshape(forwardOperator(wvt,familyIndex,iGroup)*spectrum(:,indices),Nj,1,[]);
end
end

function operator = inverseOperator(wvt,familyIndex,iGroup)
if familyIndex == 0
    operator = shiftdim(wvt.Ppm(:,iGroup),1).*wvt.PFpmInv(:,:,iGroup);
else
    operator = shiftdim(wvt.Qpm(:,iGroup),1).*wvt.QGpmInv(:,:,iGroup);
end
end

function operator = forwardOperator(wvt,familyIndex,iGroup)
if familyIndex == 0
    operator = wvt.PFpm(:,:,iGroup)./wvt.Ppm(:,iGroup);
else
    operator = wvt.QGpm(:,:,iGroup)./wvt.Qpm(:,iGroup);
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
chunkElements = 2^20;
totalWritten = 0;
for firstElement = 1:chunkElements:numel(value)
    lastElement = min(firstElement+chunkElements-1,numel(value));
    chunk = value(firstElement:lastElement);
    interleaved = zeros(2,numel(chunk));
    interleaved(1,:) = real(chunk);
    interleaved(2,:) = imag(chunk);
    totalWritten = totalWritten+fwrite(fileId,interleaved,"double");
end
if totalWritten ~= 2*numel(value)
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Expected to write %d scalar elements to %s but wrote %d.",2*numel(value),pathname,totalWritten)
end
clear cleanup
payload = payloadRecord(pathname,fileName,"complex-float64-interleaved-le",axes,shape,true);
end

function payload = writeOperatorPayload(outputDirectory,fileName,wvt,direction,axes,shape)
pathname = fullfile(outputDirectory,fileName);
fileId = fopen(pathname,"w","ieee-le");
if fileId < 0
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Unable to write %s.",pathname)
end
cleanup = onCleanup(@()fclose(fileId));
totalWritten = 0;
for iGroup = 1:wvt.nK2unique
    for familyIndex = 0:1
        if direction == "inverse"
            operator = inverseOperator(wvt,familyIndex,iGroup);
        else
            operator = forwardOperator(wvt,familyIndex,iGroup);
        end
        totalWritten = totalWritten+fwrite(fileId,operator,"double");
    end
end
expectedElements = prod(shape);
if totalWritten ~= expectedElements
    error("WaveVortexBenchmark:SpectralFluxFixtureWriteFailed","Expected to write %d operator elements to %s but wrote %d.",expectedElements,pathname,totalWritten)
end
clear cleanup
payload = payloadRecord(pathname,fileName,"float64-le",axes,shape,false);
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
digest = java.security.MessageDigest.getInstance("SHA-256");
while true
    bytes = fread(fileId,2^24,"*uint8");
    if isempty(bytes)
        break
    end
    digest.update(bytes);
end
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
