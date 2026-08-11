function finalists = compiledKernelNativeFFTWFinalists(screening,providers,threadCounts)
% Select fully sampled issue #137 configurations from screening measurements.
arguments
    screening (:,1) struct
    providers (:,1) struct
    threadCounts (1,:) double {mustBeInteger,mustBePositive}
end
valid = arrayfun(@isValid,screening);
if ~any(valid), error("WaveVortexModel:NativeFFTWNoValidScreening","No native FFTW screening configuration completed successfully."); end
scores = arrayfun(@nonlinearFluxScore,screening);
transformScores = arrayfun(@transformScore,screening);
globalFastest = min(scores(valid));
keys = strings(0,1); reasons = cell(0,1);

for iProvider = 1:numel(providers)
    providerMask = valid & string({screening.providerId})' == string(providers(iProvider).id);
    if ~any(providerMask), continue, end
    indices = find(providerMask);
    [~,relative] = min(scores(indices)); nonlinearIndex = indices(relative);
    [keys,reasons] = addCandidate(keys,reasons,screening(nonlinearIndex),"best-global-nonlinearFlux-for-build");
    [~,relative] = min(transformScores(indices)); transformIndex = indices(relative);
    [keys,reasons] = addCandidate(keys,reasons,screening(transformIndex),"best-transform-score-for-build");
    bestThread = screening(nonlinearIndex).threadCount;
    position = find(threadCounts==bestThread,1);
    neighborPositions = unique([max(1,position-1) min(numel(threadCounts),position+1)]);
    for neighbor = threadCounts(neighborPositions)
        candidate = indices([screening(indices).threadCount]==neighbor);
        if ~isempty(candidate), [keys,reasons] = addCandidate(keys,reasons,screening(candidate(1)),"neighbor-of-build-winner"); end
    end
    historical = indices([screening(indices).threadCount]==18);
    if ~isempty(historical), [keys,reasons] = addCandidate(keys,reasons,screening(historical(1)),"historical-18-thread-control"); end
end
for index = find(valid & scores <= 1.10*globalFastest)'
    [keys,reasons] = addCandidate(keys,reasons,screening(index),"within-10-percent-of-global-screening-winner");
end

finalists = repmat(struct("providerId","","threadCount",0,"reasons",strings(0,1),"screeningNonlinearFluxScoreSeconds",NaN,"screeningTransformScoreSeconds",NaN),numel(keys),1);
for iFinalist = 1:numel(keys)
    fields = split(keys(iFinalist),"|"); index = find(string({screening.providerId})==fields(1) & [screening.threadCount]==str2double(fields(2)),1);
    finalists(iFinalist) = struct("providerId",fields(1),"threadCount",str2double(fields(2)),"reasons",unique(reasons{iFinalist},"stable"),"screeningNonlinearFluxScoreSeconds",scores(index),"screeningTransformScoreSeconds",transformScores(index));
end
[~,order] = sortrows(table(string({finalists.providerId})',[finalists.threadCount]'),[1 2]); finalists = finalists(order);
end

function valid = isValid(result)
valid = string(result.status)=="complete" && ~isempty(result.cases) && all(string({result.cases.status})=="complete") && all([result.cases.maximumRelativeError]<=1e-12) && all([result.cases.lifecyclePassed]);
end

function score = nonlinearFluxScore(result)
if ~isValid(result), score = Inf; return, end
values = arrayfun(@(item)operationMedian(item,"nonlinearFlux"),result.cases);
score = exp(mean(log(values)));
end

function score = transformScore(result)
if ~isValid(result), score = Inf; return, end
values = [];
for iCase = 1:numel(result.cases)
    for operation = ["forward" "inverse" "fAll" "gAll"]
        values(end+1) = operationMedian(result.cases(iCase),operation); %#ok<AGROW>
    end
end
score = exp(mean(log(values)));
end

function value = operationMedian(caseResult,operation)
record = caseResult.timings(string({caseResult.timings.operation})==operation);
value = record.internalMedianSeconds;
end

function [keys,reasons] = addCandidate(keys,reasons,result,reason)
key = string(result.providerId)+"|"+result.threadCount;
index = find(keys==key,1);
if isempty(index)
    keys(end+1,1) = key; reasons{end+1,1} = string(reason);
else
    reasons{index}(end+1,1) = string(reason);
end
end
