classdef ThermalProcessForcing < WVForcing
    % Exercise accumulation semantics and invalid external callback output.
    properties
        multiplier = 2
        invalidFamily = false
        lastSpeed = NaN
    end
    methods
        function self=ThermalProcessForcing(w,priority,name)
            if nargin<3, name='ordered process fixture'; end
            self@WVForcing(w,name,WVForcingType.QGSpectral);
            if nargin<2, priority=255; end
            self.priority=priority;
        end
        function tendency=addQuasigeostrophicSpectralForcing(self,~,tendency,physical)
            assert(~isfield(physical,'thermalNonlinearTendency'));
            self.lastSpeed=physical.uvMax;
            tendency.Ath=self.multiplier*tendency.Ath;
            if self.invalidFamily, tendency.Ag_q=0; end
        end
    end
end
