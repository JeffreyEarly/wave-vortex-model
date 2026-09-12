function op=advectionStudyOperators(w,profile,form)
% Authoring RHS variants with the same production reconstruction and projection.
base=thermodynamicComparisonOperators(w,profile,"displacement");
op=base; op.rhs=@rhs;
context=WVInternal.freeSurfaceThermodynamics(w);
xi=reshape(w.z,1,1,[]); alpha=1+xi/w.Lz;
weights=w.verticalQuadratureWeights(:); boundary=zeros(w.Nz); boundary(1,1)=-1; boundary(end,end)=1;
adjoint=(boundary-w.verticalDerivativeMatrix.'.*weights.')./weights;
derivative=struct(x=@(a)w.diffX(a),y=@(a)w.diffY(a),xi=@(a)w.diffZ(a), ...
    adjointXi=@(a)reshape(reshape(a,[],w.Nz)*adjoint.',size(a)));
    function [rate,source,terms]=rhs(time,state)
        w.t=time;
        for family=string(fieldnames(state)).', w.(family)=state.(family); end
        f=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
        h=struct(u=f.u_hat,v=f.v_hat,w=f.w_hat,eta=f.eta,p=f.p,ssh=f.ssh);
        thermal=context.evaluateNonlinear(xi+alpha.*h.ssh,h.eta,h.ssh,w.N2);
        terms=advectionFormTerms(h,h.p,w.z,w.Lz,w.f,w.rho0,w.N2,thermal.buoyancyRemainder,derivative,form);
        source=terms.source; rate=w.projectSources(source);
    end
end
