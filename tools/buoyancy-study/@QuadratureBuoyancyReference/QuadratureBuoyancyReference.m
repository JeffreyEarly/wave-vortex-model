classdef QuadratureBuoyancyReference < WVTransformFreeSurfaceBoussinesq
    properties (Access=private)
        quadratureContext = []
    end
    methods
        function self=QuadratureBuoyancyReference(state)
            self@WVTransformFreeSurfaceBoussinesq(state);
        end
        function [u,v,w,eta]=nonlinearAdvectionSources(self)
            if isempty(self.quadratureContext)
                self.quadratureContext=quadratureThermodynamicsReference(self);
            end
            [u,v,w,eta]=quadratureNonlinearSources(self,self.quadratureContext);
        end
    end
end
