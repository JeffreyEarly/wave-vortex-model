classdef FreeSurfaceFieldOperation < WVOperation
    % Existing operation/cache protocol with selective Boussinesq outputs.
    properties (SetAccess=private)
        fieldNames
        component
    end
    methods
        function self = FreeSurfaceFieldOperation(name,annotations,names,component)
            self@WVOperation(name,annotations,@(wvt)[]);
            self.fieldNames = names;
            self.component = component;
        end
        function varargout = compute(self,wvt,varargin)
            fields = wvt.reconstructFields(self.fieldNames,flowComponent=self.component);
            varargout = cell(1,self.nVarOut);
            for index=1:self.nVarOut, varargout{index}=fields.(self.fieldNames(index)); end
        end
        function computeSelected(self,wvt,outputNames)
            names = string({self.outputVariables.name});
            [~,indices] = ismember(outputNames,names);
            fields = wvt.reconstructFields(self.fieldNames(indices),flowComponent=self.component);
            for index=1:numel(indices)
                wvt.addToVariableCache(outputNames(index),fields.(self.fieldNames(indices(index))));
            end
        end
    end
end
