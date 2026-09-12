function op=thermodynamicComparisonOperators(w,profile,variant)
% Complete authoring RHS, physical diagnostics, and common-grid observations.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    variant (1,1) string {mustBeMember(variant,["displacement","density","equivalent"])}
end
context=WVInternal.freeSurfaceThermodynamics(w);
xi=reshape(w.z,1,1,[]); alpha=1+xi/w.Lz;
if profile=="constant", lambda=0; else, lambda=1/650; end
weights=reshape(w.verticalQuadratureWeights,1,1,[])/(w.Nx*w.Ny);
D=struct(x=@(f)w.diffX(f),y=@(f)w.diffY(f),xi=@(f)w.diffZ(f));
% All variants use the generic #482 represented-profile evaluator.
op=struct(rhs=@rhs,observe=@observe,fields=@fields,checkpoint=@checkpoint);

    function [rate,source]=rhs(time,state)
        source=struct();
        if variant=="equivalent"
            original=invertThermodynamicCoefficientMap(w,profile,state,time);
            assign(time,original);
            [source.u,source.v,source.w,source.eta]=w.nonlinearAdvectionSources();
            native=w.projectSources(source);
            [~,rate]=thermodynamicCoefficientMap(w,profile,original,time,native);
            return
        end
        assign(time,state);
        if variant=="displacement"
            [source.u,source.v,source.w,source.eta]=w.nonlinearAdvectionSources();
        else
            f=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
            a=struct(u=f.u_hat,v=f.v_hat,w=f.w_hat,eta=f.eta,p=f.p,ssh=f.ssh);
            e=a.eta-alpha.*a.ssh;
            label=xi-inverseInterior(e); needsAdjustment=checkLabels(label);
            z=xi+alpha.*a.ssh;
            % R_h depends only on geometry: B=-q*e+B_geometry.
            thermal=context.evaluateNonlinear(z,alpha.*a.ssh,a.ssh,w.N2);
            if needsAdjustment
                adjustment=min(0,max(-w.Lz,label))-label;
                if lambda==0, deltaI=1e-4*adjustment; else, deltaI=1e-4*exp(lambda*label).*expm1(lambda*adjustment)/lambda; end
                % Preserve the supplied h in its linear term, while using
                % the bounded parcel density, as the displacement baseline does.
                thermal.buoyancyRemainder=thermal.buoyancyRemainder-deltaI;
            end
            terms=WVInternal.freeSurfaceNonlinearTerms(a,a.p,w.z,w.Lz,w.f,w.rho0,w.N2,thermal.buoyancyRemainder,D);
            source=terms.source;
            wi=(a.w-alpha.*a.w(:,:,end))./(1+a.ssh/w.Lz);
            source.eta=source.eta-e.*wi*lambda;
        end
        rate=w.projectSources(source);
    end

    function assign(time,state)
        w.t=time;
        for name=string(fieldnames(state)).', w.(name)=state.(name); end
    end

    function f=fields(time,state)
        if variant=="equivalent", state=invertThermodynamicCoefficientMap(w,profile,state,time); end
        assign(time,state);
        a=w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]);
        eta=a.eta;
        if variant=="density", eta=inverseInterior(eta-alpha.*a.ssh)+alpha.*a.ssh; end
        gamma=1+a.ssh/w.Lz; u=a.u_hat./gamma; v=a.v_hat./gamma;
        vertical=a.w_hat+alpha.*(u.*w.diffX(a.ssh)+v.*w.diffY(a.ssh));
        z=xi+alpha.*a.ssh; label=z-eta; checkLabels(label);
        thermal=context.evaluate(z,eta,a.ssh);
        f=struct(u=u,v=v,w=vertical,eta=eta,ssh=a.ssh,z=z,label=label,density=thermal.density,ape=thermal.ape,p=a.p,gamma=gamma);
    end

    function d=observe(time,state)
        f=fields(time,state);
        d=struct(time=time,energy=sum(weights.*f.gamma.*(.5*(f.u.^2+f.v.^2+f.w.^2)+f.ape),'all')+.5*w.g*mean(f.ssh.^2,'all'), ...
            volume=sum(weights.*f.gamma,'all'),densityMoment=sum(weights.*f.gamma.*(f.density-w.rho0),'all'), ...
            densitySquaredMoment=sum(weights.*f.gamma.*(f.density-w.rho0).^2,'all'), ...
            minimumLabel=min(f.label,[],'all'),maximumLabel=max(f.label,[],'all'));
    end

    function c=checkpoint(time,state)
        % Interpolate primitive physical fields in analytic WKB coordinate.
        f=fields(time,state); target=linspace(-w.Lz,0,101).';
        if lambda==0, nodes=(w.z+w.Lz)/w.Lz; x=(target+w.Lz)/w.Lz;
        else, nodes=expm1((w.z+w.Lz)/1300)/expm1(w.Lz/1300); x=expm1((target+w.Lz)/1300)/expm1(w.Lz/1300); end
        n=numel(nodes); bw=(-1).^(0:n-1)'; bw([1 end])=bw([1 end])/2;
        M=zeros(numel(x),n);
        for j=1:numel(x)
            [distance,k]=min(abs(x(j)-nodes));
            if distance<1e-13, M(j,k)=1; else, row=bw./(x(j)-nodes); M(j,:)=row'/sum(row); end
        end
        c=struct();
        for name=["u","v","w","density","eta"]
            value=real(interpft(interpft(f.(name),24,1),24,2));
            c.(name)=reshape(reshape(value,24*24,w.Nz)*M.',24,24,[]);
        end
        c.ssh=real(interpft(interpft(f.ssh,24,1),24,2));
    end

    function interior=inverseInterior(e)
        if lambda==0, interior=e; else, interior=-log1p(-lambda*e)/lambda; end
        assert(isreal(interior) && all(isfinite(interior),'all'),'Density profile inversion must be real and finite.');
    end
    function needsAdjustment=checkLabels(label)
        tolerance=32*eps(w.Lz);
        lower=min(label,[],'all'); upper=max(label,[],'all');
        needsAdjustment=lower < -w.Lz || upper > 0;
        assert(lower>=-w.Lz-tolerance && upper<=tolerance,'WVStudy:ParcelLabelDomain','Parcel labels exceed the established endpoint roundoff allowance.');
    end
end
