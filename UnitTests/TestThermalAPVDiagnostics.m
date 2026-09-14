classdef TestThermalAPVDiagnostics < matlab.unittest.TestCase
    properties
        thermalStates
        diagnosticTransforms
    end
    methods (TestClassSetup)
        function constructControls(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            testCase.thermalStates=cell(1,2); testCase.diagnosticTransforms=cell(1,2);
            for j=1:2
                a=(j-1)/1300; N2=@(z)1e-4*exp(2*a*z);
                w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=N2,thermalModeCount=33,mdaModeCount=4);
                testCase.thermalStates{j}=w.scientificState;
                testCase.diagnosticTransforms{j}=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 129],N2Function=N2,apvModeCount=6,mdaModeCount=1,shouldCheckQuadraticAliasing=false);
            end
        end
    end
    methods (Test,TestTags="full")
        function independentProjectionAndPhysicalAccounting(testCase)
            for j=1:2
                w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{j}); apv=testCase.diagnosticTransforms{j};
                thermalManufacturedState(w,[2 3 8],100); w.Amda=[.02;-.01;.03;-.04];
                state=w.coefficientState(); originalAPV=apv.coefficientState(); w.t=123; apv.t=17;
                diagnosis=w.apvDecomposition(apv,quadratureCount=513);
                reference=thermalAPVDiagnosticReference(w,apv,state,1025);
                refined=thermalAPVDiagnosticReference(w,apv,state,2049);
                verifyScaled(testCase,reference.coefficients.Ag_q,refined.coefficients.Ag_q,2e-9);
                verifyScaled(testCase,diagnosis.coefficients.Ag_q,refined.coefficients.Ag_q,1e-8);
                verifyScaled(testCase,diagnosis.coefficients.Ag_0,refined.coefficients.Ag_0,1e-8);
                for name=string(fieldnames(reference.inventories)).'
                    actual=diagnosis.inventories.(name); expected=refined.inventories.(name);
                    scale=sum(abs(cell2mat(struct2cell(expected))));
                    for term=string(fieldnames(expected)).'
                        testCase.verifyLessThanOrEqual(abs(actual.(term)-expected.(term)),1e-8*scale+1e-24);
                    end
                    pieces=rmfield(actual,'total');
                    testCase.verifyLessThanOrEqual(abs(actual.total-sum(cell2mat(struct2cell(pieces)))),5e-12*sum(abs(cell2mat(struct2cell(pieces))))+1e-24);
                    testCase.verifyEqual(sum(diagnosis.radialSpectrum.(name).total)+actual.mean,actual.total,RelTol=5e-12,AbsTol=1e-24);
                end
                for name=string(fieldnames(refined.residuals)).'
                    actual=diagnosis.residuals.(name); expected=refined.residuals.(name);
                    testCase.verifyLessThanOrEqual(abs(actual.absolute-expected.absolute),1e-8*expected.reference+absoluteFloor(name));
                end
                testCase.verifyEqual(diagnosis.mean.sourceAmda,state.Amda);
                testCase.verifyEqual(diagnosis.time,123);
                testCase.verifyEqual(w.coefficientState(),state); testCase.verifyEqual(apv.coefficientState(),originalAPV);
                testCase.verifyEqual([w.t apv.t],[123 17]);
                apv.t=0;
            end
        end
        function requestedFieldsRecomposeAndMatchFourierReference(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{2}); apv=testCase.diagnosticTransforms{2};
            thermalManufacturedState(w,[2 3 4],100); w.Amda=[.02;-.01;.03;-.04];
            names=["u","v","qgpv","eta","eta_i","buoyancy","ssh","endpointAnomalies"];
            [~,fields]=w.apvDecomposition(apv,quadratureCount=257,fieldNames=names);
            reference=thermalAPVDiagnosticReference(w,apv,w.coefficientState(),257);
            testCase.verifyEqual(fields.z,reference.z,AbsTol=2e-11);
            for name=names
                recomposed=fields.apv.(name)+fields.zeroAPV.(name)+fields.mean.(name)+fields.residual.(name);
                scale=norm(fields.apv.(name)(:))+norm(fields.zeroAPV.(name)(:))+norm(fields.mean.(name)(:))+norm(fields.residual.(name)(:));
                testCase.verifyLessThanOrEqual(norm(fields.total.(name)(:)-recomposed(:)),5e-12*scale+absoluteFloor(name));
                for component=["apv","zeroAPV","mean","residual","total"]
                    physical=explicitFourier(w,reference.components,component,name);
                    actual=fields.(component).(name);
                    testCase.verifyLessThanOrEqual(norm(actual(:)-physical(:)),1e-8*norm(physical(:))+sqrt(numel(actual))*absoluteFloor(name));
                    testCase.verifyTrue(isreal(actual));
                end
            end
            [~,small]=w.apvDecomposition(apv,quadratureCount=257);
            testCase.verifyEqual(sort(string(fieldnames(small.total))),sort(["ssh";"endpointAnomalies"]));
            testCase.verifySize(small.total.endpointAnomalies,[w.Nx w.Ny 2]);
            testCase.verifyError(@()w.apvDecomposition(apv,fieldNames="notAField"),'WV:APVDiagnosticField');
        end
        function nullAndMeanControlsHaveHonestResidualScales(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{2}); apv=testCase.diagnosticTransforms{2};
            d=w.apvDecomposition(apv,quadratureCount=257);
            for name=string(fieldnames(d.residuals)).'
                testCase.verifyEqual(d.residuals.(name).absolute,zeros(size(d.residuals.(name).absolute)));
                testCase.verifyTrue(all(isnan(d.residuals.(name).relative)));
            end
            w.Amda=[.02;-.01;.03;-.04]; state=w.coefficientState();
            d=w.apvDecomposition(apv,quadratureCount=257);
            testCase.verifyEqual(d.coefficients.Ag_q,zeros(size(d.coefficients.Ag_q)));
            testCase.verifyEqual(d.coefficients.Ag_0,zeros(size(d.coefficients.Ag_0)));
            reference=thermalAPVDiagnosticReference(w,apv,state,1025);
            for name=string(fieldnames(reference.inventories)).'
                testCase.verifyEqual(d.inventories.(name).total,reference.inventories.(name).mean,RelTol=1e-8,AbsTol=1e-20);
                testCase.verifyEqual(d.inventories.(name).total,d.inventories.(name).mean);
            end
            testCase.verifyEqual(d.mean.sourceAmda,state.Amda);
        end
        function directionsAgreeWithIndependentDifferences(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{2}); apv=testCase.diagnosticTransforms{2};
            thermalManufacturedState(w,[2 3 4],100); w.Amda=[.02;-.01;.03;-.04]; state=w.coefficientState();
            direction=struct(Ath=.2*state.Ath+.1i*circshift(state.Ath,1,2),Amda=flipud(state.Amda)/3);
            opposite=struct(Ath=-direction.Ath,Amda=-direction.Amda);
            d=w.apvDecomposition(apv,tendency=[direction opposite],quadratureCount=513);
            h=1e-3; plus=state; minus=state;
            for family=["Ath","Amda"],plus.(family)=state.(family)+h*direction.(family);minus.(family)=state.(family)-h*direction.(family);end
            positive=thermalAPVDiagnosticReference(w,apv,plus,1025); negative=thermalAPVDiagnosticReference(w,apv,minus,1025);
            reference=thermalAPVDiagnosticReference(w,apv,direction,1025);
            verifyScaled(testCase,d.directional(1).coefficients.Ag_q,reference.coefficients.Ag_q,1e-8);
            verifyScaled(testCase,d.directional(1).coefficients.Ag_0,reference.coefficients.Ag_0,1e-8);
            for name=string(fieldnames(reference.residuals)).'
                actual=d.directional(1).residualRateNorms.(name); expected=reference.residuals.(name);
                allowance=1e-8*expected.reference+absoluteFloor(name);
                testCase.verifyLessThanOrEqual(abs(actual.absolute-expected.absolute),allowance);
                testCase.verifyLessThanOrEqual(abs(actual.reference-expected.reference),allowance);
                oppositeNorm=d.directional(2).residualRateNorms.(name);
                testCase.verifyEqual(oppositeNorm.absolute,actual.absolute,RelTol=5e-12,AbsTol=absoluteFloor(name));
                testCase.verifyEqual(oppositeNorm.reference,actual.reference,RelTol=5e-12,AbsTol=absoluteFloor(name));
            end
            for name=string(fieldnames(d.inventories)).'
                expected=(cell2mat(struct2cell(positive.inventories.(name)))-cell2mat(struct2cell(negative.inventories.(name))))/(2*h);
                actual=cell2mat(struct2cell(d.directional(1).inventories.(name)));
                testCase.verifyLessThanOrEqual(abs(actual-expected),1e-8*sum(abs(expected))+1e-20);
                testCase.verifyEqual(d.directional(2).inventories.(name).total,-d.directional(1).inventories.(name).total,RelTol=5e-12,AbsTol=1e-24);
            end
            testCase.verifyEqual(w.coefficientState(),state);
        end
        function richerBandDoesNotRequireThermalRightInverse(testCase)
            source=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4+zeros(size(z)),thermalModeCount=17,mdaModeCount=2);
            apv=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 257],N2Function=source.N2Function,apvModeCount=20,mdaModeCount=1,shouldCheckQuadraticAliasing=false); thermalManufacturedState(source,[2 3 4],100);
            d=source.apvDecomposition(apv,quadratureCount=513);
            testCase.verifySize(d.coefficients.Ag_q,[20 numel(source.klNonzero)]);
            testCase.verifyGreaterThan(apv.apvModeCount+2,source.thermalModeCount);
            reference=thermalAPVDiagnosticReference(source,apv,source.coefficientState(),1025);
            verifyScaled(testCase,d.coefficients.Ag_q,reference.coefficients.Ag_q,1e-8);
        end
        function cacheTracksOnlyScientificDependenciesAndPreservesClosure(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{1}); apv=testCase.diagnosticTransforms{1};
            thermalManufacturedState(w,[2 3 4],100); w.Amda=[.02;-.01;.03;-.04];
            force=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5); w.addForcing(force);
            forceState=struct();
            for name=string(force.classRequiredPropertyNames()),forceState.(name)=force.(name);end
            [before,~,processes]=w.coefficientTendency(linearDynamics=true); original=w.coefficientState(); scientific=w.scientificState;
            settings=profile('status'); testCase.addTeardown(@()profile('-detail',settings.DetailLevel));
            profile clear; profile on
            cleanup=onCleanup(@()profile('off'));
            first=w.apvDecomposition(apv,quadratureCount=257);
            w.Ath=2*w.Ath; w.t=100; apv.t=42;
            changed=w.apvDecomposition(apv,quadratureCount=257);
            profile off; info=profile('info');
            testCase.verifyEqual(preparationCalls(info),1);
            testCase.verifyEqual(changed.coefficients.Ag_q,2*first.coefficients.Ag_q);
            w.Ath=original.Ath; apv.t=0; w.t=0;
            other=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=w.N2Function,g0=1.2*apv.g0,gd=.8*apv.gd,apvModeCount=8,mdaModeCount=1,shouldCheckQuadraticAliasing=false);
            profile resume
            w.apvDecomposition(other,quadratureCount=257);
            w.apvDecomposition(other,quadratureCount=513);
            replacement=WVTransformFreeSurfaceThermalQG(scientificState=w.scientificState);
            replacement.apvDecomposition(other,quadratureCount=513);
            profile off; info=profile('info'); clear cleanup
            testCase.verifyEqual(preparationCalls(info),4);
            for name=string(fieldnames(forceState)).',testCase.verifyEqual(force.(name),forceState.(name));end
            [after,~,afterProcesses]=w.coefficientTendency(linearDynamics=true);
            testCase.verifyEqual(after,before);testCase.verifyEqual(afterProcesses.labels,processes.labels);
            testCase.verifyEqual(w.coefficientState(),original);testCase.verifyEqual(w.scientificState,scientific);
        end
        function orderedPhysicalProcessesUseTheSavedClockOnce(testCase)
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=17,mdaModeCount=4,kappa_z=.001,shouldCheckQuadraticAliasing=true);
            apv=testCase.diagnosticTransforms{2}; thermalManufacturedState(w,[2 3 4],100); w.Amda=[.02;-.01;.03;-.04]; w.t=1500;
            w.addForcing(WVNonlinearAdvection(w));
            w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=sin(2*pi*w.Y(:,:,1)/w.Ly),amplitude=1e-6,period=20000,phase=.3));
            w.addForcing(WVBottomFrictionQuadratic(w,Cd=1e-3));
            state=w.coefficientState(); [total,~,processes]=w.coefficientTendency();
            d=w.apvDecomposition(apv,tendency=processes.tendencies,quadratureCount=513);
            totalDiagnosis=w.apvDecomposition(apv,tendency=total,quadratureCount=513);
            physical=w.quadraticDiagnostics(tendency=processes.tendencies);
            testCase.verifyEqual(d.time,1500);testCase.verifyEqual(numel(d.directional),numel(processes.labels));
            for name=string(fieldnames(d.inventories)).'
                actual=arrayfun(@(value)value.inventories.(name).total,d.directional).';
                expected=physical.(name+"Tendency"); scale=sum(abs(expected));
                testCase.verifyLessThanOrEqual(abs(actual-expected),1e-8*scale+1e-20);
                testCase.verifyLessThanOrEqual(abs(sum(actual)-totalDiagnosis.directional.inventories.(name).total),5e-12*scale+1e-20);
            end
            testCase.verifyEqual(w.coefficientState(),state);testCase.verifyEqual(w.t,1500);
            [~,~,after]=w.coefficientTendency();testCase.verifyEqual(after.labels,processes.labels);testCase.verifyEqual(after.tendencies,processes.tendencies);
        end
        function warmCacheRejectsChangedPhysicsAndInvalidState(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{1}); apv=testCase.diagnosticTransforms{1};
            originalGravity=apv.g; cleanup=onCleanup(@()restoreGravity(apv,originalGravity));
            w.apvDecomposition(apv,quadratureCount=257);
            apv.g=2*originalGravity;
            testCase.verifyError(@()w.apvDecomposition(apv,quadratureCount=257),'WV:APVDiagnosticGeometry');
            w.g=apv.g;
            testCase.verifyError(@()w.apvDecomposition(apv,quadratureCount=257),'WV:APVDiagnosticGeometry');
            apv.g=originalGravity; w.g=originalGravity;
            testCase.verifyError(@()w.apvDecomposition(apv,state=struct(Ath=w.Ath)),'WV:APVDiagnosticState');
            testCase.verifyError(@()w.apvDecomposition(apv,quadratureCount=17),'WV:APVDiagnosticQuadrature');
            clear cleanup
        end
        function nativeAPVContractAndSeparateEndpointFits(testCase)
            for j=1:2
                w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.thermalStates{j}); apv=testCase.diagnosticTransforms{j};
                for kind=["apv","surface","bottom","mixed"]
                    [state,expected,fit]=thermalAPVDiagnosticFit(w,apv,kind);
                    d=w.apvDecomposition(apv,state=state,quadratureCount=513);
                    testCase.verifyLessThan(fit,2e-9);
                    verifyScaled(testCase,[d.coefficients.Ag_q;d.coefficients.Ag_0],[expected.Ag_q;expected.Ag_0],1e-8);
                    reference=thermalAPVDiagnosticReference(w,apv,state,1025);
                    testCase.verifyLessThan(reference.residuals.energyNorm.relative,1e-8);
                    testCase.verifyEqual(w.z,apv.z,AbsTol=2e-10);
                    temporary=WVTransformFreeSurfaceThermalQG(scientificState=w.scientificState);temporary.Ath=state.Ath;temporary.Amda=state.Amda;
                    physical=temporary.reconstructFields(["qgpv","endpointAnomalies"]);
                    qHat=temporary.transformFromSpatialDomainWithFourier(physical.qgpv);
                    geometry=WVGeometryDoublyPeriodic([w.Lx w.Ly],[w.Nx w.Ny],Nz=2,shouldAntialias=w.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=w.conjugateDimension);
                    endpoints=geometry.transformFromSpatialDomainWithFourier(physical.endpointAnomalies);
                    [nativeQ,native0]=apv.transformStateForward(qHat(:,w.klNonzero),endpoints(:,w.klNonzero));
                    verifyScaled(testCase,[d.coefficients.Ag_q;d.coefficients.Ag_0],[nativeQ;native0],1e-8);
                end
            end
        end
    end
