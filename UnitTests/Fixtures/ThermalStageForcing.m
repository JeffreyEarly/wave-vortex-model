classdef ThermalStageForcing < WVForcing
    % Manufactured coefficient dynamics and deliberate stage failure.
    properties
        rate = 1
        failureTime = Inf
    end
    methods
        function self=ThermalStageForcing(w,isClosure)
            self@WVForcing(w,'manufactured thermal tendency',WVForcingType('QGSpectral'));
            if nargin>1, self.isClosure=isClosure; end
        end
        function tendency=addQuasigeostrophicSpectralForcing(self,w,tendency,~)
            if w.t>self.failureTime, error('ThermalStageForcing:Failure','Deliberate stage failure.'); end
            tendency.Ath=tendency.Ath+self.rate*w.Ath;
        end
    end
end
