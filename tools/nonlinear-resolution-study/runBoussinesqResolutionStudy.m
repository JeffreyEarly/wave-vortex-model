function runBoussinesqResolutionStudy
% Frozen input/output modes; separate horizontal/vertical evaluation sweeps.
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
addpath(fullfile(fileparts(folder),'nonlinear-study'));
rows=struct([]); references=struct([]); sourceRows=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
    seed=manuscriptEvolutionOperators(w,profile,padding=1); initial=seed.seed("mixed",1);
    for amplitude=[.01 .1 1]
        for time=[327 901]
            for name=string(fieldnames(initial)).', w.(name)=amplitude*initial.(name); end
            w.t=time; w.t0=-17;
            p=WVInternal.prepareBoussinesqRHSAssessment(w);
            referenceNz=257;
            while true
                reference=WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 referenceNz]);
                refinedNz=round(1.5*(referenceNz-1))+1;
                controls={WVInternal.evaluateBoussinesqRHSAssessment(p,[96 96 referenceNz]),WVInternal.evaluateBoussinesqRHSAssessment(p,[64 64 refinedNz]),WVInternal.evaluateBoussinesqRHSAssessment(p,[96 96 refinedNz])};
                check=WVInternal.assessBoussinesqRHSResolution(reference,reference,controls);
                if check.referencesStable || referenceNz>=1025, break; end
                referenceNz=2*(referenceNz-1)+1;
            end
            fprintf('reference %s a%g t%g %s max fraction %.4g\n',profile,amplitude,time,check.status,max(check.rows.referenceFraction));
            for j=1:height(check.rows)
                item=table2struct(check.rows(j,:)); item.profile=profile; item.amplitude=amplitude; item.time=time; item.referenceNz=referenceNz;
                if isempty(references), references=item; else, references(end+1)=item; end %#ok<AGROW>
            end
            for direction=["horizontal","vertical"]
                if direction=="horizontal", counts=[8 12 16 24 32 48 64]; else, counts=[9 13 17 25 33 49 65 97 129 193 257]; end
                for count=counts
                    if direction=="horizontal", grid=[count count referenceNz]; else, grid=[64 64 count]; end
                    actual=WVInternal.evaluateBoussinesqRHSAssessment(p,grid);
                    report=WVInternal.assessBoussinesqRHSResolution(actual,reference,controls);
                    for j=1:height(report.rows)
                        item=table2struct(report.rows(j,:)); item.profile=profile; item.amplitude=amplitude; item.time=time; item.direction=direction; item.count=count; item.status=report.status; item.referenceNz=referenceNz;
                        family=item.family;
                        noB=actual.tendency.(family)-actual.buoyancy.(family);
                        refNoB=reference.tendency.(family)-reference.buoyancy.(family);
                        item.withoutBuoyancyError=norm(noB-refNoB,'fro')/max(item.referenceNorm,1e-18); item.minimumGamma=actual.minimumGamma; item.maximumSSHOverDepth=actual.maximumSSHOverDepth;
                        if isempty(rows), rows=item; else, rows(end+1)=item; end %#ok<AGROW>
                    end
                    M=interpolate(size(actual.source.u,1),size(reference.source.u,1));
                    for field=["u","v","w","eta"]
                        a=M*actual.source.(field); b=reference.source.(field);
                        item=struct(profile=profile,amplitude=amplitude,time=time,direction=direction,count=count,field=field,absoluteError=norm(a-b,'fro'),referenceNorm=norm(b,'fro'));
                        if isempty(sourceRows), sourceRows=item; else, sourceRows(end+1)=item; end %#ok<AGROW>
                    end
                    fprintf('evaluated %s a%g t%g %s %d %.3g\n',profile,amplitude,time,direction,count,max(report.rows.relativeError));
                end
            end
            writetable(struct2table(rows),fullfile(output,'convergence.csv'));
            writetable(struct2table(references),fullfile(output,'references.csv'));
            writetable(struct2table(sourceRows),fullfile(output,'sources.csv'));
        end
    end
end
end
function M=interpolate(n,m)
x=-cos(pi*(0:n-1)'/(n-1)); y=-cos(pi*(0:m-1)'/(m-1)); b=(-1).^(0:n-1)'; b([1 end])=b([1 end])/2; M=zeros(m,n);
for j=1:m
    [d,k]=min(abs(y(j)-x)); if d<32*eps, M(j,k)=1; else, row=b./(y(j)-x); M(j,:)=row.'/sum(row); end
end
end
