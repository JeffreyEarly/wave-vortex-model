function result = waveVortexTransformStorageComparison(Nxyz,backends)
% Compare builtin and FFTW exact-storage and repeated-RSS measurements.
arguments
    Nxyz (1,3) double {mustBeInteger,mustBePositive}
    backends (1,:) struct
end

threshold = thresholdBytes(Nxyz);
builtin = selectBackend(backends,"builtin");
fftw = selectBackend(backends,"fftw");
hasLedgers = isfield(builtin.ledger,"knownPersistentBytes") && isfield(fftw.ledger,"knownPersistentBytes");
if hasLedgers
    exactSavings = builtin.ledger.knownPersistentBytes-fftw.ledger.knownPersistentBytes;
    noFullSpectrum = ~fftw.ledger.hasPersistentFullSpectrum;
    noScratch = fftw.ledger.preservingScratchAllocatedBytes == 0;
else
    exactSavings = NaN;
    noFullSpectrum = false;
    noScratch = false;
end

rssSupported = string(builtin.rss.status) == "complete" && string(fftw.rss.status) == "complete";
if rssSupported
    persistentImprovement = builtin.rss.medianPersistentIncrementBytes-fftw.rss.medianPersistentIncrementBytes;
    peakImprovement = builtin.rss.medianPeakIncrementBytes-fftw.rss.medianPeakIncrementBytes;
else
    persistentImprovement = NaN;
    peakImprovement = NaN;
end
lifecyclePassed = all(arrayfun(@isBalancedRun,fftw.runs));
gates = struct( ...
    "exactStorageSavingsPassed",hasLedgers && exactSavings > 0, ...
    "noPersistentFullSpectrumPassed",noFullSpectrum, ...
    "noPreservingScratchPassed",noScratch, ...
    "lifecyclePassed",lifecyclePassed, ...
    "rssSupported",rssSupported, ...
    "persistentRSSPassed",rssSupported && persistentImprovement >= threshold, ...
    "peakRSSPassed",rssSupported && peakImprovement >= threshold);
result = struct( ...
    "thresholdBytes",threshold, ...
    "thresholdMiB",threshold/2^20, ...
    "exactKnownPersistentSavingsBytes",exactSavings, ...
    "exactKnownPersistentSavingsMiB",exactSavings/2^20, ...
    "medianPersistentRSSImprovementBytes",persistentImprovement, ...
    "medianPersistentRSSImprovementMiB",persistentImprovement/2^20, ...
    "medianPeakRSSImprovementBytes",peakImprovement, ...
    "medianPeakRSSImprovementMiB",peakImprovement/2^20, ...
    "gates",gates);
end

function backend = selectBackend(backends,identifier)
iBackend = find(string({backends.id}) == identifier,1);
if isempty(iBackend)
    error("WaveVortexBenchmark:TransformStorageBackendsRequired","Transform-storage comparison requires backend '%s'.",identifier);
end
backend = backends(iBackend);
end

function tf = isBalancedRun(run)
tf = string(run.status) == "complete" && isfield(run.lifecycle,"isBalanced") && run.lifecycle.isBalanced;
end

function value = thresholdBytes(Nxyz)
if isequal(Nxyz,[256 256 65])
    value = 16.125*2^20;
elseif isequal(Nxyz,[512 512 129])
    value = 128.496*2^20;
else
    error("WaveVortexBenchmark:UnknownTransformStorageThreshold","No transform-storage threshold is defined for [%s].",join(string(Nxyz)," "));
end
end
