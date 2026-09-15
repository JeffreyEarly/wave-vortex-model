function results=qualifyThermalDamping(outputDirectory,options)
% Measure the named APV-coordinate closure and its bounded physical biases.
%
% Uses fresh deterministic controls, never historical checkpoint mutations.
% The seasonal mode-5 control retains the target 500 km horizontal domain;
% exact same-space spinup avoids a long numerical seasonal campaign.
%
% - Topic: Developer utilities
% - Parameter outputDirectory: directory for reproducible CSV evidence
% - Parameter options.sections: mapped, developed, seasonal, and/or timing
% - Parameter options.seasonalScientificState: optional canonical target state to reuse scientific construction
% - Returns results: completed qualification tables
arguments (Input)
    outputDirectory (1,1) string
    options.sections (1,:) string {mustBeMember(options.sections,["mapped","developed","seasonal","timing"])} = ["mapped","developed","seasonal","timing"]
    options.seasonalScientificState (1,1) struct = struct()
end
arguments (Output)
    results (1,1) struct
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
root=fileparts(fileparts(mfilename('fullpath'))); oldPath=path; cleanup=onCleanup(@()path(oldPath));
addpath(fullfile(root,'UnitTests','Fixtures'));
results=struct();
if any(ismember(options.sections,["mapped","developed","timing"]))
    w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[12 12 129],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=17,mdaModeCount=4,kappa_z=.01,shouldCheckQuadraticAliasing=true);
    [closure,apv]=newClosure(w);
    thermalManufacturedState(w,[2 3 4],1e4); w.Amda=[.1;-.2;.3;-.1];
    if ismember("mapped",options.sections)
        results.mapped=mappedComparison(w,closure,apv);
        writetable(results.mapped,fullfile(outputDirectory,'mapped-comparison.csv'));
        writetable(auditThermalDampingEnergy(w,closure),fullfile(outputDirectory,'energy-audit.csv'));
    end
    if ismember("timing",options.sections)
        results.timing=onlineTiming(w,closure);
        writetable(results.timing,fullfile(outputDirectory,'online-cost.csv'));
    end
    if ismember("developed",options.sections)
        results.developed=developedControls(w,closure,outputDirectory);
        writetable(results.developed,fullfile(outputDirectory,'developed-comparison.csv'));
    end
end
if ismember("seasonal",options.sections)
    results.seasonal=seasonalControls(outputDirectory,options.seasonalScientificState);
    writetable(results.seasonal,fullfile(outputDirectory,'seasonal-comparison.csv'));
end
end

function [closure,apv]=newClosure(w)
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny w.Nz],N2Function=@(z)w.N20*exp(2*w.inverseScale*z),latitude=w.latitude,g=w.g,apvModeCount=6,mdaModeCount=4,gramTolerance=.1);
closure=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5);
end

function rows=mappedComparison(w,closure,apv)
data=closure.coefficientDampingData(); legacy=WVAdaptiveDamping(apv,apvCutoffFraction=.5);
original=w.coefficientState(); [~,column]=max(hypot(w.k(w.klNonzero),w.l(w.klNonzero)));
page=w.klNonzeroKhUniqueIndex(column); c=zeros(w.thermalModeCount,1); c(1:3)=[10;3;2];
w.Ath(:,column)=w.polynomialToThermal(:,:,page)*c;
state=w.coefficientState(); diagnostic=complex(zeros(8,numel(w.klNonzero))); complement=state;
for p=1:numel(data.pages)
    columns=w.klNonzeroKhUniqueIndex==p; page=data.pages{p};
    diagnostic(:,columns)=page.projection*state.Ath(:,columns);
    complement.Ath(:,columns)=state.Ath(:,columns)-page.lift*diagnostic(:,columns);
