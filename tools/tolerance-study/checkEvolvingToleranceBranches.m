function results=checkEvolvingToleranceBranches(outputFolder)
% Audit absolute/relative branch selection for an evolving zero-initial-wave state.
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
prepareToleranceTrace(fullfile(outputFolder,'solver'));
verifyToleranceTrace();
[wvt,scale]=makeEvolvingToleranceBoussinesq();
initial=wvt.coefficientState(); initial.Aw_p(:)=0; initial.Aw_m(:)=0;
energy=wvt.coefficientAbsoluteTolerances(1);
rows=struct([]);
for R=[1e-9 1e-3]
    actual=trajectory(wvt,initial,0,scale.time,energy,1e-5,R);
    branch=actual.traceBranches;
    [~,family]=max(actual.trace(:,4:end),[],2);
    row=struct(relativeTolerance=R,rhs=actual.rhs,attempts=size(branch,1),absoluteControlled=nnz(branch(:,2)<=1),relativeControlled=nnz(branch(:,2)>1),maximumControllerRelativeToAbsolute=max(branch(:,2)),maximumAnyRelativeToAbsolute=max(branch(:,3)),waveControlled=sum(family<=2));
    rows=[rows;row]; %#ok<AGROW> Two relative-tolerance settings.
    save(fullfile(outputFolder,sprintf('branch-%g.mat',R)),'actual','-v7.3');
    writetable(struct2table(rows),fullfile(outputFolder,'branches.csv'));
    fprintf('R %.0e: %d absolute-controlled, %d relative-controlled attempts; RHS %d\n',R,row.absoluteControlled,row.relativeControlled,row.rhs);
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
