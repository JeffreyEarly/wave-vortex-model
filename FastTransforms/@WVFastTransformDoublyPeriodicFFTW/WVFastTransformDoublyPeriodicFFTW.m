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
    % Spatial derivatives deliberately retain MATLAB's one-dimensional FFT
    % implementation until issue #74 evaluates derivative dispatch.
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
            if ~isempty(self.horizontalTransform) && isvalid(self.horizontalTransform)
                delete(self.horizontalTransform);
            end
            self.horizontalTransform = [];
        end
    end

    methods
        uBar = transformFromSpatialDomainWithFourier(self,u)
        u = transformToSpatialDomainWithFourier(self,uBar)
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
                "horizontalPlanCount",1, ...
                "persistentArrayBytes",0);
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
