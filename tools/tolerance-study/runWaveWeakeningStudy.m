function results = runWaveWeakeningStudy(outputFolder)
% Hold balanced coefficients and dimensional tolerance scales fixed while reducing waves.
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
wvt=makeToleranceBoussinesq();
base=wvt.coefficientState(); initialTime=wvt.t; finalTime=200;
energy=wvt.coefficientAbsoluteTolerances(1);
invariant=invariantTolerances(wvt,energy);
scales=struct();
for name=string(fieldnames(energy)).'
    if isempty(energy.(name)), scales.(name)=1; continue; end
    scales.(name)=energy.(name)(1)/invariant.(name)(1);
    invariant.(name)=scales.(name)*invariant.(name);
end
save(fullfile(outputFolder,'fixed-controls.mat'),'base','energy','invariant','scales','initialTime','finalTime');
rows=struct([]);
for waveAmplitude=[1 .1 .01 0]
    initial=base;
    initial.Aw_p=waveAmplitude*base.Aw_p;
    initial.Aw_m=waveAmplitude*base.Aw_m;
    reference=trajectory(wvt,initial,initialTime,finalTime,energy,1e-11,1e-11);
    tighter=trajectory(wvt,initial,initialTime,finalTime,energy,1e-12,1e-12);
    referenceError=physicalError(reference.fields,tighter.fields);
    assert(referenceError.maximum<1e-5,'WaveWeakening:Reference','Time reference uncertainty exceeds one tenth of the tighter target.');
    save(fullfile(outputFolder,sprintf('reference-%g.mat',waveAmplitude)),'reference','tighter','referenceError','-v7.3');
    for policy=["energy","invariant"]
        if policy=="energy", tolerances=energy; else, tolerances=invariant; end
        for absoluteScale=[1e-2 1e-3 1e-4]
            actual=trajectory(wvt,initial,initialTime,finalTime,tolerances,absoluteScale,1e-9);
            error=physicalError(actual.fields,tighter.fields);
            row=struct(waveAmplitude=waveAmplitude,waveEnergyFraction=waveAmplitude^2,policy=policy,absoluteScale=absoluteScale,relativeTolerance=1e-9,maximumError=error.maximum,boundaryError=error.boundary,pvError=error.q,velocityError=error.velocity,displacementError=error.eta,rhs=actual.rhs,acceptedSteps=actual.acceptedSteps,rejectedSteps=actual.rejectedSteps,runtime=actual.runtime,referenceError=referenceError.maximum);
            rows=[rows;row]; %#ok<AGROW> Twenty-four bounded comparison rows.
            save(fullfile(outputFolder,sprintf('trial-%g-%s-%g.mat',waveAmplitude,policy,absoluteScale)),'actual','error','-v7.3');
            fprintf('wave %.2g %s %.0e: error %.3g, RHS %d\n',waveAmplitude,policy,absoluteScale,error.maximum,actual.rhs);
            writetable(struct2table(rows),fullfile(outputFolder,'wave-weakening.csv'));
        end
    end
end
results=struct2table(rows);
end

function result=trajectory(wvt,initial,t0,finalTime,tolerances,amplitude,relativeTolerance)
setState(wvt,initial); wvt.t=t0;
model=WVModel(wvt);
model.setupIntegrator(integratorType="adaptive",absTolerance=1e-6,relTolerance=relativeTolerance);
alpha=[];
for annotation=wvt.coefficientStateAnnotations()
    values=tolerances.(annotation.name); alpha=[alpha;values(:)]; %#ok<AGROW> One setup allocation per family.
end
model.odeOptions=odeset(model.odeOptions,'AbsTol',amplitude*alpha,'MaxStep',finalTime-t0,'InitialStep',6);
if isa(wvt,'WVTransformFreeSurfaceQG'), initialBudget=wvt.quadraticDiagnostics(); else, initialBudget=wvt.nonlinearEnergy(); end
model.odeOptions=odeset(model.odeOptions,'Stats','on');
started=tic;
log=evalc('model.integrateToTime(finalTime,shouldShowIntegrationDiagnostics=false);');
runtime=toc(started);
accepted=regexp(log,'(\d+) successful steps','tokens','once');
rejected=regexp(log,'(\d+) failed attempts','tokens','once');
assert(~isempty(accepted) && ~isempty(rejected),'ToleranceStudy:MissingStats','ode78 did not report accepted/rejected step counts.');
if isa(wvt,'WVTransformFreeSurfaceQG'), finalBudget=wvt.quadraticDiagnostics(); else, finalBudget=wvt.nonlinearEnergy(); end
result=struct(fields=physicalFields(wvt),state=wvt.coefficientState(),rhs=double(model.nFluxComputations),runtime=runtime,acceptedSteps=str2double(accepted{1}),rejectedSteps=str2double(rejected{1}),initialBudget=initialBudget,finalBudget=finalBudget);
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
    denominator=norm(b.(name)(:));
    if denominator<1e-12
        errors.(name)=max(abs(a.(name)-b.(name)),[],'all');
    else
        errors.(name)=norm(a.(name)(:)-b.(name)(:))/denominator;
    end
end
errors.maximum=max(cell2mat(struct2cell(errors)));
end