end
apv.Ag_q=diagnostic(1:6,:); apv.Ag_0=diagnostic(7:8,:); apv.Amda=0*apv.Amda;
[h,v]=closure.quasigeostrophicDampingContributions(w,struct(uvMax=.1));
[ah,av]=legacy.quasigeostrophicDampingContributions(apv,struct(uvMax=.1));
rows=table();
for kind=["horizontal","vertical"]
    if kind=="horizontal", th=h; ad=ah; else, th=v; ad=av; end
    expected=[ad.Ag_q;ad.Ag_0]; actual=expected*0;
    remaining=th;
    for p=1:numel(data.pages)
        columns=w.klNonzeroKhUniqueIndex==p; page=data.pages{p};
        actual(:,columns)=page.projection*th.Ath(:,columns);
        remaining.Ath(:,columns)=th.Ath(:,columns)-page.lift*actual(:,columns);
    end
    coordinateError=norm(actual-expected,'fro')/max(norm(expected,'fro'),realmin);
    assign(w,th); tf=w.reconstructFields(["qgpv","endpointAnomalies","u","v"]);
    assign(apv,ad); [aq,~,~,ab]=apv.quasigeostrophicSpatialState();
    % Compare on the APV physical-depth grid, retaining all thermal q content.
    r=WVInternal.thermalPolynomialFields(apv.z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
    qHat=complex(zeros(apv.Nz,apv.Nkl));
    for p=1:numel(data.pages)
        columns=w.klNonzeroKhUniqueIndex==p; C=w.thermalToPolynomial(:,:,p)*th.Ath(:,columns);
        qHat(:,apv.klNonzero(columns))=(r.qgpv-w.khUnique(p)^2*r.psi)*C;
    end
    tq=apv.transformToSpatialDomainWithFourier(qHat);
    fullQDifference=norm(tq(:)-aq(:))/max(norm(aq(:)),realmin);
    endpointDifference=reshape(sqrt(mean(abs(tf.endpointAnomalies-ab).^2,[1 2])),1,2);
    endpointScale=reshape(sqrt(mean(abs(ab).^2,[1 2])),1,2);
    endpointRelative=endpointDifference./max(endpointScale,1e-18);
    complementAction=stateNorm(w,remaining)/max(stateNorm(w,th),realmin);
    rows=[rows;table(kind,coordinateError,fullQDifference,endpointDifference(1),endpointDifference(2),max(endpointRelative),complementAction,VariableNames={'action','coordinateRelativeError','fullAPVQRelativeDifference','surfaceRMSDifference','bottomRMSDifference','maximumEndpointRelativeError','complementActionRelative'})]; %#ok<AGROW>
end
assign(w,complement); [~,zero]=closure.quasigeostrophicDampingContributions(w,struct(uvMax=.1));
assert(stateNorm(w,zero)<1e-10*max(stateNorm(w,v),realmin),'Vertical closure changed the unresolved complement.');
assign(w,original);
assert(all(rows.coordinateRelativeError<1e-10),'Claimed APV-coordinate equality failed.');
assert(all(rows.maximumEndpointRelativeError<1e-6),'Mapped physical endpoint tendencies did not agree.');
end

function rows=onlineTiming(w,closure)
physical=struct(uvMax=w.uvMax);
for j=1:3, closure.quasigeostrophicDampingContributions(w,physical); end
seconds=zeros(15,1);
for j=1:15
    timer=tic; closure.quasigeostrophicDampingContributions(w,physical); seconds(j)=toc(timer);
end
rows=table(w.thermalModeCount,numel(closure.dampingAPVMode),numel(w.klNonzero),numel(w.khUnique),maxNumCompThreads,median(seconds),min(seconds),max(seconds),VariableNames={'thermalCount','apvCount','fourierCount','radiusCount','threads','medianOnlineSeconds','minimumOnlineSeconds','maximumOnlineSeconds'});
end

function rows=developedControls(base,closure,outputDirectory)
% A nonlinear precursor develops the initial mixed state before rescaling.
precursor=base.withDiffusivity(0); precursor.addForcing(WVNonlinearAdvection(precursor));
initial=precursor.coefficientState(); model=WVModel(precursor);
model.setupIntegrator(integratorType="exponential",initialStep=5000,maximumStep=5000,exponentialAdaptive=false);
model.integrateToTime(1e5,shouldShowIntegrationDiagnostics=false);
precursorChange=stateNorm(precursor,subtract(precursor.coefficientState(),initial))/stateNorm(precursor,initial);
assert(precursorChange>1e-3,'The common precursor did not evolve.');
seed=precursor.coefficientState(); normalization=.001/precursor.uvMax;
seed.Ath=normalization*seed.Ath; seed.Amda=normalization*seed.Amda;
rows=table();
for multiplier=[1 10 100]
    initial=seed; initial.Ath=multiplier*seed.Ath; initial.Amda=multiplier*seed.Amda;
    states=cell(2,3); studies=cell(2,3);
    for damped=[false true]
        for j=1:3
            h=200/2^(j-1);
            w=WVTransformFreeSurfaceThermalQG(scientificState=base.scientificState,coefficientState=initial);
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(WVBottomFrictionQuadratic(w,Cd=1e-3));
            if damped, w.addForcing(closure.forcingWithResolutionOfTransform(w)); end
            [states{damped+1,j},studies{damped+1,j}]=integrateControl(w,20000,h,closure);
        end
        d=studies{damped+1,3};
        first=stateDifference(base,states{damped+1,1},states{damped+1,2});
        refined=stateDifference(base,states{damped+1,2},states{damped+1,3});
        reference=physicalNorms(base,states{damped+1,3});
        relative=refined./max(reference,[1e-14 1e-12 1e-10 1e-10 1e-10]);
        assert(max(relative)<1e-5,'Developed-state time control failed.');
        assert(all(refined<=.6*first+1e-12*reference+1e-20),'Developed-state temporal refinement failed.');
        initialSpeed=.001*multiplier;
        rows=[rows;table(multiplier,damped,initialSpeed,precursorChange,max(relative),d.maximumSpeed,d.maximumDampingNumber,d.maximumStep,d.energyChange,d.diffusionEnergy,d.diffusionEnstrophy,d.horizontalEnergy,d.verticalEnergy,d.horizontalEnstrophy,d.verticalEnstrophy,d.positiveHighAPVDiffusion,d.horizontalTail,d.apvTail,d.polynomialQTail,d.surfaceRatio,d.rossby,VariableNames={'multiplier','damped','initialSpeed','precursorRelativeChange','timeRefinementRelative','maximumSpeed','maximumDampingNumber','maximumAcceptedStep','energyChange','diffusionEnergyWork','diffusionEnstrophyWork','horizontalEnergyWork','verticalEnergyWork','horizontalEnstrophyWork','verticalEnstrophyWork','positiveHighAPVDiffusion','finalHorizontalQTail','finalAPVBandTail','finalPolynomialQTailRMSRatio','maximumDisplacementOverDepth','maximumRelativeVorticityOverF'})]; %#ok<AGROW>
        writetable(d.history,fullfile(outputDirectory,sprintf('developed-%d-%d.csv',multiplier,damped)));
    end
    bias=stateDifference(base,states{1,3},states{2,3});
    reference=physicalNorms(base,states{1,3});
    comparison=table(multiplier,bias(1),bias(2),bias(3),bias(4),bias(5),max(bias./max(reference,[1e-14 1e-12 1e-10 1e-10 1e-10])),VariableNames={'multiplier','qRMSDifference','buoyancyRMSDifference','speedRMSDifference','surfaceRMSDifference','bottomRMSDifference','maximumRelativeDifference'});
    writetable(comparison,fullfile(outputDirectory,sprintf('developed-bias-%d.csv',multiplier)));
end
end

function [state,d]=integrateControl(w,duration,h,closure)
model=WVModel(w); model.setupIntegrator(integratorType="exponential",initialStep=h,maximumStep=h,exponentialAdaptive=false);
times=unique([0:5:100,100:50:1000,1000:250:duration,duration]).';
values=zeros(numel(times),11); maximumNumber=0; maximumStep=0; maximumSpeed=0;
data=closure.coefficientDampingData();
for j=1:numel(times)
    if j>1
        model.integrateToTime(times(j),shouldShowIntegrationDiagnostics=false);
        statistics=model.exponentialStatistics;
        maximumNumber=max(maximumNumber,statistics.maximumDampingNumber);
        maximumStep=max(maximumStep,max(statistics.acceptedStepSeconds));
    end
    [~,speed,processes]=w.coefficientTendency(); maximumSpeed=max(maximumSpeed,speed);
    inventory=w.quadraticDiagnostics(tendency=processes.tendencies);
    rate=zeros(1,6); diffusion=processes.tendencies(1);
    for p=1:numel(processes.labels)
        label=processes.labels(p); columns=[];
        if label=="density diffusion", columns=[1 2]; diffusion=processes.tendencies(p); end
        if endsWith(label,": horizontal"), columns=[3 4]; end
        if endsWith(label,": vertical"), columns=[5 6]; end
        if ~isempty(columns), rate(columns)=[inventory.totalEnergyTendency(p),inventory.potentialEnstrophyTendency(p)]; end
    end
    positive=0; tail=0; band=0;
    for p=1:numel(data.pages)
        columns=w.klNonzeroKhUniqueIndex==p; P=data.pages{p}.projection;
        a=P*w.Ath(:,columns); da=P*diffusion.Ath(:,columns);
        high=5:6; powers=2*w.Lz*real(conj(a(high,:)).*da(high,:));
        positive=positive+sum(max(powers,0),'all');
        band=band+sum(abs(a(1:6,:)).^2,'all'); tail=tail+sum(abs(a(high,:)).^2,'all');
    end
    values(j,:)=[inventory.totalEnergy,inventory.potentialEnstrophy,rate,positive,tail/max(band,realmin),speed];
end
state=w.coefficientState(); integrals=trapz(times,values(:,3:9),1);
physical=w.physicalDiagnostics(); tailState=state; threshold=ceil(.8*w.thermalModeCount);
for p=1:numel(data.pages)
    columns=w.klNonzeroKhUniqueIndex==p; c=w.thermalToPolynomial(:,:,p)*state.Ath(:,columns);
    c(1:threshold,:)=0; tailState.Ath(:,columns)=w.polynomialToThermal(:,:,p)*c;
end
tailState.Amda=0*tailState.Amda; tailNorm=physicalNorms(w,tailState); totalNorm=physicalNorms(w,state);
fields=w.reconstructFields(["u","v","eta"]); vorticity=w.diffX(fields.v)-w.diffY(fields.u);
d=struct(maximumSpeed=maximumSpeed,maximumDampingNumber=maximumNumber,maximumStep=maximumStep, ...
    energyChange=values(end,1)-values(1,1),diffusionEnergy=integrals(1),diffusionEnstrophy=integrals(2), ...
    horizontalEnergy=integrals(3),horizontalEnstrophy=integrals(4),verticalEnergy=integrals(5),verticalEnstrophy=integrals(6), ...
    positiveHighAPVDiffusion=integrals(7),horizontalTail=physical.horizontalTailFraction.qgpv,apvTail=values(end,10), ...
    polynomialQTail=tailNorm(1)/max(totalNorm(1),realmin),surfaceRatio=max(abs(fields.eta),[],'all')/w.Lz,rossby=max(abs(vorticity),[],'all')/abs(w.f));
d.history=array2table([times,values],VariableNames={'time','energy','enstrophy','diffusionEnergyPower','diffusionEnstrophyPower','horizontalEnergyPower','horizontalEnstrophyPower','verticalEnergyPower','verticalEnstrophyPower','positiveHighAPVDiffusionPower','APVBandTail','speed'});
end

function rows=seasonalControls(outputDirectory,scientificState)
D=4000; N20=(5.2e-3)^2; a=1/1300; T=365.25*86400;
if isempty(fieldnames(scientificState))
    base=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 D],[18 18 385],N2Function=@(z)N20*exp(2*a*z),thermalModeCount=257,mdaModeCount=4,kappa_z=1e-5,shouldCheckQuadraticAliasing=true,assemblyQuadratureCount=1029);
