classdef TestThermalOutputRestart < matlab.unittest.TestCase
    properties
        scientificState
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            w=construct(); testCase.scientificState=w.scientificState;
        end
    end
    methods (Test, TestTags="full")
        function snapshotRestoresClockScientificStateAndForcing(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); path=fullfile(fixture.Folder,'snapshot.nc');
            nc=w.writeToFile(path); nc.close();
            [r,nc]=WVTransform.waveVortexTransformFromFile(path,iTime=Inf); cleanup=onCleanup(@()nc.close());
            testCase.verifyEqual(r.scientificState,w.scientificState);
            testCase.verifyEqual(r.coefficientState(),w.coefficientState());
            testCase.verifyEqual([r.t r.t0],[w.t w.t0]);
            testCase.verifyEqual(forcingConfiguration(r),forcingConfiguration(w));
            testCase.verifyEmpty(fieldnames(r.constructionAssessment));
            testCase.verifyFalse(isempty(nc.id));
            testCase.verifyError(@()WVTransform.waveVortexTransformFromFile(path,iTime=2),'WVTransform:SnapshotTimeIndex');
            testCase.verifyError(@()WVTransform.waveVortexTransformFromFile(path,iTime=1.5),'WVTransform:InvalidRestartIndex');
            % Canonical snapshot reader retains compatibility with schema 1.
            names=w.classRequiredPropertyNames(); newer={'shouldCheckQuadraticAliasing','nonlinearQuadratureCount','nonlinearQuadratureTolerance','nonlinearQuadratureResidual','nonlinearReferenceResidual','forcing','t0'};
            names=names(~ismember(names,newer)); old=fullfile(fixture.Folder,'schema1.nc');
            ncOld=w.writeToFile(old,names{:},shouldAddRequiredProperties=false); ncOld.close(); ncwrite(old,'schemaVersion',1);
            r=WVTransform.waveVortexTransformFromFile(old);
            testCase.verifyEqual(r.Ath,w.Ath); testCase.verifyEqual(r.t0,0);
            testCase.verifyFalse(r.shouldCheckQuadraticAliasing); testCase.verifyEmpty(r.forcing);
        end
        function committedStreamAndIndependentSchedules(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            row=runCase(testCase.scientificState,string(fixture.Folder));
            testCase.verifyLessThan(row.restartError,1e-11);
            testCase.verifyLessThan(row.outputError,1e-11);
            testCase.verifyGreaterThan(row.coefficientChange,1e-9);
        end
        function corruptStreamsRejectAndReleaseFile(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for mode=["uncommitted","hole","duplicate","missing"]
                model=newModel(testCase.scientificState); path=fullfile(fixture.Folder,mode+".nc"); file=configureOutput(model,path);
                if mode=="uncommitted"
                    file.initializeOutputFile();
                    for group=reshape(file.outputGroups,1,[]), group.stageTimeStepToNetCDFFile(file.ncfile,127); end
                    model.closeNetCDFFile();
                    expected='WVTransform:NoCommittedRestartRecord';
                elseif mode=="missing"
                    model.closeNetCDFFile(); names=model.wvt.classRequiredPropertyNames(); names=setdiff(names,{'Ath','Amda','t'});
                    nc=model.wvt.writeToFile(char(path),names{:},shouldAddRequiredProperties=false); nc.close();
                    expected='WVTransform:MissingRestartCoefficients';
                else
                    model.integrateToTime(167,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile();
                    nc=NetCDFFile(char(path));
                    if mode=="hole"
                        group=nc.groupWithName('wave-vortex'); n=WVModelOutputGroup.committedRecordCountForGroup(group);
                        group.variableWithName('t').setValueAlongDimensionAtIndex(247,'t',n+2);
                        expected='WVModelOutputGroup:NoncontiguousCommittedRecords';
                    else
                        group=nc.addGroup('duplicate'); group.addDimension('t',length=Inf,type='double');
                        group.variableWithName('t').setValueAlongDimensionAtIndex(167,'t',1);
                        for name=["Ath","Amda"]
                            annotation=model.wvt.propertyAnnotationWithName(name);
                            variable=group.addVariable(char(name),[annotation.dimensions {'t'}],type='double',isComplex=annotation.isComplex);
                            variable.setValueAlongDimensionAtIndex(model.wvt.(name),'t',1);
                        end
                        expected='WVTransform:AmbiguousRestartState';
                    end
                    nc.close();
                end
                testCase.verifyError(@()WVModel.modelFromFile(char(path)),expected);
                nc=NetCDFFile(char(path)); nc.close();
            end
        end
        function observationCadenceAndStageFailure(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            models=cell(1,2);
            for j=1:2
                model=newModel(testCase.scientificState); intervals=[17 29];
                configureOutput(model,fullfile(fixture.Folder,"cadence"+j+".nc"),intervals(j));
                model.integrateToTime(367,shouldShowIntegrationDiagnostics=false); model.closeNetCDFFile(); models{j}=model;
            end
            testCase.verifyEqual(models{1}.exponentialStatistics.acceptedStepSeconds,models{2}.exponentialStatistics.acceptedStepSeconds);
            testCase.verifyEqual(models{1}.wvt.coefficientState(),models{2}.wvt.coefficientState());
            model=WVModel(models{1}.wvt); configureIntegrator(model); force=ThermalStageForcing(model.wvt); force.rate=0; force.failureTime=model.wvt.t;
            model.wvt.addForcing(force); before=model.wvt.coefficientState(); time=model.wvt.t;
            testCase.verifyError(@()model.integrateToTime(time+20,shouldShowIntegrationDiagnostics=false),'ThermalStageForcing:Failure');
            testCase.verifyEqual(model.wvt.coefficientState(),before); testCase.verifyEqual(model.wvt.t,time);
            model.wvt.removeForcing(force); file=fullfile(fixture.Folder,'recovered.nc'); nc=model.wvt.writeToFile(file); nc.close();
            restored=WVTransform.waveVortexTransformFromFile(file); continued=WVModel(restored); configureIntegrator(continued);
            continued.integrateToTime(time+20,shouldShowIntegrationDiagnostics=false);
            model.integrateToTime(time+20,shouldShowIntegrationDiagnostics=false);
            testCase.verifyLessThan(stateError(continued.wvt.coefficientState(),model.wvt.coefficientState()),1e-11);
        end
        function physicalTransferRefinesAndQuantifiesCoarsening(testCase)
            w=populated(testCase.scientificState); before=w.coefficientState();
            [fine,a]=w.waveVortexTransformWithResolution([12 12 97],thermalModeCount=25);
            testCase.verifyLessThan(a.relativeFieldError,1e-7);
            testCase.verifyLessThan(max(a.endpointRMS),1e-9);
            testCase.verifyEqual([fine.t fine.t0],[w.t w.t0]);
            [back,b]=fine.waveVortexTransformWithResolution([8 8 65],thermalModeCount=17);
            testCase.verifyLessThan(b.relativeFieldError,1e-7); testCase.verifyLessThan(stateError(back.coefficientState(),before),1e-6);
            % Add content outside the coarser polynomial/Fourier space.
            w.Ath(:)=0; thermalManufacturedState(w,[2 16 9],1000);
            [coarse,a]=w.waveVortexTransformWithResolution([6 6 65],thermalModeCount=9,mdaModeCount=3);
            [~,refined]=w.coefficientStateForTransform(coarse,quadratureCount=259);
            testCase.verifyGreaterThan(a.errorEnergy,1e-8);
            testCase.verifyGreaterThan(a.discardedFourierCount,0);
            testCase.verifyEqual(a.errorEnergy,refined.errorEnergy,RelTol=1e-7);
            testCase.verifyEqual(a.endpointRMS,refined.endpointRMS,AbsTol=1e-9);
            testCase.verifyTrue(isreal(coarse.Amda));
            testCase.verifyEqual(fine.forcing(1).name,w.forcing(1).name);
        end
        function transferIgnoresThermalOrderingAndRejectsIncompatiblePhysics(testCase)
            w=populated(testCase.scientificState); s=w.scientificState; order=17:-1:1;
            for p=1:numel(s.khUnique)
                s.thermalToPolynomial(:,:,p)=-s.thermalToPolynomial(:,order,p);
                s.polynomialToThermal(:,:,p)=-s.polynomialToThermal(order,:,p);
                s.sourceDual(:,:,p)=-s.sourceDual(order,:,p); s.sourceEndpoint(:,:,p)=-s.sourceEndpoint(order,:,p);
                s.thermalEnergyGram(:,:,p)=s.thermalEnergyGram(order,order,p);
                s.thermalRatesPerDiffusivity(:,p)=s.thermalRatesPerDiffusivity(order,p);
                s.conjugateDirection(:,p)=18-s.conjugateDirection(order,p);
            end
            target=WVTransformFreeSurfaceThermalQG(scientificState=s); before=target.coefficientState();
            [state,a]=w.coefficientStateForTransform(target);
            testCase.verifyEqual(state.Ath,-w.Ath(order,:),AbsTol=1e-10);
            testCase.verifyLessThan(a.relativeFieldError,1e-10); testCase.verifyEqual(target.coefficientState(),before);
            testCase.verifyError(@()w.coefficientStateForTransform(w.withDiffusivity(0)),'WV:TransferIncompatible');
            testCase.verifyError(@()w.coefficientStateForTransform(target,quadratureCount=65),'WV:TransferQuadrature');
        end
        function seasonalPatternTransferPreservesClockAndRejectsLoss(testCase)
            w=populated(testCase.scientificState); force=w.forcing(arrayfun(@(f)isa(f,'WVSeasonalSurfaceAnomalyForcing'),w.forcing)); target=w.waveVortexTransformWithResolution([12 12 65]);
            [converted,residual]=force.forcingWithResolutionOfTransform(target);
            testCase.verifyLessThan(residual,1e-12);
            testCase.verifyEqual([converted.amplitude converted.period converted.phase],[force.amplitude force.period force.phase]);
            testCase.verifyTrue(converted.wvt==target); testCase.verifyTrue(force.wvt==w);
            force=WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(cos(4*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7);
            target=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[4 4 65],N2Function=w.N2Function,thermalModeCount=17,mdaModeCount=4);
            testCase.verifyError(@()force.forcingWithResolutionOfTransform(target),'WVSeasonalSurfaceAnomalyForcing:UnresolvedTransfer');
        end
    end
    methods (Static)
        function results=runStudy(folder,options)
            arguments (Input)
                folder (1,1) string
                options.fullPhysics (1,1) logical = false
            end
            if ~isfolder(folder), mkdir(folder); end
            w=construct();
            rows=runCase(w.scientificState,folder,options.fullPhysics);
            results=struct2table(rows); writetable(results,fullfile(folder,'restart.csv'));
        end
        function verifyRestartWithoutProvider(folder)
            assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')),'Scientific provider must be absent in this fresh process.');
            reference=load(fullfile(folder,'reference.mat'));
            copyfile(fullfile(folder,'checkpoint.nc'),fullfile(folder,'fresh-process.nc'));
            model=WVModel.modelFromFile(char(fullfile(folder,'fresh-process.nc'))); cleanup=onCleanup(@()model.closeNetCDFFile());
            assert(stateError(model.wvt.coefficientState(),reference.checkpoint.coefficients)==0);
            assert(isequal(forcingConfiguration(model.wvt),reference.checkpoint.forcing));
            [transferred,assessment]=model.wvt.coefficientStateForTransform(model.wvt);
            assert(stateError(transferred,reference.checkpoint.coefficients)<1e-9 && assessment.relativeFieldError<1e-9);
            configureIntegrator(model); % Rebuild numeric MDA cache from the saved generator.
            model.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
            residual=stateError(model.wvt.coefficientState(),reference.final.coefficients);
            assert(residual<1e-11); assertSnapshot(model.wvt,reference.final);
            fprintf('Provider-unavailable thermal continuation: %.8g\n',residual);
        end
    end
end

function w=construct()
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=17,mdaModeCount=4,kappa_z=1e-5,shouldCheckQuadraticAliasing=true);
end
function w=populated(scientificState)
w=WVTransformFreeSurfaceThermalQG(scientificState=scientificState);
thermalManufacturedState(w,[2 3 4],1000); w.Amda=[.1;-.2;.3;-.1]; w.t=127; w.t0=31;
w.addForcing(WVNonlinearAdvection(w));
w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7,period=1000,phase=.7));
end
function model=newModel(scientificState,fullPhysics)
if nargin<2, fullPhysics=false; end
w=populated(scientificState);
if fullPhysics
    w.addForcing(WVBottomFrictionQuadratic(w,Cd=1e-3));
    apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny w.Nz],N2Function=w.N2Function,latitude=w.latitude,apvModeCount=4,mdaModeCount=4);
    w.addForcing(WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5));
