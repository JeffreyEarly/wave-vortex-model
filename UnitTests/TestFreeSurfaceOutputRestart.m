classdef TestFreeSurfaceOutputRestart < matlab.unittest.TestCase
    properties (TestParameter)
        modelType = {"qg","boussinesq"}
        emptyGroupPayload = {false,true}
        partialPayload = {"oneVariable","allObservers"}
        observerType = {"particles","tracer"}
    end
    methods (Test, TestTags="full")
        function partialPayloadDoesNotRestoreObserverState(testCase,modelType,partialPayload)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"exponential");
            file=configureOutput(model,fullfile(fixture.Folder,'partial.nc'));
            model.integrateToTime(207,shouldShowIntegrationDiagnostics=false);
            expected=snapshot(model);
            if partialPayload=="oneVariable"
                names=model.wvt.coefficientStateVariableNamesForPersistence(); name=names{1};
                group=file.outputGroupWithName('wave-vortex');
                group.group.variableWithName(name).setValueAlongDimensionAtIndex(3*model.wvt.(name),'t',group.incrementsWrittenToGroup+1);
                file.ncfile.sync();
            else
                poisonNextRecords(model,file);
            end
            model.closeNetCDFFile();
            restored=WVModel.modelFromFile(char(file.path)); cleanup=onCleanup(@()restored.closeNetCDFFile());
            testCase.verifyEqual(restored.wvt.t,207)
            testCase.verifyEqual(restored.wvt.coefficientState(),expected.coefficients)
            testCase.verifyEqual(restored.fluxedObservingSystemWithName('particles').initialConditions(),expected.particles)
            testCase.verifyEqual(restored.tracer('dye'),expected.tracer)
            actual=snapshot(restored);
            testCase.verifyEqual(actual.tracked,expected.tracked)
            verifySharedObservers(testCase,restored)
        end
        function scheduledOutputsAndContinuationAgree(testCase,modelType)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            result=runCase(modelType,"exponential",string(fixture.Folder));
            testCase.verifyLessThan(result.restartError,1e-12)
            testCase.verifyLessThan(result.outputError,1e-12)
        end
        function unwrittenSharedObserversRestoreFromCommittedGroup(testCase,modelType,emptyGroupPayload)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"exponential"); file=configureOutput(model,fullfile(fixture.Folder,'late.nc'));
            late=file.addNewEvenlySpacedOutputGroup('late',initialTime=247,outputInterval=40);
            late.addObservingSystem(model.fluxedObservingSystemWithName('particles'));
            late.addObservingSystem(model.fluxedObservingSystemWithName('dye'));
            model.integrateToTime(207,shouldShowIntegrationDiagnostics=false); expected=snapshot(model);
            if emptyGroupPayload
                particles=model.fluxedObservingSystemWithName('particles'); state=particles.initialConditions(); state{1}=state{1}+1000;
                particles.updateIntegratorValues(207,state);
                tracer=model.fluxedObservingSystemWithName('dye'); tracer.updateIntegratorValues(207,{tracer.phi+7});
                late.stageTimeStepToNetCDFFile(file.ncfile,247); file.ncfile.sync();
            end
            model.closeNetCDFFile();
            restored=WVModel.modelFromFile(char(file.path)); cleanup=onCleanup(@()restored.closeNetCDFFile());
            testCase.verifyEqual(assertSnapshot(snapshot(restored),expected),0)
            late=restored.outputFiles(1).outputGroupWithName('late');
            testCase.verifyEqual(late.incrementsWrittenToGroup,uint64(0))
            for name=["particles","dye"]
                testCase.verifyTrue(late.observingSystemWithName(name)==restored.fluxedObservingSystemWithName(name))
            end
            restored.setupIntegrator(integratorType="fixed",deltaT=5);
            restored.integrateToTime(247,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(late.group.readVariables('t'),247)
            testCase.verifyEqual(late.incrementsWrittenToGroup,uint64(1))
        end
        function observerWithoutSavedStateIsRejected(testCase,modelType,observerType)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"constant"); file=configureOutput(model,fullfile(fixture.Folder,'missing-observer.nc'));
            late=file.addNewEvenlySpacedOutputGroup('late',initialTime=247,outputInterval=40);
            if observerType=="particles"
                observer=WVLagrangianParticles(model,name="unsaved",x=1000,y=2000,z=-300,isXYOnly=modelType=="qg");
            else
                observer=WVTracer(model,name="unsaved",phi=ones(model.wvt.spatialMatrixSize),isXYOnly=modelType=="qg");
            end
            late.addObservingSystem(observer);
            model.integrateToTime(207,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            testCase.verifyError(@()WVModel.modelFromFile(char(file.path)),'')
            nc=NetCDFFile(char(file.path)); nc.close();
        end
        function eachFileRestoresOnlyItsOwnOutputGraph(testCase,modelType)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"exponential"); pathA=fullfile(fixture.Folder,'first.nc'); pathB=fullfile(fixture.Folder,'second.nc');
            configureOutput(model,pathA); model.createNetCDFFileForModelOutput(char(pathB),outputInterval=20);
            model.integrateToTime(207,shouldShowIntegrationDiagnostics=false); expected=snapshot(model); model.closeNetCDFFile();
            for path=string({pathA,pathB})
                restored=WVModel.modelFromFile(char(path)); cleanup=onCleanup(@()restored.closeNetCDFFile());
                [~,name,ext]=fileparts(path);
                testCase.verifyEqual(restored.outputFileNames,name+ext)
                expectedGroups="wave-vortex";
                if path==pathA, expectedGroups=["wave-vortex";"fields"]; end
                testCase.verifyEqual(sort(string(restored.outputFiles(1).outputGroupNames())),sort(expectedGroups))
                testCase.verifyEqual(assertSnapshot(snapshot(restored),expected),0)
                clear cleanup
            end
        end
        function noCommitAndRecordHolesAreRejected(testCase,modelType)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"constant"); file=configureOutput(model,fullfile(fixture.Folder,'no-commit.nc'));
            file.initializeOutputFile();
            for group=reshape(file.outputGroups,1,[]), group.stageTimeStepToNetCDFFile(file.ncfile,127); end
            file.ncfile.sync(); model.closeNetCDFFile();
            testCase.verifyError(@()WVModel.modelFromFile(char(file.path)),'WVTransform:NoCommittedRestartRecord')
            for groupName=["wave-vortex","fields"]
                model=newModel(modelType,"constant"); path=fullfile(fixture.Folder,groupName+"-hole.nc"); configureOutput(model,path);
                model.integrateToTime(167,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
                nc=NetCDFFile(char(path)); group=nc.groupWithName(groupName);
                count=WVModelOutputGroup.committedRecordCountForGroup(group);
                group.variableWithName('t').setValueAlongDimensionAtIndex(247,'t',count+2); nc.close();
                testCase.verifyError(@()WVModel.modelFromFile(char(path)),'WVModelOutputGroup:NoncontiguousCommittedRecords')
                nc=NetCDFFile(char(path)); nc.close();
            end
        end
        function duplicateCompleteStreamsAreRejected(testCase,modelType)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            model=newModel(modelType,"constant"); path=fullfile(fixture.Folder,'duplicate.nc'); file=configureOutput(model,path);
            duplicate=file.addNewEvenlySpacedOutputGroup('duplicate',outputInterval=40);
            names=model.wvt.coefficientStateVariableNamesForPersistence();
            duplicate.addObservingSystem(WVEulerianFields(model,fieldNames=names));
            file.outputTimesForIntegrationPeriod(127,127);
            testCase.verifyError(@()file.writeTimeStepToOutputFile(127),'WVModelOutputFile:MultipleCompleteCoefficientStreams')
            testCase.verifyFalse(isfile(path))
            % A malformed file must also be rejected by the reader.
            model=newModel(modelType,"constant"); configureOutput(model,path);
            model.integrateToTime(167,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
            nc=NetCDFFile(char(path)); duplicate=nc.addGroup('duplicate');
            duplicate.addDimension('t',length=Inf,type='double');
            duplicate.variableWithName('t').setValueAlongDimensionAtIndex(167,'t',1);
            for name=string(names)
                annotation=model.wvt.propertyAnnotationWithName(name);
                variable=duplicate.addVariable(char(name),[annotation.dimensions {'t'}],type='double',isComplex=annotation.isComplex);
                variable.setValueAlongDimensionAtIndex(model.wvt.(name),'t',1);
            end
            nc.close();
            testCase.verifyError(@()WVModel.modelFromFile(char(path)),'WVTransform:AmbiguousRestartState')
            nc=NetCDFFile(char(path)); nc.close();
        end
    end
    methods (Static)
        function results=runStudy(outputFolder)
            arguments (Input)
                outputFolder (1,1) string
            end
            if ~isfolder(outputFolder), mkdir(outputFolder); end
            rows=struct([]);
            for type=["qg","boussinesq"]
                for profile=["constant","exponential"]
                    rows=[rows;runCase(type,profile,outputFolder)]; %#ok<AGROW>
                end
            end
            results=struct2table(rows);
            writetable(results,fullfile(outputFolder,'issue-352-output-restart.csv'));
        end
        function verifyRestartWithoutProvider(outputFolder)
            assert(isempty(which('IMSolverSpectral')),'InternalModes must be unavailable.')
            for type=["qg","boussinesq"]
                for profile=["constant","exponential"]
                    key=type+"-"+profile;
                    reference=load(fullfile(outputFolder,key+"-reference.mat"));
                    file=fullfile(outputFolder,key+"-checkpoint.nc");
                    model=WVModel.modelFromFile(char(file)); cleanup=onCleanup(@()model.closeNetCDFFile());
                    assertSnapshot(snapshot(model),reference.checkpoint);
                    model.setupIntegrator(integratorType="fixed",deltaT=5);
                    model.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
                    error=assertSnapshot(snapshot(model),reference.final);
                    model.closeNetCDFFile(); clear cleanup
                    outputError=compareOutputFiles(file,fullfile(outputFolder,key+"-control.nc"));
                    assert(outputError<1e-12);
                    fprintf('%s provider-free output/restart error %.6g / %.6g\n',key,error,outputError)
                end
            end
        end
    end
end

function model=newModel(type,profile)
if profile=="constant", N2=@(z)1e-4+0*z; else, N2=@(z)1e-4*exp(2*z/700); end
if type=="qg"
    w=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 6 65],N2Function=N2,latitude=30,apvModeCount=3,mdaModeCount=2);
    w.addForcing(WVVerticalDiffusivity(w,kappa_z=1e-5));
