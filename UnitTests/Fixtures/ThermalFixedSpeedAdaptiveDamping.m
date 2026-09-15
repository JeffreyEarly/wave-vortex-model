classdef ThermalFixedSpeedAdaptiveDamping < WVAdaptiveDamping
    % Test-only closure with a prescribed stage speed for exponential decay.
    properties
        fixedSpeed (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 0
    end

    methods
        function self = ThermalFixedSpeedAdaptiveDamping(wvt,options)
            arguments
                wvt (1,1) WVTransformFreeSurfaceThermalQG
                options.fixedSpeed (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.generalizedEnstrophyCutoffFraction (1,1) double = NaN
                options.thermalGeneralizedEnstrophyState (1,1) WVInternal.ThermalGeneralizedEnstrophyState
            end
            self@WVAdaptiveDamping(wvt,generalizedEnstrophyCutoffFraction=options.generalizedEnstrophyCutoffFraction,thermalGeneralizedEnstrophyState=options.thermalGeneralizedEnstrophyState);
            self.fixedSpeed = options.fixedSpeed;
        end

        function [horizontal,selective] = quasigeostrophicDampingContributions(self,wvt,~)
            [horizontal,selective] = quasigeostrophicDampingContributions@WVAdaptiveDamping(self,wvt,struct(uvMax=self.fixedSpeed));
        end

        function rate = maximumExplicitDampingRate(self,~)
            rate = maximumExplicitDampingRate@WVAdaptiveDamping(self,struct(uvMax=self.fixedSpeed));
        end
    end
end
