classdef ThermalCustomDamping < WVAdaptiveDamping
    % Confirm the thermal fast path does not bypass subclass overrides.
    methods
        function self=ThermalCustomDamping(w)
            self@WVAdaptiveDamping(w,verticalDampingStrength=1);
        end
        function tendency=addQuasigeostrophicSpectralForcing(self,w,tendency,physical)
            tendency=addQuasigeostrophicSpectralForcing@WVAdaptiveDamping(self,w,tendency,physical);
            tendency.Ag_T=2*tendency.Ag_T;
        end
    end
end