else
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 65],shouldAntialias=true,N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
    [X,~,Z]=ndgrid(w.x,w.y,w.z);
    w.addForcing(WVPrescribedBoussinesqSource(w,uRate=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),frequency=.0003,referenceTime=17,phase=.4));
end
w.t=127; w.t0=31;
for name=string(fieldnames(w.coefficientState())).'
    a=w.(name); ordinal=reshape(1:numel(a),size(a)); scale=.002;
    if ismember(name,["Ag_q","Ag_0"]), scale=1e-8; end
    if name=="Amda", a=scale*cos(ordinal); else, a=scale*exp(1i*ordinal)./(1+ordinal); end
    w.(name)=a;
end
model=WVModel(w); model.setupIntegrator(integratorType="fixed",deltaT=5);
particles=WVLagrangianParticles(model,name="particles",x=[12000 53000],y=[23000 71000],z=[-250 -650],isXYOnly=type=="qg",trackedFieldNames={'u','eta'},absToleranceXY=3e-4,absToleranceZ=7e-5);
model.addFluxedObservingSystem(particles);
[X,Y,Z]=ndgrid(w.x,w.y,w.z);
tracer=WVTracer(model,name="dye",phi=cos(2*pi*X/w.Lx).*sin(2*pi*Y/w.Ly).*(1+Z/(2*w.Lz)),isXYOnly=type=="qg",absTolerance=2e-7);
model.addFluxedObservingSystem(tracer);
end

