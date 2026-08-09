classdef WVFastTransformDoublyPeriodic < handle
    % Define and select a doubly periodic horizontal-transform backend.
    %
    % Concrete adapters implement the horizontal Fourier transform and
    % derivative operations used by doubly periodic WaveVortex geometries.
    % The static `create` method keeps optional FFTW package discovery,
    % capability validation, local compilation, and fallback behavior out of
    % the geometry classes. The canonical WV grid is complete before `create`
    % is called; the selected adapter owns its Fourier storage layout.
    %
    % `"builtin"` never queries FFTWTransforms. An explicit `"fftw"` request
    % accepts only the validated MATLAB-bundled half-x r2c/c2r contract from
    % FFTWTransforms 1.0.2 or later. If required, one local build is attempted
    % before capabilities are queried again. An unavailable request emits one
    % warning and returns the builtin adapter.
    %
    % ```matlab
    % [adapter,selection] = WVFastTransformDoublyPeriodic.create( ...
    %     geometry,Nz,"fftw");
    % ```
    %
    % This class is developer infrastructure rather than an end-user modeling
    % or extension API.
    %
    % - Topic: Developer internals
    % - Declaration: classdef WVFastTransformDoublyPeriodic

    properties (SetAccess=protected)
        % Stable identifier for the active horizontal-transform backend.
        %
        % - Topic: Developer internals
        % - Developer: true
        backendIdentifier (1,1) string

        fourierStorageLayout
    end

    methods (Static)
        function [adapter,selection] = create(geometry,Nz,requestedBackend)
            % Construct the requested backend or a safe builtin fallback.
            %
            % The canonical geometry and WV coefficient ordering must be
            % complete before calling this method. Backend selection changes
            % only Fourier storage and execution; it does not change the WV
            % grid. The returned selection record reports the requested and
            % active backends, fallback and build status, provider/library
            % identity, and any structured failure reason.
            %
            % - Topic: Developer internals
            % - Parameter geometry: completed doubly periodic WV geometry
            % - Parameter Nz: number of horizontal-transform batches
            % - Parameter requestedBackend: `"builtin"` or `"fftw"`
            % - Returns adapter: selected `WVFastTransformDoublyPeriodic`
            % - Returns selection: structured selection and fallback record
            % - Developer: true
            arguments
                geometry (1,1) WVGeometryDoublyPeriodic
                Nz (1,1) double {mustBeInteger,mustBePositive}
                requestedBackend (1,1) string {mustBeMember(requestedBackend,["builtin","fftw"])}
            end

            services = WVFastTransformDoublyPeriodic.defaultServices();
            [adapter,selection] = WVFastTransformDoublyPeriodic.createWithServices(geometry,Nz,requestedBackend,services);
        end
    end

    methods (Static, Hidden)
        function [adapter,selection] = createWithServices(geometry,Nz,requestedBackend,services)
            % Construct a backend using injected authoring/test services.
            arguments
                geometry (1,1) WVGeometryDoublyPeriodic
                Nz (1,1) double {mustBeInteger,mustBePositive}
                requestedBackend (1,1) string {mustBeMember(requestedBackend,["builtin","fftw"])}
                services (1,1) struct
            end

            WVFastTransformDoublyPeriodic.validateServices(services);
            selection = WVFastTransformDoublyPeriodic.emptySelection(requestedBackend);
            if requestedBackend == "builtin"
                adapter = services.constructBuiltin(geometry,Nz);
                selection.activeBackend = "builtin";
                return
            end

            if ~services.isFFTWTransformsInstalled()
                reason = WVFastTransformDoublyPeriodic.reason("package-missing","FFTWTransforms is not installed or is not on the MATLAB path.");
                [adapter,selection] = WVFastTransformDoublyPeriodic.fallback(geometry,Nz,selection,reason,services);
                return
            end

            selection.packageAvailable = true;
            [capabilities,queryReason] = WVFastTransformDoublyPeriodic.queryCapabilitiesSafely(services);
            selection.capabilityQueried = true;
            selection = WVFastTransformDoublyPeriodic.recordIdentity(selection,capabilities);
            [isValid,validationReason] = WVFastTransformDoublyPeriodic.validateHorizontalCapabilities(capabilities,queryReason);

            if ~isValid && WVFastTransformDoublyPeriodic.buildIsPossible(capabilities)
                selection.buildAttempted = true;
                try
                    buildResult = services.buildBackend();
                    if isstruct(buildResult) && isfield(buildResult,"build") && isfield(buildResult.build,"succeeded")
                        selection.buildSucceeded = logical(buildResult.build.succeeded);
                    end
                    if isstruct(buildResult) && isfield(buildResult,"build") && isfield(buildResult.build,"reason")
                        selection.buildReason = WVFastTransformDoublyPeriodic.normalizedReason(buildResult.build.reason,"build-failed");
                    end
                catch exception
                    selection.buildSucceeded = false;
                    selection.buildReason = WVFastTransformDoublyPeriodic.exceptionReason("build-failed",exception);
                    validationReason = selection.buildReason;
                end

                [capabilities,queryReason] = WVFastTransformDoublyPeriodic.queryCapabilitiesSafely(services);
                selection.capabilityQueried = true;
                selection = WVFastTransformDoublyPeriodic.recordIdentity(selection,capabilities);
                [isValid,requeryReason] = WVFastTransformDoublyPeriodic.validateHorizontalCapabilities(capabilities,queryReason);
                if isValid
                    validationReason = WVFastTransformDoublyPeriodic.emptyReason();
                elseif requeryReason.code ~= ""
                    validationReason = requeryReason;
                end
            end

            if isValid
                try
                    adapter = services.constructFFTW(geometry,Nz);
                    selection.activeBackend = "fftw";
                    selection.reason = WVFastTransformDoublyPeriodic.emptyReason();
                    return
                catch exception
                    validationReason = WVFastTransformDoublyPeriodic.exceptionReason("adapter-construction-failed",exception);
                end
            end

            [adapter,selection] = WVFastTransformDoublyPeriodic.fallback(geometry,Nz,selection,validationReason,services);
        end
    end

    methods (Abstract)
        u_bar = transformFromSpatialDomainWithFourier(self,u)
        u = transformToSpatialDomainWithFourier(self,u_bar)
        du = diffX(wvg,u,options)
        du = diffY(wvg,u,options)
    end

    methods (Static, Access=private)
        function services = defaultServices()
            services = struct( ...
                "isFFTWTransformsInstalled",@()exist("FFTWBackend","class") == 8, ...
                "queryCapabilities",@()FFTWBackend.capabilities(), ...
                "buildBackend",@()FFTWBackend.build(), ...
                "constructBuiltin",@(geometry,Nz)WVFastTransformDoublyPeriodicMatlab(geometry,Nz), ...
                "constructFFTW",@(geometry,Nz)WVFastTransformDoublyPeriodicFFTW(geometry,Nz));
        end

        function validateServices(services)
            requiredFields = ["isFFTWTransformsInstalled","queryCapabilities","buildBackend","constructBuiltin","constructFFTW"];
            for field = requiredFields
                if ~isfield(services,field) || ~isa(services.(field),"function_handle")
                    error("WaveVortexModel:InvalidBackendServices","Backend services must provide a function handle named %s.",field);
                end
            end
        end

        function [capabilities,reason] = queryCapabilitiesSafely(services)
            capabilities = struct();
            reason = WVFastTransformDoublyPeriodic.emptyReason();
            try
                capabilities = services.queryCapabilities();
            catch exception
                reason = WVFastTransformDoublyPeriodic.exceptionReason("capability-query-failed",exception);
            end
        end

        function [isValid,reason] = validateHorizontalCapabilities(capabilities,queryReason)
            isValid = false;
            reason = queryReason;
            if reason.code ~= ""
                return
            end
            try
                if string(capabilities.provider.id) ~= "matlab-bundled"
                    reason = WVFastTransformDoublyPeriodic.reason("provider-mismatch","The active provider is not MATLAB's bundled FFTW provider.");
                    return
                end
                if ~capabilities.modules.r2c.identityValidated
                    reason = WVFastTransformDoublyPeriodic.reason("library-identity-failed","The r2c module did not validate its loaded MATLAB FFTW library.");
                    return
                end
                if ~capabilities.features.r2c.isAvailable || ~capabilities.features.c2r.isAvailable
                    reason = WVFastTransformDoublyPeriodic.capabilityReason(capabilities,"horizontal-feature-unavailable");
                    return
                end
                errors = [capabilities.features.r2c.maximumRelativeError capabilities.features.c2r.maximumRelativeError];
                if any(~isfinite(errors)) || any(errors > 1e-12)
                    reason = WVFastTransformDoublyPeriodic.reason("horizontal-self-test-failed","The r2c/c2r numerical self-test exceeded relative error 1e-12.");
                    return
                end
                horizontal = capabilities.eligibility.horizontal;
                expectedOwnership = "MATLAB-managed zero-copy forward and uniquely owned destructive inverse";
                if ~horizontal.isReady || string(horizontal.layout) ~= "half-x" || ~isequal(double(horizontal.transformDimensions),[2 1])
                    reason = WVFastTransformDoublyPeriodic.reason("horizontal-eligibility-failed","The validated horizontal eligibility record is not READY for half-x dimensions [2 1].");
                    return
                end
                if string(horizontal.ownership) ~= expectedOwnership
                    reason = WVFastTransformDoublyPeriodic.reason("ownership-contract-mismatch","The FFTWTransforms ownership contract is not the validated zero-copy/destructive contract.");
                    return
                end
                scratch = capabilities.memory.preservingInverseScratch;
                if string(scratch.policy) ~= "lazy-on-first-preserving-c2r" || scratch.allocatedBytesAtPlanCreation ~= 0 || scratch.allocatedBytesForDestructiveOnlyUse ~= 0
                    reason = WVFastTransformDoublyPeriodic.reason("scratch-contract-mismatch","Preserving c2r scratch is not lazy and zero-sized for destructive-only use.");
                    return
                end
            catch exception
                reason = WVFastTransformDoublyPeriodic.exceptionReason("incompatible-capability-schema",exception);
                return
            end
            isValid = true;
            reason = WVFastTransformDoublyPeriodic.emptyReason();
        end

        function tf = buildIsPossible(capabilities)
            tf = false;
            try
                tf = logical(capabilities.build.isPossible);
            catch
            end
        end

        function reason = capabilityReason(capabilities,fallbackCode)
            reason = WVFastTransformDoublyPeriodic.reason(fallbackCode,"The bundled r2c/c2r capability is unavailable.");
            candidates = {capabilities.features.r2c.reason,capabilities.features.c2r.reason,capabilities.reason};
            for iCandidate = 1:numel(candidates)
                candidate = candidates{iCandidate};
                if isstruct(candidate) && isfield(candidate,"message") && strlength(string(candidate.message)) > 0
                    reason = candidate;
                    if ~isfield(reason,"code") || strlength(string(reason.code)) == 0
                        reason.code = fallbackCode;
                    end
                    reason.code = string(reason.code);
                    reason.message = string(reason.message);
                    return
                end
            end
        end

        function selection = recordIdentity(selection,capabilities)
            try
                selection.providerId = string(capabilities.provider.id);
            catch
            end
            try
                selection.libraryPath = string(capabilities.modules.r2c.libraryPath);
            catch
            end
        end

        function [adapter,selection] = fallback(geometry,Nz,selection,reason,services)
            adapter = services.constructBuiltin(geometry,Nz);
            selection.activeBackend = "builtin";
            selection.didFallback = true;
            selection.reason = reason;
            warning("WaveVortexModel:FFTWBackendUnavailable", ...
                "The requested FFTW backend is unavailable (%s): %s Continuing with MATLAB builtin transforms. Install FFTWTransforms ^1.0.2 and inspect FFTWBackend.capabilities(); on a supported R2026a maca64 system, run FFTWBackend.build().", ...
                reason.code,reason.message);
        end

        function selection = emptySelection(requestedBackend)
            selection = struct( ...
                "requestedBackend",requestedBackend, ...
                "activeBackend","", ...
                "didFallback",false, ...
                "packageAvailable",false, ...
                "capabilityQueried",false, ...
                "buildAttempted",false, ...
                "buildSucceeded",false, ...
                "buildReason",WVFastTransformDoublyPeriodic.emptyReason(), ...
                "providerId","", ...
                "libraryPath","", ...
                "reason",WVFastTransformDoublyPeriodic.emptyReason());
        end

        function reason = reason(code,message)
            reason = struct("code",string(code),"identifier","","message",string(message));
        end

        function reason = exceptionReason(code,exception)
            reason = WVFastTransformDoublyPeriodic.reason(code,exception.message);
            reason.identifier = string(exception.identifier);
        end

        function reason = normalizedReason(candidate,fallbackCode)
            reason = WVFastTransformDoublyPeriodic.reason(fallbackCode,"The FFTWTransforms build did not succeed.");
            if ~isstruct(candidate)
                return
            end
            if isfield(candidate,"code") && strlength(string(candidate.code)) > 0
                reason.code = string(candidate.code);
            end
            if isfield(candidate,"identifier")
                reason.identifier = string(candidate.identifier);
            end
            if isfield(candidate,"message") && strlength(string(candidate.message)) > 0
                reason.message = string(candidate.message);
            end
        end

        function reason = emptyReason()
            reason = struct("code","","identifier","","message","");
        end
    end
end
