classdef ThermalReadinessInventoryObserver < WVObservingSystem
    % Record shared physical inventories for an authoring workload measurement.
    % All scientific calculations use the transform's quadraticDiagnostics.
    % This passive observer is excluded from the exported runtime package.
    % - Topic: Developer utilities
    methods
        function self = ThermalReadinessInventoryObserver(model)
            arguments (Input)
                model (1,1) WVModel
            end
            self@WVObservingSystem(model,"thermal readiness inventories");
        end

        function initializeStorage(~,group)
            names = ["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"];
            units = ["m3 s-2","m s-2","m2","m2"];
            for j = 1:numel(names)
                if ~group.hasVariableWithName(names(j))
                    group.addVariable(names(j),{'t'},type="double",isComplex=false,attributes=containers.Map({'units','long_name'},{char(units(j)),char(names(j))}));
                end
            end
        end

        function writeTimeStepToFile(self,group,index)
            inventory = self.model.wvt.quadraticDiagnostics();
            for name = ["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
                group.variableWithName(name).setValueAlongDimensionAtIndex(inventory.(name),'t',index);
            end
        end
    end
    methods (Static)
        function names = classRequiredPropertyNames()
            names = {};
        end

        function annotations = classDefinedPropertyAnnotations()
            annotations = CAPropertyAnnotation.empty(0,0);
        end
    end
end
