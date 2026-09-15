function report = qualifyThermalInvariantDamping(outputDirectory,options)
% Measure the bounded native thermal closure comparisons for issue #535.
%
% Invoke explicitly in a fresh, serial MATLAB process with the external
% guardThermalReadiness.py memory/time guard. Outputs must be outside the
% checkout. Small comparisons measure behavior, not campaign readiness.
%
% ```matlab
% qualifyThermalInvariantDamping('/private/tmp/thermal-invariants',phase="small")
% ```
% - Topic: Developer utilities
% - Parameter outputDirectory: new caller-selected output directory outside the checkout
% - Parameter options.phase: small nonlinear comparison, refinement, or target cost
% - Parameter options.inverseScale: zero for constant stratification, 1/1300 for exponential
% - Parameter options.thermalCount: 17 or 33 for the small comparison
% - Parameter options.weightMultiplier: common endpoint-weight sensitivity multiplier
% - Returns report: measured results; also saved incrementally outside the checkout
arguments (Input)
    outputDirectory (1,1) string
    options.phase (1,1) string {mustBeMember(options.phase,["small","refinement","cost","target-audit"])} = "small"
    options.inverseScale (1,1) double {mustBeReal,mustBeFinite} = 1/1300
    options.thermalCount (1,1) double {mustBeMember(options.thermalCount,[17,33])} = 17
    options.weightMultiplier (1,1) double {mustBeMember(options.weightMultiplier,[.1,1,10])} = 1
end
arguments (Output)
    report (1,1) struct
end
root=string(fileparts(fileparts(mfilename('fullpath'))));
if ~ismember(options.inverseScale,[0,1/1300])
    error('WV:InvariantQualificationProfile','Use inverseScale=0 or inverseScale=1/1300.');
end
destination=string(java.io.File(char(outputDirectory)).getCanonicalPath());
if destination==root || startsWith(destination,root+filesep)
    error('WV:InvariantQualificationOutput','Choose an output directory outside the checkout.');
end
if isfolder(destination) && numel(dir(destination))>2
    error('WV:InvariantQualificationOutput','Choose a new output directory.');
end
if ~isfolder(destination), mkdir(destination); end
threads=maxNumCompThreads(4); cleanup=onCleanup(@()maxNumCompThreads(threads));
report=struct(schema="thermal-invariant-qualification-v1",phase=options.phase, ...
    configuration=options,matlabVersion=string(version),threads=4,status="started");
originalDirectory=pwd;
directoryCleanup=onCleanup(@()cd(originalDirectory));
cd(root);
[revisionStatus,revision]=system('git rev-parse HEAD');
[statusResult,workingTree]=system('git status --porcelain');
clear directoryCleanup
if revisionStatus~=0, error('WV:InvariantQualificationRevision','Cannot identify the source revision.'); end
if statusResult~=0, error('WV:InvariantQualificationRevision','Cannot identify working-tree changes.'); end
report.sourceRevision=string(strtrim(revision));
report.internalModesPath=string(which('InternalModes'));
report.sourceIncludesUncommittedChanges=strlength(strtrim(string(workingTree)))>0;
writeReport(destination,report);
try
    if ismember(options.phase,["cost","target-audit"])
        report=costStudy(destination,report);
    elseif options.phase=="refinement"
        report=refinementStudy(destination,report);
    else
        report=smallStudy(destination,report);
    end
    report.status="completed";
catch exception
    % A failed phase does not return its local report. Preserve its latest
    % checkpoint before appending the failure, including completed timings.
    report=jsondecode(fileread(fullfile(destination,'summary.json')));
    report.status="failed";
    report.errorIdentifier=string(exception.identifier);
    report.errorMessage=string(exception.message);
    writeReport(destination,report);
    rethrow(exception);
end
writeReport(destination,report);
end

function w=smallTransform(n,a)
w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129], ...
    N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=n,mdaModeCount=2, ...
    kappa_z=1e-5,assemblyQuadratureCount=257,nonlinearQuadratureCount=257,shouldCheckQuadraticAliasing=true);
end

