function results = qualifyThermalAPVModeCapacity(outputDirectory,options)
% Measure supported APV bands and diagnostic coverage on the T9 target.
% Use existing automatic constructor selection, then compare each chosen band
% with the same band on a doubled stored grid and with doubled quadrature.
% All failed cases remain in the report. No runtime tolerance or default changes.
% - Topic: Developer utilities
% - Parameter outputDirectory: destination for capacity, comparison and cost tables
% - Parameter options.gridCounts: diagnostic grids assessed with automatic APV counts
% - Parameter options.explicitCases: rows of stored depth count and APV mode count
% - Parameter options.quadratureCount: physical integration points, doubled for comparison
% - Parameter options.samplingTolerance: relative allowance for bounded diagnostic sampling
% - Returns results: construction limits, state coverage, comparison errors and costs
arguments (Input)
    outputDirectory (1,1) string
    options.gridCounts (1,:) double {mustBeInteger,mustBePositive} = [65 129]
    options.explicitCases (:,2) double {mustBeInteger,mustBePositive} = [65 32;129 16;129 32;129 64]
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 513
    options.samplingTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-2
end
arguments (Output)
    results (1,1) struct
end
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
tic;
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 4000],[18 18 385],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),latitude=24,thermalModeCount=257,mdaModeCount=4);
thermalSeconds=toc;
state=surfaceLayerState(w);
capacity=table(); comparisons=table(); coverage=table();
gridCounts=unique(options.gridCounts);
caseGrids=[gridCounts,options.explicitCases(:,1).'];
caseCounts=[nan(size(gridCounts)),options.explicitCases(:,2).'];
for iCase=1:numel(caseGrids)
    Nz=caseGrids(iCase); requested=caseCounts(iCase);
    fprintf('T9 mode capacity: Nz=%d requested=%g (NaN means automatic).\n',Nz,requested);
    row=struct(diagnosticNz=Nz,requestedCount=requested,selectedCount=NaN,candidateCount=NaN,firstGramRejectedCount=NaN,selectedGramError=NaN,firstRejectedGramError=NaN,modeConvergenceError=NaN,boundaryGridError=NaN,maximumKh=NaN,minimumMuSeparation=NaN,constructionSeconds=NaN,status="failed",failureIdentifier="",failureMessage="");
    try
        tic;apv=newAPV(w,Nz,requested);row.constructionSeconds=toc;
        assessment=apv.constructionAssessment;
        row.selectedCount=apv.apvModeCount;
        row.candidateCount=assessment.apv.candidateConstruction.candidateCount;
        prefix=assessment.apv.prefixDiagnostics;
        rejected=find(~prefix.gramAccepted,1);
        if ~isempty(rejected)
            row.firstGramRejectedCount=prefix.modeCount(rejected);
            row.firstRejectedGramError=prefix.gramError(rejected);
        end
        row.selectedGramError=prefix.gramError(apv.apvModeCount);
        convergence=assessment.apv.convergence.measurements;
        selected=ismember(convergence.columnLabel,string(apv.apvModeNumber));
        selected=selected & ismember(convergence.quantity,["h1","equivalentDepth"]);
        row.modeConvergenceError=max(convergence.value(selected));
        row.boundaryGridError=max(assessment.boundary.pages.gridError);
        row.maximumKh=max(apv.khUnique);
        row.minimumMuSeparation=apv.minimumRelativeMuSeparation;
        row.status="constructed";
        writetable(prefix,fullfile(outputDirectory,sprintf('prefix-Nz%d-count%d.csv',Nz,apv.apvModeCount)));
        writetable(assessment.boundary.pages,fullfile(outputDirectory,sprintf('boundary-Nz%d-count%d.csv',Nz,apv.apvModeCount)));
        writetable(convergence,fullfile(outputDirectory,sprintf('convergence-Nz%d-count%d.csv',Nz,apv.apvModeCount)));
    catch exception
        row.failureIdentifier=string(exception.identifier);row.failureMessage=string(exception.message);
    end
    capacity=[capacity;struct2table(row)]; %#ok<AGROW>
    writetable(capacity,fullfile(outputDirectory,'capacity.csv'));
    if row.status~="constructed",continue;end
    comparison=struct(diagnosticNz=Nz,apvCount=apv.apvModeCount,quadratureCount=options.quadratureCount,referenceNz=2*Nz-1,referenceConstructionSeconds=NaN,maximumModeShapeError=NaN,quadratureCoefficientChange=NaN,gridCoefficientChange=NaN,quadratureResidualChangeOverSource=NaN,gridResidualChangeOverSource=NaN,preparationSeconds=NaN,cachedSeconds=NaN,samplingTolerance=options.samplingTolerance,status="failed",failureIdentifier="",failureMessage="");
    try
        Q=options.quadratureCount;
        tic;d=w.apvDecomposition(apv,state=state,quadratureCount=Q);comparison.preparationSeconds=toc;
        samples=zeros(3,1);
        for j=1:3
            tic;w.apvDecomposition(apv,state=state,quadratureCount=Q);samples(j)=toc;
        end
        comparison.cachedSeconds=median(samples);
        refined=w.apvDecomposition(apv,state=state,quadratureCount=2*Q);
        comparison.quadratureCoefficientChange=coefficientChange(d,refined);
        comparison.quadratureResidualChangeOverSource=residualChange(d,refined);
        fprintf('Compare the same %d modes at Nz=%d.\n',apv.apvModeCount,2*Nz-1);
        tic;reference=newAPV(w,2*Nz-1,apv.apvModeCount);comparison.referenceConstructionSeconds=toc;
        [~,transfer]=apv.coefficientStateForTransform(reference,modeTolerance=options.samplingTolerance,quadratureCount=2*Q);
        comparison.maximumModeShapeError=transfer.maximumModeShapeError;
        fine=w.apvDecomposition(reference,state=state,quadratureCount=2*Q);
        comparison.gridCoefficientChange=coefficientChange(refined,fine);
        comparison.gridResidualChangeOverSource=residualChange(refined,fine);
        errors=[comparison.maximumModeShapeError,comparison.quadratureCoefficientChange,comparison.gridCoefficientChange,comparison.quadratureResidualChangeOverSource,comparison.gridResidualChangeOverSource];
        if all(isfinite(errors)) && all(errors<=options.samplingTolerance)
            comparison.status="accepted";
        else
            comparison.status="sampling-limit";
        end
        for name=string(fieldnames(d.residuals)).'
            for component=1:numel(d.residuals.(name).absolute)
                a=d.residuals.(name);b=fine.residuals.(name);
                coverage=[coverage;table(Nz,apv.apvModeCount,Q,name,component,a.absolute(component),a.relative(component),b.absolute(component),b.reference(component),VariableNames={'diagnosticNz','apvCount','quadratureCount','observable','component','residual','residualOverSource','refinedResidual','sourceNorm'})]; %#ok<AGROW>
            end
        end
    catch exception
        comparison.failureIdentifier=string(exception.identifier);comparison.failureMessage=string(exception.message);
    end
    comparisons=[comparisons;struct2table(comparison)]; %#ok<AGROW>
    writetable(comparisons,fullfile(outputDirectory,'comparisons.csv'));
    writetable(coverage,fullfile(outputDirectory,'coverage.csv'));
end
environment=table(thermalSeconds,string(version),string(computer),maxNumCompThreads,string(which('IMInternalModes')),options.samplingTolerance,VariableNames={'thermalConstructionSeconds','matlab','platform','maximumThreads','providerPath','samplingTolerance'});
writetable(environment,fullfile(outputDirectory,'environment.csv'));
results=struct(capacity=capacity,comparisons=comparisons,coverage=coverage,environment=environment);
end

function apv=newAPV(w,Nz,count)
integralN2=w.N20*(-expm1(-2*w.inverseScale*w.Lz))/(2*w.inverseScale);
if isnan(count),count=[];end
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny Nz],N2Function=w.N2Function,g=w.g,latitude=w.latitude,rho0=w.rho0,g0=-integralN2,gd=integralN2,apvModeCount=count,mdaModeCount=1,shouldAntialias=w.shouldAntialias,shouldCheckQuadraticAliasing=false);
end

