classdef WVFastTransformDoublyPeriodic < handle
    properties (SetAccess=protected)
        % Stable identifier for the active horizontal-transform backend.
        %
        % - Topic: Developer internals
        % - Developer: true
        backendIdentifier (1,1) string

        fourierStorageLayout
    end

    methods (Abstract)
        u_bar = transformFromSpatialDomainWithFourier(self,u)
        u = transformToSpatialDomainWithFourier(self,u_bar)
        du = diffX(wvg,u,options)
        du = diffY(wvg,u,options)
    end
end
