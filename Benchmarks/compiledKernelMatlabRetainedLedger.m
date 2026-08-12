function ledger = compiledKernelMatlabRetainedLedger(wvt,outputs)
% Count MATLAB arrays retained after an ordinary nonlinearFlux call.
arguments
    wvt WVTransformConstantStratification {mustBeNonempty}
    outputs (1,3) cell
end

transform = wvt.transformStorageLedger();
cacheNames = string(wvt.variableCache.keys);
cacheEntries = repmat(struct("name","","className","","shape",[],"bytes",0),numel(cacheNames),1);
cacheBytes = 0;
for iName = 1:numel(cacheNames)
    value = wvt.variableCache{cacheNames(iName)};
    info = whos("value");
    cacheEntries(iName) = struct("name",cacheNames(iName),"className",string(class(value)),"shape",double(size(value)),"bytes",double(info.bytes));
    cacheBytes = cacheBytes + info.bytes;
end

outputEntries = repmat(struct("name","","className","","shape",[],"bytes",0),3,1);
outputBytes = 0;
names = ["Fp" "Fm" "F0"];
for iOutput = 1:3
    value = outputs{iOutput};
    info = whos("value");
    outputEntries(iOutput) = struct("name",names(iOutput),"className",string(class(value)),"shape",double(size(value)),"bytes",double(info.bytes));
    outputBytes = outputBytes + info.bytes;
end

ledger = struct( ...
    "schemaVersion","issue131-retained-memory-v1", ...
    "scope","active MATLAB transform storage, reachable variable-cache arrays, and three returned flux arrays; shared canonical state excluded", ...
    "transformRetainedBytes",double(transform.knownPersistentBytes), ...
    "cacheRetainedBytes",double(cacheBytes), ...
    "outputRetainedBytes",double(outputBytes), ...
    "exactRetainedApplicationBytes",double(transform.knownPersistentBytes+cacheBytes+outputBytes), ...
    "cacheEntries",cacheEntries, ...
    "outputEntries",outputEntries, ...
    "opaqueMemory","MATLAB allocator, JIT temporaries, copy-on-write sharing, and FFT internals are represented only by isolated RSS");
end
