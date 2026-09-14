function results = qualifyThermalAPVDiagnostics(outputDirectory,options)
% Qualify APV projection against independent physical polynomial references.
% Gates are fixed before execution; all rows and failed allowances are written
% before assertions. Diagnostic construction, cold preparation, cached record
% analysis and requested field reconstruction have separate timing columns.
% - Topic: Developer utilities
% - Parameter outputDirectory: destination for machine-readable evidence
% - Parameter options.shouldRunTarget: optional generic-profile 257-direction exploration; default false
% - Parameter options.resourcesOnly: run supplemental target residual and allocation measurements
% - Parameter options.residualControlsOnly: run bounded constant/exponential observable budgets
% - Returns results: numerical controls, refinement, timing and fit tables
arguments (Input)
    outputDirectory (1,1) string
    options.shouldRunTarget (1,1) logical = false
    options.resourcesOnly (1,1) logical = false
    options.residualControlsOnly (1,1) logical = false
end
arguments (Output)
    results (1,1) struct
end
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
root=fileparts(fileparts(mfilename('fullpath'))); previous=path; cleanup=onCleanup(@()path(previous));
addpath(fullfile(root,'UnitTests','Fixtures'));
if options.resourcesOnly,results=qualifyResources(outputDirectory);return;end
if options.residualControlsOnly,results=qualifyResidualControls(outputDirectory);return;end
controls=table(); fits=table(); refinement=table(); residuals=table();
for a=[0 1/1300]
    w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=33,mdaModeCount=4);
    thermalManufacturedState(w,[2 3 8],100); w.Amda=[.02;-.01;.03;-.04]; original=w.coefficientState();
    tic; apv=newAPV(w,129,6,1); basisSeconds=toc;
    for Q=[257 514 1028]
        [row,observableRows]=measureCase(w,apv,original,Q,"mixed",a,basisSeconds);
        residuals=[residuals;observableRows]; %#ok<AGROW>
        writetable(residuals,fullfile(outputDirectory,'residual-reference-budget.csv'));
        controls=[controls;row]; %#ok<AGROW>
        writetable(controls,fullfile(outputDirectory,'controls.csv'));
    end
    for kind=["apv","surface","bottom","mixed"]
        [state,expected,pressureFit,physicalFit]=thermalAPVDiagnosticFit(w,apv,kind);
        d=w.apvDecomposition(apv,state=state,quadratureCount=513);
        reference=thermalAPVDiagnosticReference(w,apv,state,1025);
        known=[expected.Ag_q;expected.Ag_0]; actual=[d.coefficients.Ag_q;d.coefficients.Ag_0]; fitted=[reference.coefficients.Ag_q;reference.coefficients.Ag_0];
        error=norm(actual-known,'fro')/norm(known,'fro'); sourceFitCoefficientError=norm(fitted-known,'fro')/norm(known,'fro');
        fits=[fits;table(a,kind,pressureFit,physicalFit.qgpvAbsolute,physicalFit.qgpvRelative,physicalFit.endpointAbsolute(1),physicalFit.endpointAbsolute(2),sourceFitCoefficientError,error,error<=1e-8,VariableNames={'inverseScale','control','relativePressureFit','qgpvAbsoluteFit','qgpvRelativeFit','surfaceAbsoluteFit','bottomAbsoluteFit','sourceFitCoefficientError','coefficientRecoveryError','passed'})]; %#ok<AGROW>
        writetable(fits,fullfile(outputDirectory,'manufactured-fits.csv'));
    end
    last=[];
    for Nz=[129 257 513]
        fprintf('T9 stored-grid a=%g diagnostic=6/%d\n',a,Nz);
        apv=newAPV(w,Nz,6,1); reference=thermalAPVDiagnosticReference(w,apv,original,2057);
        vector=[reference.coefficients.Ag_q(:);reference.coefficients.Ag_0(:)];
        if isempty(last), change=NaN;else,change=norm(vector-last)/norm(vector);end
        refinement=[refinement;table(a,"stored-grid",Nz,6,1,change,reference.residuals.qgpv.relative,reference.residuals.energyNorm.relative,VariableNames={'inverseScale','axis','diagnosticNz','apvCount','weightMultiplier','coefficientChange','qgpvResidual','energyResidual'})]; %#ok<AGROW>
        last=vector;
        writetable(refinement,fullfile(outputDirectory,'refinement.csv'));
    end
    layer=surfaceLayerState(w,30);
    for count=[3 6 10]
        apv=newAPV(w,513,count,1);
        [row,observableRows]=measureCase(w,apv,layer,1028,"surface-layer",a,NaN); controls=[controls;row]; residuals=[residuals;observableRows]; %#ok<AGROW>
        refinement=[refinement;table(a,"retained-band",513,count,1,NaN,row.qgpvResidual,row.energyResidual,VariableNames={'inverseScale','axis','diagnosticNz','apvCount','weightMultiplier','coefficientChange','qgpvResidual','energyResidual'})]; %#ok<AGROW>
    end
    apv=newAPV(w,513,6,1.2); [row,observableRows]=measureCase(w,apv,original,1028,"alternative-weights",a,NaN); controls=[controls;row]; residuals=[residuals;observableRows]; %#ok<AGROW>
    writetable(controls,fullfile(outputDirectory,'controls.csv'));writetable(refinement,fullfile(outputDirectory,'refinement.csv'));
