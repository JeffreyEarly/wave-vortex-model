function text = portableObservingSystemReadinessSummary(result)
% Render the portable observing-system readiness result as Markdown.
lines = ["# Portable observing-system readiness";""];
if result.status == "complete"
    lines(end+1:end+2,1) = ["Decision: **"+result.decision.status+"**";""];
    if isfield(result,"environment") && isfield(result,"source")
        lines(end+1:end+3,1) = ["MATLAB: `"+result.environment.release+"` on `"+result.environment.architecture+"`.";"Candidate: `"+result.source.candidateCommit+"`; baseline: `"+result.source.baselineCommit+"`.";""];
    end
    lines(end+1:end+2,1) = ["| Observer | Runtime to MATLAB | MATLAB to runtime |";"|---|---:|---:|"];
    for observer = unique(string({result.compatibility.observer}),"stable")
        selected = result.compatibility(string({result.compatibility.observer}) == observer);
        lines(end+1,1) = "| "+observer+" | "+passText(selected(string({selected.direction}) == "runtime-to-matlab").passed)+" | "+passText(selected(string({selected.direction}) == "matlab-to-runtime").passed)+" |"; %#ok<AGROW>
    end
    lines(end+1:end+3,1) = ["";"| Case | Candidate / pre-milestone no-output time | Passed |";"|---|---:|---:|"];
    for comparison = reshape(result.noOutputComparisons,1,[])
        lines(end+1,1) = sprintf("| %s | %.4f | %s |",comparison.id,comparison.candidateNoOutputRatio,passText(comparison.candidateNoOutputRatio <= 1.03 && comparison.correctnessPassed)); %#ok<AGROW>
    end
    if isfield(result,"scenarios") && ~isempty(result.scenarios)
        lines(end+1:end+3,1) = ["";"| Compatibility case | Integrator | Payload (ms) | Sync (ms) | Written (KiB) | Retained (KiB) | Peak RSS (MiB) | Provider | Fallback |";"|---|---|---:|---:|---:|---:|---:|---|---:|"];
        for scenario = reshape(result.scenarios,1,[])
            retained = scenario.metrics.sinkRetainedBytes+scenario.metrics.observerRetainedBytes;
            lines(end+1,1) = sprintf("| %s | %s | %.3f | %.3f | %.1f | %.1f | %.1f | %s | %s |",scenario.id,scenario.integrator,1e3*scenario.metrics.payloadWriteSeconds,1e3*scenario.metrics.synchronizationSeconds,scenario.metrics.writtenBytes/1024,retained/1024,scenario.rss.peakBytes/2^20,scenario.provider.id,passText(~scenario.provider.noFallback)); %#ok<AGROW>
        end
    end
else
    lines(end+1:end+5,1) = ["Status: **failed**";"";"Stage: `"+result.failure.stage+"`";"";result.failure.message];
end
text = strjoin(lines,newline)+newline;
end

function value = passText(passed)
if passed, value = "yes"; else, value = "no"; end
end
