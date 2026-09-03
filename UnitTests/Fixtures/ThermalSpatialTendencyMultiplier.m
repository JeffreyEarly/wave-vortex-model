classdef ThermalSpatialTendencyMultiplier < WVForcing
    % Spatially varying multiplier detects prematurely truncated products.
    methods
        function self=ThermalSpatialTendencyMultiplier(w)
            self@WVForcing(w,'spatial tendency multiplier',WVForcingType('QGSpatial'));
            self.priority=255;
        end
        function [q,b]=addQuasigeostrophicSpatialForcing(~,w,q,b,~)
            factor=1+.5*cos(4*pi*w.X/w.Lx);
            q=factor.*q; b=factor(:,:,end).*b;
            q=q-mean(q,[1 2]); b=b-mean(b,'all');
        end
    end
end