end
if options.shouldRunTarget
    a=1/1300; tic;
    w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 4000],[18 18 385],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=257,mdaModeCount=4);
    thermalConstructionSeconds=toc; state=surfaceLayerState(w,30); state.Amda=[.02;-.01;.03;-.04];
    tic; apv=newAPV(w,1025,6,1); basisSeconds=toc;
    [row,observableRows]=measureCase(w,apv,state,2051,"target-257",a,basisSeconds); controls=[controls;row]; residuals=[residuals;observableRows];
    target=table(thermalConstructionSeconds,basisSeconds,string(version),string(computer),maxNumCompThreads,VariableNames={'thermalConstructionSeconds','diagnosticConstructionSeconds','matlab','platform','maximumThreads'});
    writetable(target,fullfile(outputDirectory,'target-environment.csv'));
end
writetable(controls,fullfile(outputDirectory,'controls.csv'));writetable(fits,fullfile(outputDirectory,'manufactured-fits.csv'));writetable(refinement,fullfile(outputDirectory,'refinement.csv'));
writetable(residuals,fullfile(outputDirectory,'residual-reference-budget.csv'));
results=struct(controls=controls,fits=fits,refinement=refinement,residualBudget=residuals);
assert(all(residuals.referenceAllowanceRatio<=.2),'A residual reference exhausted its allowance.');
assert(all(residuals.diagnosticAllowanceRatio<=1 & residuals.scaleAllowanceRatio<=1),'A physical residual failed its allowance.');
assert(all(controls.referenceCoefficientError<=2e-9),'Independent quadrature reference exhausted its declared allowance.');
assert(all(controls.coefficientError<=1e-8),'Independent coefficient projection failed.');
assert(all(controls.inventoryError<=1e-8),'Independent inventory and cross-term accounting failed.');
assert(all(controls.recompositionError<=5e-12),'Physical component recomposition failed.');
assert(all(fits.passed),'Known modal controls failed; inspect source fit separately.');
end
function apv=newAPV(w,Nz,count,multiplier)
integralN2=w.N20*w.Lz;
if w.inverseScale~=0,integralN2=w.N20*(-expm1(-2*w.inverseScale*w.Lz))/(2*w.inverseScale);end
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny Nz],N2Function=w.N2Function,g=w.g,latitude=w.latitude,rho0=w.rho0,g0=-multiplier*integralN2,gd=integralN2/multiplier,apvModeCount=count,mdaModeCount=1,shouldAntialias=w.shouldAntialias,shouldCheckQuadraticAliasing=false);
end
function [row,residualRows]=measureCase(w,apv,state,Q,label,a,basisSeconds)
fprintf('T9 %s a=%g thermal=%d diagnostic=%d/%d Q=%d\n',label,a,w.thermalModeCount,apv.apvModeCount,apv.Nz,Q);
tic; d=w.apvDecomposition(apv,state=state,quadratureCount=Q); preparationSeconds=toc;
times=zeros(5,1);
for j=1:5,tic;w.apvDecomposition(apv,state=state,time=j,quadratureCount=Q);times(j)=toc;end
cachedSeconds=median(times);
tic; [~,fields]=w.apvDecomposition(apv,state=state,quadratureCount=Q,fieldNames=["qgpv","eta","u","v","ssh","endpointAnomalies"]); fieldSeconds=toc;
reference=thermalAPVDiagnosticReference(w,apv,state,2*Q); refined=thermalAPVDiagnosticReference(w,apv,state,4*Q);
residualRows=physicalResidualRows(w,apv,d,reference,refined,Q,label);
vector=@(v)[v.coefficients.Ag_q(:);v.coefficients.Ag_0(:)];
referenceCoefficientError=norm(vector(reference)-vector(refined))/norm(vector(refined)); coefficientError=norm(vector(d)-vector(refined))/norm(vector(refined));
inventoryError=0; recompositionError=0;
for name=string(fieldnames(refined.inventories)).'
    expected=refined.inventories.(name); actual=d.inventories.(name); scale=sum(abs(cell2mat(struct2cell(expected))));
    if scale>0,inventoryError=max(inventoryError,max(abs(cell2mat(struct2cell(expected))-cell2mat(struct2cell(actual))))/scale);end
    pieces=rmfield(actual,'total'); scale=sum(abs(cell2mat(struct2cell(pieces))));
    if scale>0,recompositionError=max(recompositionError,abs(actual.total-sum(cell2mat(struct2cell(pieces))))/scale);end
