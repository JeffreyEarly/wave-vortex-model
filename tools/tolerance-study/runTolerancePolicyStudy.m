function results = runTolerancePolicyStudy(outputFolder)
% Compare physical errors with the same WVModel ode78 integration path.
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
folder=fileparts(mfilename('fullpath'));
addpath(fullfile(folder,'..','..','Documentation','Examples'));
rows=struct([]);
for caseName=["boundary","mixedQG","boussinesq"]
    if caseName=="boussinesq"
        wvt=makeToleranceBoussinesq(); finalTime=200;
    else
        [wvt,scale]=makeBoundaryVortex(); finalTime=2*scale.time;
        if caseName=="mixedQG"
            initial=wvt.coefficientState();
            [~,u,v]=wvt.quasigeostrophicSpatialState();
            boundaryKE=mean(u.^2+v.^2,'all');
            wvt.removeAll();
            column=find(round(wvt.kNonzero*wvt.Lx/(2*pi))==1 & round(wvt.lNonzero*wvt.Ly/(2*pi))==2,1);
            wvt.Ag_q(1,column)=1;
            [~,u,v]=wvt.quasigeostrophicSpatialState();
            initial.Ag_q=wvt.Ag_q*sqrt(boundaryKE/mean(u.^2+v.^2,'all'));
            setState(wvt,initial);
        end
    end
    initial=wvt.coefficientState(); initialTime=wvt.t;
    energy=wvt.coefficientAbsoluteTolerances(1);
    invariant=invariantTolerances(wvt,energy);
    % Calibrate each dimensional family scale at a fixed represented low mode.
    % This matches its coefficient floor there, not the policies at every scale.
    scales=struct();
    for name=string(fieldnames(energy)).'
        if isempty(energy.(name)), scales.(name)=1; continue; end
        scales.(name)=energy.(name)(1)/invariant.(name)(1);
        invariant.(name)=scales.(name)*invariant.(name);
    end
    reference=trajectory(wvt,initial,initialTime,finalTime,energy,1e-11,1e-11);
    tighter=trajectory(wvt,initial,initialTime,finalTime,energy,1e-12,1e-12);
    referenceError=physicalError(reference.fields,tighter.fields);
    assert(referenceError.maximum<1e-5,'ToleranceStudy:Reference','Time reference does not resolve the tighter target.');
    save(fullfile(outputFolder,caseName+'-reference.mat'),'reference','tighter','referenceError','scales','-v7.3');
    for policy=["energy","invariant"]
        if policy=="energy", tolerances=energy; else, tolerances=invariant; end
        for amplitude=[1e-1 1e-2 1e-3 1e-4]
            actual=trajectory(wvt,initial,initialTime,finalTime,tolerances,amplitude,1e-9);
            error=physicalError(actual.fields,tighter.fields);
            row=struct(caseName=caseName,policy=policy,absoluteScale=amplitude,relativeTolerance=1e-9,error=error.maximum,boundaryError=error.boundary,pvError=error.q,velocityError=error.velocity,displacementError=error.eta,rhs=actual.rhs,runtime=actual.runtime,acceptedSteps=actual.acceptedSteps,rejectedSteps=actual.rejectedSteps);
            rows=[rows;row]; %#ok<AGROW> Bounded experiment rows.
            save(fullfile(outputFolder,sprintf('%s-%s-%g.mat',caseName,policy,amplitude)),'actual','error','-v7.3');
            fprintf('%s %s %.1e: error %.3g, RHS %d\n',caseName,policy,amplitude,error.maximum,actual.rhs);
            writetable(struct2table(rows),fullfile(outputFolder,'comparison.csv'));
        end
    end
    actual=trajectory(wvt,initial,initialTime,finalTime,energy,1e-6,1e-3);
    error=physicalError(actual.fields,tighter.fields);
    row=struct(caseName=caseName,policy="energy-practical",absoluteScale=1e-6,relativeTolerance=1e-3,error=error.maximum,boundaryError=error.boundary,pvError=error.q,velocityError=error.velocity,displacementError=error.eta,rhs=actual.rhs,runtime=actual.runtime,acceptedSteps=actual.acceptedSteps,rejectedSteps=actual.rejectedSteps);
    rows=[rows;row]; %#ok<AGROW> One production-default check.
    save(fullfile(outputFolder,caseName+"-practical.mat"),'actual','error','-v7.3');
    writetable(struct2table(rows),fullfile(outputFolder,'comparison.csv'));
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
model.odeOptions=odeset(model.odeOptions,'AbsTol',amplitude*alpha,'MaxStep',finalTime-t0);
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
