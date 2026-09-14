classdef ThermalReconstructionCounter < WVTransformFreeSurfaceThermalQG
    % Count volume and nonlinear reconstruction requests in one RHS.
    properties
        nativeCalls = 0
        nativeSpeedMultiplier = 1
        nonlinearCalls = 0
    end
    methods
        function self=ThermalReconstructionCounter(state)
            self@WVTransformFreeSurfaceThermalQG(scientificState=state);
        end
        function [q,u,v,b,ub,vb,phiHat]=quasigeostrophicSpatialState(self)
            self.nativeCalls=self.nativeCalls+1;
            [q,u,v,b,ub,vb,phiHat]=quasigeostrophicSpatialState@WVTransformFreeSurfaceThermalQG(self);
            u=self.nativeSpeedMultiplier*u; v=self.nativeSpeedMultiplier*v;
        end
        function [tendency,speed,diagnostics]=nonlinearCoefficientTendency(self)
            self.nonlinearCalls=self.nonlinearCalls+1;
            [tendency,speed,diagnostics]=nonlinearCoefficientTendency@WVTransformFreeSurfaceThermalQG(self);
        end
    end
end
