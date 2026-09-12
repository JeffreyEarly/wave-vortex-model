classdef RHSSchedulingCandidate < RHSSchedulingReference
    % Authoring candidates; the existing field cache remains the sole owner.
    properties
        strategy (1,1) string = "baseline"
    end
    properties (Access=private)
        studyDerivative
        studyXi
        studyAlpha
        studyContext
        studySurface
    end
    methods
        function self=RHSSchedulingCandidate(state,strategy)
            self@RHSSchedulingReference(state);
            self.strategy=strategy;
            self.studyContext=WVInternal.freeSurfaceThermodynamics(self);
            self.studySurface=WVGeometryDoublyPeriodic([self.Lx self.Ly],[self.Nx self.Ny],Nz=1,shouldAntialias=self.shouldAntialias,shouldExcludeNyquist=self.shouldExcludeNyquist,shouldExcludeConjugates=self.shouldExcludeConjugates,conjugateDimension=self.conjugateDimension);
            self.studyXi=reshape(self.z,1,1,[]); self.studyAlpha=1+self.studyXi/self.Lz;
            self.studyDerivative=struct(x=@(a)self.diffX(a),y=@(a)self.diffY(a),xi=@(a)self.diffZ(a));
        end
        function geometry=studySurfaceGeometry(self)
            geometry=self.studySurface;
        end
        function [u,v,w,eta]=nonlinearAdvectionSources(self)
            if self.strategy=="baseline"
                [u,v,w,eta]=nonlinearAdvectionSources@RHSSchedulingReference(self);
                return
            end
            [fields,gradient]=self.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
            pressure=0; if isfield(fields,'p'), pressure=fields.p; end
            h=struct(u=fields.u_hat,v=fields.v_hat,w=fields.w_hat,eta=fields.eta,p=pressure,ssh=fields.ssh);
            if any(self.strategy==["setup","combined"])
                z=self.studyXi+self.studyAlpha.*h.ssh; derivative=self.studyDerivative;
            else
                z=reshape(self.z,1,1,[])+reshape(1+self.z/self.Lz,1,1,[]).*h.ssh;
                derivative=struct(x=@(a)self.diffX(a),y=@(a)self.diffY(a),xi=@(a)self.diffZ(a));
            end
            context=self.studyContext; thermal=context.evaluateNonlinear(z,h.eta,h.ssh,self.N2);
            terms=schedulingNonlinearTerms(h,pressure,self.z,self.Lz,self.f,self.rho0,self.N2,thermal.buoyancyRemainder,derivative,gradient,any(self.strategy==["source","combined","stateSource"]));
            u=terms.source.u; v=terms.source.v; w=terms.source.w; eta=terms.source.eta;
        end
    end
end