else
    base=WVTransformFreeSurfaceThermalQG(scientificState=scientificState);
    assert(isequal([base.Lx base.Ly base.Lz],[5e5 5e5 D]) && isequal([base.Nx base.Ny],[18 18]) && base.thermalModeCount==257 && abs(base.N20/N20-1)<1e-12 && base.inverseScale==a);
end
[closure,sampling]=seasonalClosure(base);
writetable(sampling,fullfile(outputDirectory,'apv-sampling-refinement.csv'));
rows=table();
start=2.5*T; duration=1e6;
for M=[10 100]
    initial=WVTransformFreeSurfaceThermalQG(scientificState=base.scientificState);
    pattern=sin(10*pi*initial.Y(:,:,1)/initial.Ly);
    initial.addForcing(WVSeasonalSurfaceAnomalyForcing(initial,pattern=pattern,amplitude=M*pi/T,period=T));
    exact=WVDensityDiffusionIntegrator(initial,thermalLinearDynamics=true);
    first=exact.fromModes(exact.seasonalCoefficients(start));
    target=exact.fromModes(exact.seasonalCoefficients(start+duration));
    if M==10
        assign(initial,first);
        writetable(onlineTiming(initial,closure.forcingWithResolutionOfTransform(initial)),fullfile(outputDirectory,'online-cost-target.csv'));
    end
    for damped=[false true]
        states=cell(1,4); numbers=zeros(1,4); elapsed=zeros(1,4);
        h=86400; stepRows=table();
        for j=1:4
            w=WVTransformFreeSurfaceThermalQG(scientificState=base.scientificState,coefficientState=first,t=start);
            w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=M*pi/T,period=T));
            if damped, w.addForcing(closure.forcingWithResolutionOfTransform(w)); end
            model=WVModel(w); model.setupIntegrator(integratorType="exponential",thermalLinearDynamics=true,initialStep=h,maximumStep=h,exponentialAdaptive=false);
            fprintf('Seasonal M%g damped%d step%gs\n',M,damped,h);
            timer=tic; model.integrateToTime(start+duration,shouldShowIntegrationDiagnostics=false); elapsed(j)=toc(timer);
            states{j}=w.coefficientState(); statistics=model.exponentialStatistics; numbers(j)=statistics.maximumDampingNumber;
            actualSteps=statistics.acceptedStepSeconds(:);
            stepRows=[stepRows;table(repmat(j,numel(actualSteps),1),repmat(h,numel(actualSteps),1),actualSteps,VariableNames={'refinement','configuredMaximumStep','acceptedStepSeconds'})]; %#ok<AGROW>
            writetable(stepRows,fullfile(outputDirectory,sprintf('seasonal-accepted-steps-%d-%d.csv',M,damped)));
            % Refine actual accepted steps even when the closure norm cap is
            % smaller than the configured maximum in the first trajectory.
            h=min(h/2,max(actualSteps)/2);
        end
        initialDifference=stateDifference(base,states{1},states{2});
        coarse=stateDifference(base,states{2},states{3}); fine=stateDifference(base,states{3},states{4});
        reference=physicalNorms(base,target); bias=stateDifference(base,states{4},target);
        floors=[1e-13 1e-11 1e-8 1e-8 1e-8];
        relative=fine./max(reference,floors);
        contractionBound=reconstructionRoundoffEnvelope(base,states{4});
        names=["qgpv","buoyancy","speed","surfaceAnomaly","bottomAnomaly"];
        controls=table(names.',initialDifference.',coarse.',fine.',reference.',relative.',floors.',contractionBound.',VariableNames={'field','initialDifferenceRMS','coarseDifferenceRMS','fineDifferenceRMS','referenceRMS','fineRelative','physicalAbsoluteFloor','contractionRoundoffEnvelope'});
        writetable(controls,fullfile(outputDirectory,sprintf('seasonal-time-control-%d-%d.csv',M,damped)));
        assert(max(relative)<1e-5,'Seasonal time control is insufficient.');
        converging=fine<=.6*coarse+1e-11*reference+1e-19;
        belowFloors=max(coarse,fine)<=floors & max(coarse,fine)./max(reference,floors)<1e-5;
        assert(all(converging|belowFloors),'Seasonal time refinement failed above the physical error floors.');
        for k=1:5
            rows=[rows;table(M,damped,names(k),bias(k),bias(k)/max(reference(k),realmin),fine(k),relative(k),max(numbers),elapsed(4),VariableNames={'M','damped','field','closureBiasRMS','closureBiasRelative','timeRefinementRMS','timeRefinementRelative','maximumDampingNumber','fineRunSeconds'})]; %#ok<AGROW>
        end
        writetable(rows,fullfile(outputDirectory,'seasonal-progress.csv'));
    end