function normalization=populate(w)
% The same physical WKB-polynomial pressure is representable at either order.
% |P_j(s)|<=1 bounds the continuous velocity, rather than its sampled maximum.
modes=[1 0;1 1;2 1];
pressure=complex(zeros(w.thermalModeCount,3));
pressure([1 3],1)=[1;.4]; pressure(16,2)=.05; pressure(15,3)=.05i;
kh=hypot(2*pi*modes(:,1)/w.Lx,2*pi*modes(:,2)/w.Ly);
speedBound=2*sum(kh.'.*sum(abs(pressure),1));
endpoint=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
endpointBound=2*max(sum(abs(endpoint.eta_i*pressure),2));
factor=min(.01/speedBound,.009*w.Lz/max(endpointBound,realmin));
pressure=pressure*factor;
w.Ath(:)=0; w.Amda(:)=0;
for j=1:3
    col=find(w.kMode_wv(w.klNonzero)==modes(j,1) & w.lMode_wv(w.klNonzero)==modes(j,2));
    if ~isscalar(col), error('WV:InvariantQualificationSupport','A manufactured Fourier mode is unavailable.'); end
    p=w.klNonzeroKhUniqueIndex(col);
    w.Ath(:,col)=w.polynomialToThermal(:,:,p)*pressure(:,j);
end
normalization=struct(factor=factor,continuousSpeedBound=factor*speedBound, ...
    endpointDisplacementBound=factor*endpointBound,horizontalModes=modes, ...
    polynomialPressureReal=real(pressure),polynomialPressureImaginary=imag(pressure));
end

function report=smallStudy(folder,report)
c=report.configuration;
clock=tic; w=smallTransform(c.thermalCount,c.inverseScale);
cleanup=onCleanup(@()delete(w));
report.transformConstructionSeconds=toc(clock); report.normalization=populate(w);
clock=tic;
force=WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w,boundaryWeightMultiplier=c.weightMultiplier);
report.closureConstructionSeconds=toc(clock);
report.spectrum=describeSpectrum(force);
writetable(auditOperators(w,force),fullfile(folder,'operator-audit.csv'));
science=w.scientificState; initial=w.coefficientState(); canonical=force.thermalGeneralizedEnstrophyState;
writeReport(folder,report);
trajectories=struct(); summary=table();
for variant=["none","horizontal","native"]
    for step=[450 225]
        name=variant+"_"+step;
        local=WVTransformFreeSurfaceThermalQG(scientificState=science,coefficientState=initial);
        localCleanup=onCleanup(@()delete(local));
        local.addForcing(WVNonlinearAdvection(local));
        if variant=="horizontal"
            local.addForcing(ThermalInvariantQualificationDamping(local,canonical));
        elseif variant=="native"
            local.addForcing(WVAdaptiveDamping(local,thermalGeneralizedEnstrophyState=canonical));
        end
        model=WVModel(local); modelCleanup=onCleanup(@()delete(model));
        model.setupIntegrator(integratorType="exponential",maximumStep=step,initialStep=step,exponentialAdaptive=false);
        times=0:step:43200; inventories=zeros(numel(times),4); powers=[]; maxRate=0;
        statistics=struct(acceptedSteps=0,rejectedSteps=0,rhsEvaluations=0,acceptedStepSeconds=[],maximumCFL=0,maximumDampingNumber=0);
        clock=tic;
        for j=1:numel(times)
            if j>1
                model.integrateToTime(times(j),shouldShowIntegrationDiagnostics=false);
                statistics=accumulateStatistics(statistics,model.exponentialStatistics);
            end
            [~,speed,processes]=local.coefficientTendency();
            inventory=local.quadraticDiagnostics(tendency=processes.tendencies);
            fields=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"];
            if j==1, powers=zeros(numel(times),4,numel(processes.labels)); end
            for k=1:4
                inventories(j,k)=inventory.(fields(k));
                powers(j,k,:)=inventory.(fields(k)+"Tendency"); %#ok<AGROW> Full array allocated at the first observation.
            end
            if variant~="none"
                maxRate=max(maxRate,local.forcingWithName('adaptive damping').maximumExplicitDampingRate(struct(uvMax=speed)));
            end
        end
        wallSeconds=toc(clock);
        run=struct(times=times,inventory=inventories,powers=powers,labels=processes.labels, ...
            finalState=local.coefficientState(),statistics=statistics,wallSeconds=wallSeconds,maxDampingRate=maxRate);
        save(fullfile(folder,name+'.mat'),'run');
        writeBudgets(folder,name,run,canonical.boundaryWeights);
        trajectories.(name)=run.finalState;
        row=table(variant,step,wallSeconds,run.statistics.acceptedSteps,run.statistics.rejectedSteps, ...
            run.statistics.rhsEvaluations,maxRate,VariableNames={'variant','maximumStep','wallSeconds','acceptedSteps','rejectedSteps','rhsEvaluations','maximumDampingRate'});
        summary=[summary;row]; %#ok<AGROW> Six declared cases.
        writetable(summary,fullfile(folder,'integration.csv'));
        clear modelCleanup localCleanup model local
    end
