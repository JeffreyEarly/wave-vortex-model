classdef ThermalTendencyMultiplier < WVForcing
    % Nonadditive callback detects changes in spectral forcing order.
    methods
        function self=ThermalTendencyMultiplier(w,priority)
            self@WVForcing(w,'tendency multiplier',WVForcingType('QGSpectral'));
            self.priority=priority;
        end
        function tendency=addQuasigeostrophicSpectralForcing(~,~,tendency,~)
            tendency.Ag_T=2*tendency.Ag_T;
        end
    end
end
