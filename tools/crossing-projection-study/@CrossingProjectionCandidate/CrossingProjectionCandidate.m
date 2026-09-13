classdef CrossingProjectionCandidate < WVTransformFreeSurfaceBoussinesq
    % Authoring-only complete-callback benchmark of equivalent source loads.
    % The overridden source is a quadrature load, not a physical field.
    properties (Access=private)
        crossing
        thermodynamics
    end
    methods
        function self=CrossingProjectionCandidate(state)
            self@WVTransformFreeSurfaceBoussinesq(state);
            self.thermodynamics=WVInternal.freeSurfaceThermodynamics(self);
            self.crossing=WVInternal.prepareBuoyancyCrossingProjection(self.N2Function,self.z,self.verticalQuadratureWeights,self.Lz,8);
        end
        function [u,v,w,eta]=nonlinearAdvectionSources(self)
            fields=self.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
            h=struct(u=fields.u_hat,v=fields.v_hat,w=fields.w_hat,eta=fields.eta,p=fields.p,ssh=fields.ssh);
            z=reshape(self.z,1,1,[])+reshape(1+self.z/self.Lz,1,1,[]).*h.ssh;
            thermal=self.thermodynamics.evaluateCrossingSplit(z,h.eta,h.ssh,self.N2);
            derivative=struct(x=@(a)self.diffX(a),y=@(a)self.diffY(a),xi=@(a)self.diffZ(a));
            terms=WVInternal.freeSurfaceNonlinearTerms(h,h.p,self.z,self.Lz,self.f,self.rho0,self.N2,thermal.smoothBuoyancyRemainder,derivative,includeDiagnostics=false);
            load=self.crossing.load(h.ssh);
            u=terms.source.u; v=terms.source.v; w=terms.source.w+load; eta=terms.source.eta;
        end
    end
end