end
for name=string(fieldnames(fields.total)).'
    sumFields=fields.apv.(name)+fields.zeroAPV.(name)+fields.mean.(name)+fields.residual.(name);
    scale=norm(fields.apv.(name)(:))+norm(fields.zeroAPV.(name)(:))+norm(fields.mean.(name)(:))+norm(fields.residual.(name)(:));
    if scale>0,recompositionError=max(recompositionError,norm(fields.total.(name)(:)-sumFields(:))/scale);end
end
qgpvResidual=d.residuals.qgpv.relative; energyResidual=d.residuals.energyNorm.relative; surfaceResidual=d.residuals.endpointAnomalies.absolute(1); bottomResidual=d.residuals.endpointAnomalies.absolute(2);
row=table(label,a,w.thermalModeCount,apv.Nz,apv.apvModeCount,Q,referenceCoefficientError,coefficientError,inventoryError,recompositionError,qgpvResidual,energyResidual,surfaceResidual,bottomResidual,basisSeconds,preparationSeconds,cachedSeconds,fieldSeconds,VariableNames={'control','inverseScale','thermalCount','diagnosticNz','apvCount','quadratureCount','referenceCoefficientError','coefficientError','inventoryError','recompositionError','qgpvResidual','energyResidual','surfaceResidual','bottomResidual','basisSeconds','preparationSeconds','cachedSeconds','fieldSeconds'});
end
function state=surfaceLayerState(w,sharpness)
state=w.coefficientState(); state.Ath=0*state.Ath;state.Amda=0*state.Amda;
[x,weights]=legpts(max(513,2*w.thermalModeCount+1)); values=feval(legpoly(0:w.thermalModeCount-1),x);
c=((2*(0:w.thermalModeCount-1)'+1)/2).*(values'*(weights(:).*exp(-sharpness*(1-x))));
columns=find(w.k(w.klNonzero)>0 & w.l(w.klNonzero)==0,1);
state.Ath(:,columns)=100*w.polynomialToThermal(:,:,w.klNonzeroKhUniqueIndex(columns))*c;
end

function results=qualifyResources(outputDirectory)
% This independent fresh target pass measures resources and every residual
% allowance; it does not repeat the completed small-control matrix.
a=1/1300; Q=2051;
fprintf('T9 supplemental target: construct thermal257/native385 and APV6/native1025.\n');
tic;w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 4000],[18 18 385],N2Function=@(z)(5.2e-3)^2*exp(2*a*z),latitude=24,thermalModeCount=257,mdaModeCount=4); thermalSeconds=toc;
state=surfaceLayerState(w,30);state.Amda=[.02;-.01;.03;-.04];
tic;apv=newAPV(w,1025,6,1);basisSeconds=toc;
fprintf('T9 supplemental: prepare maps and record cached allocation profiles.\n');
tic;d=w.apvDecomposition(apv,state=state,quadratureCount=Q);preparationSeconds=toc;
% whos reads these measured values by variable name.
data=WVInternal.thermalAPVDecompositionData(w,apv,Q); %#ok<NASGU>
storage=whos('data'); mapValueBytes=storage.bytes; clear data
% profile('status') omits MemoryLogging; the service configuration is the
% snapshot used by MATLAB's own profile CLI. Keep this in authoring code.
profiler=matlab.internal.profiler.ProfilerService.getInstance();
profilerSettings=profiler.getProfilersConfig();
profilerCleanup=onCleanup(@()restoreProfiler(profiler,profilerSettings));
memoryRows=table();
for requestedFields=[false true]
    profile clear;profile on -memory
    cleanup=onCleanup(@()profile('off'));
    if requestedFields
        [~,fields]=w.apvDecomposition(apv,state=state,quadratureCount=Q,fieldNames=["u","v","qgpv","eta","eta_i","buoyancy","ssh","endpointAnomalies"]); %#ok<ASGLU>
        output=whos('fields'); outputBytes=output.bytes;clear fields
    else
        w.apvDecomposition(apv,state=state,quadratureCount=Q);outputBytes=0;
    end
    profile off;info=profile('info');clear cleanup
    selected=info.FunctionTable(contains(string({info.FunctionTable.FunctionName}),"thermalAPVDecomposition") | contains(string({info.FunctionTable.FunctionName}),".apvDecomposition"));
    for j=1:numel(selected)
        item=selected(j);
        memoryRows=[memoryRows;table(requestedFields,string(item.FunctionName),item.NumCalls,item.TotalMemAllocated,item.TotalMemFreed,item.PeakMem,outputBytes,VariableNames={'requestedVolumes','functionName','calls','totalAllocatedBytes','totalFreedBytes','profilerPeakBytes','returnedFieldBytes'})]; %#ok<AGROW>
    end
