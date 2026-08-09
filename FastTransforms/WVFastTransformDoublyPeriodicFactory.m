classdef WVFastTransformDoublyPeriodicFactory < handle
    % Select and construct a doubly periodic horizontal-transform backend.
    %
    % This developer-facing factory keeps optional FFTW package discovery,
    % capability validation, local compilation, and fallback behavior out of
    % the geometry classes. The canonical WV grid is complete before the
    % factory is called; the selected adapter owns its Fourier storage layout.
    %
    % `"builtin"` never queries FFTWTransforms. An explicit `"fftw"` request
    % accepts only the validated MATLAB-bundled half-x r2c/c2r contract from
    % FFTWTransforms 1.0.2 or later. If required, one local build is attempted
    % before the capabilities are queried again. An unavailable request emits
    % one warning and returns the builtin adapter.
    %
    % ```matlab
    % factory = WVFastTransformDoublyPeriodicFactory();
    % [adapter,selection] = factory.create(geometry,Nz,"fftw");
    % ```
    %
    % Protected service methods are narrow test seams. This class is developer
    % infrastructure rather than an end-user modeling or extension API.
    %
    % - Topic: Developer internals
    % - Declaration: classdef WVFastTransformDoublyPeriodicFactory

    methods
        function [adapter,selection] = create(self,geometry,Nz,requestedBackend)
            % Construct the requested backend or a safe builtin fallback.
            %
            % - Topic: Developer internals
            % - Parameter geometry: completed doubly periodic WV geometry
            % - Parameter Nz: number of horizontal-transform batches
            % - Parameter requestedBackend: `"builtin"` or `"fftw"`
            % - Returns adapter: selected `WVFastTransformDoublyPeriodic`
            % - Returns selection: structured selection and fallback record
            % - Developer: true
            arguments
                self (1,1) WVFastTransformDoublyPeriodicFactory
                geometry (1,1) WVGeometryDoublyPeriodic
                Nz (1,1) double {mustBeInteger,mustBePositive}
                requestedBackend (1,1) string {mustBeMember(requestedBackend,["builtin","fftw"])}
            end

            selection = self.emptySelection(requestedBackend);
            if requestedBackend == "builtin"
                adapter = self.constructBuiltin(geometry,Nz);
                selection.activeBackend = "builtin";
                return
            end

            if ~self.isFFTWTransformsInstalled()
                reason = self.reason("package-missing","FFTWTransforms is not installed or is not on the MATLAB path.");
                [adapter,selection] = self.fallback(geometry,Nz,selection,reason);
                return
            end

            selection.packageAvailable = true;
            [capabilities,queryReason] = self.queryCapabilitiesSafely();
            selection.capabilityQueried = true;
            selection = self.recordIdentity(selection,capabilities);
            [isValid,validationReason] = self.validateHorizontalCapabilities(capabilities,queryReason);

            if ~isValid && self.buildIsPossible(capabilities)
                selection.buildAttempted = true;
                try
                    buildResult = self.buildBackend();
                    if isstruct(buildResult) && isfield(buildResult,"build") && isfield(buildResult.build,"succeeded")
                        selection.buildSucceeded = logical(buildResult.build.succeeded);
                    end
                    if isstruct(buildResult) && isfield(buildResult,"build") && isfield(buildResult.build,"reason")
                        selection.buildReason = self.normalizedReason(buildResult.build.reason,"build-failed");
                    end
                catch exception
                    selection.buildSucceeded = false;
                    selection.buildReason = self.exceptionReason("build-failed",exception);
                    validationReason = selection.buildReason;
                end

                [capabilities,queryReason] = self.queryCapabilitiesSafely();
                selection.capabilityQueried = true;
                selection = self.recordIdentity(selection,capabilities);
                [isValid,requeryReason] = self.validateHorizontalCapabilities(capabilities,queryReason);
                if isValid
                    validationReason = self.emptyReason();
                elseif requeryReason.code ~= ""
                    validationReason = requeryReason;
                end
            end

            if isValid
                try
                    adapter = self.constructFFTW(geometry,Nz);
                    selection.activeBackend = "fftw";
                    selection.reason = self.emptyReason();
                    return
                catch exception
                    validationReason = self.exceptionReason("adapter-construction-failed",exception);
                end
            end

            [adapter,selection] = self.fallback(geometry,Nz,selection,validationReason);
        end
    end

    methods (Access=protected)
        function tf = isFFTWTransformsInstalled(~)
            tf = exist("FFTWBackend","class") == 8;
        end

        function capabilities = queryCapabilities(~)
            capabilities = FFTWBackend.capabilities();
        end

        function capabilities = buildBackend(~)
            capabilities = FFTWBackend.build();
        end

        function adapter = constructBuiltin(~,geometry,Nz)
            adapter = WVFastTransformDoublyPeriodicMatlab(geometry,Nz);
        end

        function adapter = constructFFTW(~,geometry,Nz)
            adapter = WVFastTransformDoublyPeriodicFFTW(geometry,Nz);
        end
    end

    methods (Access=private)
        function [capabilities,reason] = queryCapabilitiesSafely(self)
            capabilities = struct();
            reason = self.emptyReason();
            try
                capabilities = self.queryCapabilities();
            catch exception
                reason = self.exceptionReason("capability-query-failed",exception);
            end
        end

        function [isValid,reason] = validateHorizontalCapabilities(self,capabilities,queryReason)
            isValid = false;
            reason = queryReason;
            if reason.code ~= ""
                return
            end
            try
                if string(capabilities.provider.id) ~= "matlab-bundled"
                    reason = self.reason("provider-mismatch","The active provider is not MATLAB's bundled FFTW provider.");
                    return
                end
                if ~capabilities.modules.r2c.identityValidated
                    reason = self.reason("library-identity-failed","The r2c module did not validate its loaded MATLAB FFTW library.");
                    return
                end
                if ~capabilities.features.r2c.isAvailable || ~capabilities.features.c2r.isAvailable
                    reason = self.capabilityReason(capabilities,"horizontal-feature-unavailable");
                    return
                end
                errors = [capabilities.features.r2c.maximumRelativeError capabilities.features.c2r.maximumRelativeError];
                if any(~isfinite(errors)) || any(errors > 1e-12)
                    reason = self.reason("horizontal-self-test-failed","The r2c/c2r numerical self-test exceeded relative error 1e-12.");
                    return
                end
                horizontal = capabilities.eligibility.horizontal;
                expectedOwnership = "MATLAB-managed zero-copy forward and uniquely owned destructive inverse";
                if ~horizontal.isReady || string(horizontal.layout) ~= "half-x" || ~isequal(double(horizontal.transformDimensions),[2 1])
                    reason = self.reason("horizontal-eligibility-failed","The validated horizontal eligibility record is not READY for half-x dimensions [2 1].");
                    return
                end
                if string(horizontal.ownership) ~= expectedOwnership
                    reason = self.reason("ownership-contract-mismatch","The FFTWTransforms ownership contract is not the validated zero-copy/destructive contract.");
                    return
                end
                scratch = capabilities.memory.preservingInverseScratch;
                if string(scratch.policy) ~= "lazy-on-first-preserving-c2r" || scratch.allocatedBytesAtPlanCreation ~= 0 || scratch.allocatedBytesForDestructiveOnlyUse ~= 0
                    reason = self.reason("scratch-contract-mismatch","Preserving c2r scratch is not lazy and zero-sized for destructive-only use.");
                    return
                end
            catch exception
                reason = self.exceptionReason("incompatible-capability-schema",exception);
                return
            end
            isValid = true;
            reason = self.emptyReason();
        end

        function tf = buildIsPossible(~,capabilities)
            tf = false;
            try
                tf = logical(capabilities.build.isPossible);
            catch
            end
        end

        function reason = capabilityReason(self,capabilities,fallbackCode)
            reason = self.reason(fallbackCode,"The bundled r2c/c2r capability is unavailable.");
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

        function selection = recordIdentity(~,selection,capabilities)
            try
                selection.providerId = string(capabilities.provider.id);
            catch
            end
            try
                selection.libraryPath = string(capabilities.modules.r2c.libraryPath);
            catch
            end
        end

        function [adapter,selection] = fallback(self,geometry,Nz,selection,reason)
            adapter = self.constructBuiltin(geometry,Nz);
            selection.activeBackend = "builtin";
            selection.didFallback = true;
            selection.reason = reason;
            warning("WaveVortexModel:FFTWBackendUnavailable", ...
                "The requested FFTW backend is unavailable (%s): %s Continuing with MATLAB builtin transforms. Install FFTWTransforms ^1.0.2 and inspect FFTWBackend.capabilities(); on a supported R2026a maca64 system, run FFTWBackend.build().", ...
                reason.code,reason.message);
        end

        function selection = emptySelection(self,requestedBackend)
            selection = struct( ...
                "requestedBackend",requestedBackend, ...
                "activeBackend","", ...
                "didFallback",false, ...
                "packageAvailable",false, ...
                "capabilityQueried",false, ...
                "buildAttempted",false, ...
                "buildSucceeded",false, ...
                "buildReason",self.emptyReason(), ...
                "providerId","", ...
                "libraryPath","", ...
                "reason",self.emptyReason());
        end

        function reason = reason(~,code,message)
            reason = struct("code",string(code),"identifier","","message",string(message));
        end

        function reason = exceptionReason(self,code,exception)
            reason = self.reason(code,exception.message);
            reason.identifier = string(exception.identifier);
        end

        function reason = normalizedReason(self,candidate,fallbackCode)
            reason = self.reason(fallbackCode,"The FFTWTransforms build did not succeed.");
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

        function reason = emptyReason(~)
            reason = struct("code","","identifier","","message","");
        end
    end
end
