classdef MockFastTransformAdapter < WVFastTransformDoublyPeriodic
    properties
        geometry
        Nz
    end

    methods
        function self = MockFastTransformAdapter(geometry,Nz,identifier)
            self.geometry = geometry;
            self.Nz = Nz;
            self.backendIdentifier = identifier;
            self.fourierStorageLayout = WVFourierStorageLayout(geometry,"full-complex");
        end

        function output = transformFromSpatialDomainWithFourier(~,input)
            output = input;
        end

        function output = transformToSpatialDomainWithFourier(~,input)
            output = input;
        end

        function output = diffX(~,input,~)
            output = input;
        end

        function output = diffY(~,input,~)
            output = input;
        end
    end
end
