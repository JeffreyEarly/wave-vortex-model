classdef WVCountingFreeSurfaceQG < WVTransformFreeSurfaceQG
    properties
        reconstructionCount = 0
    end
    methods
        function self = WVCountingFreeSurfaceQG(varargin)
            self@WVTransformFreeSurfaceQG(varargin{:});
        end
        function varargout = reconstructSpectralState(self,varargin)
            self.reconstructionCount = self.reconstructionCount+1;
            [varargout{1:nargout}] = reconstructSpectralState@WVTransformFreeSurfaceQG(self,varargin{:});
        end
    end
end
