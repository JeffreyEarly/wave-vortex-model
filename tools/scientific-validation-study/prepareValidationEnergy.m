function evaluate=prepareValidationEnergy(w,Nxyz)
% Freeze modes and refine only quadrature of the physical energy inventory.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
    Nxyz (1,3) double
end
problem=IMInternalModes.geostrophicAPVModes(N2=w.N2Function,zDomain=[-w.Lz 0],g=w.g,g0=w.g0,gd=w.gd,surfaceBoundary="freeSurface");
solver=IMSolverSpectral(nEVP=Nxyz(3),coordinateKind="wkb").configuredForEVP(problem);
[z,q]=solver.nativeDifferentiationRule([-w.Lz 0]); q=q*w.Lz/sum(q);
geometry=WVGeometryDoublyPeriodic([w.Lx w.Ly],Nxyz(1:2),Nz=Nxyz(3),shouldAntialias=false,shouldExcludeNyquist=true,shouldExcludeConjugates=w.shouldExcludeConjugates,conjugateDimension=w.conjugateDimension);
keys=round([w.k(:)*w.Lx,w.l(:)*w.Ly]/(2*pi));
other=round([geometry.k(:)*w.Lx,geometry.l(:)*w.Ly]/(2*pi));
[found,indices]=ismember(keys,other,'rows'); assert(all(found));
x=-cos(pi*(0:w.Nz-1)'/(w.Nz-1)); y=-cos(pi*(0:Nxyz(3)-1)'/(Nxyz(3)-1));
b=(-1).^(0:w.Nz-1)'; b([1 end])=b([1 end])/2; M=zeros(Nxyz(3),w.Nz);
for j=1:Nxyz(3)
    [distance,k]=min(abs(y(j)-x));
    if distance<32*eps, M(j,k)=1; else, row=b./(y(j)-x); M(j,:)=row.'/sum(row); end
end
thermal=WVInternal.freeSurfaceThermodynamics(w); xi=reshape(z,1,1,[]); alpha=1+xi/w.Lz;
weights=reshape(q,1,1,[])/(Nxyz(1)*Nxyz(2));
evaluate=@energy;
    function value=energy(time,state)
        w.t=time; spectral=w.reconstructSpectralState(state=state); h=struct();
        for name=["u","v","w","eta"]
            field=zeros(Nxyz(3),numel(geometry.k)); field(:,indices)=M*spectral.(name);
            h.(name)=geometry.transformToSpatialDomainWithFourier(field);
        end
        field=zeros(Nxyz(3),numel(geometry.k)); field(:,indices)=repmat(spectral.ssh(end,:),Nxyz(3),1);
        surface=geometry.transformToSpatialDomainWithFourier(field); ssh=surface(:,:,end);
        gamma=1+ssh/w.Lz; u=h.u./gamma; v=h.v./gamma;
        vertical=h.w+alpha.*(u.*geometry.diffX(ssh)+v.*geometry.diffY(ssh));
        thermo=thermal.evaluate(xi+alpha.*ssh,h.eta,ssh);
        value=sum(weights.*gamma.*(.5*(u.^2+v.^2+vertical.^2)+thermo.ape),'all')+.5*w.g*mean(ssh.^2,'all');
    end
end