end
model=WVModel(w); configureIntegrator(model);
end
function configureIntegrator(model)
model.setupIntegrator(integratorType="exponential",initialStep=20,maximumStep=20,exponentialAdaptive=false,physicalAbsTolerance=[1e-14 1e-12 1e-10 1e-10 1e-10],relTolerance=1e-8);
end
function file=configureOutput(model,path,interval)
if nargin<3, interval=40; end
file=model.createNetCDFFileForModelOutput(char(path),outputInterval=interval,shouldOverwriteExisting=true);
group=file.addNewEvenlySpacedOutputGroup('fields',initialTime=137,outputInterval=30,finalTime=347);
group.addObservingSystem(WVEulerianFields(model,fieldNames={'u','v','qgpv','ssh','endpointAnomalies'}));
end
function row=runCase(scientificState,folder,fullPhysics)
if nargin<3, fullPhysics=false; end
control=newModel(scientificState,fullPhysics); configureOutput(control,fullfile(folder,'control.nc'));
initial=control.wvt.coefficientState(); clock=tic;
control.integrateToTime(367,shouldShowIntegrationDiagnostics=false); final=snapshot(control.wvt); control.closeNetCDFFile(); writeSeconds=toc(clock);
model=newModel(scientificState,fullPhysics);
clock=tic; snapshotFile=model.wvt.writeToFile(char(fullfile(folder,'canonical.nc')),shouldOverwriteExisting=true); snapshotFile.close(); snapshotWriteSeconds=toc(clock);
snapshotInfo=dir(fullfile(folder,'canonical.nc'));
file=configureOutput(model,fullfile(folder,'checkpoint.nc'));
model.integrateToTime(207,shouldShowIntegrationDiagnostics=false); checkpoint=snapshot(model.wvt);
% Advance diagnostics past the coefficient checkpoint, then interrupt every
% next record after payload writes and before its time-coordinate commit.
model.integrateToTime(227,shouldShowIntegrationDiagnostics=false);
model.wvt.Ath=3*model.wvt.Ath;
for group=reshape(file.outputGroups,1,[]), group.stageTimeStepToNetCDFFile(file.ncfile,247); end
file.ncfile.sync(); model.closeNetCDFFile();
save(fullfile(folder,'reference.mat'),'checkpoint','final');
copyfile(fullfile(folder,'checkpoint.nc'),fullfile(folder,'continued.nc'));
clock=tic; resumed=WVModel.modelFromFile(char(fullfile(folder,'continued.nc'))); readSeconds=toc(clock);
cleanup=onCleanup(@()resumed.closeNetCDFFile()); assertSnapshot(resumed.wvt,checkpoint); configureIntegrator(resumed);
resumed.integrateToTime(367,shouldShowIntegrationDiagnostics=false); assertSnapshot(resumed.wvt,final);
restartError=stateError(resumed.wvt.coefficientState(),final.coefficients); resumed.closeNetCDFFile(); clear cleanup
outputError=compareOutput(fullfile(folder,'continued.nc'),fullfile(folder,'control.nc'));
info=dir(fullfile(folder,'checkpoint.nc'));
nc=NetCDFFile(char(fullfile(folder,'checkpoint.nc'))); cleanup=onCleanup(@()nc.close());
for name=["thermalToPolynomial","polynomialToThermal","sourceDual","mdaGeneratorPerDiffusivity"]
    variable=nc.variableWithName(name); assert(~ismember('t',{variable.dimensions.name}));
