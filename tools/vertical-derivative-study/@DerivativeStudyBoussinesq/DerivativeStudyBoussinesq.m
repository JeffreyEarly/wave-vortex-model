classdef DerivativeStudyBoussinesq < WVTransformFreeSurfaceBoussinesq
    % Authoring-only backend switch to time the unchanged complete RHS.
    properties
        useFFT (1,1) logical = false
    end
    properties (SetAccess=private)
        derivativeMetric
    end
    methods
        function self = DerivativeStudyBoussinesq(state)
            self@WVTransformFreeSurfaceBoussinesq(state);
            % x is linear in the native WKB coordinate. Recover dx/dxi
            % from the persisted rule; no provider or new state is needed.
            x = -cos(pi*(0:self.Nz-1)'/(self.Nz-1));
            self.derivativeMetric = self.verticalDerivativeMatrix*x;
        end
        function du = diffZ(self,u,options)
            arguments
                self DerivativeStudyBoussinesq
                u double
                options.n (1,1) double {mustBeMember(options.n,1:4)} = 1
            end
            if self.useFFT
                assert(isequal(size(u),[self.Nx,self.Ny,self.Nz]));
                du = fftWKBDerivative(u,self.derivativeMetric,options.n);
            else
                du = diffZ@WVTransformFreeSurfaceBoussinesq(self,u,n=options.n);
            end
        end
    end
end