end
clear profilerCleanup
writetable(memoryRows,fullfile(outputDirectory,'allocation-profile.csv'));
resources=table(thermalSeconds,basisSeconds,preparationSeconds,mapValueBytes,w.Lx,w.Ly,w.Lz,w.Nx,w.Ny,w.Nz,w.thermalModeCount,w.N20,w.inverseScale,w.latitude,apv.Nz,apv.apvModeCount,Q,apv.g0,apv.gd,string(version),string(computer),maxNumCompThreads,VariableNames={'thermalConstructionSeconds','diagnosticConstructionSeconds','preparationSeconds','retainedValueBytes','Lx','Ly','Lz','Nx','Ny','sourceNz','thermalCount','N20','inverseScale','latitude','diagnosticNz','apvCount','quadratureCount','g0','gd','matlab','platform','maximumThreads'});
writetable(resources,fullfile(outputDirectory,'resources.csv'));
fprintf('T9 supplemental: independently refine every physical residual at 2Q and 4Q.\n');
reference=thermalAPVDiagnosticReference(w,apv,state,2*Q); refined=thermalAPVDiagnosticReference(w,apv,state,4*Q);
rows=physicalResidualRows(w,apv,d,reference,refined,Q,"seasonal-parameter-target");
writetable(rows,fullfile(outputDirectory,'residual-reference-budget.csv'));
results=struct(resources=resources,memory=memoryRows,residualBudget=rows);
assert(all(rows.referenceAllowanceRatio<=.2),'A residual reference consumes more than one fifth of its allowance.');
assert(all(rows.diagnosticAllowanceRatio<=1 & rows.scaleAllowanceRatio<=1),'A target residual or reference scale fails its declared allowance.');
end

function results=qualifyResidualControls(outputDirectory)
rows=table();
for a=[0 1/1300]
    w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=33,mdaModeCount=4);
    thermalManufacturedState(w,[2 3 8],100);w.Amda=[.02;-.01;.03;-.04];state=w.coefficientState();
    apv=newAPV(w,129,6,1);Q=257;
    d=w.apvDecomposition(apv,quadratureCount=Q);
    reference=thermalAPVDiagnosticReference(w,apv,state,2*Q);refined=thermalAPVDiagnosticReference(w,apv,state,4*Q);
    rows=[rows;physicalResidualRows(w,apv,d,reference,refined,Q,"small-mixed")]; %#ok<AGROW>
    writetable(rows,fullfile(outputDirectory,'residual-reference-budget.csv'));
end
results=struct(residualBudget=rows);
assert(all(rows.referenceAllowanceRatio<=.2),'A residual reference exhausted its allowance.');
assert(all(rows.diagnosticAllowanceRatio<=1 & rows.scaleAllowanceRatio<=1),'A physical residual failed its allowance.');
end
function rows=physicalResidualRows(w,apv,d,reference,refined,Q,label)
rows=table();
for name=string(fieldnames(d.residuals)).'
    actual=d.residuals.(name); medium=reference.residuals.(name); fine=refined.residuals.(name);
    switch name
        case "qgpv",floor=1e-13;
        case {"buoyancy","velocity","energyNorm"},floor=1e-12;
        otherwise,floor=1e-10;
    end
    for component=1:numel(fine.absolute)
        allowance=1e-8*fine.reference(component)+floor;
        referenceError=max(abs(medium.absolute(component)-fine.absolute(component)),abs(medium.reference(component)-fine.reference(component)));
        error=abs(actual.absolute(component)-fine.absolute(component)); scaleError=abs(actual.reference(component)-fine.reference(component));
        rows=[rows;table(label,w.N20,w.inverseScale,w.latitude,w.thermalModeCount,apv.Nz,apv.apvModeCount,Q,name,component,actual.absolute(component),fine.absolute(component),fine.reference(component),allowance,referenceError,error,scaleError,referenceError/allowance,error/allowance,scaleError/allowance,VariableNames={'control','N20','inverseScale','latitude','thermalCount','diagnosticNz','apvCount','quadratureCount','observable','component','actualResidual','referenceResidual','referenceMagnitude','allowance','referenceRefinementError','diagnosticError','referenceScaleError','referenceAllowanceRatio','diagnosticAllowanceRatio','scaleAllowanceRatio'})]; %#ok<AGROW>
    end
end
end

function restoreProfiler(profiler,settings)
profile off
profiler.configureProfilers(settings);
end
