classdef RHSReuseReference < WVTransformFreeSurfaceBoussinesq
    % Authoring baseline: retain the pre-484 nonlinear reconstruction schedule.
    properties (Access=private)
        referenceThermodynamics = []
    end
    methods
        function self=RHSReuseReference(state)
            self@WVTransformFreeSurfaceBoussinesq(state);
        end
        function rate=projectSources(self,sources)
            rate=fullBoussinesqProjectionReference(self,sources);
        end
        function [u,v,w,eta]=nonlinearAdvectionSources(self)
            if isempty(self.referenceThermodynamics)
                self.referenceThermodynamics=WVInternal.freeSurfaceThermodynamics(self);
            end
            [u,v,w,eta]=fullBoussinesqNonlinearReference(self,self.referenceThermodynamics);
        end
    end
end
