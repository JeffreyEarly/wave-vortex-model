function summary = waveVortexBenchmarkSummary(results)
% Render a WaveVortex benchmark result as a Markdown summary.
arguments
    results (1,1) struct
end
lines = ["# WaveVortex benchmark";"";"- Status: `" + results.status + "`";"- Run: `" + results.runId + "`";"- MATLAB: `" + results.environment.matlabRelease + "`";"- Architecture: `" + results.environment.architecture + "`";"";"## Suite scores";"";"| Suite | Backend | Score |";"|---|---|---:|"];
for iSuite = 1:numel(results.suites)
    for iScore = 1:numel(results.suites(iSuite).suiteScores)
        score = results.suites(iSuite).suiteScores(iScore);
        lines(end+1) = sprintf("| %s | %s | %.3f |",results.suites(iSuite).id,score.backendId,score.score); %#ok<AGROW>
    end
end
lines = [lines;"";"## Family scores";"";"| Suite | Family | Backend | Score |";"|---|---|---|---:|"];
for iSuite = 1:numel(results.suites)
    for iScore = 1:numel(results.suites(iSuite).familyScores)
        score = results.suites(iSuite).familyScores(iScore);
        lines(end+1) = sprintf("| %s | %s | %s | %.3f |",results.suites(iSuite).id,score.id,score.backendId,score.score); %#ok<AGROW>
    end
end
lines = [lines;"";"## Timing and scores";"";"| Suite | Case | Transform | Backend | Median (ms) | Reference score | Same-host speedup | Error |";"|---|---|---|---|---:|---:|---:|---:|"];
for iSuite = 1:numel(results.suites)
    suite = results.suites(iSuite);
    for iCase = 1:numel(suite.cases)
        benchmarkCase = suite.cases(iCase);
        for iBackend = 1:numel(benchmarkCase.backends)
            backend = benchmarkCase.backends(iBackend);
            lines(end+1) = sprintf("| %s | %s | %s | %s | %.3f | %.3f | %.3f | %.3g |",suite.id,benchmarkCase.id,benchmarkCase.transformId,backend.id,1e3*backend.medianSeconds,backend.caseScore,backend.sameHostSpeedup,backend.relativeError); %#ok<AGROW>
        end
    end
end
lines = [lines;"";"## Construction and cache diagnostics";"";"| Suite | Case | Backend | Construction (s) | First call (ms) | Same-state cache hit (ms) |";"|---|---|---|---:|---:|---:|"];
for iSuite = 1:numel(results.suites)
    suite = results.suites(iSuite);
    for iCase = 1:numel(suite.cases)
        benchmarkCase = suite.cases(iCase);
        for iBackend = 1:numel(benchmarkCase.backends)
            backend = benchmarkCase.backends(iBackend);
            lines(end+1) = sprintf("| %s | %s | %s | %.3f | %.3f | %.3f |",suite.id,benchmarkCase.id,backend.id,backend.constructionSeconds,1e3*backend.firstCallSeconds,1e3*backend.sameStateCacheHitSeconds); %#ok<AGROW>
        end
    end
end
lines = [lines;"";"## Memory";"";"| Suite | Case | Backend | Persistent increment (MiB) | Peak increment (MiB) | Provider |";"|---|---|---|---:|---:|---|"];
for iSuite = 1:numel(results.suites)
    suite = results.suites(iSuite);
    for iCase = 1:numel(suite.cases)
        benchmarkCase = suite.cases(iCase);
        for iBackend = 1:numel(benchmarkCase.backends)
            backend = benchmarkCase.backends(iBackend);
            lines(end+1) = sprintf("| %s | %s | %s | %.3f | %.3f | %s |",suite.id,benchmarkCase.id,backend.id,backend.memory.persistentIncrementBytes/2^20,backend.memory.peakIncrementBytes/2^20,backend.memory.provider); %#ok<AGROW>
        end
    end
end
summary = strjoin(lines,newline) + newline;
end