function file=configureOutput(model,path)
file=model.createNetCDFFileForModelOutput(char(path),outputInterval=40,shouldOverwriteExisting=true);
model.eulerianObservingSystem.addNetCDFOutputVariables('u','v','eta','ssh','qgpv');
group=file.addNewEvenlySpacedOutputGroup('fields',initialTime=137,outputInterval=30,finalTime=347);
names={'u','v','eta','ssh'};
if isa(model.wvt,'WVTransformFreeSurfaceBoussinesq'), names=[names {'w','p_linear'}]; end
group.addObservingSystem(WVEulerianFields(model,fieldNames=names));
group.addObservingSystem(WVMooring(model,name="mooring",x=[0 25000],y=[0 50000],trackedFieldNames={'u','eta'}));
group.addObservingSystem(model.fluxedObservingSystemWithName('particles'));
group.addObservingSystem(model.fluxedObservingSystemWithName('dye'));
end

function poisonNextRecords(model,file)
% Persist unmistakably wrong payloads, but never commit their time coordinates.
w=model.wvt;
for name=string(fieldnames(w.coefficientState())).', w.(name)=3*w.(name); end
particles=model.fluxedObservingSystemWithName('particles');
state=particles.initialConditions(); state{1}=state{1}+1000;
particles.updateIntegratorValues(w.t,state); particles.updateParticleTrackedFields();
tracer=model.fluxedObservingSystemWithName('dye'); tracer.updateIntegratorValues(w.t,{tracer.phi+7});
for group=reshape(file.outputGroups,1,[])
    group.stageTimeStepToNetCDFFile(file.ncfile,group.timeOfLastIncrementWrittenToGroup+group.outputInterval);
