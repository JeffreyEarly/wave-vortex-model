function results = runFreeSurfaceFrozenOverintegrationStudy()
% Freeze one canonical state and inventory while refining horizontal quadrature.
% The dense solve is an independent authoring diagnostic, never a runtime path.
helper = freeSurfaceWeakStudyHelpers();
rows = {};
for profile = ["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+0*z; else, N2=@(z)1e-4*exp(z/650); end
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2,shouldAntialias=true,shouldCheckQuadraticAliasing=true,apvModeCount=2,mdaModeCount=2,waveModeCount=3,inertialModeCount=2,nEVP=256);
    wvt.t=0; wvt.t0=-17;
    layout=WVInternal.freeSurfaceRealCoefficientLayout(wvt);
    thermal=WVInternal.freeSurfaceThermodynamics(wvt);
    state=helper.seedState(wvt);
    ix=find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
    iy=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
    state.Aw_p(:,iy)=.3*exp(.41i)*state.Aw_p(:,ix);
    state.Aw_m(:,iy)=.2*exp(.63i)*state.Aw_p(:,iy);
    original=layout.pack(state);
    native=helper.buildContext(wvt,1);
    basis=canonicalBasis(wvt,layout,helper,native);
    H0=referenceMass(basis,native,N2(wvt.z));
    scale=sqrt(diag(H0));
    T=diag(1./scale)/chol(H0./(scale*scale.'));
    for name=["u","v","w","eta","ssh"], basis.(name)=basis.(name)*T; end
    x=T\original;
    reports=cell(1,4); rates=cell(1,4); controls=cell(1,4);
    for padding=1:4
        timer=tic;
        c=helper.buildContext(wvt,padding);
        b=interpolateBasis(basis,native.shape,c.shape);
        h=fieldsFromBasis(b,x,c);
        [H,gradient,psi,energy,p,th]=geometry(b,h,c,thermal);
        F=WVInternal.freeSurfaceMappedTendency(h,zeros(c.shape),th.buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,c.derivative);
        weighted=metricFields(F,p,h,c);
        r=zeros(layout.dimension,1); workScale=0;
        for name=["u","v","w","eta"]
            if name=="eta", value=p.gamma.*th.N2AtLabel.*F.eta; else, value=weighted.(name); end
            r=r+b.(name).'*(c.weights.*value(:));
            workScale=workScale+sum(c.weights.*abs(h.(name)(:).*value(:)));
        end
        pressureWork=-h.w(:,:,end).*th.pressureSurface;
        surfaceWork=c.g*h.ssh.*h.w(:,:,end);
        r=r-b.w(c.top,:).'*(c.surfaceWeights.*th.pressureSurface(:))+c.g*b.ssh.'*(c.surfaceWeights.*reshape(h.w(:,:,end),[],1));
        workScale=workScale+mean(abs(pressureWork)+abs(surfaceWork),'all')+mean(abs(psi.*h.w(:,:,end)),'all');
        s=reshape(1+c.xi/c.D,1,1,[]);
        etaI=h.eta-s.*h.ssh;
        adv=-(h.u.*c.derivative.x(etaI)+h.v.*c.derivative.y(etaI))./p.gamma;
        target=[reshape(h.w(:,:,end),[],1);reshape(adv(:,:,end),[],1);reshape(adv(:,:,1),[],1)]/sqrt(c.nSurface);
        traces=[b.ssh;b.eta(c.top,:)-b.ssh;b.eta(c.bottom,:)]/sqrt(c.nSurface);
        [U,S,~]=svd(traces,'econ');
        singular=diag(S); traceRank=sum(singular>1e-10*singular(1)); U=U(:,1:traceRank);
        K=U.'*traces; desired=U.'*target;
        inverseR=H\r; inverseK=H\K.';
        multiplier=(K*inverseK)\(K*inverseR-desired);
        rate=inverseR-inverseK*multiplier;
        rates{padding}=rate;
        energyRate=gradient.'*rate;
        gridWork=x.'*r+mean(psi.*h.w(:,:,end),'all');
        reactionWork=-(K*x).'*multiplier;
        solverWork=x.'*(H*rate+K.'*multiplier-r);
        surfaceMismatch=reshape(b.ssh*rate,c.shape(1:2))-h.w(:,:,end);
        geometryConstraintWork=mean(psi.*surfaceMismatch,'all');
        closure=energyRate-gridWork-reactionWork-solverWork-geometryConstraintWork;
        retainedResidual=norm(K*rate-desired);
        discardedTargetRMS=norm(target-U*(U.'*target))/sqrt(3);
        gradientIdentity=norm(gradient-H*x-b.ssh.'*(c.surfaceWeights.*psi(:)))/norm(gradient);
        gramError=norm(referenceMass(b,c,N2(wvt.z))-eye(layout.dimension),'fro');
        [buoyancyError,pressureError,densityError]=analyticChecks(profile,h,p,th,c);
        minimumLabel=min(th.label,[],'all'); maximumLabel=max(th.label,[],'all');
        minimumGamma=min(p.gamma,[],'all'); minimumN2=min(th.N2AtLabel,[],'all');
        adjustedLabels=th.adjustedLabelCount;
        coefficientStateUnchanged=isequal(original,layout.pack(state));
        coefficientDimension=layout.dimension;
        controls{padding}=quadraticControl(h,c,wvt);
        elapsedSeconds=toc(timer);
        reports{padding}=table(profile,padding,traceRank,energy,energyRate,gridWork,workScale,reactionWork,solverWork,geometryConstraintWork,closure,retainedResidual,discardedTargetRMS,gradientIdentity,gramError,buoyancyError,pressureError,densityError,minimumLabel,maximumLabel,minimumGamma,minimumN2,adjustedLabels,coefficientStateUnchanged,coefficientDimension,elapsedSeconds);
        fprintf('%s padding %d: rate %.12g, grid work %.5g, reaction %.5g, %.1fs\n',profile,padding,norm(rate),gridWork,reactionWork,elapsedSeconds);
        assert(coefficientStateUnchanged && minimumLabel>=-c.D && maximumLabel<=0);
        assert(traceRank==WVInternal.freeSurfaceBoundaryOperator(wvt).dimension);
        assert(retainedResidual<1e-10 && gramError<1e-8 && abs(closure)<1e-10*max(workScale,realmin));
        if padding==1
            % A centered energy difference tests the independently assembled
            % gradient along the actual rate, staying inside the parcel domain.
            step=.1;
            plus=energyOnly(fieldsFromBasis(b,x+step*rate,c),c,thermal);
            minus=energyOnly(fieldsFromBasis(b,x-step*rate,c),c,thermal);
            reports{padding}.gradientDifferenceError=abs((plus-minus)/(2*step)-energyRate);
            runtime=WVInternal.freeSurfaceNonlinearStage(wvt);
            [~,~,runtimeStage]=runtime.evaluate(state);
            reports{padding}.runtimeRateRelativeError=norm(T\layout.pack(runtimeStage.totalRate)-rate)/norm(rate);
            assert(reports{padding}.runtimeRateRelativeError<1e-8);
        else
            reports{padding}.gradientDifferenceError=NaN;
            reports{padding}.runtimeRateRelativeError=NaN;
        end
    end
    for padding=1:4
        reports{padding}.rateNorm=norm(rates{padding});
        reports{padding}.rateErrorToPadding4=norm(rates{padding}-rates{4});
        reports{padding}.relativeRateErrorToPadding4=norm(rates{padding}-rates{4})/norm(rates{4});
        reports{padding}.quadraticControlError=norm(controls{padding}-controls{4})/norm(controls{4});
        reports{padding}.gridWorkRelative=reports{padding}.gridWork/reports{padding}.workScale;
        rows{end+1}=reports{padding}; %#ok<AGROW>
    end
end
results=vertcat(rows{:});
end

function b=canonicalBasis(wvt,layout,helper,c)
for name=["u","v","w","eta"], b.(name)=zeros(prod(c.shape),layout.dimension); end
b.ssh=zeros(c.nSurface,layout.dimension);
for j=1:layout.dimension
    unit=zeros(layout.dimension,1); unit(j)=1;
    fields=helper.sampledState(wvt,layout.unpack(unit),c);
    for name=["u","v","w","eta","ssh"], b.(name)(:,j)=fields.(name)(:); end
end
end

function b=interpolateBasis(native,oldShape,newShape)
n=size(native.u,2);
for name=["u","v","w","eta","ssh"]
    shape=oldShape; if name=="ssh", shape(3)=1; end
    values=reshape(native.(name),[shape n]);
    values=real(interpft(interpft(values,newShape(1),1),newShape(2),2));
    b.(name)=reshape(values,[],n);
end
end

function h=fieldsFromBasis(b,x,c)
for name=["u","v","w","eta"]
    h.(name)=reshape(b.(name)*x,c.shape);
end
h.ssh=reshape(b.ssh*x,c.shape(1:2));
end

function H=referenceMass(b,c,N2)
H=zeros(size(b.ssh,2));
for name=["u","v","w","eta"]
    weight=c.weights;
    if name=="eta", weight=weight.*kron(N2,ones(c.nSurface,1)); end
    H=H+b.(name).'*(weight.*b.(name));
end
H=H+c.g*b.ssh.'*(c.surfaceWeights.*b.ssh);
end

function [H,gradient,psi,E,p,th]=geometry(b,h,c,thermal)
p=WVInternal.freeSurfacePhysicalFields(h,c.xi,c.D,c.derivative.x(h.ssh),c.derivative.y(h.ssh));
th=thermal.evaluate(p.z,h.eta,h.ssh);
gamma=repmat(p.gamma,1,1,c.shape(3));
s=reshape(1+c.xi/c.D,1,1,[]);
betaX=s.*c.derivative.x(h.ssh)./p.gamma;
betaY=s.*c.derivative.y(h.ssh)./p.gamma;
vertical=b.w+betaX(:).*b.u+betaY(:).*b.v;
Ru=b.u./gamma(:)+gamma(:).*betaX(:).*vertical;
Rv=b.v./gamma(:)+gamma(:).*betaY(:).*vertical;
Rw=gamma(:).*vertical;
H=b.u.'*(c.weights.*Ru)+b.v.'*(c.weights.*Rv)+b.w.'*(c.weights.*Rw)+b.eta.'*(c.weights.*gamma(:).*th.N2AtLabel(:).*b.eta)+c.g*b.ssh.'*(c.surfaceWeights.*b.ssh);
weighted=metricFields(h,p,h,c);
gradient=zeros(size(b.ssh,2),1);
for name=["u","v","w"], gradient=gradient+b.(name).'*(c.weights.*weighted.(name)(:)); end
gradient=gradient+b.eta.'*(c.weights.*gamma(:).*th.apeEta(:));
speed2=p.u.^2+p.v.^2+p.w.^2;
G=(p.w.*h.w-.5*speed2)/c.D+th.ape/c.D+gamma.*s.*th.apeZ;
geometrySurface=verticalIntegral(G,c)-c.derivative.x(verticalIntegral(s.*p.w.*h.u,c))-c.derivative.y(verticalIntegral(s.*p.w.*h.v,c));
psi=geometrySurface+th.pressureSurface-c.g*h.ssh;
gradient=gradient+b.ssh.'*(c.surfaceWeights.*(geometrySurface(:)+th.pressureSurface(:)));
E=sum(c.weights.*gamma(:).*(.5*speed2(:)+th.ape(:)))+mean(th.energySurface,'all');
end

function value=energyOnly(h,c,thermal)
p=WVInternal.freeSurfacePhysicalFields(h,c.xi,c.D,c.derivative.x(h.ssh),c.derivative.y(h.ssh));
th=thermal.evaluate(p.z,h.eta,h.ssh);
gamma=repmat(p.gamma,1,1,c.shape(3));
speed2=p.u.^2+p.v.^2+p.w.^2;
value=sum(c.weights.*gamma(:).*(.5*speed2(:)+th.ape(:)))+mean(th.energySurface,'all');
end

function value=verticalIntegral(field,c)
value=reshape(reshape(field,c.nSurface,[])*c.weights(1:c.nSurface:end)*c.nSurface,c.shape(1:2));
end

function weighted=metricFields(F,p,h,c)
s=reshape(1+c.xi/c.D,1,1,[]);
betaX=s.*c.derivative.x(h.ssh)./p.gamma;
betaY=s.*c.derivative.y(h.ssh)./p.gamma;
vertical=F.w+betaX.*F.u+betaY.*F.v;
weighted=struct(u=F.u./p.gamma+p.gamma.*betaX.*vertical,v=F.v./p.gamma+p.gamma.*betaY.*vertical,w=p.gamma.*vertical);
end

function [bError,pError,rhoError]=analyticChecks(profile,h,p,th,c)
if profile=="constant"
    I=@(z)1e-4*z;
    J=@(z).5e-4*z.^2;
else
    I=@(z)1e-4*(650*expm1(min(z,0)/650)+max(z,0));
    J=@(z)1e-4*(650^2*(expm1(min(z,0)/650)-min(z,0)/650)+.5*max(z,0).^2);
end
bError=max(abs(th.buoyancy-(I(th.label)-I(p.z))),[],'all');
pError=max(abs(th.pressureSurface-(c.g*h.ssh-J(h.ssh))),[],'all');
rhoError=max(abs(th.density-(c.rho0-c.rho0/c.g*I(th.label))),[],'all');
end

function values=quadraticControl(h,c,wvt)
% Inspect represented low harmonics of selected polynomial products. This
% controls band aliasing, without claiming rational terms are band limited.
products={h.u.^2,h.u.*h.eta,h.eta.^2};
ik=round(wvt.kNonzero*wvt.Lx/(2*pi));
il=round(wvt.lNonzero*wvt.Ly/(2*pi));
indices=sub2ind(c.shape(1:2),mod(ik,c.shape(1))+1,mod(il,c.shape(2))+1);
values=[];
for j=1:numel(products)
    spectrum=reshape(fft2(products{j})/c.nSurface,c.nSurface,[]);
    block=spectrum(indices,:);
    values=[values;block(:)]; %#ok<AGROW>
end
end
