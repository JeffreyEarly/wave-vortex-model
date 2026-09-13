classdef (Sealed) WVCompiledTransformBackend < handle
    % Own one compiled variable-evaluation transform session.
    %
    % This developer-facing adapter provides the in-memory Hydrostatic,
    % Boussinesq and Stratified QG modal-source bridge. It owns only the native handle
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
        geometryValues = []
    end

    methods (Static)
        function backend = create(wvt)
            % Create a compiled stratified transform session.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: backend = WVCompiledTransformBackend.create(wvt)
            % - Parameter wvt: stratified transform supplying its solved modal source
            % - Returns backend: owning compiled transform session
            arguments
                wvt (1,1) WVTransform
            end
            if ~ismember(string(class(wvt)),["WVTransformHydrostatic" "WVTransformBoussinesq" "WVTransformStratifiedQG" "WVTransformBarotropicQG"])
                error("WaveVortexModel:CompiledTransformUnsupportedFamily","Compiled MATLAB support currently covers Hydrostatic, Boussinesq, Stratified QG and Barotropic QG transforms.")
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
            % - Parameter options.shouldEvaluateFlux: also return three wave flux cells or one QG flux cell; default false
            % - Returns result: scalar native result struct with values, flux, and metrics
            arguments
                self (1,1) WVCompiledTransformBackend
                wvt (1,1) WVTransform
                variableNames
                options.shouldEvaluateFlux (1,1) logical = false
            end
            self.assertActive();
            self.assertMatchingTransform(wvt);
            variableNames = WVCompiledTransformBackend.normalizeVariableNames(variableNames);
            [Ap,Am,A0] = WVCompiledTransformBackend.stateArrays(wvt,self.Nj,self.Nkl);
            result = feval(char(self.moduleName),'transformEvaluate',self.transformHandle,Ap,Am,A0,wvt.t,wvt.t0,variableNames,options.shouldEvaluateFlux);
        end

        function result = operation(self,wvt,operationName,inputs,options)
            % Invoke one explicitly supported compiled numerical primitive.
            %
            % - Developer: true
            % - Topic: Compiled transform internals
            % - Declaration: result = operation(wvt,operationName,inputs,options)
            % - Parameter wvt: source transform identifying this session
            % - Parameter operationName: native primitive identifier
            % - Parameter inputs: ordered input arrays borrowed for this call
            % - Parameter options: primitive-specific options
            % - Returns result: ordered values and native execution metrics
            arguments
                self (1,1) WVCompiledTransformBackend
                wvt (1,1) WVTransform
                operationName (1,1) string
                inputs (1,:) cell = cell(1,0)
                options (1,1) struct = struct()
            end
            self.assertActive();
            self.assertMatchingTransform(wvt);
            if ~ismember(string(class(wvt)),["WVTransformHydrostatic" "WVTransformBoussinesq" "WVTransformStratifiedQG" "WVTransformBarotropicQG"])
                error("WaveVortexModel:CompiledTransformUnsupportedFamily","Compiled operation family is not supported.")
            end
            result = feval(char(self.moduleName),'transformOperation',self.transformHandle,char(operationName),inputs,options);
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
            self.Nx = wvt.Nx; self.Ny = wvt.Ny; self.Nj = wvt.Nj; self.Nkl = wvt.Nkl;
            self.geometryValues = WVCompiledTransformBackend.sourceGeometry(wvt);
            self.Nz = self.geometryValues(3);
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
            if string(class(wvt)) ~= self.transformClass || ~isvalid(self.compiledSourceIdentity) || ~(wvt.compiledSourceIdentity == self.compiledSourceIdentity) || wvt.Nx ~= self.Nx || wvt.Ny ~= self.Ny || ~isequal(WVCompiledTransformBackend.sourceGeometry(wvt),self.geometryValues) || wvt.Nj ~= self.Nj || wvt.Nkl ~= self.Nkl
                error("WaveVortexModel:CompiledTransformMismatch","The evaluated transform does not match the compiled session configuration.")
            end
        end
    end

    methods (Static, Access=private)
        function values = sourceGeometry(wvt)
            if isa(wvt,"WVTransformBarotropicQG"), nz = 1; else, nz = wvt.Nz; end
            values = [wvt.Nx wvt.Ny nz wvt.Nj wvt.Nkl wvt.Lx wvt.Ly wvt.Lz wvt.g wvt.latitude wvt.rotationRate wvt.planetaryRadius double(wvt.shouldAntialias)];
        end

        function validateCapabilities(capabilities)
            if ~isstruct(capabilities) || ~isfield(capabilities,"isAvailable") || ~capabilities.isAvailable
                error("WaveVortexModel:CompiledTransformUnavailable","The compiled transform backend is unavailable. Build native support explicitly before creating a session.")
            end
            if ~isfield(capabilities,"module") || ~isfield(capabilities.module,"name") || strlength(string(capabilities.module.name)) == 0 || ...
                    ~isfield(capabilities.module,"identityValidated") || ~capabilities.module.identityValidated
                error("WaveVortexModel:CompiledTransformCapabilityMismatch","The installed compiled module does not have a validated identity.")
            end
            if ~isfield(capabilities.module,"matlabTransformBridgeVersion") || capabilities.module.matlabTransformBridgeVersion < 3
                error("WaveVortexModel:CompiledTransformCapabilityMismatch","The installed module predates the MATLAB transform operation bridge. Rebuild with WVCompiledBackend.build().")
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

        function [Ap,Am,A0] = stateArrays(wvt,Nj,Nkl)
            empty = complex(zeros(0,0));
            if ismember(string(class(wvt)),["WVTransformHydrostatic" "WVTransformBoussinesq"])
                Ap = complex(wvt.Ap); Am = complex(wvt.Am); A0 = complex(wvt.A0);
            else
                Ap = empty; Am = empty; A0 = complex(wvt.A0);
            end
            if ~isequal(size(A0),[Nj Nkl]) || (~isempty(Ap) && ~isequal(size(Ap),[Nj Nkl])) || (~isempty(Am) && ~isequal(size(Am),[Nj Nkl]))
                error("WaveVortexModel:CompiledTransformShape","The evaluated transform coefficient arrays do not match the compiled session shape.")
            end
        end
    end
end
