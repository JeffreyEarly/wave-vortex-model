classdef ThermalInvariantQualificationDamping < WVAdaptiveDamping
    % Supply the horizontal-only control for the #535 authoring comparison.
    %
    % This tools-only subclass removes the selective contribution and its
    % bound. Production users construct WVAdaptiveDamping through its factory.
    % - Topic: Developer utilities
    methods
        function self = ThermalInvariantQualificationDamping(w,state)
            self@WVAdaptiveDamping(w,thermalGeneralizedEnstrophyState=state);
        end
        function [horizontal,selective] = quasigeostrophicDampingContributions(self,w,physical)
            arguments
                self
                w
                physical = struct()
            end
            [horizontal,selective]=quasigeostrophicDampingContributions@WVAdaptiveDamping(self,w,physical);
            selective.Ath(:)=0;
        end
        function value = maximumExplicitDampingRate(self,physical)
            arguments
                self
                physical = struct()
            end
            if isstruct(physical) && isfield(physical,'uvMax')
                speed=physical.uvMax;
            else
                speed=self.wvt.uvMax;
            end
            data=self.coefficientDampingData();
            value=speed*max(abs(data.horizontalRates));
        end
    end
end
