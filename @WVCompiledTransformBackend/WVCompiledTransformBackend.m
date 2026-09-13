classdef (Sealed) WVCompiledTransformBackend < handle
    % Own one compiled variable-evaluation transform session.
    %
    % This developer-facing adapter is the initial Hydrostatic proof for the
    % in-memory stratified modal-source bridge. It owns only the native handle
    % and immutable shape/module identity; the native session owns modal data,
    % prepared operators, and evaluation workspaces.
    %
    % - Developer: true
    % - Topic: Compiled transform internals
    % - Declaration: classdef (Sealed) WVCompiledTransformBackend

    properties (GetAccess=public, SetAccess=private)
        capabilities
    end

    properties (Access=private)
        moduleName (1,1) string = ""
        transformHandle = []
        transformClass (1,1) string = ""
        Nx (1,1) double = 0
        Ny (1,1) double = 0
        Nz (1,1) double = 0
        Nj (1,1) double = 0
        Nkl (1,1) double = 0
        compiledSourceIdentity = []
    end

    methods (Static)
        function backend = create(wvt)
            % Create a compiled Hydrostatic transform session.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: backend = WVCompiledTransformBackend.create(wvt)
            % - Parameter wvt: Hydrostatic transform supplying the modal source
            % - Returns backend: owning compiled transform session
            arguments
                wvt (1,1) WVTransformHydrostatic
            end
            capabilities = WVCompiledBackend.capabilities();
            WVCompiledTransformBackend.validateCapabilities(capabilities);
            backend = WVCompiledTransformBackend(wvt,capabilities);
        end
    end

    methods
        function prepare(self,variableNames)
            % Prepare one immutable variable evaluation plan.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: prepare(variableNames)
            % - Parameter variableNames: names accepted by the portable variable catalog
            self.assertActive();
            variableNames = WVCompiledTransformBackend.normalizeVariableNames(variableNames);
            feval(char(self.moduleName),'transformPrepare',self.transformHandle,variableNames);
        end

        function result = evaluate(self,wvt,variableNames,options)
            % Evaluate registered variables and optionally the nonlinear flux.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: result = evaluate(wvt,variableNames,options)
            % - Parameter wvt: source transform whose state is evaluated
            % - Parameter variableNames: prepared variable names
            % - Parameter options.shouldEvaluateFlux: also return three flux cells; default false
            % - Returns result: scalar native result struct with values, flux, and metrics
            arguments
                self (1,1) WVCompiledTransformBackend
                wvt (1,1) WVTransformHydrostatic
                variableNames
                options.shouldEvaluateFlux (1,1) logical = false
            end
            self.assertActive();
            self.assertMatchingTransform(wvt);
            variableNames = WVCompiledTransformBackend.normalizeVariableNames(variableNames);
            if ~isequal(size(wvt.Ap),[self.Nj self.Nkl]) || ~isequal(size(wvt.Am),[self.Nj self.Nkl]) || ~isequal(size(wvt.A0),[self.Nj self.Nkl])
                error("WaveVortexModel:CompiledTransformShape","The evaluated transform coefficient arrays do not match the compiled session shape.")
            end
            result = feval(char(self.moduleName),'transformEvaluate',self.transformHandle,complex(wvt.Ap),complex(wvt.Am),complex(wvt.A0),wvt.t,wvt.t0,variableNames,options.shouldEvaluateFlux);
        end

        function value = metadata(self)
            % Return native transform-session metadata.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: value = metadata()
            % - Returns value: scalar native metadata struct, or deleted status
            if isempty(self.transformHandle)
                value = struct("status","deleted");
            else
                value = feval(char(self.moduleName),'transformMetadata',self.transformHandle);
            end
        end

        function delete(self)
            if isempty(self.transformHandle)
                return
            end
            handle = self.transformHandle;
            self.transformHandle = [];
            try
                feval(char(self.moduleName),'transformDelete',handle);
            catch exception
                warning("WaveVortexModel:CompiledTransformCleanup","Unable to delete the compiled transform cleanly: %s",exception.message)
            end
        end
    end

    methods (Access=private)
        function self = WVCompiledTransformBackend(wvt,capabilities)
            self.capabilities = capabilities;
            self.moduleName = string(capabilities.module.name);
            self.transformClass = string(class(wvt));
            self.Nx = wvt.Nx; self.Ny = wvt.Ny; self.Nz = wvt.Nz; self.Nj = wvt.Nj; self.Nkl = wvt.Nkl;
            self.compiledSourceIdentity = wvt.compiledSourceIdentity;
            configuration = wvCompiledStratifiedModalConfiguration(wvt);
            handle = [];
            try
                handle = feval(char(self.moduleName),'transformCreate',configuration);
                self.transformHandle = handle;
            catch exception
                if ~isempty(handle)
                    try
                        feval(char(self.moduleName),'transformDelete',handle);
                    catch
                    end
                end
                rethrow(exception)
            end
        end

        function assertActive(self)
            if isempty(self.transformHandle)
                error("WaveVortexModel:CompiledTransformDeleted","The compiled transform session has already been deleted.")
            end
        end

        function assertMatchingTransform(self,wvt)
            if string(class(wvt)) ~= self.transformClass || ~isvalid(self.compiledSourceIdentity) || ~(wvt.compiledSourceIdentity == self.compiledSourceIdentity) || wvt.Nx ~= self.Nx || wvt.Ny ~= self.Ny || wvt.Nz ~= self.Nz || wvt.Nj ~= self.Nj || wvt.Nkl ~= self.Nkl
                error("WaveVortexModel:CompiledTransformMismatch","The evaluated transform does not match the compiled session configuration.")
            end
        end
    end

    methods (Static, Access=private)
        function validateCapabilities(capabilities)
            if ~isstruct(capabilities) || ~isfield(capabilities,"isAvailable") || ~capabilities.isAvailable
                error("WaveVortexModel:CompiledTransformUnavailable","The compiled transform backend is unavailable. Build native support explicitly before creating a session.")
            end
            if ~isfield(capabilities,"module") || ~isfield(capabilities.module,"name") || strlength(string(capabilities.module.name)) == 0 || ...
                    ~isfield(capabilities.module,"identityValidated") || ~capabilities.module.identityValidated
                error("WaveVortexModel:CompiledTransformCapabilityMismatch","The installed compiled module does not have a validated identity.")
            end
            if ~isfield(capabilities.module,"matlabTransformBridgeVersion") || capabilities.module.matlabTransformBridgeVersion ~= 1
                error("WaveVortexModel:CompiledTransformCapabilityMismatch","The installed module predates the MATLAB transform bridge. Rebuild with WVCompiledBackend.build().")
            end
        end

        function variableNames = normalizeVariableNames(variableNames)
            if isstring(variableNames)
                variableNames = cellstr(variableNames(:));
            elseif ischar(variableNames)
                variableNames = {variableNames};
            elseif iscell(variableNames) && all(cellfun(@(name) ischar(name) && isrow(name),variableNames(:)))
                variableNames = variableNames(:);
            else
                error("WaveVortexModel:CompiledTransformVariables","Variable names must be a string array, character vector, or cell array of character vectors.")
            end
            if isempty(variableNames)
                error("WaveVortexModel:CompiledTransformVariables","At least one variable name is required.")
            end
        end
    end
end
