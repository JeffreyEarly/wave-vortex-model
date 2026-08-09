function summary = waveVortexFFTWReadinessSummary(results)
% Render the final FFTW WaveVortex readiness result as Markdown.
arguments
    results (1,1) struct
end

decision = results.decision;
lines = strings(0,1);
lines(end+1,1) = "# FFTW WaveVortex readiness";
lines(end+1,1) = "";
lines(end+1,1) = "- Outcome: **" + string(decision.outcome) + "**";
lines(end+1,1) = "- Run: `" + string(results.runId) + "`";
lines(end+1,1) = "- MATLAB: `" + string(results.environment.matlabRelease) + "`";
lines(end+1,1) = "- Architecture: `" + string(results.environment.architecture) + "`";
lines(end+1,1) = "- Source commit: `" + string(results.source.commit) + "`";
lines(end+1,1) = "- Required release boundary: `" + string(results.source.requiredTag) + "`";
lines(end+1,1) = "- Provider: `" + string(results.capabilities.providerId) + "`";
lines(end+1,1) = "- Library: `" + string(results.capabilities.libraryVersion) + "` at `" + string(results.capabilities.libraryPath) + "`";
lines(end+1,1) = "";
lines(end+1,1) = "## End-to-end timing and correctness";
lines(end+1,1) = "";
lines(end+1,1) = "| Case | MATLAB builtin (ms) | FFTW (ms) | Speedup | Error | Speed gate | Correctness |";
lines(end+1,1) = "|---|---:|---:|---:|---:|---|---|";
for benchmarkCase = decision.cases
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3f | %.3g | %s | %s |",benchmarkCase.id,1e3*benchmarkCase.builtinMedianSeconds,1e3*benchmarkCase.fftwMedianSeconds,benchmarkCase.speedup,benchmarkCase.relativeError,passFail(benchmarkCase.gates.speedPassed),passFail(benchmarkCase.gates.correctnessPassed)); %#ok<AGROW>
end

lines = [lines;"";"## Storage and lifecycle gates";"";"| Case | Exact savings (MiB) | Persistent RSS improvement (MiB) | Peak RSS improvement (MiB) | No full spectrum | No scratch | Lifecycle | Persistent RSS | Peak RSS |";"|---|---:|---:|---:|---|---|---|---|---|"];
for benchmarkCase = decision.cases
    comparison = benchmarkCase.storageComparison;
    if isempty(fieldnames(comparison))
        lines(end+1) = "| " + benchmarkCase.id + " | NaN | NaN | NaN | fail | fail | fail | fail | fail |"; %#ok<AGROW>
        continue
    end
    gates = benchmarkCase.gates;
    lines(end+1) = sprintf("| %s | %.3f | %.3f | %.3f | %s | %s | %s | %s | %s |",benchmarkCase.id,comparison.exactKnownPersistentSavingsMiB,comparison.medianPersistentRSSImprovementMiB,comparison.medianPeakRSSImprovementMiB,passFail(gates.noPersistentFullSpectrumPassed),passFail(gates.noPreservingScratchPassed),passFail(gates.lifecyclePassed),passFail(gates.persistentRSSPassed),passFail(gates.peakRSSPassed)); %#ok<AGROW>
end

lines = [lines;"";"## Dispatch and configuration";"";"| Case | Backend | Fourier storage | Mapping | Vertical dispatch records | Spatial derivative dispatch |";"|---|---|---|---|---:|---|"];
for coreCase = results.core.cases
    for backend = coreCase.backends
        storageType = string(backend.metadata.fourierStorageType);
        if storageType == "hermitian-half" && isequal(backend.metadata.compressedDimension,1)
            storageType = "hermitian-half-x";
        end
        recordCount = 0;
        if isfield(backend.metadata,"verticalTransformDispatch")
            recordCount = numel(backend.metadata.verticalTransformDispatch);
        end
        derivativeDispatch = "unavailable";
        if isfield(backend.metadata,"spatialDerivativeDispatch")
            records = backend.metadata.spatialDerivativeDispatch;
            derivativeDispatch = join(string({records.operation}) + "=" + string({records.implementation}),", ");
        end
        lines(end+1) = sprintf("| %s | %s | %s | %s | %d | %s |",coreCase.id,backend.id,storageType,backend.metadata.mappingMethod,recordCount,derivativeDispatch); %#ok<AGROW>
    end
end

lines = [lines;"";"## Failed criteria";""];
for benchmarkCase = decision.cases
    if isempty(benchmarkCase.failedCriteria)
        lines(end+1) = "- `" + benchmarkCase.id + "`: none"; %#ok<AGROW>
    else
        lines(end+1) = "- `" + benchmarkCase.id + "`: " + join("`" + benchmarkCase.failedCriteria + "`",", "); %#ok<AGROW>
    end
end
lines = [lines;"";"The thresholds were fixed before this run. A complete `NOT READY` result is a successful benchmark outcome and does not advertise or release the optional backend.";""];
summary = strjoin(lines,newline);
end

function value = passFail(flag)
if flag
    value = "pass";
else
    value = "fail";
end
end
