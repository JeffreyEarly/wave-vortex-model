function runRationalGeometryControls
% Analytic full-source control: eta=alpha*ssh keeps labels exactly at xi.
% The large velocity is a nondimensional stress scaling, not an ocean scenario.
folder=fileparts(mfilename('fullpath')); rows=struct([]);
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
k=2*pi/w.Lx; U=sqrt(w.g*w.Lz); [inputX,~,inputZ]=ndgrid(w.x,w.y,w.z);
for ratio=[.05 .2 .5]
    A=ratio*w.Lz; ssh=A*cos(k*inputX); p=WVInternal.prepareBoussinesqRHSAssessment(w);
    h=struct(u=U+zeros(size(inputX)),v=zeros(size(inputX)),w=zeros(size(inputX)),eta=(1+inputZ/w.Lz).*ssh,p=w.rho0*w.g*ssh);
    for name=["u","v","w","eta","p"], p.spectral.(name)=w.transformFromSpatialDomainWithFourier(h.(name)); end
    errors=[];
    for n=[8 12 16 24 32 48 64]
        e=WVInternal.evaluateBoussinesqRHSAssessment(p,[n n 33]);
        g=WVGeometryDoublyPeriodic([w.Lx w.Ly],[n n],Nz=33,shouldAntialias=false,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
        [X,~,Z]=ndgrid(g.x,g.y,e.z); alpha=1+Z/w.Lz;
        ssh=A*cos(k*X); sx=-A*k*sin(k*X); sxx=-A*k^2*cos(k*X); gamma=1+ssh/w.Lz;
        exact=struct(u=U^2*sx./(w.Lz*gamma.^2)-w.g*ssh.*sx/w.Lz,v=zeros(size(X)),w=-U^2*alpha.*sxx./gamma.^2+alpha*w.g.*sx.^2+1e-4*max(Z+alpha.*ssh,0),eta=zeros(size(X)));
        [~,indices]=ismember(round([w.k*w.Lx,w.l*w.Ly]/(2*pi)),round([g.k*w.Lx,g.l*w.Ly]/(2*pi)),'rows');
        maximum=0;
        for name=["u","v","w","eta"]
            values=g.transformFromSpatialDomainWithFourier(exact.(name)); values=values(:,indices);
            difference=norm(e.source.(name)-values,'fro'); scale=norm(values,'fro');
            relative=difference/max(scale,1e-12);
            if scale>1e-12, maximum=max(maximum,relative); end
            if n==64, fprintf('analytic ratio %g field %s difference %.9g norm %.9g\n',ratio,name,difference,scale); assert(difference<=1e-10*scale+1e-12,'The analytic full-source check failed.'); end
            row=struct(surfaceRatio=ratio,nx=n,field=name,absoluteError=difference,referenceNorm=scale,relativeError=relative);
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
        end
        errors(end+1)=maximum; %#ok<AGROW>
    end
    writetable(struct2table(rows),fullfile(folder,'results','rational-controls.csv'));
    fprintf('rational ratio %g max at n64 %.6g\n',ratio,errors(end));
    assert(errors(end)<1e-9 && errors(end)<errors(1)*1e-4,'Rational source differentiation must converge to its independent analytic expression.');
end
writetable(struct2table(rows),fullfile(folder,'results','rational-controls.csv'));
end
