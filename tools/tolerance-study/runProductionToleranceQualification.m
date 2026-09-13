function results=runProductionToleranceQualification(outputFolder,options)
% Qualify the public family policy against independently tightened references.
arguments (Input)
    outputFolder (1,1) string
    options.surfaceReferenceFolder (1,1) string = ""
    options.cases (1,:) string = ["surface","bottom"]
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
rows=struct([]);
for caseName=options.cases
    grid=[32 32 65]; if caseName=="bottom", grid=[16 16 65]; end
    [wvt,scale]=makeEvolvingToleranceBoussinesq(gridSize=grid,activeBoundary=caseName);
    initial=wvt.coefficientState(); duration=scale.time;
    if caseName=="surface" && strlength(options.surfaceReferenceFolder)>0
        controls=load(fullfile(options.surfaceReferenceFolder,'fixed-controls.mat'));
        assert(isequaln(initial,controls.base),'ToleranceQualification:ReferenceMismatch','Initial states must match exactly.');
        data=load(fullfile(options.surfaceReferenceFolder,'reference-1.mat'));
        reference=data.reference; tighter=data.tighter;
    else
        reference=trajectory(wvt,initial,duration,1e-8,1e-10,"energy");
        tighter=trajectory(wvt,initial,duration,1e-9,1e-11,"energy");
    end
    uncertainty=physicalError(reference.fields,tighter.fields);
    assert(uncertainty.maximum<1e-4,'ToleranceQualification:ReferenceUncertainty','Tighten the time reference.');
    previous=Inf;
    for absoluteScale=[1e-6,1e-7]
        actual=trajectory(wvt,initial,duration,absoluteScale,1e-3,"family");
        errors=physicalError(actual.fields,tighter.fields);
        assert(errors.maximum<1e-3 && errors.maximum<previous,'ToleranceQualification:Accuracy','Recommended settings must pass and tightening must improve error.');
        previous=errors.maximum;
        a=actual.fields; b=tighter.fields;
        if ~isfield(b,'ssh')
            setState(wvt,tighter.state); wvt.t=duration;
            f=wvt.reconstructFields("ssh"); b.ssh=f.ssh;
        end
        weights=reshape(wvt.verticalQuadratureWeights,1,1,[]);
        normEnergy=@(f) .5*mean(sum(weights.*(sum(abs(f.velocity).^2,4)+reshape(wvt.N2,1,1,[]).*abs(f.eta).^2),3),'all')+.5*wvt.g*mean(abs(f.ssh).^2,'all');
        difference=struct(velocity=a.velocity-b.velocity,eta=a.eta-b.eta,ssh=a.ssh-b.ssh);
        energyError=sqrt(normEnergy(difference)/normEnergy(b));
        [~,index]=max(abs(tighter.state.Aw_p(:)));
        phase=abs(angle(actual.state.Aw_p(index)*conj(tighter.state.Aw_p(index))));
        row=struct(caseName=caseName,absoluteScale=absoluteScale,relativeTolerance=1e-3,maximumError=errors.maximum,boundaryError=errors.boundary,pvError=errors.q,velocityError=errors.velocity,displacementError=errors.eta,positiveEnergyError=energyError,wavePhaseError=phase,referenceUncertainty=uncertainty.maximum,rhs=actual.rhs,runtime=actual.runtime,boundaryChange=actual.boundaryChange,energyBudgetDrift=actual.energyBudgetDrift);
        rows=[rows;row]; %#ok<AGROW> Four bounded qualification rows.
        save(fullfile(outputFolder,sprintf('%s-%g.mat',caseName,absoluteScale)),'actual','reference','tighter','errors','uncertainty','scale','-v7.3');
        writetable(struct2table(rows),fullfile(outputFolder,'production-qualification.csv'));
        fprintf('%s %.0e: field error %.4g; reference %.4g; RHS %d\n',caseName,absoluteScale,errors.maximum,uncertainty.maximum,actual.rhs);
    end
end
results=struct2table(rows);
end

function result=trajectory(wvt,initial,duration,absoluteScale,relativeTolerance,policy)
setState(wvt,initial); wvt.t=0; initialFields=physicalFields(wvt); initialBudget=wvt.nonlinearEnergy();
model=WVModel(wvt);
model.setupIntegrator(tolerancePolicy=policy,absTolerance=absoluteScale,relTolerance=relativeTolerance);
started=tic; model.integrateToTime(duration,shouldShowIntegrationDiagnostics=false); runtime=toc(started);
fields=physicalFields(wvt); finalBudget=wvt.nonlinearEnergy();
result=struct(fields=fields,state=wvt.coefficientState(),rhs=double(model.nFluxComputations),runtime=runtime);
result.boundaryChange=norm(fields.boundary(:)-initialFields.boundary(:))/norm(reshape(initialFields.boundary-mean(initialFields.boundary,[1 2]),[],1));
result.energyBudgetDrift=(finalBudget.totalEnergy-initialBudget.totalEnergy)/initialBudget.totalEnergy;
end

function setState(wvt,state)
for name=string(fieldnames(state)).', wvt.(name)=state.(name); end
end

function fields=physicalFields(wvt)
f=wvt.reconstructFields(["qgpv","u","v","w","eta","ssh"]);
fields=struct(q=f.qgpv,velocity=cat(4,f.u,f.v,f.w),boundary=cat(3,f.eta(:,:,end)-f.ssh,f.eta(:,:,1)),eta=f.eta,ssh=f.ssh);
end

function errors=physicalError(a,b)
errors=struct();
for name=["q","velocity","boundary","eta"]
    reference=b.(name);
    if name=="boundary", reference=reference-mean(reference,[1 2]); end
    denominator=norm(reference(:));
    if denominator<1e-12
        errors.(name)=max(abs(a.(name)-b.(name)),[],'all');
    else
        errors.(name)=norm(a.(name)(:)-b.(name)(:))/denominator;
    end
end
errors.maximum=max(cell2mat(struct2cell(errors)));
end
