classdef MockWVBackendServices < handle
    properties
        installed (1,1) logical = true
        capabilityResults cell = {struct()}
        buildResult = struct("build",struct("succeeded",false))
        queryException = MException.empty
        buildException = MException.empty
        shouldFailFFTWConstruction (1,1) logical = false
        queryCount (1,1) double = 0
        buildCount (1,1) double = 0
    end

    methods
        function self = MockWVBackendServices(results)
            if nargin == 0
                return
            end
            if iscell(results)
                self.capabilityResults = results;
            else
                self.capabilityResults = {results};
            end
        end

        function services = functionHandles(self)
            services = struct( ...
                "isFFTWTransformsInstalled",@()self.installed, ...
                "queryCapabilities",@()self.queryCapabilities(), ...
                "buildBackend",@()self.buildBackend(), ...
                "constructBuiltin",@(geometry,Nz)WVFastTransformDoublyPeriodicMatlab(geometry,Nz), ...
                "constructFFTW",@(geometry,Nz)self.constructFFTW(geometry,Nz));
        end
    end

    methods (Access=private)
        function capabilities = queryCapabilities(self)
            self.queryCount = self.queryCount + 1;
            if ~isempty(self.queryException)
                throw(self.queryException);
            end
            index = min(self.queryCount,numel(self.capabilityResults));
            capabilities = self.capabilityResults{index};
        end

        function capabilities = buildBackend(self)
            self.buildCount = self.buildCount + 1;
            if ~isempty(self.buildException)
                throw(self.buildException);
            end
            capabilities = self.buildResult;
        end

        function adapter = constructFFTW(self,geometry,Nz)
            if self.shouldFailFFTWConstruction
                error("MockWVBackendServices:ConstructionFailed","injected adapter construction failure");
            end
            adapter = MockFastTransformAdapter(geometry,Nz,"fftw");
        end
    end
end
