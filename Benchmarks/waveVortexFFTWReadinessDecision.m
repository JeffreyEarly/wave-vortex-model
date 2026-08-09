function decision = waveVortexFFTWReadinessDecision(coreSuite,storageSuite,capabilities,options)
% Evaluate the fixed FFTW WaveVortex readiness gates.
arguments
    coreSuite (1,1) struct
    storageSuite (1,1) struct
    capabilities (1,1) struct
    options.speedThreshold (1,1) double {mustBeGreaterThan(options.speedThreshold,1)} = 1.10
    options.correctnessTolerance (1,1) double {mustBePositive} = 1e-12
end

requiredIds = [ ...
    "constant-nonhydrostatic-256x256x65" ...
    "constant-hydrostatic-256x256x65" ...
    "constant-nonhydrostatic-512x512x129" ...
    "constant-hydrostatic-512x512x129"];
identityPassed = capabilityIdentityPassed(capabilities);
cases = emptyCases();
for caseId = requiredIds
    [coreCase,coreFound] = selectCase(coreSuite,caseId);
    [storageCase,storageFound] = selectCase(storageSuite,caseId);
    evidenceComplete = coreFound && storageFound && string(coreCase.status) == "complete" && string(storageCase.status) == "complete";
    if evidenceComplete
        [builtin,builtinFound] = selectBackend(coreCase,"builtin");
        [fftw,fftwFound] = selectBackend(coreCase,"fftw");
        evidenceComplete = builtinFound && fftwFound && isfinite(builtin.medianSeconds) && isfinite(fftw.medianSeconds);
    else
        builtin = struct();
        fftw = struct();
    end

    speedup = NaN;
    relativeError = NaN;
    speedPassed = false;
    correctnessPassed = false;
    activeBackendPassed = false;
    storageGates = emptyStorageGates();
    storageComparison = struct();
    if evidenceComplete
        speedup = builtin.medianSeconds/fftw.medianSeconds;
        relativeError = fftw.relativeError;
        speedPassed = speedup >= options.speedThreshold;
        correctnessPassed = relativeError <= options.correctnessTolerance;
        activeBackendPassed = string(fftw.id) == "fftw";
        storageComparison = storageCase.comparison;
        storageGates = normalizeStorageGates(storageComparison.gates);
    end

    gates = struct( ...
        "evidenceComplete",evidenceComplete, ...
        "activeBackendPassed",activeBackendPassed, ...
        "libraryIdentityPassed",identityPassed, ...
        "speedPassed",speedPassed, ...
        "correctnessPassed",correctnessPassed, ...
        "exactStorageSavingsPassed",storageGates.exactStorageSavingsPassed, ...
        "noPersistentFullSpectrumPassed",storageGates.noPersistentFullSpectrumPassed, ...
        "noPreservingScratchPassed",storageGates.noPreservingScratchPassed, ...
        "lifecyclePassed",storageGates.lifecyclePassed, ...
        "persistentRSSPassed",storageGates.persistentRSSPassed, ...
        "peakRSSPassed",storageGates.peakRSSPassed);
    gateNames = string(fieldnames(gates));
    failedCriteria = gateNames(~cell2mat(struct2cell(gates)))';
    cases(end+1) = struct("id",caseId,"evidenceComplete",evidenceComplete,"builtinMedianSeconds",fieldValue(builtin,"medianSeconds",NaN),"fftwMedianSeconds",fieldValue(fftw,"medianSeconds",NaN),"speedup",speedup,"relativeError",relativeError,"storageComparison",storageComparison,"gates",gates,"failedCriteria",failedCriteria); %#ok<AGROW>
end

if any(~[cases.evidenceComplete])
    outcome = "INCOMPLETE";
elseif all(arrayfun(@(value)all(cell2mat(struct2cell(value.gates))),cases))
    outcome = "READY";
else
    outcome = "NOT READY";
end
failedCases = string({cases(arrayfun(@(value)~all(cell2mat(struct2cell(value.gates))),cases)).id});
decision = struct("schema","fftw-wavevortex-readiness-v1","outcome",outcome,"speedThreshold",options.speedThreshold,"correctnessTolerance",options.correctnessTolerance,"requiredCaseIds",requiredIds,"cases",cases,"failedCaseIds",failedCases,"thresholdsChanged",false);
end

function passed = capabilityIdentityPassed(capabilities)
passed = false;
try
    passed = string(capabilities.provider.id) == "matlab-bundled" && logical(capabilities.provider.identityValidated) && logical(capabilities.library.identityValidated) && logical(capabilities.modules.r2c.identityValidated) && logical(capabilities.features.r2c.isAvailable) && logical(capabilities.features.c2r.isAvailable);
catch
end
end

function [value,found] = selectCase(suite,caseId)
found = false;
value = struct();
if ~isfield(suite,"cases")
    return
end
index = find(string({suite.cases.id}) == caseId,1);
if ~isempty(index)
    value = suite.cases(index);
    found = true;
end
end

function [value,found] = selectBackend(benchmarkCase,backendId)
found = false;
value = struct();
if ~isfield(benchmarkCase,"backends")
    return
end
index = find(string({benchmarkCase.backends.id}) == backendId,1);
if ~isempty(index)
    value = benchmarkCase.backends(index);
    found = true;
end
end

function value = normalizeStorageGates(gates)
value = emptyStorageGates();
names = string(fieldnames(value));
for name = names'
    if isfield(gates,name)
        value.(name) = logical(gates.(name));
    end
end
if isfield(gates,"rssSupported") && ~logical(gates.rssSupported)
    value.persistentRSSPassed = false;
    value.peakRSSPassed = false;
end
end

function value = emptyStorageGates()
value = struct("exactStorageSavingsPassed",false,"noPersistentFullSpectrumPassed",false,"noPreservingScratchPassed",false,"lifecyclePassed",false,"persistentRSSPassed",false,"peakRSSPassed",false);
end

function value = fieldValue(record,name,defaultValue)
value = defaultValue;
if isfield(record,name)
    value = record.(name);
end
end

function values = emptyCases()
values = struct("id",{},"evidenceComplete",{},"builtinMedianSeconds",{},"fftwMedianSeconds",{},"speedup",{},"relativeError",{},"storageComparison",{},"gates",{},"failedCriteria",{});
end
