classdef (Hidden) WVFourierSpectrumLayout
    % Internal mapping contract between Fourier storage and WV coefficients.
    properties (SetAccess=private)
        storageType
        compressedDimension
        physicalShape
        storageShape
        storageRowCount
        Nkl
        mappingStrategy = "two-dimensional-rows"
        directStorageRows uint64
        directWVColumns uint64
        conjugatedStorageRows uint64
        conjugatedWVColumns uint64
        completionStorageRows uint64
        completionSourceRows uint64
        completionWVColumns uint64
        selfConjugateStorageRows uint64
        mappingBytes
    end

    methods
        function self = WVFourierSpectrumLayout(wvg,storageType,options)
            arguments
                wvg (1,1) WVGeometryDoublyPeriodic
                storageType (1,1) string {mustBeMember(storageType,["full","hermitian-half"])}
                options.compressedDimension (1,1) double {mustBeMember(options.compressedDimension,[0 1 2])} = 0
            end
            if storageType == "full" && options.compressedDimension ~= 0
                error("WaveVortexModel:InvalidFullSpectrumLayout","Full spectrum storage requires compressedDimension=0.");
            elseif storageType == "hermitian-half" && options.compressedDimension == 0
                error("WaveVortexModel:InvalidHalfSpectrumLayout","Hermitian-half storage requires compressedDimension 1 or 2.");
            end

            self.storageType = storageType;
            self.compressedDimension = options.compressedDimension;
            self.physicalShape = [wvg.Nx wvg.Ny];
            self.Nkl = wvg.Nkl;
            if storageType == "full"
                self.storageShape = self.physicalShape;
                implicitHermitianDimension = wvg.conjugateDimension;
            else
                self.storageShape = self.physicalShape;
                self.storageShape(options.compressedDimension) = floor(self.storageShape(options.compressedDimension)/2)+1;
                implicitHermitianDimension = options.compressedDimension;
            end
            self.storageRowCount = prod(self.storageShape);

            kMode = double(wvg.kMode_wv(:));
            lMode = double(wvg.lMode_wv(:));
            [self.directStorageRows,self.directWVColumns,self.conjugatedStorageRows,self.conjugatedWVColumns,representedK,representedL] = self.primaryMappings(kMode,lMode);
            [self.completionStorageRows,self.completionSourceRows,self.selfConjugateStorageRows] = self.boundaryMappings(representedK,representedL,implicitHermitianDimension);
            self.completionWVColumns = self.wvColumnsForDirectRows(self.completionSourceRows);
            if self.storageType == "full"
                % Preserve the measured builtin assignment contract. Valid
                % real transforms already make self-conjugate values real.
                self.selfConjugateStorageRows = uint64.empty(0,1);
            end
            self.mappingBytes = self.exactMappingBytes();
        end

        function uBar = extractCanonical(self,storageRows)
            self.validateStorageRows(storageRows);
            nBatch = size(storageRows,2);
            if self.storageType == "full" && isempty(self.conjugatedWVColumns) && isequal(self.directWVColumns,uint64((1:self.Nkl)'))
                uBar = storageRows(self.directStorageRows,:).';
                return
            end
            uBar = complex(zeros(nBatch,self.Nkl));
            uBar(:,self.directWVColumns) = storageRows(self.directStorageRows,:).';
            if ~isempty(self.conjugatedWVColumns)
                uBar(:,self.conjugatedWVColumns) = conj(storageRows(self.conjugatedStorageRows,:).');
            end
        end

        function storageRows = allocateStorage(self,nBatch)
            arguments
                self (1,1) WVFourierSpectrumLayout
                nBatch (1,1) double {mustBeInteger,mustBePositive}
            end
            storageRows = complex(zeros(self.storageRowCount,nBatch));
        end

        function storageRows = insertCanonical(self,storageRows,uBar)
            self.validateStorageRows(storageRows);
            if size(uBar,1) ~= size(storageRows,2) || size(uBar,2) ~= self.Nkl
                error("WaveVortexModel:InvalidCanonicalSpectrumShape","Canonical coefficients must have shape [Nbatch,Nkl]=[%d,%d].",size(storageRows,2),self.Nkl);
            end
            storageRows(self.directStorageRows,:) = uBar(:,self.directWVColumns).';
            if ~isempty(self.conjugatedStorageRows)
                storageRows(self.conjugatedStorageRows,:) = conj(uBar(:,self.conjugatedWVColumns).');
            end
            if ~isempty(self.completionStorageRows)
                storageRows(self.completionStorageRows,:) = conj(storageRows(self.completionSourceRows,:));
            end
            if ~isempty(self.selfConjugateStorageRows)
                storageRows(self.selfConjugateStorageRows,:) = real(storageRows(self.selfConjugateStorageRows,:));
            end
        end

        function storageRows = rowsFromSpectrum(self,spectrum)
            spectrumSize = size(spectrum);
            if numel(spectrumSize) < 2 || ~isequal(spectrumSize(1:2),self.storageShape)
                error("WaveVortexModel:InvalidStoredSpectrumShape","Stored spectrum must begin with shape [%d,%d].",self.storageShape(1),self.storageShape(2));
            end
            if mod(numel(spectrum),self.storageRowCount) ~= 0
                error("WaveVortexModel:InvalidStoredSpectrumShape","Stored spectrum size is incompatible with the layout.");
            end
            storageRows = reshape(spectrum,self.storageRowCount,[]);
        end

        function spectrum = spectrumFromRows(self,storageRows)
            self.validateStorageRows(storageRows);
            spectrum = reshape(storageRows,[self.storageShape size(storageRows,2)]);
        end

        function ledger = mappingLedger(self)
            names = ["directStorageRows" "directWVColumns" "conjugatedStorageRows" "conjugatedWVColumns" "completionStorageRows" "completionSourceRows" "completionWVColumns" "selfConjugateStorageRows"];
            ledger = repmat(struct("name","","class","","shape",[],"bytes",0),1,numel(names));
            for iName = 1:numel(names)
                value = self.(names(iName));
                info = whos("value");
                ledger(iName) = struct("name",names(iName),"class",string(class(value)),"shape",double(size(value)),"bytes",double(info.bytes));
            end
        end

        function [dftPrimaryIndex,dftConjugateIndex,wvConjugateIndex] = expandedLegacyMappings(self,nBatch)
            arguments
                self (1,1) WVFourierSpectrumLayout
                nBatch (1,1) double {mustBeInteger,mustBePositive}
            end
            if ~isempty(self.conjugatedWVColumns)
                error("WaveVortexModel:LegacyMappingUnavailable","Legacy linear mappings cannot represent a layout whose canonical modes require conjugated extraction.");
            end
            offsets = uint64((0:nBatch-1)*self.storageRowCount);
            primary = self.directStorageRows(:)+offsets;
            dftPrimaryIndex = reshape(primary.',[],1);
            completion = self.completionStorageRows(:)+offsets;
            dftConjugateIndex = reshape(completion.',[],1);

            sourceWVColumns = zeros(numel(self.completionSourceRows),1,"uint64");
            for iSource = 1:numel(self.completionSourceRows)
                iDirect = find(self.directStorageRows == self.completionSourceRows(iSource),1);
                sourceWVColumns(iSource) = self.directWVColumns(iDirect);
            end
            wvIndices = uint64((0:nBatch-1)')+1+nBatch*(sourceWVColumns(:)'-1);
            wvConjugateIndex = reshape(wvIndices,[],1);
        end
    end

    methods (Access=private)
        function [directRows,directColumns,conjugatedRows,conjugatedColumns,representedK,representedL] = primaryMappings(self,kMode,lMode)
            wvColumns = uint64((1:numel(kMode))');
            representedK = kMode;
            representedL = lMode;
            conjugated = false(size(kMode));
            if self.storageType == "hermitian-half"
                compressedModes = kMode;
                if self.compressedDimension == 2
                    compressedModes = lMode;
                end
                conjugated = compressedModes < 0;
                representedK(conjugated) = -representedK(conjugated);
                representedL(conjugated) = -representedL(conjugated);
            end
            rows = self.rowForModes(representedK,representedL);
            directRows = rows(~conjugated);
            directColumns = wvColumns(~conjugated);
            conjugatedRows = rows(conjugated);
            conjugatedColumns = wvColumns(conjugated);
        end

        function [destinationRows,sourceRows,selfRows] = boundaryMappings(self,kMode,lMode,implicitHermitianDimension)
            boundaryModes = lMode;
            boundaryLength = self.physicalShape(2);
            if implicitHermitianDimension == 1
                boundaryModes = kMode;
                boundaryLength = self.physicalShape(1);
            end
            isBoundary = boundaryModes == 0;
            if mod(boundaryLength,2) == 0
                isBoundary = isBoundary | abs(boundaryModes) == boundaryLength/2;
            end
            sourceRows = self.rowForModes(kMode(isBoundary),lMode(isBoundary));
            conjugateRows = self.rowForModes(-kMode(isBoundary),-lMode(isBoundary));
            selfConjugate = sourceRows == conjugateRows;
            selfRows = unique(sourceRows(selfConjugate),"stable");

            assignedRows = [self.directStorageRows;self.conjugatedStorageRows];
            needsCompletion = ~selfConjugate & ~ismember(conjugateRows,assignedRows);
            destinationRows = conjugateRows(needsCompletion);
            sourceRows = sourceRows(needsCompletion);
            [destinationRows,uniqueIndices] = unique(destinationRows,"stable");
            sourceRows = sourceRows(uniqueIndices);
        end

        function rows = rowForModes(self,kMode,lMode)
            iK = mod(kMode,self.physicalShape(1))+1;
            iL = mod(lMode,self.physicalShape(2))+1;
            if self.storageType == "hermitian-half"
                if self.compressedDimension == 1
                    iK = min(iK,self.storageShape(1));
                else
                    iL = min(iL,self.storageShape(2));
                end
            end
            rows = uint64(iK+self.storageShape(1)*(iL-1));
        end

        function bytes = exactMappingBytes(self)
            ledger = self.mappingLedger();
            bytes = sum([ledger.bytes]);
        end

        function columns = wvColumnsForDirectRows(self,rows)
            columns = zeros(size(rows),"uint64");
            for iRow = 1:numel(rows)
                iDirect = find(self.directStorageRows == rows(iRow),1);
                if ~isempty(iDirect)
                    columns(iRow) = self.directWVColumns(iDirect);
                end
            end
        end

        function validateStorageRows(self,storageRows)
            if ~ismatrix(storageRows) || size(storageRows,1) ~= self.storageRowCount
                error("WaveVortexModel:InvalidStoredSpectrumShape","Spectrum rows must have shape [%d,Nbatch].",self.storageRowCount);
            end
        end
    end
end