end
comparison=table();
for variant=["none","horizontal","native"]
    reference=trajectories.(variant+"_225"); candidate=trajectories.(variant+"_450");
    error=stateDifference(w,candidate,reference);
    closureChange=stateDifference(w,reference,trajectories.none_225);
    comparison=[comparison;table(variant,error(1),error(2),closureChange(1),closureChange(2), ...
        VariableNames={'variant','temporalRelativeEnergyNorm','temporalLowDegreeRelativeEnergyNorm','closureRelativeEnergyNorm','closureLowDegreeRelativeEnergyNorm'})]; %#ok<AGROW>
end
writetable(comparison,fullfile(folder,'comparisons.csv'));
report.integration=table2struct(summary); report.comparisons=table2struct(comparison);
end

function writeBudgets(folder,name,run,alpha)
fields=["energy","interiorEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance","generalizedEnstrophy"];
inventory=[run.inventory,run.inventory(:,2)+run.inventory(:,3:4)*alpha(:)];
power=cat(2,run.powers,run.powers(:,2,:)+alpha(1)*run.powers(:,3,:)+alpha(2)*run.powers(:,4,:));
work=squeeze(trapz(run.times,power,1));
indices=unique([1:2:numel(run.times),numel(run.times)]);
coarse=squeeze(trapz(run.times(indices),power(indices,:,:),1));
rows=table();
for j=1:numel(fields)
    for p=1:numel(run.labels)
        rows=[rows;table(fields(j),run.labels(p),inventory(1,j),inventory(end,j),work(j,p),abs(work(j,p)-coarse(j,p)), ...
            inventory(end,j)-inventory(1,j)-sum(work(j,:)), ...
            VariableNames={'inventory','process','initialValue','finalValue','integratedPower','samplingUncertainty','budgetResidual'})]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(folder,name+'-budgets.csv'));
end

function errors=stateDifference(w,a,b)
% Compare complete physical energy and the common low-degree pressure part.
norms=zeros(2,2);
for p=1:numel(w.khUnique)
    [FE,~]=physicalFactors(w,p,513);
    columns=w.klNonzeroKhUniqueIndex==p;
    reference=w.thermalToPolynomial(:,:,p)*b.Ath(:,columns);
    difference=w.thermalToPolynomial(:,:,p)*(a.Ath(:,columns)-b.Ath(:,columns));
    for j=1:2
        if j==2, reference(4:end,:)=0; difference(4:end,:)=0; end
        norms(j,:)=norms(j,:)+[norm(FE*difference,'fro')^2,norm(FE*reference,'fro')^2];
    end
end
errors=sqrt(norms(:,1)./max(norms(:,2),realmin));
end