end
assert(~ismember("Ath",string([{nc.realVariables.name},{nc.complexVariables.name}])));
row=struct(fullPhysics=fullPhysics,checkpointTime=207,diagnosticTime=227,finalTime=367,restartError=restartError,outputError=outputError,coefficientChange=stateError(final.coefficients,initial),checkpointBytes=info.bytes,snapshotBytes=snapshotInfo.bytes,snapshotWriteSeconds=snapshotWriteSeconds,writeAndIntegrateSeconds=writeSeconds,readSeconds=readSeconds);
end
function value=snapshot(w)
value=struct(t=w.t,t0=w.t0,coefficients=w.coefficientState(),fields=w.reconstructFields(["u","v","qgpv","buoyancy","ssh","endpointAnomalies"]),energy=w.totalEnergy,scientific=w.scientificState,forcing=forcingConfiguration(w));
end
function assertSnapshot(w,value)
assert(w.t==value.t && w.t0==value.t0); assert(isequal(w.scientificState,value.scientific));
assert(isequal(forcingConfiguration(w),value.forcing)); assert(stateError(w.coefficientState(),value.coefficients)<1e-11);
actual=w.reconstructFields(string(fieldnames(value.fields)).');
for name=string(fieldnames(actual)).', assert(norm(actual.(name)(:)-value.fields.(name)(:))<=1e-12+1e-11*norm(value.fields.(name)(:))); end
assert(abs(w.totalEnergy-value.energy)<=1e-12+1e-11*abs(value.energy));
end
function value=forcingConfiguration(w)
value=struct([]);
for force=w.forcing
    config=struct(class=string(class(force)),name=string(force.name),priority=force.priority);
    for name=string(force.requiredProperties), config.(name)=force.(name); end
    value=[value;struct(configuration=config)]; %#ok<AGROW>
end
end
function error=stateError(a,b)
error=max(norm(a.Ath-b.Ath,'fro')/max(norm(b.Ath,'fro'),realmin),norm(a.Amda-b.Amda)/max(norm(b.Amda),realmin));
end
function error=compareOutput(actualPath,expectedPath)
actual=NetCDFFile(char(actualPath)); ca=onCleanup(@()actual.close()); expected=NetCDFFile(char(expectedPath)); ce=onCleanup(@()expected.close()); error=0;
for name=["wave-vortex","fields"]
    A=actual.groupWithName(name); E=expected.groupWithName(name); ta=A.readVariables('t'); te=E.readVariables('t'); assert(isequal(ta(:),te(:)));
    for variable=reshape(E.realVariables,1,[])
        if ismember('t',{variable.dimensions.name})
            a=A.readVariables(variable.name); e=E.readVariables(variable.name);
            error=max(error,norm(a(:)-e(:))/max(norm(e(:)),realmin));
        end
    end
end
end