end
end

function envelope=reconstructionRoundoffEnvelope(w,state)
% Standard gamma_n absolute dot-product bound for these stored factors only.
% This measures final contraction roundoff, not accumulated trajectory error.
data=w.linearEvolutionData(); variance=zeros(1,5); n=w.thermalModeCount;
gamma=n*eps/(1-n*eps);
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    for field=1:5
        magnitude=abs(data.physicalNormFactors{p,field})*abs(state.Ath(:,columns));
        variance(field)=variance(field)+2*sum((gamma*magnitude).^2,'all');
    end
end
gamma=w.mdaModeCount*eps/(1-w.mdaModeCount*eps);
for field=1:5
    magnitude=abs(data.physicalNormFactors{end,field})*abs(state.Amda);
    variance(field)=variance(field)+sum((gamma*magnitude).^2);
end
envelope=sqrt(variance);
end

function values=physicalNorms(w,state)
e=w.linearEvolutionData(); values=e.physicalErrorNorms(e.toModes(state));
end
function value=stateNorm(w,state)
d=w.quadraticDiagnostics(state=state); value=sqrt(d.totalEnergy);
end
function value=stateDifference(w,a,b)
value=physicalNorms(w,subtract(a,b));
end
function value=subtract(a,b)
value=struct(Ath=a.Ath-b.Ath,Amda=a.Amda-b.Amda);
end
function assign(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end

function [closure,rows]=seasonalClosure(w)
% Refine quadrature of one qualified scientific APV basis using its own API.
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=@(z)w.N20*exp(2*w.inverseScale*z),latitude=w.latitude,g=w.g,apvModeCount=6,mdaModeCount=4,gramTolerance=.1);
coarse=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5);
options=struct(g=w.g,g0=apv.g0,gd=apv.gd,apvModeCount=6,mdaModeCount=4,gramTolerance=.1,modeConvergenceTolerance=1e-6,quadraticDealiasing="none",retainedFraction=2/3,energyFraction=.99,bandwidthFraction=2/3);
vertical=WVInternal.buildFreeSurfaceBalancedModes(w.Lz,129,@(z)w.N20*exp(2*w.inverseScale*z),options);
assert(norm(vertical.apvTransform.inverseMatrix(variable="F")-apv.apvF,'fro')<1e-8*norm(apv.apvF,'fro'),'Frozen APV orientation differs.');
frozen=struct(); for name=string(coarse.classRequiredPropertyNames()), frozen.(name)=coarse.(name); end
counts=[513 1025 2049]; candidates=cell(1,3); rows=table();
for j=1:3
    grid=IMSolverSpectral(nEVP=counts(j),coordinateKind="wkb").configuredForEVP(vertical.apvProblem);
    [z,weights]=grid.nativeDifferentiationRule([-w.Lz 0]); weights=weights*w.Lz/sum(weights);
    transform=vertical.apvBasis.discreteTransform(z=z,weights=weights,variables=["F","G"],nModes=6,gramTolerance=.1);
    frozen.apvZ=z; frozen.apvForward=transform.forwardMatrix(variable="F"); args=namedargs2cell(frozen);
    candidates{j}=WVThermalAPVDamping(w,args{:});
end
reference=candidates{3}.coefficientDampingData();
for j=1:2
    actual=candidates{j}.coefficientDampingData(); largest=0; projection=0;
    for p=1:numel(reference.pages)
        E=w.Lz*w.thermalEnergyGram(:,:,p); R=chol((E+E')/2);
        a=actual.pages{p}; b=reference.pages{p};
        A=a.lift*(actual.verticalRates.*a.projection); B=b.lift*(reference.verticalRates.*b.projection);
        largest=max(largest,norm(R*(A-B)/R,2)/max(norm(R*B/R,2),realmin));
        scales=vecnorm(b.projection/R,2,2);
        projection=max(projection,norm(((a.projection-b.projection)/R)./scales,'fro')/sqrt(numel(scales)));
    end
    rows=[rows;table(6,counts(j),counts(3),projection,largest,VariableNames={'frozenAPVBand','sampleCount','referenceSampleCount','projectionRelative','energyActionRelative'})]; %#ok<AGROW>
end
assert(rows.energyActionRelative(end)<1e-6,'Frozen APV sampling needs further refinement.');
closure=candidates{3};
end
