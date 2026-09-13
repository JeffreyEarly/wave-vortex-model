function results = runEvolvingToleranceStudy(outputFolder,options)
% Hold balanced coefficients and dimensional tolerance scales fixed while reducing waves.
arguments (Input)
    outputFolder (1,1) string
    options.waveAmplitudes (1,:) double = [1 .1 .01 0]
    options.absoluteScales (1,:) double = 1e-5
    options.turnovers (1,1) double = 1
    options.gridSize (1,3) double = [32 32 65]
    options.referenceScale (1,1) double = 1e-6
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
prepareToleranceTrace(fullfile(outputFolder,'solver'));
[wvt,scale]=makeEvolvingToleranceBoussinesq(gridSize=options.gridSize);
base=wvt.coefficientState(); initialTime=wvt.t; finalTime=initialTime+options.turnovers*scale.time;
energy=wvt.coefficientAbsoluteTolerances(1);
invariant=invariantTolerances(wvt,energy);
scales=struct();
for name=string(fieldnames(energy)).'
    if isempty(energy.(name)), scales.(name)=1; continue; end
    scales.(name)=energy.(name)(1)/invariant.(name)(1);
    invariant.(name)=scales.(name)*invariant.(name);
end
if isfile(fullfile(outputFolder,'fixed-controls.mat'))
    previous=load(fullfile(outputFolder,'fixed-controls.mat'));
    assert(isequaln(previous.base,base) && isequaln(previous.energy,energy) && isequaln(previous.invariant,invariant) && previous.initialTime==initialTime && previous.finalTime==finalTime && isequal(previous.options.gridSize,options.gridSize),'ToleranceStudy:CacheMismatch','Use a new output folder after changing the physical setup.');
end
save(fullfile(outputFolder,'fixed-controls.mat'),'base','energy','invariant','scales','initialTime','finalTime','scale','options');
rows=struct([]);
if isfile(fullfile(outputFolder,'evolving-comparison.csv'))
    rows=table2struct(readtable(fullfile(outputFolder,'evolving-comparison.csv'),TextType='string'));
end
for waveAmplitude=options.waveAmplitudes
    initial=base;
    initial.Aw_p=waveAmplitude*base.Aw_p;
    initial.Aw_m=waveAmplitude*base.Aw_m;
    for refinement=0:2
        qualifiedReferenceScale=options.referenceScale/10^refinement;
        reference=cachedReference(wvt,initial,initialTime,finalTime,energy,qualifiedReferenceScale,1e-10,outputFolder,waveAmplitude);
        tighter=cachedReference(wvt,initial,initialTime,finalTime,energy,qualifiedReferenceScale/10,1e-10,outputFolder,waveAmplitude);
        referenceError=physicalError(reference.fields,tighter.fields);
        if referenceError.maximum<1e-5, break; end
        fprintf('Wave %.2g reference discrepancy %.3g; tightening reference.\n',waveAmplitude,referenceError.maximum);
    end
    assert(referenceError.maximum<1e-5,'WaveWeakening:Reference','Time reference uncertainty exceeds one tenth of the tighter target.');
    save(fullfile(outputFolder,sprintf('reference-%g.mat',waveAmplitude)),'reference','tighter','referenceError','qualifiedReferenceScale','-v7.3');
    for policy=["energy","invariant"]
        if policy=="energy", tolerances=energy; else, tolerances=invariant; end
        for absoluteScale=options.absoluteScales
            actual=trajectory(wvt,initial,initialTime,finalTime,tolerances,absoluteScale,1e-9);
            error=physicalError(actual.fields,tighter.fields);
            row=struct(waveAmplitude=waveAmplitude,waveEnergyFraction=waveAmplitude^2,policy=policy,absoluteScale=absoluteScale,relativeTolerance=1e-9,maximumError=error.maximum,boundaryError=error.boundary,pvError=error.q,velocityError=error.velocity,displacementError=error.eta,rhs=actual.rhs,acceptedSteps=actual.acceptedSteps,rejectedSteps=actual.rejectedSteps,runtime=actual.runtime,referenceError=referenceError.maximum);
            names=string({wvt.coefficientStateAnnotations().name});
            [~,controller]=max(actual.trace(:,4:end),[],2);
            for k=1:numel(names)
                row.("controlled_"+names(k))=sum(controller==k);
            end
            row.boundaryChange=norm(actual.fields.boundary(:)-actual.initialFields.boundary(:))/norm(reshape(actual.initialFields.boundary-mean(actual.initialFields.boundary,[1 2]),[],1));
            if ~isempty(rows)
                duplicate=[rows.waveAmplitude]==waveAmplitude & string({rows.policy})==policy & [rows.absoluteScale]==absoluteScale;
                rows=rows(~duplicate);
            end
            rows=[rows;row]; %#ok<AGROW> Twenty-four bounded comparison rows.
            save(fullfile(outputFolder,sprintf('trial-%g-%s-%g.mat',waveAmplitude,policy,absoluteScale)),'actual','error','-v7.3');
            fprintf('wave %.2g %s %.0e: error %.3g, RHS %d\n',waveAmplitude,policy,absoluteScale,error.maximum,actual.rhs);
            writetable(struct2table(rows),fullfile(outputFolder,'evolving-comparison.csv'));
        end
    end
end
results=struct2table(rows);
end

function result=trajectory(wvt,initial,t0,finalTime,tolerances,amplitude,relativeTolerance)
setState(wvt,initial); wvt.t=t0;
initialFields=physicalFields(wvt);
model=WVModel(wvt);
model.setupIntegrator(integratorType="adaptive",absTolerance=1e-6,relTolerance=relativeTolerance);
alpha=[];
for annotation=wvt.coefficientStateAnnotations()
    values=tolerances.(annotation.name); alpha=[alpha;values(:)]; %#ok<AGROW> One setup allocation per family.
