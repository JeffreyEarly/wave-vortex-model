classdef ThermalNativeGridTransform < WVTransformFreeSurfaceQGDiffusion
    % Control with physical-grid vertical interpolation and projection.
    % Everything else, including batched modal products, is unchanged.
    methods
        function self=ThermalNativeGridTransform(varargin)
            self@WVTransformFreeSurfaceQGDiffusion(varargin{:});
        end
        function [qHat,bHat,speed]=dealiasedAdvectionFourierTendency(self,physical)
            [qHat,bHat,speed]=ThermalNativeGridTransform.advectionFourierReference(self,physical);
        end
    end
    methods (Static)
        function [qHat,bHat,speed]=advectionFourierReference(w,physical)
            [q,b,speed]=w.dealiasedAdvection(physical);
            qHat=w.spectralField(q); qHat=qHat(2:end-1,:);
            bHat=w.spectralField(b);
        end
    end
end
