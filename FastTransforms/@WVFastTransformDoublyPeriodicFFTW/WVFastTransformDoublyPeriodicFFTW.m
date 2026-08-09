classdef WVFastTransformDoublyPeriodicFFTW < WVFastTransformDoublyPeriodic
    % Apply memory-lean horizontal transforms through FFTWTransforms.
    %
    % This developer-facing adapter stores horizontal Fourier coefficients
    % in Hermitian half-x form while preserving the canonical WaveVortex
    % grid shape `[Nz,Nkl]`. It owns one two-dimensional FFTW plan and no
    % real- or spectrum-sized persistent MATLAB array.
    %
    % Forward transforms return normalized WaveVortex coefficients. Inverse
    % transforms assemble a uniquely owned transient half spectrum and use
    % FFTW's destructive c2r operation without additional normalization.
    % Spatial derivatives retain MATLAB by default and lazily create
    % one-dimensional FFTW plans only for exact issue #74 dispatch records.
    % Per-field reconstruction can apply horizontal multipliers directly on
    % the canonical WV grid without retaining additional Fourier storage.
    %
    % ```matlab
    % adapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz);
    % coefficients = adapter.transformFromSpatialDomainWithFourier(u);
    % u = adapter.transformToSpatialDomainWithFourier(coefficients);
    % ```
    %
    % - Topic: Create an FFTW adapter
    % - Topic: Apply horizontal transforms
    % - Topic: Apply spatial derivatives
    % - Declaration: classdef WVFastTransformDoublyPeriodicFFTW < WVFastTransformDoublyPeriodic

    properties (SetAccess=private)
        % Geometry defining the horizontal WaveVortex grid.
        %
        % - Topic: Create an FFTW adapter
        % - Developer: true
        wvg

        % Number of independent horizontal-transform batches.
        %
        % - Topic: Create an FFTW adapter
        % - Developer: true
        Nz (1,1) double
    end

    properties (Access=private)
        horizontalTransform
        xDerivativeTransform
        yDerivativeTransform
        xDerivativeUnavailable (1,1) logical = false
        yDerivativeUnavailable (1,1) logical = false
        hasWarnedOfDerivativeFailure (1,1) logical = false
        forwardMappingMethod (1,1) string
        inverseMappingMethod (1,1) string
    end

    methods
        function self = WVFastTransformDoublyPeriodicFFTW(wvg,Nz,options)
            % Create a half-x FFTW horizontal-transform adapter.
            %
            % The mapping-method options are authoring benchmark controls.
            % Production construction uses the general layout method for
            % forward extraction and the benchmark-selected specialized
            % compact-row assignments for inverse assembly. The options
            % remain available so authoring benchmarks can compare both
            % implementations with complete adapter calls.
            %
            % - Topic: Create an FFTW adapter
            % - Parameter wvg: doubly periodic WaveVortex geometry
            % - Parameter Nz: positive number of horizontal transform batches
            % - Parameter nCores: FFTW thread count
            % - Parameter planner: FFTW planning strategy
            % - Parameter alignmentMode: FFTW new-array alignment policy
            % - Parameter plannerTimeLimitSeconds: planning limit for each plan
            % - Parameter forwardMappingMethod: compact forward mapping implementation used by authoring benchmarks
            % - Parameter inverseMappingMethod: compact inverse mapping implementation used by authoring benchmarks
            % - Returns self: configured adapter
            % - Developer: true
            arguments
                wvg (1,1) WVGeometryDoublyPeriodic
                Nz (1,1) double {mustBeInteger,mustBePositive}
                options.nCores (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
                options.planner (1,1) string {mustBeMember(options.planner,["estimate","measure","patient","exhaustive"])} = "measure"
                options.alignmentMode (1,1) string {mustBeMember(options.alignmentMode,["matched","unaligned"])} = "unaligned"
                options.plannerTimeLimitSeconds (1,1) double {mustBePositive,mustBeFinite} = 10
                options.forwardMappingMethod (1,1) string {mustBeMember(options.forwardMappingMethod,["layout-methods","specialized-rows"])} = "layout-methods"
                options.inverseMappingMethod (1,1) string {mustBeMember(options.inverseMappingMethod,["layout-methods","specialized-rows"])} = "specialized-rows"
            end
            self.backendIdentifier = "fftw";
            self.wvg = wvg;
            self.Nz = Nz;
            self.forwardMappingMethod = options.forwardMappingMethod;
            self.inverseMappingMethod = options.inverseMappingMethod;
            self.fourierStorageLayout = WVFourierStorageLayout(wvg,"hermitian-half",compressedDimension=1);
            self.horizontalTransform = RealToComplexTransform([wvg.Nx wvg.Ny Nz],dims=[2 1],planner=options.planner,nCores=options.nCores,alignmentMode=options.alignmentMode,plannerTimeLimitSeconds=options.plannerTimeLimitSeconds);
        end

        function delete(self)
            if ~isempty(self.xDerivativeTransform) && isvalid(self.xDerivativeTransform)
                delete(self.xDerivativeTransform);
            end
            self.xDerivativeTransform = [];
            if ~isempty(self.yDerivativeTransform) && isvalid(self.yDerivativeTransform)
                delete(self.yDerivativeTransform);
            end
            self.yDerivativeTransform = [];
            if ~isempty(self.horizontalTransform) && isvalid(self.horizontalTransform)
                delete(self.horizontalTransform);
            end
            self.horizontalTransform = [];
        end
    end

    methods
        uBar = transformFromSpatialDomainWithFourier(self,u)
        u = transformToSpatialDomainWithFourier(self,uBar)
        [u,u_x,u_y] = transformToSpatialDomainWithFourierAndDerivatives(self,uBar)
        du = diffX(self,u,options)
        du = diffY(self,u,options)
    end

    methods (Hidden)
        function diagnostics = storageDiagnostics(self)
            % Return issue #71 structural storage diagnostics.
            %
            % This narrow developer record intentionally precedes the full
            % storage-ledger contract owned by issue #75.
            %
            % - Topic: Create an FFTW adapter
            % - Returns diagnostics: layout, mapping, plan-count, and persistent-array record
            % - Developer: true
            diagnostics = struct( ...
                "fourierStorageType",self.fourierStorageLayout.fourierStorageType, ...
                "compressedDimension",self.fourierStorageLayout.compressedDimension, ...
                "fourierStorageSize",self.fourierStorageLayout.fourierStorageSize, ...
                "forwardMappingMethod",self.forwardMappingMethod, ...
                "inverseMappingMethod",self.inverseMappingMethod, ...
                "mappingMemoryBytes",self.fourierStorageLayout.mappingMemoryBytes, ...
                "horizontalPlanCount",1 + double(~isempty(self.xDerivativeTransform) && isvalid(self.xDerivativeTransform)) + double(~isempty(self.yDerivativeTransform) && isvalid(self.yDerivativeTransform)), ...
                "persistentArrayBytes",0);
        end

        function entries = storageLedger(self)
            % Return exact arrays and opaque FFTW plans for memory benchmarks.
            entries = emptyLedger();
            mappings = self.fourierStorageLayout.mappingMemoryUsage();
            for iMapping = 1:numel(mappings)
                mapping = mappings(iMapping);
                entries(end+1,1) = ledgerEntry("horizontal.layout." + mapping.name,"WVFourierStorageLayout","mapping","Fourier/WV index mapping",mapping.class,mapping.shape,mapping.bytes,"persistent","allocated","exact","mapping",mapping.bytes); %#ok<AGROW>
            end
            halfBytes = 16*prod(self.horizontalTransform.complexSize);
            entries(end+1,1) = ledgerEntry("horizontal.persistentSpectrumBuffer","WVFastTransformDoublyPeriodicFFTW","spectrum-buffer","No persistent Fourier buffer is retained","double",self.horizontalTransform.complexSize,0,"persistent","unallocated","exact","hermitian-half",halfBytes);
            entries(end+1,1) = ledgerEntry("horizontal.preservingInverseScratch","RealToComplexTransform","preserving-scratch","Lazy preserving-c2r scratch; production uses destructive c2r","double",self.horizontalTransform.complexSize,0,"persistent","unallocated","exact","hermitian-half",halfBytes);
            entries(end+1,1) = planEntry("horizontal.plan","Horizontal half-x r2c/c2r plan",self.horizontalTransform);
            if ~isempty(self.xDerivativeTransform) && isvalid(self.xDerivativeTransform)
                entries(end+1,1) = planEntry("horizontal.derivativePlanX","One-dimensional x-derivative r2c/c2r plan",self.xDerivativeTransform);
            end
            if ~isempty(self.yDerivativeTransform) && isvalid(self.yDerivativeTransform)
                entries(end+1,1) = planEntry("horizontal.derivativePlanY","One-dimensional y-derivative r2c/c2r plan",self.yDerivativeTransform);
            end
            realBytes = 8*prod(self.horizontalTransform.realSize);
            entries(end+1,1) = ledgerEntry("horizontal.forwardHalfSpectrum","WVFastTransformDoublyPeriodicFFTW","temporary","Zero-copy allocating forward result","double",self.horizontalTransform.complexSize,halfBytes,"transient","allocated","exact","hermitian-half",halfBytes);
            entries(end+1,1) = ledgerEntry("horizontal.inverseHalfSpectrum","WVFastTransformDoublyPeriodicFFTW","temporary","Uniquely owned destructive inverse input","double",self.horizontalTransform.complexSize,halfBytes,"transient","allocated","exact","hermitian-half",halfBytes);
            entries(end+1,1) = ledgerEntry("horizontal.inverseSpatialResult","WVFastTransformDoublyPeriodicFFTW","temporary","Caller-owned destructive inverse output","double",self.horizontalTransform.realSize,realBytes,"transient","allocated","exact","real",realBytes);
        end

        function [u,diagnostics] = destructiveInverseDiagnostics(self,uBar)
            % Exercise the production destructive inverse with pointer evidence.
            %
            % - Topic: Apply horizontal transforms
            % - Parameter uBar: canonical WV-grid coefficients `[Nz,Nkl]`
            % - Returns u: reconstructed real spatial array `[Nx,Ny,Nz]`
            % - Returns diagnostics: before/after spectrum and real-output pointer tokens
            % - Developer: true
            halfSpectrum = self.assembleHalfSpectrum(uBar);
            u = zeros(self.horizontalTransform.realSize);
            spectrumBefore = fftw_r2c('pointer',halfSpectrum);
            outputBefore = fftw_r2c('pointer',u);
            [halfSpectrum,u] = self.horizontalTransform.transformBackIntoArrayDestructive(halfSpectrum,u);
            diagnostics = struct( ...
                "spectrumBefore",spectrumBefore, ...
                "spectrumAfter",fftw_r2c('pointer',halfSpectrum), ...
                "outputBefore",outputBefore, ...
                "outputAfter",fftw_r2c('pointer',u));
        end
    end

    methods (Access=private)
        function halfSpectrum = assembleHalfSpectrum(self,uBar)
            rows = self.fourierStorageLayout.allocateFourierStorage(self.Nz);
            if self.inverseMappingMethod == "specialized-rows"
                rows = self.insertSpecialized(rows,uBar);
            else
                rows = self.fourierStorageLayout.transformFromWVGridToFourierStorage(rows,uBar);
            end
            halfSpectrum = self.fourierStorageLayout.reshapeFourierRowsToStorage(rows);
        end

        function rows = insertSpecialized(self,rows,uBar)
            layout = self.fourierStorageLayout;
            rows(layout.fourierRowsForDirectWVIndices,:) = uBar(:,layout.directWVIndices).';
            if ~isempty(layout.fourierRowsForConjugatedWVIndices)
                rows(layout.fourierRowsForConjugatedWVIndices,:) = conj(uBar(:,layout.conjugatedWVIndices).');
            end
            if ~isempty(layout.hermitianCompletionRows)
                rows(layout.hermitianCompletionRows,:) = conj(rows(layout.hermitianSourceRows,:));
            end
            if ~isempty(layout.selfConjugateFourierRows)
                rows(layout.selfConjugateFourierRows,:) = real(rows(layout.selfConjugateFourierRows,:));
            end
        end
    end
end

function value = planEntry(identifier,purpose,plan)
value = ledgerEntry(identifier,"RealToComplexTransform","fftw-plan",purpose,string(class(plan)),plan.realSize,NaN,"persistent","allocated","opaque","plan",NaN);
end

function value = ledgerEntry(identifier,owner,category,purpose,className,shape,bytes,persistence,allocationState,byteStatus,storageType,potentialBytes)
value = struct("identifier",identifier,"owner",owner,"category",category,"purpose",purpose,"className",className,"shape",double(shape),"bytes",double(bytes),"persistence",persistence,"allocationState",allocationState,"byteStatus",byteStatus,"storageType",storageType,"potentialBytes",double(potentialBytes));
end

function value = emptyLedger()
value = repmat(ledgerEntry("","","","","",[],0,"","","","",0),0,1);
end
