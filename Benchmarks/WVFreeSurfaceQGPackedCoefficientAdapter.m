classdef WVFreeSurfaceQGPackedCoefficientAdapter < WVCoefficients
    % Authoring-only packed integrator adapter for free-surface QG benchmarks.

    properties (Access=private)
        familyNames (1,:) string = strings(1,0)
        familyShapes (1,:) cell = cell(1,0)
        familyCounts (1,:) double = zeros(1,0)
        familyOffsets (1,:) double = zeros(1,0)
    end

    methods
        function self = WVFreeSurfaceQGPackedCoefficientAdapter(model,options)
            arguments
                model (1,1) WVModel
                options.absTolerance = 1e-6
            end

            self@WVCoefficients(model,absTolerance=options.absTolerance);
            annotations = self.wvt.coefficientStateAnnotations();
            self.familyNames = string({annotations.name});
            if ~isequal(self.familyNames,["Ag_q" "Ag_0" "Amda"])
                error('WaveVortexBenchmark:PackedAdapterTransform', ...
                    'The packed coefficient adapter requires the free-surface QG family order Ag_q, Ag_0, Amda.');
            end
            self.familyShapes = arrayfun(@(annotation)size(self.wvt.(annotation.name)),annotations,UniformOutput=false);
            self.familyCounts = cellfun(@prod,self.familyShapes);
            self.familyOffsets = [0 cumsum(self.familyCounts(1:end-1))];
            self.nFluxComponents = 1;
        end

        function nArray = lengthOfFluxComponents(self)
            nArray = sum(self.familyCounts);
        end

        function Y0 = absErrorTolerance(self)
            tolerances = self.wvt.coefficientAbsoluteTolerances(self.absTolerance);
            values = cell(1,length(self.familyNames));
            for iFamily = 1:length(self.familyNames)
                values{iFamily} = tolerances.(self.familyNames(iFamily));
            end
            Y0 = {self.packCanonicalState(values)};
        end

        function Y0 = initialConditions(self)
            values = cell(1,length(self.familyNames));
            for iFamily = 1:length(self.familyNames)
                values{iFamily} = self.wvt.(self.familyNames(iFamily));
            end
            Y0 = {self.packCanonicalState(values)};
        end

        function nlF = fluxAtTime(self,t,y0)
            self.updateIntegratorValues(t,y0);
            tendency = self.wvt.coefficientTendency();
            values = cell(1,length(self.familyNames));
            for iFamily = 1:length(self.familyNames)
                values{iFamily} = tendency.(self.familyNames(iFamily));
            end
            nlF = {self.packCanonicalState(values)};
        end

        function updateIntegratorValues(self,t,y0)
            self.wvt.t = t;
            values = self.canonicalStateFromIntegratorState(y0);
            for iFamily = 1:length(self.familyNames)
                self.wvt.(self.familyNames(iFamily)) = values{iFamily};
            end
        end

        function values = canonicalStateFromIntegratorState(self,y0)
            arguments
                self (1,1) WVFreeSurfaceQGPackedCoefficientAdapter
                y0 (1,1) cell
            end
            packed = y0{1};
            if numel(packed) ~= sum(self.familyCounts)
                error('WaveVortexBenchmark:PackedAdapterStateSize', ...
                    'The packed coefficient state has %d elements; expected %d.',numel(packed),sum(self.familyCounts));
            end
            values = cell(length(self.familyNames),1);
            for iFamily = 1:length(self.familyNames)
                indices = self.familyOffsets(iFamily)+(1:self.familyCounts(iFamily));
                values{iFamily} = reshape(packed(indices),self.familyShapes{iFamily});
            end
        end

        function packed = packCanonicalState(self,values)
            arguments
                self (1,1) WVFreeSurfaceQGPackedCoefficientAdapter
                values cell
            end
            if numel(values) ~= length(self.familyNames)
                error('WaveVortexBenchmark:PackedAdapterFamilyCount', ...
                    'The canonical state has %d families; expected %d.',numel(values),length(self.familyNames));
            end
            packed = complex(zeros(sum(self.familyCounts),1));
            for iFamily = 1:length(self.familyNames)
                value = values{iFamily};
                if numel(value) ~= self.familyCounts(iFamily)
                    error('WaveVortexBenchmark:PackedAdapterFamilySize', ...
                        'Family %s has %d elements; expected %d.',self.familyNames(iFamily),numel(value),self.familyCounts(iFamily));
                end
                indices = self.familyOffsets(iFamily)+(1:self.familyCounts(iFamily));
                packed(indices) = value(:);
            end
        end
    end
end
