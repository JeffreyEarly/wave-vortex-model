function study = manuscriptEvolutionOperators(wvt,profile,options)
% Small authoring-only direct manuscript evolution and physical diagnostics.
% No weak-stage, constraint, pressure-recovery or runtime activation path.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    profile (1,1) string {mustBeMember(profile,["constant","exponential"])}
    options.padding (1,1) double {mustBeMember(options.padding,[1 2 4])} = 2
end
xi=reshape(wvt.z,1,1,[]); alpha=1+xi/wvt.Lz;
weights=reshape(wvt.verticalQuadratureWeights,1,1,[])/(options.padding^2*wvt.Nx*wvt.Ny);
derivative=struct(x=@(a)fourierDerivative(a,wvt.Lx,1),y=@(a)fourierDerivative(a,wvt.Ly,2),xi=@(a)reshape(reshape(a,[],wvt.Nz)*wvt.verticalDerivativeMatrix.',size(a)));
study=struct(rhs=@rhs,observe=@observe,seed=@seed,sample=@sample,phaseRate=@phaseRate,checkpoint=@checkpoint,thermodynamics=@thermodynamics,derivative=derivative);

    function [rate,terms,hatted] = rhs(time,state)
        hatted=sample(time,state,options.padding);
        [integralN2,~]=thermodynamics(hatted);
        terms=evaluateManuscriptNonlinearTerms(hatted,hatted.p,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,integralN2,derivative);
        source=struct();
        for name=["u","v","w","eta"], source.(name)=restrict(terms.source.(name),wvt.Nx,wvt.Ny); end
        rate=wvt.projectSources(source);
    end

    function hatted = sample(time,state,padding)
        wvt.t=time;
        spectral=wvt.reconstructSpectralState(state=state);
        hatted=struct();
        for name=["u","v","w","eta","ssh","p"]
            value=wvt.transformToSpatialDomainWithFourier(spectral.(name));
            if padding~=1, value=real(interpft(interpft(value,padding*wvt.Nx,1),padding*wvt.Ny,2)); end
            if name=="ssh", value=value(:,:,end); end
            hatted.(name)=value;
        end
    end

    function rate = phaseRate(state)
        rate=structfun(@(a)zeros(size(a)),state,UniformOutput=false);
        omega=wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
        omega(~wvt.activeWaveModes)=0;
        rate.Aw_p=1i*omega.*state.Aw_p; rate.Aw_m=-1i*omega.*state.Aw_m;
        rate.Aio=1i*wvt.f*state.Aio;
    end

    function state = seed(scenario,amplitude)
        % The mean offsets keep both endpoint parcel labels in the reference
        % domain. They are part of every nonlinear fixture, including waves.
        wvt.t=327;
        state=wvt.coefficientState();
        column=find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
        index=wvt.klNonzero(column);
        if scenario~="balanced"
            for mode=1:2
                unit=wvt.coefficientState(); unit.Aw_p(mode,column)=1;
                fields=wvt.reconstructSpectralState(state=unit);
                height=[2 .15]; angle=[.37 1.1];
                state.Aw_p(mode,column)=height(mode)*exp(1i*angle(mode))/(2*fields.ssh(end,index));
            end
            other=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
            unit=wvt.coefficientState(); unit.Aw_m(1,other)=1;
            fields=wvt.reconstructSpectralState(state=unit);
            state.Aw_m(1,other)=.7*exp(.43i)/(2*fields.ssh(end,wvt.klNonzero(other)));
        end
        if scenario~="waves"
            state.Ag_q(1,column)=5e-9*exp(.83i);
            fields=wvt.reconstructSpectralState(state=state);
            existing=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
            response=zeros(2,2);
            for mode=1:2
                unit=wvt.coefficientState(); unit.Ag_0(mode,column)=1;
                fields=wvt.reconstructSpectralState(state=unit);
                response(:,mode)=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
            end
            state.Ag_0(:,column)=response\([.2*exp(.7i);.1*exp(1.3i)]/2-existing);
        end
        if scenario=="mixed", state.Aio(1)=.02*exp(.33i)/(2*wvt.inertialF(end,1)); end
        state.Amda(1:2)=wvt.mdaG([end 1],1:2)\[2;-2];
        state=structfun(@(a)amplitude*a,state,UniformOutput=false);
    end

    function [integralN2,thermal] = thermodynamics(hatted)
        z=xi+alpha.*hatted.ssh; label=z-hatted.eta;
        tolerance=32*eps(wvt.Lz);
        if any(label < -wvt.Lz-tolerance | label > tolerance,'all')
            error('WVStudy:ParcelLabels','Parcel labels outside [-D,0]: [%g,%g] m.',min(label,[],'all'),max(label,[],'all'))
        end
        r=min(0,max(-wvt.Lz,label)); upper=min(z,0); interval=upper-r;
        if profile=="constant"
            integralN2=1e-4*interval;
            ILabel=1e-4*r; JLabel=.5e-4*r.^2; JUpper=.5e-4*upper.^2;
            N2AtLabel=1e-4+zeros(size(r));
        else
            L=650;
            integralN2=1e-4*L*exp(r/L).*expm1(interval/L);
            ILabel=1e-4*L*expm1(r/L);
            JLabel=1e-4*L^2*(expm1(r/L)-r/L);
            JUpper=1e-4*L^2*(expm1(upper/L)-upper/L);
            N2AtLabel=1e-4*exp(r/L);
        end
        ape=-hatted.eta.*ILabel-JLabel+JUpper;
        thermal=struct(label=label,N2AtLabel=N2AtLabel,ape=ape);
    end

    function [d,detail] = observe(time,state,rate)
        h=sample(time,state,options.padding);
        phase=phaseRate(state); total=rate;
        for name=string(fieldnames(rate)).', total.(name)=total.(name)+phase.(name); end
        v=sample(time,total,options.padding);
        nonlinear=sample(time,rate,options.padding);
        [integralN2,thermal]=thermodynamics(h);
        gamma=1+h.ssh/wvt.Lz; gammaT=v.ssh/wvt.Lz;
        u=h.u./gamma; vv=h.v./gamma;
        sshX=derivative.x(h.ssh); sshY=derivative.y(h.ssh);
        w=h.w+alpha.*(u.*sshX+vv.*sshY);
        ut=(v.u-u.*gammaT)./gamma; vt=(v.v-vv.*gammaT)./gamma;
        wt=v.w+alpha.*(ut.*sshX+vt.*sshY+u.*derivative.x(v.ssh)+vv.*derivative.y(v.ssh));
        betaX=alpha.*sshX./gamma; betaY=alpha.*sshY./gamma;
        betaXt=alpha.*derivative.x(v.ssh)./gamma-betaX.*gammaT./gamma;
        betaYt=alpha.*derivative.y(v.ssh)./gamma-betaY.*gammaT./gamma;
        dx=@(a)derivative.x(a)-betaX.*derivative.xi(a);
        dy=@(a)derivative.y(a)-betaY.*derivative.xi(a);
        dz=@(a)derivative.xi(a)./gamma;
        r=thermal.label; rt=alpha.*v.ssh-v.eta;
        rx=dx(r); ry=dy(r); rz=dz(r);
        rxt=dx(rt)-betaXt.*derivative.xi(r);
        ryt=dy(rt)-betaYt.*derivative.xi(r);
        rzt=dz(rt)-gammaT.*rz./gamma;
        ox=dy(w)-dz(vv); oy=dz(u)-dx(w); oz=dx(vv)-dy(u)+wvt.f;
        oxt=dy(wt)-betaYt.*derivative.xi(w)-dz(vt)+gammaT.*dz(vv)./gamma;
        oyt=dz(ut)-gammaT.*dz(u)./gamma-dx(wt)+betaXt.*derivative.xi(w);
        ozt=dx(vt)-betaXt.*derivative.xi(vv)-dy(ut)+betaYt.*derivative.xi(u);
        q=ox.*rx+oy.*ry+oz.*rz-wvt.f;
        qt=oxt.*rx+oyt.*ry+ozt.*rz+ox.*rxt+oy.*ryt+oz.*rzt;
        % The actual moving-mesh velocity is determined by reconstructed
        % SSH_t, including any finite-inventory kinematic mismatch.
        transport=(h.w-alpha.*v.ssh)./gamma;
        advect=@(a)u.*derivative.x(a)+vv.*derivative.y(a)+transport.*derivative.xi(a);
        Rr=rt+advect(r); Rq=qt+advect(q);
        eU=ut+advect(u)-wvt.f*vv+dx(h.p)/wvt.rho0;
        eV=vt+advect(vv)+wvt.f*u+dy(h.p)/wvt.rho0;
        eW=wt+advect(w)+integralN2+dz(h.p)/wvt.rho0;
        surface=h.eta(:,:,end)-h.ssh; bottom=h.eta(:,:,1);
        Rssh=v.ssh-h.w(:,:,end);
        Rs=v.eta(:,:,end)-v.ssh+u(:,:,end).*derivative.x(surface)+vv(:,:,end).*derivative.y(surface);
        Rb=v.eta(:,:,1)+u(:,:,1).*derivative.x(bottom)+vv(:,:,1).*derivative.y(bottom);
        kinetic=.5*(u.^2+vv.^2+w.^2);
        energy=sum(weights.*gamma.*(kinetic+thermal.ape),'all')+.5*wvt.g*mean(h.ssh.^2,'all');
        apeT=integralN2.*alpha.*v.ssh-h.eta.*thermal.N2AtLabel.*rt;
        energyRate=sum(weights.*(gammaT.*(kinetic+thermal.ape)+gamma.*(u.*ut+vv.*vt+w.*wt+apeT)),'all')+wvt.g*mean(h.ssh.*v.ssh,'all');
        energyWork=sum(weights.*gamma.*(u.*eU+vv.*eV+w.*eW-h.eta.*thermal.N2AtLabel.*Rr),'all')+mean(Rssh.*(kinetic(:,:,end)+thermal.ape(:,:,end)+wvt.g*h.ssh),'all');
        moment=@(a)sum(weights.*gamma.*a,'all');
        momentRate=@(a,at)sum(weights.*(gammaT.*a+gamma.*at),'all');
        label2=moment(r.^2); label2Rate=momentRate(r.^2,2*r.*rt);
        apv2=moment(q.^2); apv2Rate=momentRate(q.^2,2*q.*qt);
        label2Work=moment(2*r.*Rr)+mean(Rssh.*r(:,:,end).^2,'all');
        apv2Work=moment(2*q.*Rq)+mean(Rssh.*q(:,:,end).^2,'all');
        normRate=sqrt(sum(weights.*(nonlinear.u.^2+nonlinear.v.^2+nonlinear.w.^2+reshape(wvt.N2,1,1,[]).*nonlinear.eta.^2),'all')+wvt.g*mean(nonlinear.ssh.^2,'all'));
        d=struct(time=time,energy=energy,energyRate=energyRate,energyWork=energyWork,energyBudgetResidual=energyRate-energyWork,label2=label2,label2Rate=label2Rate,label2Work=label2Work,apv2=apv2,apv2Rate=apv2Rate,apv2Work=apv2Work,sshResidual=max(abs(Rssh),[],'all'),surfaceResidual=max(abs(Rs),[],'all'),bottomResidual=max(abs(Rb),[],'all'),sshIdentityError=max(abs(Rssh-nonlinear.ssh),[],'all'),minimumLabel=min(r,[],'all'),maximumLabel=max(r,[],'all'),nonlinearRateNorm=normRate,maximumSpeed=max(sqrt(u.^2+vv.^2+w.^2),[],'all'),sshRMS=sqrt(mean(h.ssh.^2,'all')),surfaceRMS=sqrt(mean(surface.^2,'all')),bottomRMS=sqrt(mean(bottom.^2,'all')),divergence=max(abs(derivative.x(h.u)+derivative.y(h.v)+derivative.xi(h.w)),[],'all'));
        detail=struct(hatted=h,totalRate=v,nonlinear=nonlinear,Rssh=Rssh,Rsurface=Rs,Rbottom=Rb,apv=q,apvRate=qt,label=r,labelRate=rt,materialLabelResidual=Rr,materialAPVResidual=Rq);
    end

    function [vector,minimumLabel,maximumLabel] = checkpoint(time,state)
        % Independent barycentric evaluation in the analytic WKB coordinate
        % on one fixed physical-reference grid for all vertical inventories.
        h=sample(time,state,2);
        if wvt.Nx~=8 || wvt.Ny~=8
            for name=string(fieldnames(h)).', h.(name)=real(interpft(interpft(h.(name),16,1),16,2)); end
        end
        target=linspace(-wvt.Lz,0,101).';
        if profile=="constant"
            nodes=(wvt.z+wvt.Lz)/wvt.Lz; targetCoordinate=(target+wvt.Lz)/wvt.Lz;
        else
            nodes=expm1((wvt.z+wvt.Lz)/1300)/expm1(wvt.Lz/1300);
            targetCoordinate=expm1((target+wvt.Lz)/1300)/expm1(wvt.Lz/1300);
        end
        expected=(1-cos(pi*(0:wvt.Nz-1).'/(wvt.Nz-1)))/2;
        assert(max(abs(nodes-expected))<1e-10,'The independent analytic WKB map does not match the native samples.');
        matrix=barycentricMatrix(nodes,targetCoordinate);
        for name=["u","v","w","eta"]
            h.(name)=reshape(reshape(h.(name),[],wvt.Nz)*matrix.',16,16,[]);
        end
        z=reshape(target,1,1,[])+reshape(1+target/wvt.Lz,1,1,[]).*h.ssh;
        label=z-h.eta;
        minimumLabel=min(label,[],'all'); maximumLabel=max(label,[],'all');
        vector=[h.u(:)/sqrt(101);h.v(:)/sqrt(101);h.w(:)/sqrt(101);.01*h.eta(:)/sqrt(101);sqrt(wvt.g/wvt.Lz)*h.ssh(:)]/16;
    end
end

function value = fourierDerivative(field,L,dimension)
count=size(field,dimension); k=(2*pi/L)*[0:count/2-1,0,-count/2+1:-1];
shape=ones(1,ndims(field)); shape(dimension)=count;
value=real(ifft(reshape(1i*k,shape).*fft(field,[],dimension),[],dimension));
end

function value = restrict(field,Nx,Ny)
if size(field,1)==Nx && size(field,2)==Ny, value=field; return; end
spectrum=fft2(field)/(size(field,1)*size(field,2));
mx=[0:Nx/2-1,-Nx/2:-1]; my=[0:Ny/2-1,-Ny/2:-1];
c=spectrum(mod(mx,size(field,1))+1,mod(my,size(field,2))+1,:);
c(Nx/2+1,:,:)=0; c(:,Ny/2+1,:)=0;
value=real(ifft2(c))*(Nx*Ny);
end

function matrix = barycentricMatrix(nodes,target)
% Generic physical-node polynomial interpolation. Log weights avoid products
% overflowing; this does not assume that physical nodes are Chebyshev nodes.
nodes=nodes(:); n=numel(nodes); weight=zeros(n,1);
for j=1:n
    differences=nodes(j)-nodes([1:j-1,j+1:n]);
    weight(j)=-sum(log(abs(differences)));
end
weight=exp(weight-max(weight)).*(-1).^(n-(1:n)).';
matrix=zeros(numel(target),n);
for j=1:numel(target)
    [distance,index]=min(abs(target(j)-nodes));
    if distance<32*eps(max(abs(nodes))), matrix(j,index)=1; continue; end
    row=weight./(target(j)-nodes); matrix(j,:)=row.'/sum(row);
end
end
