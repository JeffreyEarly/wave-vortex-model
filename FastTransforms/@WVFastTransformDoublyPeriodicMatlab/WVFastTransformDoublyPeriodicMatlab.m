classdef WVFastTransformDoublyPeriodicMatlab < WVFastTransformDoublyPeriodic
    properties (Dependent)
        complexBuffer
    end

    properties
        wvg
        Nz
    end

    properties (Access=private)
        complexBufferRows = []
    end

    methods
        function self = WVFastTransformDoublyPeriodicMatlab(wvg,Nz)
            self.wvg = wvg;
            self.Nz=Nz;
            self.fourierStorageLayout = WVFourierStorageLayout(wvg,"full-complex");
        end

        function value = get.complexBuffer(self)
            self.allocateComplexBufferRowsIfNeeded();
            value = self.fourierStorageLayout.reshapeFourierRowsToStorage(self.complexBufferRows);
        end

        function set.complexBuffer(self,value)
            self.complexBufferRows = self.fourierStorageLayout.reshapeFourierStorageToRows(value);
        end
    end

    methods (Access=private)
        function allocateComplexBufferRowsIfNeeded(self)
            if isempty(self.complexBufferRows)
                self.complexBufferRows = self.fourierStorageLayout.allocateFourierStorage(self.Nz);
            end
        end
    end

    methods
        u_bar = transformFromSpatialDomainWithFourier(self,u)
        u = transformToSpatialDomainWithFourier(self,u_bar)
        du = diffX(wvg,u,options)
        du = diffY(wvg,u,options)
    end

    methods (Hidden)
        function entries = storageLedger(self)
            % Return exact transform-owned storage for memory benchmarks.
            entries = emptyLedger();
            mappings = self.fourierStorageLayout.mappingMemoryUsage();
            for iMapping = 1:numel(mappings)
                mapping = mappings(iMapping);
                entries(end+1,1) = ledgerEntry("horizontal.layout." + mapping.name,"WVFourierStorageLayout","mapping","Fourier/WV index mapping",mapping.class,mapping.shape,mapping.bytes,"persistent","allocated","exact","mapping",mapping.bytes); %#ok<AGROW>
            end
            potentialShape = [self.fourierStorageLayout.nFourierStorageRows self.Nz];
            potentialBytes = 16*prod(potentialShape);
            if isempty(self.complexBufferRows)
                bufferBytes = 0;
                allocationState = "unallocated";
            else
                bufferBytes = potentialBytes;
                allocationState = "allocated";
            end
            entries(end+1,1) = ledgerEntry("horizontal.fullSpectrumBuffer","WVFastTransformDoublyPeriodicMatlab","spectrum-buffer","Lazily allocated reusable inverse-transform Fourier storage","double",potentialShape,bufferBytes,"persistent",allocationState,"exact","full-complex",potentialBytes);
            spatialBytes = 8*prod([self.wvg.Nx self.wvg.Ny self.Nz]);
            entries(end+1,1) = ledgerEntry("horizontal.forwardSpectrumResult","WVFastTransformDoublyPeriodicMatlab","temporary","Complete forward-FFT result","double",[self.wvg.Nx self.wvg.Ny self.Nz],2*spatialBytes,"transient","allocated","exact","full-complex",2*spatialBytes);
            entries(end+1,1) = ledgerEntry("horizontal.inverseSpatialResult","WVFastTransformDoublyPeriodicMatlab","temporary","Inverse-FFT spatial result","double",[self.wvg.Nx self.wvg.Ny self.Nz],spatialBytes,"transient","allocated","exact","real",spatialBytes);
            entries(end+1,1) = ledgerEntry("horizontal.matlabFFTWorkspace","MATLAB","fft-workspace","MATLAB-internal FFT work storage","",[],0,"transient","unknown","opaque","unknown",0);
        end
    end
end

function value = ledgerEntry(identifier,owner,category,purpose,className,shape,bytes,persistence,allocationState,byteStatus,storageType,potentialBytes)
value = struct("identifier",identifier,"owner",owner,"category",category,"purpose",purpose,"className",className,"shape",double(shape),"bytes",double(bytes),"persistence",persistence,"allocationState",allocationState,"byteStatus",byteStatus,"storageType",storageType,"potentialBytes",double(potentialBytes));
end

function value = emptyLedger()
value = repmat(ledgerEntry("","","","","",[],0,"","","","",0),0,1);
end
