classdef (Sealed) WVVerticalTransformConstantStratification < handle
    % Select and cache constant-stratification vertical transforms.
    %
    % This developer-facing strategy applies normalized DCT-I and DST-I
    % transforms to canonical vertical arrays shaped `[Nz,Nbatch]`. It is
    % independent of horizontal Fourier storage. With the builtin backend it
    % always evaluates the supplied dense matrix expression. With an active
    % FFTW backend it uses only the exact issue #43 eligibility records and
    % falls back to the same matrix expression everywhere else.
    %
    % Cosine transforms retain the first `Nj` coefficients and discard all
    % excluded modes, including the Nyquist coefficient. Sine transforms add
    % the WaveVortex logical `j=0` zero row around FFTW's `Nz-2` interior-mode
    % representation. Scaling by `F_g`, `G_g`, `F_wg`, or `G_wg` remains the
    % responsibility of the geometry.
    %
    % ```matlab
    % strategy = WVVerticalTransformConstantStratification.create(Nz,Nj,"fftw");
    % coefficients = strategy.transformForward(values,"cosine",DCT);
    % values = strategy.transformBack(coefficients,"cosine",iDCT);
    % records = strategy.dispatchRecords();
    % ```
    %
    % - Topic: Developer internals
    % - Declaration: classdef (Sealed) WVVerticalTransformConstantStratification < handle

    properties (SetAccess=private)
        % Number of physical vertical grid points.
        %
        % - Topic: Developer internals
        % - Developer: true
        Nz (1,1) double

        % Number of retained WaveVortex vertical modes.
        %
        % - Topic: Developer internals
        % - Developer: true
        Nj (1,1) double

        % Active model-wide transform backend, `"builtin"` or `"fftw"`.
        %
        % - Topic: Developer internals
        % - Developer: true
        backendIdentifier (1,1) string
    end

    properties (Access=private)
        capabilities (1,1) struct = struct()
        planConstructor
        planCache
        failedConfigurations
        dispatchRecordMap
        initializationFailure (1,1) struct
        hasWarnedOfFailure (1,1) logical = false
    end

    properties (Constant, Access=private)
        relativeErrorTolerance = 1e-12
        eligibilitySchema = "issue43-v1"
    end

    methods (Static)
        function strategy = create(Nz,Nj,activeBackend)
            % Create a vertical strategy for the active model backend.
            %
            % Builtin construction performs no FFTW capability query. FFTW
            % construction queries capabilities once and never attempts a
            % build; horizontal backend construction owns the build attempt.
            %
            % - Topic: Developer internals
            % - Parameter Nz: Number of physical vertical grid points.
            % - Parameter Nj: Number of retained WV vertical modes.
            % - Parameter activeBackend: `"builtin"` or `"fftw"`.
            % - Returns strategy: Configured vertical transform strategy.
            % - Developer: true
            arguments
                Nz (1,1) double {mustBeInteger,mustBePositive}
                Nj (1,1) double {mustBeInteger,mustBePositive}
                activeBackend (1,1) string {mustBeMember(activeBackend,["builtin","fftw"])}
            end
            services = WVVerticalTransformConstantStratification.defaultServices();
            strategy = WVVerticalTransformConstantStratification.createWithServices(Nz,Nj,activeBackend,services);
        end
    end

    methods (Static, Hidden)
        function strategy = createWithServices(Nz,Nj,activeBackend,services)
            % Create a strategy with injected authoring/test services.
            arguments
                Nz (1,1) double {mustBeInteger,mustBePositive}
                Nj (1,1) double {mustBeInteger,mustBePositive}
                activeBackend (1,1) string {mustBeMember(activeBackend,["builtin","fftw"])}
                services (1,1) struct
            end
            if Nj > Nz-1
                error("WaveVortexModel:InvalidVerticalModeCount","Nj must not exceed Nz-1 for constant-stratification transforms.");
            end
            WVVerticalTransformConstantStratification.validateServices(services);
            capabilities = struct();
            initializationFailure = WVVerticalTransformConstantStratification.emptyReason();
            if activeBackend == "fftw"
                try
                    capabilities = services.queryCapabilities();
                    WVVerticalTransformConstantStratification.validateCapabilitySchema(capabilities);
                catch exception
                    initializationFailure = WVVerticalTransformConstantStratification.exceptionReason("vertical-capability-query-failed",exception);
                end
            end
            strategy = WVVerticalTransformConstantStratification(Nz,Nj,activeBackend,capabilities,initializationFailure,services.constructPlan);
            if initializationFailure.code ~= ""
                strategy.warnOnce(initializationFailure);
            end
        end
    end

    methods
        function coefficients = transformForward(self,values,transformType,fallbackMatrix)
            % Transform `[Nz,Nbatch]` values to `[Nj,Nbatch]` coefficients.
            %
            % The fallback matrix must be the existing normalized WV cosine
            % or sine forward matrix with shape `[Nj,Nz]`.
            %
            % - Topic: Developer internals
            % - Parameter values: Real or complex `[Nz,Nbatch]` values.
            % - Parameter transformType: `"cosine"` or `"sine"`.
            % - Parameter fallbackMatrix: Normalized `[Nj,Nz]` dense matrix.
            % - Returns coefficients: Retained `[Nj,Nbatch]` coefficients.
            % - Developer: true
            arguments
                self (1,1) WVVerticalTransformConstantStratification
                values double
                transformType (1,1) string {mustBeMember(transformType,["cosine","sine"])}
                fallbackMatrix double
            end
            self.validateForwardShapes(values,fallbackMatrix);
            [useFFTW,record,key,planKey] = self.dispatchDecision(values,transformType,"forward");
            if ~useFFTW
                coefficients = fallbackMatrix*values;
                self.storeRecord(key,record,"matrix",false,false);
                return
            end

            [plan,record,created,reused] = self.planForConfiguration(planKey,values,transformType,record);
            if isempty(plan)
                coefficients = fallbackMatrix*values;
                self.storeRecord(key,record,"matrix",created,reused);
                return
            end
            try
                rawCoefficients = plan.transformForward(values);
                if transformType == "cosine"
                    coefficients = rawCoefficients(1:self.Nj,:);
                else
                    coefficients = zeros(self.Nj,size(values,2),"like",rawCoefficients);
                    coefficients(2:self.Nj,:) = rawCoefficients(1:self.Nj-1,:);
                end
                self.storeRecord(key,record,"fftw",created,reused);
            catch exception
                record.reason = self.failConfiguration(planKey,"vertical-transform-execution-failed",exception);
                coefficients = fallbackMatrix*values;
                self.storeRecord(key,record,"matrix",created,reused);
            end
        end

        function values = transformBack(self,coefficients,transformType,fallbackMatrix)
            % Transform `[Nj,Nbatch]` coefficients to `[Nz,Nbatch]` values.
            %
            % The fallback matrix must be the existing normalized WV cosine
            % or sine inverse matrix with shape `[Nz,Nj]`.
            %
            % - Topic: Developer internals
            % - Parameter coefficients: Real or complex retained coefficients.
            % - Parameter transformType: `"cosine"` or `"sine"`.
            % - Parameter fallbackMatrix: Normalized `[Nz,Nj]` dense matrix.
            % - Returns values: Reconstructed `[Nz,Nbatch]` values.
            % - Developer: true
            arguments
                self (1,1) WVVerticalTransformConstantStratification
                coefficients double
                transformType (1,1) string {mustBeMember(transformType,["cosine","sine"])}
                fallbackMatrix double
            end
            self.validateBackShapes(coefficients,fallbackMatrix);
            [useFFTW,record,key,planKey] = self.dispatchDecision(coefficients,transformType,"inverse");
            if ~useFFTW
                values = fallbackMatrix*coefficients;
                self.storeRecord(key,record,"matrix",false,false);
                return
            end

            [plan,record,created,reused] = self.planForConfiguration(planKey,coefficients,transformType,record);
            if isempty(plan)
                values = fallbackMatrix*coefficients;
                self.storeRecord(key,record,"matrix",created,reused);
                return
            end
            try
                if transformType == "cosine"
                    paddedCoefficients = zeros(self.Nz,size(coefficients,2),"like",coefficients);
                    paddedCoefficients(1:self.Nj,:) = coefficients;
                else
                    paddedCoefficients = zeros(self.Nz-2,size(coefficients,2),"like",coefficients);
                    paddedCoefficients(1:self.Nj-1,:) = coefficients(2:self.Nj,:);
                end
                values = plan.transformBack(paddedCoefficients);
                if transformType == "sine"
                    values([1 end],:) = 0;
                end
                self.storeRecord(key,record,"fftw",created,reused);
            catch exception
                record.reason = self.failConfiguration(planKey,"vertical-transform-execution-failed",exception);
                values = fallbackMatrix*coefficients;
                self.storeRecord(key,record,"matrix",created,reused);
            end
        end

        function records = dispatchRecords(self)
            % Return stable, JSON-safe records for encountered operations.
            %
            % - Topic: Developer internals
            % - Returns records: Configuration, implementation, eligibility,
            %   failure, call-count, and plan-reuse records sorted by key.
            % - Developer: true
            keys = sort(string(self.dispatchRecordMap.keys));
            records = WVVerticalTransformConstantStratification.emptyDispatchRecords();
            for iKey = 1:numel(keys)
                records(end+1) = self.dispatchRecordMap(char(keys(iKey))); %#ok<AGROW>
            end
        end

        function delete(self)
            % Delete every cached FFTW plan idempotently.
            %
            % The strategy retains no array-sized MATLAB work buffers. Plan
            % deletion releases the native FFTW plans owned by the cached
            % `RealToRealTransform` objects.
            %
            % - Topic: Developer internals
            % - Developer: true
            if isempty(self.planCache) || self.planCache.Count == 0
                return
            end
            keys = self.planCache.keys;
            for iKey = 1:numel(keys)
                plan = self.planCache(keys{iKey});
                if ~isempty(plan) && isvalid(plan)
                    delete(plan);
                end
            end
            remove(self.planCache,self.planCache.keys);
        end
    end

    methods (Hidden)
        function diagnostics = cacheDiagnostics(self)
            diagnostics = struct( ...
                "planCount",self.planCache.Count, ...
                "failedConfigurationCount",self.failedConfigurations.Count, ...
                "hasWarnedOfFailure",self.hasWarnedOfFailure);
        end

        function record = dispatchForConfiguration(self,Nbatch,dataType,transformType,direction)
            % Return eligibility without allocating an input or creating a plan.
            arguments
                self (1,1) WVVerticalTransformConstantStratification
                Nbatch (1,1) double {mustBeInteger,mustBePositive}
                dataType (1,1) string {mustBeMember(dataType,["real","complex"])}
                transformType (1,1) string {mustBeMember(transformType,["cosine","sine"])}
                direction (1,1) string {mustBeMember(direction,["forward","inverse"])}
            end
            [~,record] = self.dispatchDecisionForConfiguration(Nbatch,dataType,transformType,direction);
        end
    end

    methods (Access=private)
        function self = WVVerticalTransformConstantStratification(Nz,Nj,activeBackend,capabilities,initializationFailure,planConstructor)
            self.Nz = Nz;
            self.Nj = Nj;
            self.backendIdentifier = activeBackend;
            self.capabilities = capabilities;
            self.initializationFailure = initializationFailure;
            self.planConstructor = planConstructor;
            self.planCache = containers.Map("KeyType","char","ValueType","any");
            self.failedConfigurations = containers.Map("KeyType","char","ValueType","any");
            self.dispatchRecordMap = containers.Map("KeyType","char","ValueType","any");
        end

        function validateForwardShapes(self,values,fallbackMatrix)
            if ~ismatrix(values) || size(values,1) ~= self.Nz
                error("WaveVortexModel:InvalidVerticalTransformShape","Forward vertical values must have shape [Nz,Nbatch].");
            end
            if ~isequal(size(fallbackMatrix),[self.Nj self.Nz])
                error("WaveVortexModel:InvalidVerticalFallbackShape","Forward fallback matrix must have shape [Nj,Nz].");
            end
        end

        function validateBackShapes(self,coefficients,fallbackMatrix)
            if ~ismatrix(coefficients) || size(coefficients,1) ~= self.Nj
                error("WaveVortexModel:InvalidVerticalTransformShape","Inverse vertical coefficients must have shape [Nj,Nbatch].");
            end
            if ~isequal(size(fallbackMatrix),[self.Nz self.Nj])
                error("WaveVortexModel:InvalidVerticalFallbackShape","Inverse fallback matrix must have shape [Nz,Nj].");
            end
        end

        function [useFFTW,record,key,planKey] = dispatchDecision(self,values,transformType,direction)
            dataType = "real";
            if ~isreal(values)
                dataType = "complex";
            end
            batchCount = size(values,2);
            key = char(sprintf("%s|%s|%s|%d",transformType,direction,dataType,batchCount));
            planKey = char(sprintf("%s|%s|%d",transformType,dataType,batchCount));
            [useFFTW,record] = self.dispatchDecisionForConfiguration(batchCount,dataType,transformType,direction);
        end

        function [useFFTW,record] = dispatchDecisionForConfiguration(self,batchCount,dataType,transformType,direction)
            key = char(sprintf("%s|%s|%s|%d",transformType,direction,dataType,batchCount));
            planKey = char(sprintf("%s|%s|%d",transformType,dataType,batchCount));
            record = self.newDispatchRecord(key,batchCount,dataType,transformType,direction);
            useFFTW = false;

            if self.backendIdentifier ~= "fftw"
                record.reason = self.reason("builtin-backend","The builtin backend uses the existing dense vertical matrices.");
                return
            end
            if self.initializationFailure.code ~= ""
                record.reason = self.initializationFailure;
                return
            end
            if isKey(self.failedConfigurations,planKey)
                record.reason = self.failedConfigurations(planKey);
                return
            end

            try
                capabilityRecord = self.capabilities;
                if string(capabilityRecord.provider.id) ~= "matlab-bundled"
                    record.reason = self.reason("provider-mismatch","The active FFTW provider is not matlab-bundled.");
                    return
                end
                if ~capabilityRecord.modules.r2r.identityValidated
                    record.reason = self.reason("r2r-library-identity-failed","The r2r module did not validate its loaded FFTW library.");
                    return
                end
                featureName = "dct1";
                if transformType == "sine"
                    featureName = "dst1";
                end
                feature = capabilityRecord.features.(featureName);
                if ~feature.isAvailable
                    record.reason = self.reason("vertical-feature-unavailable","The requested FFTW real-to-real feature is unavailable.");
                    return
                end
                if ~isfinite(feature.maximumRelativeError) || feature.maximumRelativeError > self.relativeErrorTolerance
                    record.reason = self.reason("vertical-self-test-failed","The FFTW real-to-real self-test exceeded relative error 1e-12.");
                    return
                end
                eligibility = capabilityRecord.eligibility.realToReal;
                if string(eligibility.schemaVersion) ~= self.eligibilitySchema
                    error("WaveVortexModel:IncompatibleR2REligibility","Expected issue43-v1 real-to-real eligibility records.");
                end
                records = eligibility.records;
                matches = [records.Nz] == self.Nz & string({records.dataType}) == dataType & ...
                    string({records.transformType}) == transformType & string({records.direction}) == direction;
                if nnz(matches) ~= 1
                    record.reason = self.reason("eligibility-record-missing","No exact issue #43 eligibility record matches this operation.");
                    return
                end
                eligibilityRecord = records(matches);
                if ~eligibilityRecord.eligible
                    record.reason = self.reason("eligibility-record-ineligible","Issue #43 did not establish a qualifying FFTW speedup for this operation.");
                    return
                end
                intervals = eligibilityRecord.intervals;
                intervalMask = batchCount >= [intervals.minimumBatchCount] & batchCount <= [intervals.maximumBatchCount];
                if ~any(intervalMask)
                    record.reason = self.reason("batch-outside-eligibility","Nbatch is outside the validated issue #43 intervals.");
                    return
                end
                interval = intervals(find(intervalMask,1));
                record.isEligible = true;
                record.minimumBatchCount = interval.minimumBatchCount;
                record.maximumBatchCount = interval.maximumBatchCount;
                record.sourceIssue = eligibility.sourceIssue;
                record.sourceArtifact = string(eligibility.sourceArtifact);
                useFFTW = true;
            catch exception
                record.reason = self.exceptionReason("incompatible-vertical-capability-schema",exception);
                self.failedConfigurations(planKey) = record.reason;
                self.warnOnce(record.reason);
            end
        end

        function [plan,record,created,reused] = planForConfiguration(self,planKey,values,transformType,record)
            created = false;
            reused = false;
            plan = [];
            if isKey(self.failedConfigurations,planKey)
                record.reason = self.failedConfigurations(planKey);
                return
            end
            if isKey(self.planCache,planKey)
                plan = self.planCache(planKey);
                reused = true;
                return
            end
            dataType = "real";
            if ~isreal(values)
                dataType = "complex";
            end
            try
                plan = self.planConstructor([self.Nz size(values,2)],transformType,dataType);
                self.planCache(planKey) = plan;
                created = true;
            catch exception
                record.reason = self.failConfiguration(planKey,"vertical-plan-construction-failed",exception);
            end
        end

        function reason = failConfiguration(self,planKey,code,exception)
            if isKey(self.planCache,planKey)
                plan = self.planCache(planKey);
                remove(self.planCache,planKey);
                if ~isempty(plan) && isvalid(plan)
                    delete(plan);
                end
            end
            reason = self.exceptionReason(code,exception);
            self.failedConfigurations(planKey) = reason;
            self.warnOnce(reason);
        end

        function storeRecord(self,key,record,implementation,created,reused)
            if isKey(self.dispatchRecordMap,key)
                previous = self.dispatchRecordMap(key);
                record.callCount = previous.callCount;
                record.planCreationCount = previous.planCreationCount;
                record.planReuseCount = previous.planReuseCount;
            end
            record.callCount = record.callCount+1;
            record.planCreationCount = record.planCreationCount+double(created);
            record.planReuseCount = record.planReuseCount+double(reused);
            record.implementation = string(implementation);
            self.dispatchRecordMap(key) = record;
        end

        function record = newDispatchRecord(self,key,batchCount,dataType,transformType,direction)
            record = struct( ...
                "key",string(key), ...
                "Nz",self.Nz, ...
                "Nj",self.Nj, ...
                "Nbatch",batchCount, ...
                "dataType",string(dataType), ...
                "transformType",string(transformType), ...
                "direction",string(direction), ...
                "implementation","matrix", ...
                "isEligible",false, ...
                "minimumBatchCount",0, ...
                "maximumBatchCount",0, ...
                "sourceIssue",0, ...
                "sourceArtifact","", ...
                "reason",self.emptyReason(), ...
                "callCount",0, ...
                "planCreationCount",0, ...
                "planReuseCount",0);
        end

        function warnOnce(self,reason)
            if self.hasWarnedOfFailure
                return
            end
            self.hasWarnedOfFailure = true;
            warning("WaveVortexModel:FFTWVerticalTransformUnavailable", ...
                "An eligible FFTW vertical transform is unavailable (%s): %s Continuing with the existing dense matrix transform.", ...
                reason.code,reason.message);
        end
    end

    methods (Static, Access=private)
        function services = defaultServices()
            services = struct( ...
                "queryCapabilities",@()FFTWBackend.capabilities(), ...
                "constructPlan",@(sz,transformType,dataType)RealToRealTransform(sz, ...
                    dims=1,transform=transformType,dataType=dataType,planner="measure", ...
                    nCores=maxNumCompThreads,alignmentMode="unaligned",plannerTimeLimitSeconds=10));
        end

        function validateServices(services)
            requiredFields = ["queryCapabilities","constructPlan"];
            for field = requiredFields
                if ~isfield(services,field) || ~isa(services.(field),"function_handle")
                    error("WaveVortexModel:InvalidVerticalTransformServices","Vertical transform services must provide a function handle named %s.",field);
                end
            end
        end

        function validateCapabilitySchema(capabilities)
            requiredTopLevel = ["provider","modules","features","eligibility"];
            for field = requiredTopLevel
                if ~isfield(capabilities,field)
                    error("WaveVortexModel:IncompatibleVerticalCapabilitySchema","FFTW capabilities are missing %s.",field);
                end
            end
            if ~isfield(capabilities.modules,"r2r") || ~isfield(capabilities.features,"dct1") || ...
                    ~isfield(capabilities.features,"dst1") || ~isfield(capabilities.eligibility,"realToReal")
                error("WaveVortexModel:IncompatibleVerticalCapabilitySchema","FFTW capabilities do not contain the required real-to-real records.");
            end
        end

        function reason = reason(code,message)
            reason = struct("code",string(code),"identifier","","message",string(message));
        end

        function reason = exceptionReason(code,exception)
            reason = WVVerticalTransformConstantStratification.reason(code,exception.message);
            reason.identifier = string(exception.identifier);
        end

        function reason = emptyReason()
            reason = struct("code","","identifier","","message","");
        end

        function records = emptyDispatchRecords()
            records = repmat(struct( ...
                "key","","Nz",0,"Nj",0,"Nbatch",0,"dataType","", ...
                "transformType","","direction","","implementation","", ...
                "isEligible",false,"minimumBatchCount",0,"maximumBatchCount",0, ...
                "sourceIssue",0,"sourceArtifact","","reason",WVVerticalTransformConstantStratification.emptyReason(), ...
                "callCount",0,"planCreationCount",0,"planReuseCount",0),0,1);
        end
    end
end