function records=auditOperators(w,force)
% Mapped physical audit using production field definitions. Independent
% analytic assembly is a separate obligation of the focused unit tests.
data=force.coefficientDampingData(); state=force.thermalGeneralizedEnstrophyState;
records=table();
for p=1:numel(w.khUnique)
    [FE,parts]=physicalFactors(w,p,max(513,2*w.assemblyQuadratureCount)); [~,R]=qr(FE,0);
    V=state.polynomialEigenvectors(:,:,p); P=state.polynomialDuals(:,:,p);
    rates=data.pages{p}.selectiveRates;
    native=V*(rates.*P);
    mapped=w.thermalToPolynomial(:,:,p)*applicationMatrix(data.pages{p},w.thermalModeCount)*w.polynomialToThermal(:,:,p);
    B=(R*mapped)/R;
    componentRates=zeros(1,3);
    H=zeros(size(R));
    for j=1:3
        F=parts{j}/R; S=F'*F;
        componentRates(j)=max(eig((S*B+B'*S)/2));
        weight=1; if j>1, weight=state.boundaryWeights(j-1); end
        H=H+weight*S;
    end
    energyGrowth=max(eig((B+B')/2)); invariantGrowth=max(eig((H*B+B'*H)/2));
    mappedError=norm(R*(mapped-native)/R,2)/max(max(abs(rates)),realmin);
    lambdaMin=min(data.pages{p}.eigenvalues(rates~=0));
    selectiveBound=max(eig((H*B+B'*H)/2/lambdaMin-(B+B')/2));
    rateScale=max(abs(rates)); lambdaScale=max(data.pages{p}.eigenvalues);
    columns=w.klNonzeroKhUniqueIndex==p;
    horizontalRate=max(abs(data.horizontalRates(columns)));
    rateBoundError=max(0,norm(B-horizontalRate*eye(size(B)),2)/(rateScale+horizontalRate)-1);
    normalized=[max(0,energyGrowth)/rateScale,max(0,invariantGrowth)/(lambdaScale*rateScale), ...
        max(0,selectiveBound)/(rateScale*lambdaScale/lambdaMin),mappedError,rateBoundError];
    if max(normalized)>1e-8
        error('WV:InvariantQualificationMappedOperator','Actual mapped application failed the 1e-8 physical gate at radius %.16g.',w.khUnique(p));
    end
    row=table(w.khUnique(p),energyGrowth,invariantGrowth,componentRates(1),componentRates(2),componentRates(3),mappedError,selectiveBound, ...
        normalized(1),normalized(2),normalized(3),rateBoundError, ...
        VariableNames={'kh','maximumEnergyPowerOverTwoE','maximumGeneralizedPowerOverTwoE','maximumInteriorEnstrophyPowerOverTwoE','maximumSurfaceVariancePowerOverTwoE','maximumBottomVariancePowerOverTwoE','mappedRelativeOperatorError','maximumSelectivityViolationOverTwoE','normalizedEnergySignViolation','normalizedGeneralizedSignViolation','normalizedSelectivityViolation','relativeTotalRateBoundViolation'});
    records=[records;row]; %#ok<AGROW> One row per radius.
end
end

function [FE,parts]=physicalFactors(w,p,count)
[x,weights]=legpts(count); z=(x-1)*w.Lz/2; weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,w.khUnique(p),w.f,w.g);
endpoint=WVInternal.thermalPolynomialFields([0;-w.Lz],w.thermalModeCount,w.Lz,w.N20,w.inverseScale,w.khUnique(p),w.f,w.g);
FE=[sqrt(weights)*w.khUnique(p).*r.psi;sqrt(weights.*w.N2Function(z)).*r.eta;sqrt(w.g)*r.ssh];
parts={sqrt(weights).*r.qgpv,endpoint.eta_i(1,:),endpoint.eta_i(2,:)};
end

function matrix=applicationMatrix(page,n)
if page.applicationKind=="dense"
    matrix=page.denseOperator;
elseif page.activeCount==0
    matrix=zeros(n);
else
    matrix=page.leftFactor*page.rightFactor;
end
end

function value=describeSpectrum(force)
d=force.coefficientDampingData(); s=force.thermalGeneralizedEnstrophyState;
value=struct(nominalCutoff=d.nominalSelectiveCutoff,maximumUnitSpeedRate=d.maximumUnitSpeedRate, ...
    activeCounts=cellfun(@(p)p.activeCount,d.pages),effectiveZeroCutoffs=cellfun(@(p)p.effectiveZeroCutoff,d.pages), ...
    minimumEigenvalues=min(s.generalizedEigenvalues,[],1),maximumEigenvalues=max(s.generalizedEigenvalues,[],1), ...
    eigenvalues=s.generalizedEigenvalues,unitSelectiveRates=cell2mat(cellfun(@(p)p.selectiveRates,d.pages,UniformOutput=false).'), ...
    horizontalUnitRates=d.horizontalRates,clusterUpperOrdinal=s.clusterUpperOrdinal, ...
    singularValueUncertainty=s.singularValueUncertainty,eigenvalueNormalization=s.eigenvalueNormalization, ...
    minimumActiveEigenvalue=cellfun(@(p)p.minimumActiveEigenvalue,d.pages),boundaryWeights=s.boundaryWeights, ...
    energyFormDrift=s.energyFormDrift,generalizedOperatorDrift=s.generalizedOperatorDrift, ...
    energyOrthogonalityResidual=s.energyOrthogonalityResidual,factorizationResidual=s.factorizationResidual);
end

function report=refinementStudy(folder,report)
a=report.configuration.inverseScale;
source=smallTransform(17,a); sourceCleanup=onCleanup(@()delete(source));
target=smallTransform(33,a); targetCleanup=onCleanup(@()delete(target));
report.normalization=populate(source); populate(target);
sf=WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(source,boundaryWeightMultiplier=report.configuration.weightMultiplier);
tf=WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(target,boundaryWeightMultiplier=report.configuration.weightMultiplier);
sd=sf.coefficientDampingData(); td=tf.coefficientDampingData();
ss=sf.thermalGeneralizedEnstrophyState; ts=tf.thermalGeneralizedEnstrophyState;
records=table();
for p=1:numel(source.khUnique)
    lambda=ss.generalizedEigenvalues(:,p); rates=sd.pages{p}.selectiveRates;
    [knots,indices]=unique(lambda); values=rates(indices);
    targetLambda=ts.generalizedEigenvalues(:,p);
    fixed=interp1([0;knots],[0;values],targetLambda,'linear',NaN);
    beyond=targetLambda>lambda(end);
    fixed(beyond)=-targetLambda(beyond)/(source.effectiveHorizontalGridResolution*lambda(end));
    if any(~isfinite(fixed)), error('WV:InvariantQualificationFrozenLaw','The frozen scalar law is undefined.'); end
    original=ss.polynomialEigenvectors(:,:,p)*(rates.*ss.polynomialDuals(:,:,p));
    frozen=ts.polynomialEigenvectors(:,:,p)*(fixed.*ts.polynomialDuals(:,:,p));
    retuned=ts.polynomialEigenvectors(:,:,p)*(td.pages{p}.selectiveRates.*ts.polynomialDuals(:,:,p));
    columns=source.klNonzeroKhUniqueIndex==p;
    coeff=source.thermalToPolynomial(:,:,p)*source.Ath(:,columns);
    prolonged=[coeff;zeros(16,size(coeff,2))];
    reference=[original*coeff;zeros(16,size(coeff,2))];
    [FE,~]=physicalFactors(target,p,513);
    scale=norm(FE*reference,'fro');
    fixedError=norm(FE*(frozen*prolonged-reference),'fro');
    retunedError=norm(FE*(retuned*prolonged-reference),'fro');
    horizontalRate=max(abs(sd.horizontalRates(columns)));
    records=[records;table(source.khUnique(p),scale,fixedError,retunedError,max(abs(fixed)),horizontalRate+max(abs(fixed)), ...
        VariableNames={'kh','referenceTendencyEnergyNormPerSpeed','fixedLawTendencyErrorPerSpeed','retunedTendencyErrorPerSpeed','targetMaximumFixedSelectiveUnitRate','targetMaximumFixedTotalUnitRate'})]; %#ok<AGROW>
end
writetable(records,fullfile(folder,'fixed-law-refinement.csv'));
report.refinement=table2struct(records);
report.horizontalLaw="Identical 8-by-8 horizontal grid and spacing; common support at unit prescribed speed.";
end

function report=costStudy(folder,report)
report.configuration=struct(grid=[64 64 385],domain=[5e5 5e5 4000],thermalCount=257,meanCount=4, ...
    N20=(5.2e-3)^2,inverseScale=1/1300,latitude=24,kappa_z=1e-5,assemblyCount=2057,productCount=769, ...
    weightMultiplier=1,threads=4,applicationWarmups=5,applicationSamples=21,rhsPairs=10,integrationRepeats=3);
writeReport(folder,report);
clock=tic;
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 4000],[64 64 385], ...
    N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),latitude=24,thermalModeCount=257, ...
    mdaModeCount=4,kappa_z=1e-5,assemblyQuadratureCount=2057,nonlinearQuadratureCount=769,shouldCheckQuadraticAliasing=true);
