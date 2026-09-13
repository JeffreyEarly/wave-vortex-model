function runCrossingProjectionStudy
% Compare the same frozen modal state with and without crossing quadrature.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
addpath(fullfile(fileparts(folder),'nonlinear-study'));
rows=struct([]); references=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
    seed=manuscriptEvolutionOperators(w,profile,padding=1); initial=seed.seed("mixed",1);
    for amplitude=[.01 .1 1]
        for time=[327 901]
            for name=string(fieldnames(initial)).', w.(name)=amplitude*initial.(name); end
            w.t=time; w.t0=-17; p=WVInternal.prepareBoussinesqRHSAssessment(w);
            reference=WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 129],crossingOrder=16);
            controls={WVInternal.evaluateBoussinesqRHSAssessment(p,[96 96 129],crossingOrder=16),WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 193],crossingOrder=32),WVInternal.evaluateBoussinesqRHSAssessment(p,[96 96 193],crossingOrder=32)};
            independent=WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 1025]);
            check=WVInternal.assessBoussinesqRHSResolution(reference,reference,controls);
            assert(check.referencesStable,'Crossing reference is inconclusive.');
            for j=1:height(check.rows)
                item=table2struct(check.rows(j,:)); item.profile=profile; item.amplitude=amplitude; item.time=time;
                item.unsplitDifference=norm(independent.tendency.(item.family)-reference.tendency.(item.family),'fro');
                if isempty(references), references=item; else, references(end+1)=item; end %#ok<AGROW>
            end
            for count=[9 13 17 25 33 49 65]
                for order=[0 8 16]
                    actual=WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 count],crossingOrder=order);
                    report=WVInternal.assessBoussinesqRHSResolution(actual,reference,controls);
                    for j=1:height(report.rows)
                        item=table2struct(report.rows(j,:)); item.profile=profile; item.amplitude=amplitude; item.time=time; item.count=count; item.order=order; item.status=report.status;
                        if isempty(rows), rows=item; else, rows(end+1)=item; end %#ok<AGROW>
                    end
                    fprintf('%s a%g t%g Z%d Q%d %s %.3g\n',profile,amplitude,time,count,order,report.status,max(report.rows.relativeError));
                end
            end
            writetable(struct2table(rows),fullfile(output,'convergence.csv'));
            writetable(struct2table(references),fullfile(output,'references.csv'));
        end
    end
end
end
