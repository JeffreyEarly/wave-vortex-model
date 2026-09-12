classdef RHSSchedulingReference < WVTransformFreeSurfaceBoussinesq
    % Frozen fadb169d RHS/reconstruction; identical lazy private context owners.
    properties (Access=private)
        referenceContext = []
        referenceSurface = []
    end
    methods
        function self=RHSSchedulingReference(state)
            self@WVTransformFreeSurfaceBoussinesq(state);
        end
    end
    methods (Access=private)
        function context=thermodynamicContext(self)
            if isempty(self.referenceContext)
                self.referenceContext=WVInternal.freeSurfaceThermodynamics(self);
            end
            context=self.referenceContext;
        end
        function geometry=surfaceGeometry(self)
            if isempty(self.referenceSurface)
                self.referenceSurface=WVGeometryDoublyPeriodic([self.Lx self.Ly],[self.Nx self.Ny],Nz=1,shouldAntialias=self.shouldAntialias,shouldExcludeNyquist=self.shouldExcludeNyquist,shouldExcludeConjugates=self.shouldExcludeConjugates,conjugateDimension=self.conjugateDimension);
            end
            geometry=self.referenceSurface;
        end
    end
end
