classdef ThermalFailureForcing < WVForcing
    % Deliberately fail a trial stage to exercise accepted-state recovery.
    methods
        function self=ThermalFailureForcing(wvt)
            self@WVForcing(wvt,'stage failure',WVForcingType('QGSpatial'));
        end
        function [Fq,Fb]=addQuasigeostrophicSpatialForcing(~,wvt,Fq,Fb,~)
            if wvt.t>0
                error('ThermalFailureForcing:ExpectedFailure','Deliberate trial-stage failure.');
            end
        end
    end
end
