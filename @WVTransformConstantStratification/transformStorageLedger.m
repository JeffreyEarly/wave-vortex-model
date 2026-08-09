function ledger = transformStorageLedger(self)
% Return the exact known and explicitly opaque transform storage ledger.
%
% This hidden benchmark contract excludes canonical model coefficients,
% forcing state, and MATLAB-internal FFT work buffers. It includes the
% horizontal layout and buffer state, vertical fallback matrices, transient
% transform arrays, and opaque FFTW plan records after production warmup.
%
% This method is intended for benchmark and backend development. It does
% not estimate MATLAB-internal work buffers or FFTW plan-owned memory.
%
% - Topic: Inspect transform storage
% - Declaration: ledger = transformStorageLedger()
% - Returns ledger: exact application-owned arrays, opaque plan records, and aggregate byte counts
% - Developer: true

entries = [self.fastTransform.storageLedger();self.verticalTransform.storageLedger()];
matrixNames = ["DCT" "iDCT" "DST" "iDST"];
for matrixName = matrixNames
    value = self.(matrixName);
    info = whos("value");
    entries(end+1,1) = ledgerEntry("vertical.matrix." + matrixName,"WVGeometryDoublyPeriodicStratifiedConstant","vertical-matrix","Dense vertical fallback operator",string(class(value)),double(size(value)),double(info.bytes),"persistent","allocated","exact","real",double(info.bytes)); %#ok<AGROW>
end

isExact = string({entries.byteStatus}) == "exact";
isAllocated = string({entries.allocationState}) == "allocated";
isPersistent = string({entries.persistence}) == "persistent";
isTransient = string({entries.persistence}) == "transient";
knownPersistentBytes = sum([entries(isExact & isAllocated & isPersistent).bytes]);
knownTransientBytes = sum([entries(isExact & isAllocated & isTransient).bytes]);
opaquePlanCount = nnz(string({entries.byteStatus}) == "opaque" & string({entries.category}) == "fftw-plan");
hasPersistentFullSpectrum = any(isAllocated & isPersistent & string({entries.category}) == "spectrum-buffer" & string({entries.storageType}) == "full-complex");
scratchEntries = entries(string({entries.category}) == "preserving-scratch" & isAllocated);
preservingScratchAllocatedBytes = sum([scratchEntries.bytes]);

ledger = struct( ...
    "schema","transform-storage-ledger-v1", ...
    "scope","explicit-transform-storage", ...
    "backendIdentifier",self.fastTransform.backendIdentifier, ...
    "fourierStorageType",self.fastTransform.fourierStorageLayout.fourierStorageType, ...
    "entries",entries, ...
    "knownPersistentBytes",knownPersistentBytes, ...
    "knownTransientBytes",knownTransientBytes, ...
    "opaquePlanCount",opaquePlanCount, ...
    "hasPersistentFullSpectrum",hasPersistentFullSpectrum, ...
    "preservingScratchAllocatedBytes",preservingScratchAllocatedBytes, ...
    "matlabInternalStorage","unresolved", ...
    "opaquePlanBytes","unresolved");
end

function value = ledgerEntry(identifier,owner,category,purpose,className,shape,bytes,persistence,allocationState,byteStatus,storageType,potentialBytes)
value = struct("identifier",identifier,"owner",owner,"category",category,"purpose",purpose,"className",className,"shape",double(shape),"bytes",double(bytes),"persistence",persistence,"allocationState",allocationState,"byteStatus",byteStatus,"storageType",storageType,"potentialBytes",double(potentialBytes));
end
