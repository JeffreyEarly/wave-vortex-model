function results=qualifyThermalIntegration(outputDirectory)
% Qualify actual WVModel seasonal evolution against the preserved reference.
arguments
    outputDirectory (1,1) string
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
sourceRoot=fileparts(fileparts(mfilename('fullpath')));
oldPath=path; cleanup=onCleanup(@()path(oldPath));
addpath(fullfile(sourceRoot,'Documentation','Experiments','Diffusion'));
baseline=TestCompleteThermalModes.runCompleteThermalStudy(fullfile(outputDirectory,'reference'));
fineReference=TestCompleteThermalModes.runCompleteThermalStudy(fullfile(outputDirectory,'refined-reference'),counts=257,referenceCount=513,assemblyQuadratureCount=4097);
rows=table(); refinement=table(); referenceControl=table(); statistics=table();
coarseStates=cell(1,numel(baseline.options.days));
for n=[129 257 385]
    [states,counts]=evolve(n,2049,baseline,outputDirectory);
    statistics=[statistics;counts]; %#ok<AGROW>
    for j=1:numel(states)
        reference=baseline.referenceStates{j}; original=baseline.states{find(baseline.options.counts==n,1),j};
        rows=[rows;compare(states{j},original,reference,baseline.weights,4000,n,baseline.options.days(j))]; %#ok<AGROW>
    end
    if n==257, coarseStates=states; end
end
[fineStates,counts]=evolve(257,4097,baseline,outputDirectory); statistics=[statistics;counts];
for j=1:numel(fineStates)
    day=baseline.options.days(j); ref=baseline.referenceStates{j};
    refinement=[refinement;compare(coarseStates{j},fineStates{j},ref,baseline.weights,4000,257,day)]; %#ok<AGROW>
    referenceControl=[referenceControl;compare(ref,fineReference.referenceStates{j},ref,baseline.weights,4000,513,day)]; %#ok<AGROW>
end
writetable(rows,fullfile(outputDirectory,'model-response.csv'));
writetable(refinement,fullfile(outputDirectory,'model-assembly-refinement.csv'));
writetable(referenceControl,fullfile(outputDirectory,'reference-refinement.csv'));
writetable(statistics,fullfile(outputDirectory,'model-steps.csv'));
results=struct(response=rows,assembly=refinement,reference=referenceControl,statistics=statistics);
assert(all(rows.prototypeRatio<.2),'Actual model differs from the preserved prototype.');
assert(all(rows.referenceRatio(rows.count>=257)<=1),'Qualified thermal resolutions failed.');
assert(any(rows.referenceRatio(rows.count==129)>1),'Historical unresolved case was not preserved.');
assert(all(refinement.prototypeRatio<.2),'Fixed-space assembly refinement failed.');
assert(all(referenceControl.prototypeRatio<.2),'Independent reference refinement failed.');
end

function [states,statistics]=evolve(n,assembly,baseline,outputDirectory)
D=4000; N20=(5.2e-3)^2; a=1/1300; wavelength=100e3; kh=2*pi/wavelength;
sampling=513; if n>257, sampling=1025; end
w=WVTransformFreeSurfaceThermalQG.fromStratification([wavelength wavelength D],[4 4 sampling],N2Function=@(z)N20*exp(2*a*z),thermalModeCount=n,mdaModeCount=4,assemblyQuadratureCount=assembly);
file=fullfile(outputDirectory,sprintf('construction-%d-%d.json',n,assembly));
fid=fopen(file,'w'); fileCleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(w.constructionAssessment,PrettyPrint=true)); clear fileCleanup
pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1);
% The reduced periodic box carries exactly the physical mode-5 wavevector.
padded=repmat(pattern,1,1,w.Nz); hat=w.transformFromSpatialDomainWithFourier(padded);
[~,column]=max(abs(hat(1,w.klNonzero))); index=w.klNonzero(column); radius=w.klNonzeroKhUniqueIndex(column);
assert(abs(hypot(w.k(index),w.l(index))-kh)<1e-14 && abs(abs(hat(1,index))-.5)<1e-14);
period=365.25*86400; w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=10*pi/period,period=period));
model=WVModel(w); model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=86400,maximumStep=8*86400);
r=WVInternal.thermalPolynomialFields(baseline.z,n,D,N20,a,kh,w.f,w.g);
e=WVInternal.thermalPolynomialFields([0;-D],n,D,N20,a,kh,w.f,w.g);
weights=baseline.weights; states=cell(1,numel(baseline.options.days)); statistics=table();
for j=1:numel(states)
    day=baseline.options.days(j); model.integrateToTime(day*86400,shouldShowIntegrationDiagnostics=false);
    c=w.thermalToPolynomial(:,:,radius)*(w.Ath(:,column)/hat(1,index));
    states{j}=struct(q=r.qgpv*c,b=r.buoyancy*c,ssh=r.ssh*c,endpoint=e.eta_i*c,energy=[sqrt(weights)*kh.*(r.psi*c);sqrt(weights.*(N20*exp(2*a*baseline.z))).*(r.eta*c);sqrt(w.g)*(r.ssh*c)]);
    st=model.exponentialStatistics;
    statistics=[statistics;table(n,sampling,assembly,day,st.acceptedSteps,st.rejectedSteps,st.maximumCFL,VariableNames={'count','sampling','assembly','day','accepted','rejected','maximumCFL'})]; %#ok<AGROW>
end
end

function rows=compare(actual,original,reference,w,D,n,day)
names=["qgpv","buoyancy","ssh","surfaceAnomaly","bottomAnomaly","physicalEnergyNorm"]';
magnitude=norms(reference,w,D);
allowance=[1e-13;1e-10;1e-8;1e-8;1e-8;0]+[.05;.001;.0001;.001;.001;.0001].*magnitude;
prototypeError=difference(actual,original,w,D); referenceError=difference(actual,reference,w,D);
rows=table(repmat(n,6,1),repmat(day,6,1),names,prototypeError,referenceError,allowance,prototypeError./allowance,referenceError./allowance,VariableNames={'count','day','observable','prototypeError','referenceError','allowance','prototypeRatio','referenceRatio'});
end
function v=difference(a,b,w,D)
names=fieldnames(a); d=struct();
for k=1:numel(names), d.(names{k})=a.(names{k})-b.(names{k}); end
v=norms(d,w,D);
end
function v=norms(a,w,D)
v=[sqrt(sum(w.*abs(a.q).^2)/(2*D));sqrt(sum(w.*abs(a.b).^2)/(2*D));abs(a.ssh)/sqrt(2);abs(a.endpoint)/sqrt(2);norm(a.energy)/2];
end
