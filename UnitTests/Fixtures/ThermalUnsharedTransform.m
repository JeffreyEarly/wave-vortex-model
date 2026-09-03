classdef ThermalUnsharedTransform < WVTransformFreeSurfaceQGDiffusion
    % Same persisted representation, original RHS for short benchmark runs.
    methods
        function self=ThermalUnsharedTransform(varargin)
            self@WVTransformFreeSurfaceQGDiffusion(varargin{:});
        end
        function [tendency,speed]=nonthermalCoefficientTendency(self,excludeSeasonal)
            if nargin<2, excludeSeasonal=false; end
            [tendency,speed]=thermalQGUnsharedTendency(self,excludeSeasonal);
        end
        function [q,b]=transformStateBack(self,a)
            [q,b]=ThermalUnsharedTransform.stateBack(self,a);
        end
        function a=transformStateForward(self,q,b)
            a=ThermalUnsharedTransform.stateForward(self,q,b);
        end
        function [phi,eta,q,b]=reconstructSpectralState(self,a)
            if nargin<2, a=self.Ag_T; end
            [phi,eta,q,b]=ThermalUnsharedTransform.reconstruct(self,a);
        end
    end
    methods (Static)
        function [q,b]=stateBack(w,a)
            state=ThermalUnsharedTransform.multiply(w,w.scaledStateFromModes,a);
            scale=[(w.Lz/abs(w.f))*sqrt(w.verticalQuadratureWeights(2:end-1)/w.Lz);1];
            state=state./scale; q=state(1:end-1,:); b=state(end,:);
        end
        function a=stateForward(w,q,b)
            scale=[(w.Lz/abs(w.f))*sqrt(w.verticalQuadratureWeights(2:end-1)/w.Lz);1];
            a=ThermalUnsharedTransform.multiply(w,w.modesFromScaledState,scale.*[q;b]);
        end
        function [phi,eta,q,b]=reconstruct(w,a)
            phi=complex(zeros(w.Nz,length(w.klNonzero))); eta=phi; q=phi;
            for ip=1:length(w.khUnique)
                entries=find(w.klNonzeroKhUniqueIndex==ip); page=a(:,entries);
                phi(:,entries)=w.phiModes(:,:,ip)*page;
                eta(:,entries)=w.etaModes(:,:,ip)*page;
                q(:,entries)=w.qModes(:,:,ip)*page;
            end
            [~,b]=ThermalUnsharedTransform.stateBack(w,a);
        end
        function result=multiply(w,matrices,a)
            result=complex(zeros(size(matrices,1),size(a,2)));
            for ip=1:length(w.khUnique)
                entries=find(w.klNonzeroKhUniqueIndex==ip);
                result(:,entries)=matrices(:,:,ip)*a(:,entries);
            end
        end
    end
end
