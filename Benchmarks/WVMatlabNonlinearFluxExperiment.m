classdef WVMatlabNonlinearFluxExperiment < handle
    % Execute author-only MATLAB nonlinear-flux scheduling variants.
    %
    % This class exists only for issue #125 benchmarks. It deliberately
    % leaves the production WVTransform API unchanged.

    properties (SetAccess=private)
        wvt
        variant
        layout
    end

    properties (Access=private)
        FuBuffer = []
        FvBuffer = []
        FwBuffer = []
        FetaBuffer = []
        spatialBatch = []
        inverseFourierRows = []
    end

    methods
        function self = WVMatlabNonlinearFluxExperiment(wvt,variant)
            arguments
                wvt (1,1) WVTransformConstantStratification
                variant (1,1) string
            end
            if ~ismember(variant,WVMatlabNonlinearFluxExperiment.variantIdentifiers())
                error("WaveVortexBenchmark:UnknownMATLABOptimizationVariant","Unknown MATLAB nonlinear-flux optimization variant %s.",variant);
            end
            self.wvt = wvt;
            self.variant = variant;
            if contains(variant,"batch")
                self.layout = WVFourierStorageLayout(wvt,"full-complex");
            end
            if ismember(variant,["reusable-reset" "reusable-overwrite"])
                self.allocateFluxBuffers();
            end
            if ismember(variant,["forward-batch-preallocated" "full-batch-preallocated"])
                self.spatialBatch = zeros([wvt.spatialMatrixSize self.fieldCount()]);
            end
            if variant == "full-batch-preallocated"
                self.inverseFourierRows = self.layout.allocateFourierStorage(4*wvt.Nz);
            end
        end

        function [Fp,Fm,F0,metrics] = execute(self,options)
            arguments
                self (1,1) WVMatlabNonlinearFluxExperiment
                options.shouldInstrument (1,1) logical = false
            end
            metrics = self.emptyMetrics();
            totalTimer = tic;
            switch self.variant
                case "current"
                    [Fp,Fm,F0] = self.wvt.nonlinearFlux();
                case "scalar-zero"
                    stageTimer = tic;
                    fields = self.spatialFluxScalarZero();
                    metrics.spatialForcingSeconds = elapsed(stageTimer,options.shouldInstrument);
                    stageTimer = tic;
                    [Fp,Fm,F0] = self.projectCurrent(fields);
                    metrics.projectionSeconds = elapsed(stageTimer,options.shouldInstrument);
                    [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
                case "reusable-reset"
                    stageTimer = tic;
                    fields = self.spatialFluxReusableReset();
                    metrics.spatialForcingSeconds = elapsed(stageTimer,options.shouldInstrument);
                    stageTimer = tic;
                    [Fp,Fm,F0] = self.projectCurrent(fields);
                    metrics.projectionSeconds = elapsed(stageTimer,options.shouldInstrument);
                    [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
                case "reusable-overwrite"
                    stageTimer = tic;
                    fields = self.spatialFluxReusableOverwrite();
                    metrics.spatialForcingSeconds = elapsed(stageTimer,options.shouldInstrument);
                    stageTimer = tic;
                    [Fp,Fm,F0] = self.projectCurrent(fields);
                    metrics.projectionSeconds = elapsed(stageTimer,options.shouldInstrument);
                    [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
                case "forward-batch-cat"
                    stageTimer = tic;
                    fields = self.spatialFluxScalarZero();
                    metrics.spatialForcingSeconds = elapsed(stageTimer,options.shouldInstrument);
                    stageTimer = tic;
                    [Fp,Fm,F0] = self.projectBatched(fields,false);
                    metrics.projectionSeconds = elapsed(stageTimer,options.shouldInstrument);
                    [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
                case "forward-batch-preallocated"
                    stageTimer = tic;
                    fields = self.spatialFluxScalarZero();
                    metrics.spatialForcingSeconds = elapsed(stageTimer,options.shouldInstrument);
                    stageTimer = tic;
                    [Fp,Fm,F0] = self.projectBatched(fields,true);
                    metrics.projectionSeconds = elapsed(stageTimer,options.shouldInstrument);
                    [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
                case "full-batch-cat"
                    [Fp,Fm,F0,stageMetrics] = self.fullBatchedNonlinearFlux(false,options.shouldInstrument);
                    metrics = mergeMetrics(metrics,stageMetrics);
                case "full-batch-preallocated"
                    [Fp,Fm,F0,stageMetrics] = self.fullBatchedNonlinearFlux(true,options.shouldInstrument);
                    metrics = mergeMetrics(metrics,stageMetrics);
            end
            metrics.totalSeconds = elapsed(totalTimer,options.shouldInstrument);
            metrics.variant = self.variant;
        end

        function ledger = storageLedger(self)
            names = ["FuBuffer" "FvBuffer" "FwBuffer" "FetaBuffer" "spatialBatch" "inverseFourierRows"];
            entries = repmat(struct("name","","class","","shape",[],"bytes",0),0,1);
            for name = names
                value = self.(name);
                if isempty(value)
                    continue
                end
                info = whos("value");
                entries(end+1,1) = struct("name",name,"class",string(class(value)),"shape",double(size(value)),"bytes",double(info.bytes)); %#ok<AGROW>
            end
            transient = self.transientStorageLedger();
            ledger = struct( ...
                "variant",self.variant, ...
                "entries",entries, ...
                "knownPersistentBytes",sum([entries.bytes]), ...
                "transient",transient, ...
                "logicalMaximumLiveBytes",sum([entries.bytes])+transient.logicalMaximumLiveBytes, ...
                "physicalAliasing","unavailable-supported-api", ...
                "interpretation","Exact logical bytes for experiment-owned arrays; MATLAB-internal FFT work buffers and physical copy-on-write sharing remain opaque.");
        end

        function metadata = executionMetadata(self)
            metadata = struct( ...
                "variant",self.variant, ...
                "fieldCount",self.fieldCount(), ...
                "usesScalarZero",ismember(self.variant,["scalar-zero" "forward-batch-cat" "forward-batch-preallocated"]), ...
                "usesReusableFluxBuffers",ismember(self.variant,["reusable-reset" "reusable-overwrite"]), ...
                "usesBatchedForward",contains(self.variant,"forward-batch") || contains(self.variant,"full-batch"), ...
                "usesBatchedInverse",contains(self.variant,"full-batch"), ...
                "usesPreallocatedBatch",endsWith(self.variant,"preallocated"), ...
                "copyOnWriteEvidence","unavailable-supported-api", ...
                "pointerEvidence","unavailable-supported-api");
        end
    end

    methods (Access=private)
        function allocateFluxBuffers(self)
            self.FuBuffer = zeros(self.wvt.spatialMatrixSize);
            self.FvBuffer = zeros(self.wvt.spatialMatrixSize);
            self.FetaBuffer = zeros(self.wvt.spatialMatrixSize);
            if ~self.wvt.isHydrostatic
                self.FwBuffer = zeros(self.wvt.spatialMatrixSize);
            end
        end

        function count = fieldCount(self)
            count = 3 + double(~self.wvt.isHydrostatic);
        end

        function fields = spatialFluxScalarZero(self)
            if self.wvt.isHydrostatic
                Fu = 0;
                Fv = 0;
                Feta = 0;
                for forcing = self.wvt.spatialFluxForcing
                    [Fu,Fv,Feta] = forcing.addHydrostaticSpatialForcing(self.wvt,Fu,Fv,Feta);
                end
                fields = {Fu,Fv,Feta};
            else
                Fu = 0;
                Fv = 0;
                Fw = 0;
                Feta = 0;
                for forcing = self.wvt.spatialFluxForcing
                    [Fu,Fv,Fw,Feta] = forcing.addNonhydrostaticSpatialForcing(self.wvt,Fu,Fv,Fw,Feta);
                end
                fields = {Fu,Fv,Fw,Feta};
            end
        end

        function fields = spatialFluxReusableReset(self)
            self.FuBuffer(:) = 0;
            self.FvBuffer(:) = 0;
            self.FetaBuffer(:) = 0;
            if self.wvt.isHydrostatic
                for forcing = self.wvt.spatialFluxForcing
                    [self.FuBuffer,self.FvBuffer,self.FetaBuffer] = forcing.addHydrostaticSpatialForcing(self.wvt,self.FuBuffer,self.FvBuffer,self.FetaBuffer);
                end
                fields = {self.FuBuffer,self.FvBuffer,self.FetaBuffer};
            else
                self.FwBuffer(:) = 0;
                for forcing = self.wvt.spatialFluxForcing
                    [self.FuBuffer,self.FvBuffer,self.FwBuffer,self.FetaBuffer] = forcing.addNonhydrostaticSpatialForcing(self.wvt,self.FuBuffer,self.FvBuffer,self.FwBuffer,self.FetaBuffer);
                end
                fields = {self.FuBuffer,self.FvBuffer,self.FwBuffer,self.FetaBuffer};
            end
        end

        function fields = spatialFluxReusableOverwrite(self)
            self.requireDefaultNonlinearAdvectionOnly();
            U = self.wvt.u;
            V = self.wvt.v;
            W = self.wvt.w;
            ETA = self.wvt.eta;
            self.FuBuffer(:) = -(U.*self.wvt.diffX(U) + V.*self.wvt.diffY(U) + W.*self.wvt.diffZF(U));
            self.FvBuffer(:) = -(U.*self.wvt.diffX(V) + V.*self.wvt.diffY(V) + W.*self.wvt.diffZF(V));
            self.FetaBuffer(:) = -(U.*self.wvt.diffX(ETA) + V.*self.wvt.diffY(ETA) + W.*self.wvt.diffZG(ETA));
            if self.wvt.isHydrostatic
                fields = {self.FuBuffer,self.FvBuffer,self.FetaBuffer};
            else
                self.FwBuffer(:) = -(U.*self.wvt.diffX(W) + V.*self.wvt.diffY(W) + W.*self.wvt.diffZG(W));
                fields = {self.FuBuffer,self.FvBuffer,self.FwBuffer,self.FetaBuffer};
            end
        end

        function [Fp,Fm,F0] = projectCurrent(self,fields)
            if self.wvt.isHydrostatic
                [Fp,Fm,F0] = self.wvt.transformUVEtaToWaveVortex(fields{:});
            else
                [Fp,Fm,F0] = self.wvt.transformUVWEtaToWaveVortex(fields{:});
            end
        end

        function [Fp,Fm,F0] = projectBatched(self,fields,usesPreallocatedBatch)
            hats = self.horizontalForwardBatch(fields,usesPreallocatedBatch);
            uHat = hats(:,:,1);
            vHat = hats(:,:,2);
            if self.wvt.isHydrostatic
                nHat = hats(:,:,3);
                [Fp,Fm,F0] = self.projectHydrostaticHats(uHat,vHat,nHat);
            else
                wHat = hats(:,:,3);
                nHat = hats(:,:,4);
                [Fp,Fm,F0] = self.projectNonhydrostaticHats(uHat,vHat,wHat,nHat);
            end
        end

        function hats = horizontalForwardBatch(self,fields,usesPreallocatedBatch)
            if usesPreallocatedBatch
                for iField = 1:numel(fields)
                    self.spatialBatch(:,:,:,iField) = fields{iField};
                end
                spatial = self.spatialBatch;
            else
                spatial = cat(4,fields{:});
            end
            spectrum = fft(fft(spatial,self.wvt.Nx,1),self.wvt.Ny,2)/(self.wvt.Nx*self.wvt.Ny);
            rows = self.layout.reshapeFourierStorageToRows(spectrum);
            wvRows = self.layout.transformFromFourierStorageToWVGrid(rows);
            hats = permute(reshape(wvRows,[self.wvt.Nz numel(fields) self.wvt.Nkl]),[1 3 2]);
        end

        function fields = reconstructBatchedFields(self,usesPreallocatedBatch)
            Apt = self.wvt.Apt;
            Amt = self.wvt.Amt;
            A0t = self.wvt.A0t;
            uBar = self.wvt.iDCT*(self.wvt.F_g.*((self.wvt.UAp.*Apt + self.wvt.UAm.*Amt)./self.wvt.F_wg + self.wvt.UA0.*A0t));
            vBar = self.wvt.iDCT*(self.wvt.F_g.*((self.wvt.VAp.*Apt + self.wvt.VAm.*Amt)./self.wvt.F_wg + self.wvt.VA0.*A0t));
            nBar = self.wvt.iDST*(self.wvt.G_g.*((self.wvt.NAp.*Apt + self.wvt.NAm.*Amt)./self.wvt.G_wg + self.wvt.NA0.*A0t));
            wBar = self.wvt.iDST*(self.wvt.G_g.*((self.wvt.WAp.*Apt + self.wvt.WAm.*Amt)./self.wvt.G_wg));
            wvBatch = cat(3,uBar,vBar,wBar,nBar);
            fields = self.horizontalInverseBatch(wvBatch,usesPreallocatedBatch);
        end

        function fields = horizontalInverseBatch(self,wvBatch,usesPreallocatedBatch)
            count = size(wvBatch,3);
            wvRows = reshape(permute(wvBatch,[1 3 2]),self.wvt.Nz*count,self.wvt.Nkl);
            if usesPreallocatedBatch
                self.writeWVRowsIntoInverseStorage(wvRows);
                rows = self.inverseFourierRows;
            else
                rows = self.layout.allocateFourierStorage(self.wvt.Nz*count);
                rows = self.layout.transformFromWVGridToFourierStorage(rows,wvRows);
            end
            storage = reshape(rows,[self.wvt.Nx self.wvt.Ny self.wvt.Nz count]);
            if self.wvt.conjugateDimension == 1
                fields = ifft(ifft(storage,self.wvt.Ny,2),self.wvt.Nx,1,"symmetric")*(self.wvt.Nx*self.wvt.Ny);
            else
                fields = ifft(ifft(storage,self.wvt.Nx,1),self.wvt.Ny,2,"symmetric")*(self.wvt.Nx*self.wvt.Ny);
            end
        end

        function writeWVRowsIntoInverseStorage(self,wvRows)
            layout = self.layout;
            self.inverseFourierRows(layout.fourierRowsForDirectWVIndices,:) = wvRows(:,layout.directWVIndices).';
            if ~isempty(layout.fourierRowsForConjugatedWVIndices)
                self.inverseFourierRows(layout.fourierRowsForConjugatedWVIndices,:) = conj(wvRows(:,layout.conjugatedWVIndices).');
            end
            if ~isempty(layout.hermitianCompletionRows)
                self.inverseFourierRows(layout.hermitianCompletionRows,:) = conj(self.inverseFourierRows(layout.hermitianSourceRows,:));
            end
            if ~isempty(layout.selfConjugateFourierRows)
                self.inverseFourierRows(layout.selfConjugateFourierRows,:) = real(self.inverseFourierRows(layout.selfConjugateFourierRows,:));
            end
        end

        function [Fp,Fm,F0,metrics] = fullBatchedNonlinearFlux(self,usesPreallocatedBatch,shouldInstrument)
            self.requireDefaultNonlinearAdvectionOnly();
            metrics = self.emptyMetrics();
            stageTimer = tic;
            fields = self.reconstructBatchedFields(usesPreallocatedBatch);
            metrics.inverseBatchSeconds = elapsed(stageTimer,shouldInstrument);
            U = fields(:,:,:,1);
            V = fields(:,:,:,2);
            W = fields(:,:,:,3);
            ETA = fields(:,:,:,4);

            stageTimer = tic;
            Fu = -(U.*self.wvt.diffX(U) + V.*self.wvt.diffY(U) + W.*self.wvt.diffZF(U));
            Fv = -(U.*self.wvt.diffX(V) + V.*self.wvt.diffY(V) + W.*self.wvt.diffZF(V));
            Feta = -(U.*self.wvt.diffX(ETA) + V.*self.wvt.diffY(ETA) + W.*self.wvt.diffZG(ETA));
            if self.wvt.isHydrostatic
                fluxFields = {Fu,Fv,Feta};
            else
                Fw = -(U.*self.wvt.diffX(W) + V.*self.wvt.diffY(W) + W.*self.wvt.diffZG(W));
                fluxFields = {Fu,Fv,Fw,Feta};
            end
            metrics.spatialForcingSeconds = elapsed(stageTimer,shouldInstrument);

            stageTimer = tic;
            [Fp,Fm,F0] = self.projectBatched(fluxFields,usesPreallocatedBatch);
            metrics.projectionSeconds = elapsed(stageTimer,shouldInstrument);
            [Fp,Fm,F0] = self.applySpectralForcing(Fp,Fm,F0);
        end

        function [Ap,Am,A0] = projectHydrostaticHats(self,uHat,vHat,nHat)
            iK = 1i*repmat(shiftdim(self.wvt.k,-1),self.wvt.Nz,1);
            iL = 1i*repmat(shiftdim(self.wvt.l,-1),self.wvt.Nz,1);
            nBar = self.wvt.transformFromSpatialDomainWithGg(nHat);
            zetaBar = self.wvt.transformFromSpatialDomainWithFg(iK.*vHat - iL.*uHat);
            A0 = self.wvt.A0Z.*zetaBar + self.wvt.A0N.*nBar;
            deltaBar = self.wvt.transformWithG_wg(self.wvt.h_0.*self.wvt.transformFromSpatialDomainWithFg(iK.*uHat + iL.*vHat));
            nwBar = self.wvt.transformWithG_wg(nBar - self.wvt.NA0.*A0);
            Ap = self.wvt.ApmD.*deltaBar + self.wvt.ApmN.*nwBar;
            Am = self.wvt.ApmD.*deltaBar - self.wvt.ApmN.*nwBar;
            Ap(:,1) = self.wvt.transformFromSpatialDomainWithFio(uHat(:,1) - 1i*vHat(:,1))/2;
            Am(:,1) = conj(Ap(:,1));
            Ap = Ap.*self.wvt.conjPhase;
            Am = Am.*self.wvt.phase;
        end

        function [Ap,Am,A0] = projectNonhydrostaticHats(self,uHat,vHat,wHat,nHat)
            iK = 1i*repmat(shiftdim(self.wvt.k,-1),self.wvt.Nz,1);
            iL = 1i*repmat(shiftdim(self.wvt.l,-1),self.wvt.Nz,1);
            nBar = self.wvt.transformFromSpatialDomainWithGg(nHat);
            zetaBar = self.wvt.transformFromSpatialDomainWithFg(iK.*vHat - iL.*uHat);
            A0 = self.wvt.A0Z.*zetaBar + self.wvt.A0N.*nBar;
            nwBar = self.wvt.transformWithG_wg(nBar - self.wvt.NA0.*A0);
            deltaBar = self.wvt.ApmD_scaled.*(self.wvt.DCT*(self.wvt.cos_alpha.*uHat + self.wvt.sin_alpha.*vHat));
            wBar = self.wvt.ApmW_scaled.*(self.wvt.DST*wHat);
            Ap = deltaBar + wBar + self.wvt.ApmN.*nwBar;
            Am = deltaBar + wBar - self.wvt.ApmN.*nwBar;
            Ap(:,1) = self.wvt.transformFromSpatialDomainWithFio(uHat(:,1) - 1i*vHat(:,1))/2;
            Am(:,1) = conj(Ap(:,1));
            Ap = Ap.*self.wvt.conjPhase;
            Am = Am.*self.wvt.phase;
        end

        function [Fp,Fm,F0] = applySpectralForcing(self,Fp,Fm,F0)
            for forcing = self.wvt.spectralFluxForcing
                [Fp,Fm,F0] = forcing.addSpectralForcing(self.wvt,Fp,Fm,F0);
            end
            for forcing = self.wvt.spectralAmplitudeForcing
                [Fp,Fm,F0] = forcing.setSpectralForcing(self.wvt,Fp,Fm,F0);
            end
        end

        function requireDefaultNonlinearAdvectionOnly(self)
            forcing = self.wvt.forcing;
            if numel(forcing) ~= 1 || ~isa(forcing(1),"WVNonlinearAdvection") || ~isempty(self.wvt.spectralFluxForcing) || ~isempty(self.wvt.spectralAmplitudeForcing)
                error("WaveVortexBenchmark:UnsupportedForcingConfiguration","The issue #125 direct-overwrite and full-batch variants require the default WVNonlinearAdvection forcing only.");
            end
        end

        function metrics = emptyMetrics(~)
            metrics = struct("variant","","totalSeconds",NaN,"inverseBatchSeconds",NaN,"spatialForcingSeconds",NaN,"projectionSeconds",NaN);
        end

        function ledger = transientStorageLedger(self)
            realFieldBytes = 8*prod(self.wvt.spatialMatrixSize);
            complexFieldBytes = 16*prod(self.wvt.spatialMatrixSize);
            wvFieldBytes = 16*self.wvt.Nz*self.wvt.Nkl;
            fieldCount = self.fieldCount();
            batchInputBytes = 0;
            fourierStorageBytes = 0;
            wvOutputBytes = 0;
            if contains(self.variant,"forward-batch") || contains(self.variant,"full-batch")
                batchInputBytes = fieldCount*realFieldBytes;
                fourierStorageBytes = fieldCount*complexFieldBytes;
                wvOutputBytes = fieldCount*wvFieldBytes;
            end
            inverseBatchBytes = 0;
            if contains(self.variant,"full-batch")
                inverseBatchBytes = 4*realFieldBytes + 4*complexFieldBytes + 4*wvFieldBytes;
            end
            entries = [ ...
                struct("name","forwardBatchInput","bytes",batchInputBytes); ...
                struct("name","forwardFourierStorage","bytes",fourierStorageBytes); ...
                struct("name","forwardWVOutput","bytes",wvOutputBytes); ...
                struct("name","inverseBatchPipeline","bytes",inverseBatchBytes)];
            entries = entries([entries.bytes] > 0);
            ledger = struct( ...
                "entries",entries, ...
                "logicalMaximumLiveBytes",sum([entries.bytes]), ...
                "scope","experiment-added batch pipeline only", ...
                "physicalAliasing","unavailable-supported-api");
        end
    end

    methods (Static)
        function identifiers = variantIdentifiers()
            identifiers = ["current" "scalar-zero" "reusable-reset" "reusable-overwrite" "forward-batch-cat" "forward-batch-preallocated" "full-batch-cat" "full-batch-preallocated"];
        end
    end
end

function seconds = elapsed(timer,shouldInstrument)
if shouldInstrument
    seconds = toc(timer);
else
    seconds = NaN;
end
end

function target = mergeMetrics(target,source)
names = string(fieldnames(source));
for name = names'
    target.(name) = source.(name);
end
end