end
file.ncfile.sync();
end

function value=snapshot(model)
w=model.wvt;
value=struct(t=w.t,t0=w.t0,coefficients=w.coefficientState(),fields=w.reconstructFields(["u","v","eta","ssh","qgpv"]),particles={model.fluxedObservingSystemWithName('particles').initialConditions()},tracer=model.tracer('dye'));
[~,~,~,value.tracked]=model.fluxedObservingSystemWithName('particles').particlePositions();
value.inventory=struct(total=w.totalEnergy);
for component=w.flowComponents
    value.inventory.(matlab.lang.makeValidName(component.name))=w.totalEnergyOfFlowComponent(component);
end
value.operators=struct();
for name=["z","apvF","apvG","apvMu","mdaG","zeroAPVF","zeroAPVG","verticalDerivativeMatrix","verticalQuadratureWeights"]
    value.operators.(name)=w.(name);
end
value.observers=struct();
for name=["particles","dye"]
    observer=model.fluxedObservingSystemWithName(name); config=struct(class=string(class(observer)));
    for property=string(observer.requiredProperties)
        item=observer.(property);
        if ischar(item), item=string(item); end
        config.(property)=item;
    end
    value.observers.(name)=config;
end
value.forcing=cell(1,length(w.forcing));
for j=1:length(w.forcing)
    force=w.forcing(j); config=struct(class=string(class(force)),name=string(force.name),priority=force.priority);
    for name=string(force.requiredProperties), config.(name)=force.(name); end
    value.forcing{j}=config;
end
end

function residual=assertSnapshot(actual,expected)
assert(actual.t==expected.t && actual.t0==expected.t0);
assert(isequal(actual.operators,expected.operators)); assert(isequal(actual.forcing,expected.forcing));
assert(isequal(actual.observers,expected.observers));
residual=0;
for category=["coefficients","fields","inventory","tracked"]
    for name=string(fieldnames(expected.(category))).'
        residual=max(residual,relativeDifference(actual.(category).(name),expected.(category).(name)));
    end
