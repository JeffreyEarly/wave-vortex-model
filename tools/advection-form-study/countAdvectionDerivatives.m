function countAdvectionDerivatives
% Count source-kernel calls in distinct volume and surface derivative units.
w=makeAdvectionStudyTransform("constant",[8 33 3 4 2 3]);
seed=manuscriptEvolutionOperators(w,"constant",padding=1); state=seed.seed("mixed",.1);
base=advectionStudyOperators(w,"constant","divergence"); base.rhs(327,state);
f=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
h=struct(u=f.u_hat,v=f.v_hat,w=f.w_hat,eta=f.eta,p=f.p,ssh=f.ssh);
context=WVInternal.freeSurfaceThermodynamics(w); xi=reshape(w.z,1,1,[]);
t=context.evaluateNonlinear(xi+(1+xi/w.Lz).*h.ssh,h.eta,h.ssh,w.N2);
weights=w.verticalQuadratureWeights(:); B=zeros(w.Nz); B(1,1)=-1; B(end,end)=1;
adj=(B-w.verticalDerivativeMatrix'.*weights')./weights;
rows=struct([]); counts=zeros(2,4);
D=struct(x=@(a)derivative(a,1),y=@(a)derivative(a,2),xi=@(a)derivative(a,3),adjointXi=@(a)derivative(a,4));
for form=["divergence","advective","split","compatible"]
    counts(:)=0;
    advectionFormTerms(h,h.p,w.z,w.Lz,w.f,w.rho0,w.N2,t.buoyancyRemainder,D,form);
    row=struct(form=form,volumeX=counts(1,1),volumeY=counts(1,2),volumeXi=counts(1,3),volumeAdjointXi=counts(1,4),surfaceX=counts(2,1),surfaceY=counts(2,2));
    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
end
writetable(struct2table(rows),fullfile(fileparts(mfilename('fullpath')),'results','derivative-counts.csv'));
    function out=derivative(a,direction)
        level=1+(size(a,3)==1); counts(level,direction)=counts(level,direction)+1;
        switch direction
            case 1, out=w.diffX(a);
            case 2, out=w.diffY(a);
            case 3, out=w.diffZ(a);
            case 4, out=reshape(reshape(a,[],w.Nz)*adj.',size(a));
        end
    end
end
