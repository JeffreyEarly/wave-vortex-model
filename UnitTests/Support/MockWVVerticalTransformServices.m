classdef MockWVVerticalTransformServices < handle
    properties
        capabilities (1,1) struct = struct()
        queryException = []
        planException = []
        failForward (1,1) logical = false
        failInverse (1,1) logical = false
        queryCount (1,1) double = 0
        planConstructionCount (1,1) double = 0
        planDeletionCount (1,1) double = 0
        constructedPlans cell = {}
    end

    methods
        function self = MockWVVerticalTransformServices(capabilities)
            if nargin > 0
                self.capabilities = capabilities;
            end
        end

        function services = serviceRecord(self)
            services = struct( ...
                "queryCapabilities",@()self.queryCapabilities(), ...
                "constructPlan",@(sz,transformType,dataType)self.constructPlan(sz,transformType,dataType));
        end

        function capabilities = queryCapabilities(self)
            self.queryCount = self.queryCount+1;
            if ~isempty(self.queryException)
                throw(self.queryException);
            end
            capabilities = self.capabilities;
        end

        function plan = constructPlan(self,sz,transformType,dataType)
            self.planConstructionCount = self.planConstructionCount+1;
            if ~isempty(self.planException)
                throw(self.planException);
            end
            plan = MockWVVerticalR2RPlan(sz,transformType,dataType,self);
            plan.failForward = self.failForward;
            plan.failInverse = self.failInverse;
            self.constructedPlans{end+1} = plan;
        end

        function notePlanDeletion(self)
            self.planDeletionCount = self.planDeletionCount+1;
        end
    end
end
