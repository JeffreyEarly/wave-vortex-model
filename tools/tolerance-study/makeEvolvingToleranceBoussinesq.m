function [wvt,scale] = makeEvolvingToleranceBoussinesq(options)
% Elliptical surface vortex plus nonparallel APV, with a fixed wave template.
arguments (Input)
    options.gridSize (1,3) double = [32 32 65]
    options.activeBoundary (1,1) string {mustBeMember(options.activeBoundary,["surface","bottom"])} = "surface"
end
L=1e4;
if options.activeBoundary=="surface", g0=-.1; gd=Inf; else, g0=Inf; gd=.1; end
wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([8*L 8*L 1000],options.gridSize,N2Function=@(z)1e-4+0*z,g0=g0,gd=gd,apvModeCount=4,mdaModeCount=2,inertialModeCount=2,waveModeCount=4,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
empty=wvt.coefficientState();
[X,Y]=ndgrid(wvt.x-4*L,wvt.y-4*L);
b=zeros(size(X));
for ix=-1:1
    for iy=-1:1
        b=b+exp(-((X+ix*wvt.Lx)/L).^2-((Y+iy*wvt.Ly)/(L/2)).^2);
    end
end
b=b-mean(b,'all');
field=zeros(wvt.spatialMatrixSize); field(:,:,1)=b;
bhat=wvt.transformFromSpatialDomainWithFourier(field);
unit=empty; unit.Ag_0(:)=1;
f=wvt.reconstructSpectralState(state=unit);
state=empty;
if options.activeBoundary=="surface"
    response=f.eta(end,wvt.klNonzero)-f.ssh(end,wvt.klNonzero);
else
    response=f.eta(1,wvt.klNonzero);
end
state.Ag_0=bhat(1,wvt.klNonzero)./response;
setState(wvt,state);
f=wvt.reconstructFields(["u","v"]);
U=.05*abs(wvt.f)*L;
state.Ag_0=state.Ag_0*U/max(hypot(f.u,f.v),[],'all');
setState(wvt,state); boundaryKE=kineticEnergy(wvt);
unit=empty;
column=find(round(wvt.kNonzero*wvt.Lx/(2*pi))==1 & round(wvt.lNonzero*wvt.Ly/(2*pi))==2,1);
unit.Ag_q(1,column)=exp(.83i);
setState(wvt,unit); state.Ag_q=unit.Ag_q*sqrt(boundaryKE/kineticEnergy(wvt));
setState(wvt,state); balancedKE=kineticEnergy(wvt);
% A smooth two-direction wave template with comparable initial horizontal KE.
unit=empty;
xColumn=find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
yColumn=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
unit.Aw_p(1,xColumn)=exp(.37i); unit.Aw_p(1,yColumn)=.3*exp(.41i);
unit.Aw_m=.2*exp(.63i)*unit.Aw_p;
setState(wvt,unit); multiplier=sqrt(balancedKE/kineticEnergy(wvt));
state.Aw_p=multiplier*unit.Aw_p; state.Aw_m=multiplier*unit.Aw_m;
setState(wvt,state);
f=wvt.reconstructFields(["eta","ssh"]);
margin=2*max(abs(f.eta),[],'all')+2*max(abs(f.ssh),[],'all')+1;
if options.activeBoundary=="surface"
    state.Amda(1)=margin/wvt.mdaG(end,1);
else
    state.Amda(1)=-margin/wvt.mdaG(1,1);
end
fprintf('Fixed surface mean displacement: %.6g m\n',margin);
setState(wvt,state);
wvt.addForcing(WVNonlinearAdvection(wvt));
scale=struct(radius=L,speed=U,time=L/U,rossbyNumber=.05,boundaryKE=boundaryKE,balancedKE=balancedKE);
end

function value=kineticEnergy(wvt)
f=wvt.reconstructSpectralState();
value=sum(wvt.verticalQuadratureWeights.*(abs(f.u).^2+abs(f.v).^2),'all');
end

function setState(wvt,state)
for name=string(fieldnames(state)).', wvt.(name)=state.(name); end
end
