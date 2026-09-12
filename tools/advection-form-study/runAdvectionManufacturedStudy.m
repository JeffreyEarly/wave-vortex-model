function runAdvectionManufacturedStudy
% Analytic scalar transport references and endpoint-sensitive budget identities.
folder=fileparts(mfilename('fullpath')); rows=struct([]);
for nx=[8 16 32 64]
    for nz=[9 17 33 65]
        a=thermodynamicFormulationFixture("constant",.1,nx,nz);
        s=1+a.xi/a.D; theta=2*pi*((0:nx-1)'+.137)/nx; k=a.k;
        u=cos(2*theta).*(1+.3*cos(pi*s));
        surface=2*k*a.D*sin(2*theta);
        w=2*k*.3*a.D/pi*sin(2*theta).*sin(pi*s);
        c=-surface/a.D;
        x=1+2*a.xi(:)/a.D; V=cos(acos(x)*(0:nz-1));
        moments=zeros(nz,1); moments(1:2:end)=a.D./(1-(0:2:nz-1).^2);
        weights=V.'\moments;
        nodes=a.xi(:); delta=nodes-nodes'; delta(1:nz+1:end)=1;
        bw=(-1).^(0:nz-1)'; bw([1 end])=bw([1 end])/2;
        Dz=(bw'./bw)./delta; Dz(1:nz+1:end)=0; Dz(1:nz+1:end)=-sum(Dz,2);
        B=zeros(nz); B(1,1)=-1; B(end,end)=1;
        adj=(B-Dz'.*weights')./weights;
        derivative=a.derivative; derivative.adjointXi=@(q)reshape(reshape(q,[],nz)*adj.',size(q));
        for scenario=["oscillatory","boundary"]
            if scenario=="oscillatory", F=cos(6*pi*s); Fz=-6*pi/a.D*sin(6*pi*s);
            else, F=exp(-25*s)+.4*exp(18*(s-1)); Fz=(-25*exp(-25*s)+7.2*exp(18*(s-1)))/a.D; end
            Q=sin(3*theta)+.35*cos(theta)+.2*sin(2*theta);
            Qx=k*(3*cos(3*theta)-.35*sin(theta)+.4*cos(2*theta));
            q=Q.*F; qx=Qx.*F; qz=Q.*Fz;
            exact=u.*qx+w.*qz;
            for form=["divergence","advective","split","compatible"]
                result=advectionTransport(q,u,zeros(size(u)),w,c,derivative,form);
                error=result-exact;
                scalarDefect=sum(reshape(weights,1,1,nz).*(q.*result+.5*c.*q.^2),'all')/nx;
                row=struct(nx=nx,nz=nz,scenario=scenario,form=form,rmsError=sqrt(mean(error.^2,'all')),maxError=max(abs(error),[],'all'),scalarBudgetDefect=scalarDefect);
                if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','manufactured.csv'));
end
