function results=runBuoyancyComparison(outputFolder)
% Compare represented-profile degrees, amplitudes, grids, and full RHS time.
arguments
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path; cleanup=onCleanup(@()path(originalPath));
addpath(fullfile(root,'UnitTests','ReferenceImplementations'),fullfile(root,'tools','nonlinear-study'));
rows={}; rhsRows={};
for degree=[0 8 32 64]
    profile=@(z)1e-4*(1+.2*(1+z/1000).^degree);
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=profile,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    start=tic; direct=WVInternal.freeSurfaceThermodynamics(w); setupDirect=toc(start);
    start=tic; reference=quadratureThermodynamicsReference(w); setupReference=toc(start);
    represented=length(chebfun(w.N2Function,[-w.Lz,0],'splitting','off'))-1;
    for side=[8 32]
        xi=reshape(linspace(-999,-1,65),1,1,[]);
        eta=repmat(reshape(linspace(-1,1,side^2),side,side),1,1,65);
        for amplitude=[.1 1e-7 1e-12]
            displacement=amplitude*eta; z=xi+0.3*displacement; ssh=zeros(side);
            N2=reshape(profile(xi),[],1);
            old=reference.evaluateNonlinear(z,displacement,ssh,N2);
            actual=direct.evaluateNonlinear(z,displacement,ssh,N2);
            error=max(abs(actual.buoyancyRemainder-old.buoyancyRemainder),[],'all');
            bound=128*eps(1e-4)*max(abs(displacement),[],'all');
            assert(error<=bound,'Remainder differs beyond profile-evaluation roundoff.');
            [before,after]=paired(@()reference.evaluateNonlinear(z,displacement,ssh,N2),@()direct.evaluateNonlinear(z,displacement,ssh,N2));
            rows(end+1,:)={degree,represented,side,65,amplitude,setupReference,setupDirect,before,after,error};
            fprintf('P=%d side=%d amplitude=%g: quadrature %.4g recurrence %.4g s\n',represented,side,amplitude,before,after);
        end
    end
    study=manuscriptEvolutionOperators(w,"constant",padding=1); state=study.seed("mixed",1);
    old=QuadratureBuoyancyReference(w.scientificState());
    for object={w,old}
        a=object{1}; for name=string(fieldnames(state)).', a.(name)=state.(name); end
        a.t=327; a.t0=-17; a.addForcing(WVNonlinearAdvection(a));
    end
    expected=old.coefficientTendency(); actual=w.coefficientTendency(); error=0;
    for name=string(fieldnames(actual)).'
        error=max(error,norm(actual.(name)(:)-expected.(name)(:))/max(norm(expected.(name)(:)),realmin));
    end
    assert(error<3e-10,'Coefficient RHS differs from quadrature baseline.');
    [before,after]=paired(@()cold(old),@()cold(w));
    rhsRows(end+1,:)={degree,represented,before,after,error};
    fprintf('RHS P=%d: quadrature %.4g recurrence %.4g s\n',represented,before,after);
end
results.evaluator=cell2table(rows,VariableNames={'requestedDegree','representedDegree','horizontalSide','Z','amplitude','quadratureSetupSeconds','recurrenceSetupSeconds','quadratureSeconds','recurrenceSeconds','absoluteRemainderDifference'});
results.rhs=cell2table(rhsRows,VariableNames={'requestedDegree','representedDegree','quadratureSeconds','recurrenceSeconds','relativeDifference'});
writetable(results.evaluator,fullfile(outputFolder,'evaluator.csv'));
writetable(results.rhs,fullfile(outputFolder,'rhs.csv'));
end
function value=cold(w)
w.clearVariableCacheOfApAmA0DependentVariables(); value=w.coefficientTendency();
end
function [before,after]=paired(reference,candidate)
reference(); candidate(); samples=zeros(3,2); actions={reference,candidate};
for repeat=1:3
    if mod(repeat,2), order=[1 2]; else, order=[2 1]; end
    for index=order
        start=tic; for iteration=1:10, actions{index}(); end
        samples(repeat,index)=toc(start)/10;
    end
end
before=median(samples(:,1)); after=median(samples(:,2));
end