end
model.odeOptions=odeset(model.odeOptions,'AbsTol',amplitude*alpha,'MaxStep',finalTime-t0,'InitialStep',6);
global toleranceTrace %#ok<GVMIS> Temporary solver probe shared with the unmodified solver interface.
toleranceTrace=struct(first=model.arrayStartIndex,last=model.arrayEndIndex,rows=zeros(0,3+numel(model.arrayStartIndex)));
model.odeIntegrator=@tracedOde78;
if isa(wvt,'WVTransformFreeSurfaceQG'), initialBudget=wvt.quadraticDiagnostics(); else, initialBudget=wvt.nonlinearEnergy(); end
model.odeOptions=odeset(model.odeOptions,'Stats','on');
started=tic;
log=evalc('model.integrateToTime(finalTime,shouldShowIntegrationDiagnostics=false);');
runtime=toc(started);
accepted=regexp(log,'(\d+) successful steps','tokens','once');
rejected=regexp(log,'(\d+) failed attempts','tokens','once');
assert(~isempty(accepted) && ~isempty(rejected),'ToleranceStudy:MissingStats','ode78 did not report accepted/rejected step counts.');
if isa(wvt,'WVTransformFreeSurfaceQG'), finalBudget=wvt.quadraticDiagnostics(); else, finalBudget=wvt.nonlinearEnergy(); end
result=struct(initialFields=initialFields,trace=toleranceTrace.rows,traceBranches=toleranceTrace.branches,fields=physicalFields(wvt),state=wvt.coefficientState(),rhs=double(model.nFluxComputations),runtime=runtime,acceptedSteps=str2double(accepted{1}),rejectedSteps=str2double(rejected{1}),initialBudget=initialBudget,finalBudget=finalBudget);
end

function alpha=invariantTolerances(wvt,energy)
alpha=energy;
if isa(wvt,'WVTransformFreeSurfaceQG')
    metrics=wvt.physicalMetricOperators();
    pages=wvt.klNonzeroKhUniqueIndex;
    for column=1:numel(pages)
        p=metrics.pages{pages(column)};
        weights=real(diag(p.kineticEnergy+p.interiorPotentialEnergy+p.surfacePotentialEnergy));
        alpha.Ag_q(:,column)=energy.Ag_q(:,column).*sqrt(weights(1:wvt.apvModeCount)/wvt.Lz);
        for endpoint=1:wvt.activeEndpointCount
            factor=(wvt.f/(wvt.g*wvt.khNonzero(column)^2))^2;
            alpha.Ag_0(endpoint,column)=energy.Ag_0(endpoint,column)*sqrt(weights(wvt.apvModeCount+endpoint)/factor);
        end
    end
else
    empty=wvt.coefficientState();
    for name=string(fieldnames(empty)).', empty.(name)=zeros(size(empty.(name))); end
    for name=["Ag_q","Ag_0"]
        for mode=1:size(empty.(name),1)
            state=empty; state.(name)(mode,:)=1;
            f=wvt.reconstructSpectralState(state=state);
            E=sum(wvt.verticalQuadratureWeights.*(abs(f.u).^2+abs(f.v).^2+abs(f.w).^2+wvt.N2.*abs(f.eta).^2),1)+wvt.g*abs(f.ssh(end,:)).^2;
            if name=="Ag_q"
                C=sum(wvt.verticalQuadratureWeights.*abs(f.qgpv).^2,1);
            elseif wvt.activeEndpoint(mode)==1
                C=abs(f.eta(end,:)-f.ssh(end,:)).^2;
            else
                C=abs(f.eta(1,:)).^2;
            end
            columns=wvt.klNonzero;
            alpha.(name)(mode,:)=energy.(name)(mode,:).*sqrt(E(columns)./C(columns));
        end
    end
end
end

function setState(wvt,state)
for name=string(fieldnames(state)).', wvt.(name)=state.(name); end
end

function fields=physicalFields(wvt)
if isa(wvt,'WVTransformFreeSurfaceQG')
    [q,u,v,b]=wvt.quasigeostrophicSpatialState();
    fields=struct(q=q,velocity=cat(4,u,v),boundary=b,eta=wvt.eta);
else
    f=wvt.reconstructFields(["qgpv","u","v","w","eta","ssh"]);
    fields=struct(q=f.qgpv,velocity=cat(4,f.u,f.v,f.w),boundary=cat(3,f.eta(:,:,end)-f.ssh,f.eta(:,:,1)),eta=f.eta);
end
end

function errors=physicalError(a,b)
errors=struct();
for name=string(fieldnames(a)).'
    referenceField=b.(name);
    if name=="boundary", referenceField=referenceField-mean(referenceField,[1 2]); end
    denominator=norm(referenceField(:));
    if denominator<1e-12
        errors.(name)=max(abs(a.(name)-b.(name)),[],'all');
    else
        errors.(name)=norm(a.(name)(:)-b.(name)(:))/denominator;
    end
end
errors.maximum=max(cell2mat(struct2cell(errors)));
end

function reference=cachedReference(wvt,initial,t0,tf,energy,absoluteScale,relativeTolerance,folder,waveAmplitude)
file=fullfile(folder,sprintf('time-reference-%g-%g-%g.mat',waveAmplitude,absoluteScale,relativeTolerance));
if isfile(file)
    saved=load(file); reference=saved.reference;
else
    reference=trajectory(wvt,initial,t0,tf,energy,absoluteScale,relativeTolerance);
    save(file,'reference','-v7.3');
end
end
