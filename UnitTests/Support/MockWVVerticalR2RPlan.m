classdef MockWVVerticalR2RPlan < handle
    properties (SetAccess=private)
        realSize (1,2) double
        transformType (1,1) string
        dataType (1,1) string
        forwardCallCount (1,1) double = 0
        inverseCallCount (1,1) double = 0
    end

    properties
        failForward (1,1) logical = false
        failInverse (1,1) logical = false
    end

    properties (Access=private)
        owner
        deletionRecorded (1,1) logical = false
    end

    methods
        function self = MockWVVerticalR2RPlan(sz,transformType,dataType,owner)
            self.realSize = sz;
            self.transformType = transformType;
            self.dataType = dataType;
            self.owner = owner;
        end

        function coefficients = transformForward(self,values)
            self.forwardCallCount = self.forwardCallCount+1;
            if self.failForward
                error("WaveVortexModel:InjectedVerticalForwardFailure","Injected vertical forward failure.");
            end
            if self.transformType == "cosine"
                matrix = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformForwardMatrix(self.realSize(1));
            else
                matrix = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformForwardMatrix(self.realSize(1));
            end
            coefficients = matrix*values;
        end

        function values = transformBack(self,coefficients)
            self.inverseCallCount = self.inverseCallCount+1;
            if self.failInverse
                error("WaveVortexModel:InjectedVerticalInverseFailure","Injected vertical inverse failure.");
            end
            if self.transformType == "cosine"
                matrix = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformBackMatrix(self.realSize(1));
            else
                matrix = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformBackMatrix(self.realSize(1));
            end
            values = matrix*coefficients;
            if self.transformType == "sine"
                values([1 end],:) = 0;
            end
        end

        function delete(self)
            if self.deletionRecorded
                return
            end
            self.deletionRecorded = true;
            if ~isempty(self.owner) && isvalid(self.owner)
                self.owner.notePlanDeletion();
            end
        end
    end
end
