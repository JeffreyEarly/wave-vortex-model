function results=runRHSReuseComparison(outputFolder)
% Compare complete unforced RHSs; setup is excluded and caches are explicit.
arguments
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path; cleanup=onCleanup(@()path(originalPath));
addpath(fullfile(root,'UnitTests','ReferenceImplementations'),fullfile(root,'tools','nonlinear-study'));
addpath(fullfile(fileparts(root),'OceanKit','tools','profiling'));
rows={}; gradients=[];
for grid=[8 8 33;8 8 65;8 8 129;16 16 65].'
    Nx=grid(1); Ny=grid(2); Z=grid(3);
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[Nx Ny Z],N2Function=@(z)1e-4*exp(z/650),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    old=RHSReuseReference(w.scientificState());
    study=manuscriptEvolutionOperators(w,"exponential",padding=1);
    state=study.seed("mixed",1);
    for object={w,old}
        a=object{1};
        for name=string(fieldnames(state)).', a.(name)=state.(name); end
        a.t=327; a.t0=-17; a.addForcing(WVNonlinearAdvection(a));
    end
    expected=old.coefficientTendency(); actual=w.coefficientTendency();
    difference=0;
    for name=string(fieldnames(actual)).'
        difference=max(difference,norm(actual.(name)(:)-expected.(name)(:))/max(norm(expected.(name)(:)),realmin));
    end
    assert(difference<1e-10,'RHS differs from baseline.');
    for mode=["cold","warm","overlap","successive"]
        baseline=@()evaluate(old,mode); selected=@()evaluate(w,mode);
        [before,after]=paired(baseline,selected);
        rows(end+1,:)={Nx,Ny,Z,mode,before,after,difference};
        fprintf('%dx%dx%d %s: old %.4g new %.4g s\n',Nx,Ny,Z,mode,before,after);
    end
    spectral=w.reconstructSpectralState(); p=w.transformToSpatialDomainWithFourier(spectral.p);
    [dx,dy]=directGradient(w,spectral.p);
    relative=max(norm(dx(:)-reshape(w.diffX(p),[],1))/max(norm(dx(:)),realmin),norm(dy(:)-reshape(w.diffY(p),[],1))/max(norm(dy(:)),realmin));
    assert(relative<1e-10,'Pressure-gradient candidate differs.');
    [before,after]=paired(@()directionalGradient(w,p),@()directGradient(w,spectral.p));
    gradients(end+1,:)=[Nx,Ny,Z,before,after,relative];
    fprintf('Pressure %dx%dx%d: directional %.4g spectral %.4g s\n',Nx,Ny,Z,before,after);
    if Z==65 && Nx==8
        baselineProfile=profileCodeHotspots(@()evaluate(old,"cold"),projectRoots=root);
        selectedProfile=profileCodeHotspots(@()evaluate(w,"cold"),projectRoots=root);
        save(fullfile(outputFolder,'profiles.mat'),'baselineProfile','selectedProfile');
    end
end
results.rhs=cell2table(rows,VariableNames={'Nx','Ny','Z','cacheMode','referenceSeconds','selectedSeconds','relativeDifference'});
results.pressure=array2table(gradients,VariableNames={'Nx','Ny','Z','directionalSeconds','spectralSeconds','relativeDifference'});
writetable(results.rhs,fullfile(outputFolder,'rhs.csv'));
writetable(results.pressure,fullfile(outputFolder,'pressure.csv'));
end
function value=evaluate(w,mode)
if mode=="cold" || mode=="overlap"
    w.clearVariableCacheOfApAmA0DependentVariables();
    if mode=="overlap", w.reconstructFields(["u_hat","p","ssh"]); end
elseif mode=="successive"
    w.t=w.t+1;
end
value=w.coefficientTendency();
end
function [x,y]=directionalGradient(w,p)
x=w.diffX(p); y=w.diffY(p);
end
function [x,y]=directGradient(w,p)
x=w.transformToSpatialDomainWithFourier(p.*(1i*w.k.'));
y=w.transformToSpatialDomainWithFourier(p.*(1i*w.l.'));
end
function [before,after]=paired(reference,selected)
reference(); selected(); measurements=zeros(5,2);
for repeat=1:5
    if mod(repeat,2), order=[1 2]; else, order=[2 1]; end
    functions={reference,selected};
    for index=order
        start=tic;
        for iteration=1:30, functions{index}(); end
        measurements(repeat,index)=toc(start)/30;
    end
end
before=median(measurements(:,1)); after=median(measurements(:,2));
end