cleanup=onCleanup(@()delete(w));
report.transformConstructionSeconds=toc(clock); report.normalization=populate(w);
report.status="transform constructed"; writeReport(folder,report);
clock=tic; force=WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w);
report.closureConstructionSeconds=toc(clock); report.spectrum=describeSpectrum(force);
report.status="closure constructed"; writeReport(folder,report);
if report.phase=="target-audit"
    records=auditOperators(w,force);
    writetable(records,fullfile(folder,'operator-audit.csv'));
    report.audit=table2struct(records);
    return
end
canonical=struct();
state=force.thermalGeneralizedEnstrophyState;
for name=string(state.classRequiredPropertyNames()), canonical.(name)=state.(name); end
data=force.coefficientDampingData(); %#ok<NASGU> Retained-byte measurement below uses whos.
sizes=whos('canonical','data'); report.canonicalArrayBytes=sizes(strcmp({sizes.name},'canonical')).bytes;
report.applicationCacheBytes=sizes(strcmp({sizes.name},'data')).bytes;
w.addForcing(WVNonlinearAdvection(w)); model=WVModel(w); modelCleanup=onCleanup(@()delete(model));
model.setupIntegrator(integratorType="exponential",maximumStep=450,initialStep=450,exponentialAdaptive=false);
physical=struct(uvMax=w.uvMax);
for j=1:5, force.quasigeostrophicDampingContributions(w,physical); end
application=zeros(21,1);
for j=1:21
    clock=tic; force.quasigeostrophicDampingContributions(w,physical); application(j)=toc(clock);