end
function verifyScaled(testCase,actual,expected,tolerance)
scale=norm(expected,'fro');
if scale==0,testCase.verifyEqual(actual,zeros(size(actual)));else,testCase.verifyLessThanOrEqual(norm(actual-expected,'fro'),tolerance*scale);end
end
function floor=absoluteFloor(name)
switch name
    case "qgpv",floor=1e-13;
    case {"u","v","velocity","buoyancy"},floor=1e-12;
    case "energyNorm",floor=1e-12;
    otherwise,floor=1e-10;
end
end
function fields=explicitFourier(w,components,component,name)
if component=="mean"
    value=components.mean.(name); fields=repmat(reshape(real(value),1,1,[]),w.Nx,w.Ny,1); return
end
value=components.(component).(name); fields=zeros(w.Nx,w.Ny,size(value,1));
x=w.x(:); y=w.y(:).';
for column=1:numel(w.klNonzero)
    phase=exp(1i*(w.k(w.klNonzero(column))*x+w.l(w.klNonzero(column))*y));
    fields=fields+2*real(phase.*reshape(value(:,column),1,1,[]));
end
if component=="total",fields=fields+repmat(reshape(real(components.mean.(name)),1,1,[]),w.Nx,w.Ny,1);end
end

function count=preparationCalls(info)
entries=info.FunctionTable(endsWith(string({info.FunctionTable.FunctionName}),"thermalAPVDecompositionData"));
count=sum([entries.NumCalls]);
end

function restoreGravity(apv,value)
apv.g=value;
end
