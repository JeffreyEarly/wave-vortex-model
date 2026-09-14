classdef ThermalStageBoundForcing < WVForcing
    % A state-dependent bound that becomes restrictive inside a trial step.
    properties
        initialMagnitude
        observed = zeros(0,3)
    end
    methods
        function self=ThermalStageBoundForcing(w)
            self@WVForcing(w,'manufactured stage bound',WVForcingType.QGSpectral);
            self.initialMagnitude=norm(w.Ath,'fro');
        end
        function tendency=addQuasigeostrophicSpectralForcing(~,w,tendency,~)
            tendency.Ath=tendency.Ath+w.Ath;
        end
        function rate=maximumExplicitDampingRate(self,~)
            magnitude=norm(self.wvt.Ath,'fro')/self.initialMagnitude;
            rate=1+99*(magnitude>1.2);
            self.observed(end+1,:)=[self.wvt.t,magnitude,rate];
        end
    end
end