end
writetable(table((1:21)',application,VariableNames={'sample','seconds'}),fullfile(folder,'application.csv'));
model.explicitFlux(); w.addForcing(force); model.explicitFlux(); w.removeForcing(force);
timings=zeros(10,2);
for j=1:10
    % Alternate pair order to reduce drift bias; state is held unchanged.
    order=[1 2]; if mod(j,2)==0, order=[2 1]; end
    for k=order
        if k==2, w.addForcing(force); end
        clock=tic; model.explicitFlux(); timings(j,k)=toc(clock);
        if k==2, w.removeForcing(force); end
    end
end
writetable(table((1:10)',timings(:,1),timings(:,2),VariableNames={'sample','baselineSeconds','closureSeconds'}),fullfile(folder,'rhs.csv'));
report.medianApplicationSeconds=median(application);
report.medianBaselineRhsSeconds=median(timings(:,1)); report.medianClosureRhsSeconds=median(timings(:,2));
report.warmRhsOverhead=median(timings(:,2))/median(timings(:,1))-1;
report.status="warm timing complete"; writeReport(folder,report);
initial=w.coefficientState(); integration=table();
for repeat=1:3
    order=[false true]; if mod(repeat,2)==0, order=[true false]; end
    for closure=order
        clear modelCleanup model
        w.t=0; w.t0=0; w.Ath=initial.Ath; w.Amda=initial.Amda;
        if closure, w.addForcing(force); end
        model=WVModel(w); modelCleanup=onCleanup(@()delete(model));
        model.setupIntegrator(integratorType="exponential",maximumStep=450,initialStep=450,exponentialAdaptive=false);
        clock=tic; model.integrateToTime(1350,shouldShowIntegrationDiagnostics=false); seconds=toc(clock);
        s=model.exponentialStatistics;
        integration=[integration;table(repeat,closure,seconds,s.acceptedSteps,s.rejectedSteps,s.rhsEvaluations,s.maximumCFL,s.maximumDampingNumber, ...
            VariableNames={'repeat','closure','seconds','acceptedSteps','rejectedSteps','rhsEvaluations','maximumCFL','maximumDampingNumber'})]; %#ok<AGROW>
        writetable(integration,fullfile(folder,'integration.csv'));
        writetable(table(s.acceptedStepSeconds(:),VariableNames={'acceptedStepSeconds'}),fullfile(folder,"steps-"+repeat+"-"+closure+".csv"));
        if closure, w.removeForcing(force); end
    end
end
report.integration=table2struct(integration);
end

function total=accumulateStatistics(total,value)
for name=["acceptedSteps","rejectedSteps","rhsEvaluations"]
    total.(name)=total.(name)+value.(name);
end
total.acceptedStepSeconds=[total.acceptedStepSeconds,value.acceptedStepSeconds(:).'];
for name=["maximumCFL","maximumDampingNumber"]
    total.(name)=max(total.(name),value.(name));
end
end

function writeReport(folder,report)
encoded=jsonencode(report,PrettyPrint=true);
nextPath=fullfile(folder,'summary.next');
fid=fopen(nextPath,'w');
if fid<0, error('WV:InvariantQualificationWrite','Cannot write output report.'); end
cleanup=onCleanup(@()fclose(fid));
fwrite(fid,encoded);
clear cleanup
movefile(nextPath,fullfile(folder,'summary.json'),'f');
end