function state=surfaceLayerState(w)
state=w.coefficientState();state.Ath=0*state.Ath;state.Amda=[.02;-.01;.03;-.04];
[x,weights]=legpts(max(513,2*w.thermalModeCount+1));
values=feval(legpoly(0:w.thermalModeCount-1),x);
c=((2*(0:w.thermalModeCount-1)'+1)/2).*(values'*(weights(:).*exp(-30*(1-x))));
column=find(w.k(w.klNonzero)>0 & w.l(w.klNonzero)==0,1);
state.Ath(:,column)=100*w.polynomialToThermal(:,:,w.klNonzeroKhUniqueIndex(column))*c;
end

function value=coefficientChange(a,b)
% Compare magnitudes after label matching; solver signs can differ.
value=0;
for name=["Ag_q","Ag_0"]
    labels="apvModeNumber";
    if name=="Ag_0",labels="activeEndpoint";end
    [matched,indices]=ismember(a.metadata.(labels),b.metadata.(labels));
    assert(all(matched) && numel(indices)==numel(b.metadata.(labels)),'The compared bands must have identical physical labels.');
    x=abs(a.coefficients.(name));y=abs(b.coefficients.(name)(indices,:));
    scale=norm(y,'fro');difference=norm(x-y,'fro');
    if scale>0,value=max(value,difference/scale);elseif difference>0,value=Inf;end
end
end

function value=residualChange(a,b)
value=0;
for name=string(fieldnames(a.residuals)).'
    x=a.residuals.(name);y=b.residuals.(name);
    % An absolute near-zero floor has the units of each declared observable.
    floor=1e-10;
    if name=="qgpv",floor=1e-13;elseif ismember(name,["velocity","buoyancy"]),floor=1e-12;end
    value=max(value,max(abs(x.absolute-y.absolute)./max(y.reference,floor)));
end
end