end
for i=1:length(expected.particles), residual=max(residual,relativeDifference(actual.particles{i},expected.particles{i})); end
residual=max(residual,relativeDifference(actual.tracer,expected.tracer));
assert(residual<1e-12,'Restored scientific/observer state differs: %.6g.',residual)
end

function error=relativeDifference(actual,expected)
assert(isequal(size(actual),size(expected)));
error=norm(actual(:)-expected(:))/max(norm(expected(:)),realmin);
end

function result=runCase(type,profile,folder)
key=type+"-"+profile;
control=newModel(type,profile); controlPath=fullfile(folder,key+"-control.nc"); configureOutput(control,controlPath);
initial=snapshot(control);
control.integrateToTime(367,shouldShowIntegrationDiagnostics=false); final=snapshot(control); control.closeNetCDFFile();
particleDisplacement=norm(cell2mat(final.particles)-cell2mat(initial.particles));
tracerChange=relativeDifference(final.tracer,initial.tracer);
assert(particleDisplacement>0 && tracerChange>0,'The observer continuation must exercise evolving state.');
model=newModel(type,profile); checkpointPath=fullfile(folder,key+"-checkpoint.nc"); file=configureOutput(model,checkpointPath);
model.integrateToTime(207,shouldShowIntegrationDiagnostics=false); checkpoint=snapshot(model);
% The diagnostic group advances beyond the coefficient checkpoint before interruption.
model.integrateToTime(227,shouldShowIntegrationDiagnostics=false);
poisonNextRecords(model,file); model.closeNetCDFFile();
save(fullfile(folder,key+"-reference.mat"),'checkpoint','final');
continuedPath=fullfile(folder,key+"-continued.nc"); copyfile(checkpointPath,continuedPath);
resumed=WVModel.modelFromFile(char(continuedPath)); cleanup=onCleanup(@()resumed.closeNetCDFFile());
initialError=assertSnapshot(snapshot(resumed),checkpoint);
resumed.setupIntegrator(integratorType="fixed",deltaT=5);
resumed.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
restartError=assertSnapshot(snapshot(resumed),final);
resumed.closeNetCDFFile(); clear cleanup
outputError=compareOutputFiles(continuedPath,controlPath); assert(outputError<1e-12);
result=struct(model=type,profile=profile,checkpointTime=207,diagnosticTime=227,finalTime=367,initialError=initialError,restartError=restartError,outputError=outputError,particleDisplacement=particleDisplacement,tracerChange=tracerChange);
end

function error=compareOutputFiles(actualPath,expectedPath)
actual=NetCDFFile(char(actualPath)); cleanupA=onCleanup(@()actual.close());
expected=NetCDFFile(char(expectedPath)); cleanupB=onCleanup(@()expected.close());
error=0;
for groupName=["wave-vortex","fields"]
    A=actual.groupWithName(groupName); E=expected.groupWithName(groupName);
    assert(isequal(A.readVariables('t'),E.readVariables('t')));
    assert(isequal(string({A.realVariables.name}),string({E.realVariables.name})));
    for variable=reshape(E.realVariables,1,[])
        if ismember('t',{variable.dimensions.name})
            error=max(error,relativeDifference(A.readVariables(variable.name),E.readVariables(variable.name)));
        end
    end
end
end

function verifySharedObservers(testCase,model)
file=model.outputFiles(1); main=file.outputGroupWithName('wave-vortex'); other=file.outputGroupWithName('fields');
for name=["particles","dye"]
    testCase.verifyTrue(main.observingSystemWithName(name)==other.observingSystemWithName(name))
    testCase.verifyTrue(main.observingSystemWithName(name)==model.fluxedObservingSystemWithName(name))
end
end
