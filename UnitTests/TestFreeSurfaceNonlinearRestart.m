classdef TestFreeSurfaceNonlinearRestart < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyHelpers(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function fixedRK4AndProviderFreeNativeContinuationAgree(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,shouldCheckQuadraticAliasing=true,shouldAntialias=true);
            scientific = base.scientificState();
            initial = mixedSeed(base);
            source = physicalSourceOptions(base);
            reference = configuredTransform(scientific,initial,source);
            [expected,stageMetrics] = explicitStageRK4(reference,40,5);
            testCase.verifyGreaterThan(stageMetrics.minimumLabel,-base.Lz)
            testCase.verifyLessThan(stageMetrics.maximumLabel,0)
            testCase.verifyLessThan(stageMetrics.maximumSolverResidual,5e-10)

            uninterrupted = WVModel(configuredTransform(scientific,initial,source));
            uninterrupted.setupIntegrator(integratorType="fixed",deltaT=5);
            uninterrupted.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
            modelError = coefficientError(uninterrupted.wvt.coefficientState(),expected);
            testCase.verifyLessThan(modelError,2e-11)
            testCase.verifyGreaterThan(coefficientError(expected,initial),1e-7)
            finalFields = uninterrupted.wvt.reconstructFields(outputNames());
            finalEnergy = uninterrupted.wvt.nonlinearEnergy();

            model = WVModel(configuredTransform(scientific,initial,source));
            model.setupIntegrator(integratorType="fixed",deltaT=5);
            filePath = fullfile(fixture.Folder,'nonlinear-restart.nc');
            model.createNetCDFFileForModelOutput(filePath,outputInterval=20);
            names = cellstr(outputNames());
            model.eulerianObservingSystem.addNetCDFOutputVariables(names{:});
            model.integrateToTime(347,shouldShowIntegrationDiagnostics=false);
            checkpoint = model.wvt.coefficientState();
            checkpointFields = model.wvt.reconstructFields(outputNames());
            model.closeNetCDFFile();

            % A fresh restored instance must use saved operators. Remove
            % the mode provider before constructing it or continuing it.
            originalPath = string(matlabpath);
            pathCleanup = onCleanup(@()path(char(originalPath)));
            entries = string(strsplit(char(originalPath),pathsep));
            provider = contains(lower(entries),'internalmodes') | contains(lower(entries),'internal-modes');
            testCase.assertTrue(any(provider))
            for entry = entries(provider), rmpath(char(entry)); end
            testCase.assertEmpty(which('IMSolverSpectral'))
            testCase.assertEmpty(which('IMInternalModes'))
            resumed = WVModel.modelFromFile(filePath);
            fileCleanup = onCleanup(@()resumed.closeNetCDFFile());
            testCase.verifyFalse(resumed.isDynamicsLinear)
            testCase.verifyEmpty(resumed.wvt.verticalModes)
            testCase.verifyEqual([resumed.wvt.t,resumed.wvt.t0],[347,-17])
            testCase.verifyEqual(resumed.wvt.coefficientState(),checkpoint)
            restoredScientific = resumed.wvt.scientificState();
            for name = string(fieldnames(scientific)).'
                if ~isa(scientific.(name),'function_handle')
                    testCase.verifyEqual(restoredScientific.(name),scientific.(name))
                end
            end
            testCase.verifyEqual(resumed.wvt.activeWaveModes,base.activeWaveModes)
            testCase.verifyEqual(resumed.wvt.waveModeCountByKh,3+zeros(size(base.khUnique)))
            testCase.verifyTrue(resumed.wvt.shouldCheckQuadraticAliasing)
            testCase.verifyTrue(resumed.wvt.shouldAntialias)
            testCase.verifyTrue(isa(resumed.wvt.forcingWithName("nonlinear advection"),'WVNonlinearAdvection'))
            restoredSource = resumed.wvt.forcingWithName("prescribed Boussinesq source");
            for name = string(fieldnames(source)).'
                testCase.verifyEqual(restoredSource.(name),source.(name))
            end
            testCase.verifyTrue(restoredSource.wvt==resumed.wvt)
            checkpointFieldError = fieldError(resumed.wvt.reconstructFields(outputNames()),checkpointFields);
            testCase.verifyLessThan(checkpointFieldError,2e-11)
            resumed.setupIntegrator(integratorType="fixed",deltaT=5);
            resumed.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
            restartError = coefficientError(resumed.wvt.coefficientState(),uninterrupted.wvt.coefficientState());
            testCase.verifyLessThan(restartError,2e-11)
            testCase.verifyEmpty(resumed.wvt.verticalModes)
            testCase.verifyEqual([resumed.wvt.t,resumed.wvt.t0],[367,-17])
            physicalFieldError = fieldError(resumed.wvt.reconstructFields(outputNames()),finalFields);
            testCase.verifyLessThan(physicalFieldError,2e-10)
            energy = resumed.wvt.nonlinearEnergy();
            testCase.verifyEqual(energy.totalEnergy,finalEnergy.totalEnergy,RelTol=2e-11)
            group = resumed.outputFiles(1).outputGroupWithName('wave-vortex');
            count = WVModelOutputGroup.committedRecordCountForGroup(group.group);
            testCase.verifyEqual(group.group.readVariablesAtIndexAlongDimension('t',count,'t'),367)
            outputError = 0;
            for name = outputNames()
                saved = group.group.readVariablesAtIndexAlongDimension('t',count,char(name));
                expectedField = finalFields.(name);
                errorValue = norm(saved(:)-expectedField(:))/max(norm(expectedField(:)),realmin);
                outputError = max(outputError,errorValue);
            end
            testCase.verifyLessThan(outputError,2e-10)
            fprintf('Nonlinear RK4/native restart: model %.6g, restart %.6g, fields %.6g, output %.6g, label range [%.9g %.9g], solver %.6g\n',modelError,restartError,physicalFieldError,outputError,stageMetrics.minimumLabel,stageMetrics.maximumLabel,stageMetrics.maximumSolverResidual)
            clear fileCleanup pathCleanup
        end
    end
end

function names = outputNames()
names = ["u","v","w","eta","eta_i","ssh","p_linear","p_full","w_i","z_physical"];
end

function state = mixedSeed(wvt)
helper = freeSurfaceWeakStudyHelpers();
state = helper.seedState(wvt);
state.Aw_m = 0.35*exp(0.63i)*state.Aw_p;
column = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
unit = wvt.coefficientState();
unit.Aw_p(1,column) = 1;
fields = wvt.reconstructSpectralState(state=unit);
amplitude = 0.3/(2*abs(fields.ssh(end,wvt.klNonzero(column))));
state.Aw_p(1,column) = amplitude*exp(0.43i);
state.Aw_m(1,column) = 0.27*amplitude*exp(-0.71i);
end

function options = physicalSourceOptions(wvt)
[X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
options = struct(uRate=1e-8*cos(2*pi*X/wvt.Lx).*(1+Z/wvt.Lz),vRate=-2e-8*sin(2*pi*Y/wvt.Ly).*(Z/wvt.Lz).^2,wRate=3e-9*cos(2*pi*(X/wvt.Lx+Y/wvt.Ly)).*(1+Z/wvt.Lz),etaRate=2e-7*(1+0.1*cos(2*pi*X/wvt.Lx)).*(1+Z/(2*wvt.Lz)),sourceCoordinates="physical",frequency=0.003,referenceTime=19,phase=0.4);
end

function wvt = configuredTransform(scientific,state,source)
wvt = WVTransformFreeSurfaceBoussinesq(scientific);
for name = string(fieldnames(state)).', wvt.(name)=state.(name); end
wvt.t = 327;
wvt.t0 = -17;
args = namedargs2cell(source);
wvt.setForcing([WVNonlinearAdvection(wvt),WVPrescribedBoussinesqSource(wvt,args{:})]);
end

function [state,metrics] = explicitStageRK4(wvt,duration,step)
context = WVInternal.freeSurfaceNonlinearStage(wvt);
state = wvt.coefficientState();
initial = state;
start = wvt.t;
metrics = struct(minimumLabel=Inf,maximumLabel=-Inf,maximumSolverResidual=0);
for time = start:step:start+duration-step
    [k1,d1] = evaluate(time,state);
    [k2,d2] = evaluate(time+step/2,advance(state,k1,step/2));
    [k3,d3] = evaluate(time+step/2,advance(state,k2,step/2));
    [k4,d4] = evaluate(time+step,advance(state,k3,step));
    for name = string(fieldnames(state)).'
        state.(name) = state.(name)+(step/6)*(k1.(name)+2*k2.(name)+2*k3.(name)+k4.(name));
    end
    diagnostics = [d1,d2,d3,d4];
    metrics.minimumLabel = min(metrics.minimumLabel,min([diagnostics.minimumLabel]));
    metrics.maximumLabel = max(metrics.maximumLabel,max([diagnostics.maximumLabel]));
    reports = [diagnostics.solver];
    metrics.maximumSolverResidual = max(metrics.maximumSolverResidual,max([reports.relativeResidual]));
end
assert(isequal(wvt.coefficientState(),initial),'Explicit-state stage evaluation must not change stored coefficients.')

    function [rate,diagnostic] = evaluate(time,value)
        wvt.t = time;
        [rate,diagnostic] = context.evaluate(value,includeForcing=true);
    end
end

function result = advance(state,rate,step)
result = state;
for name = string(fieldnames(state)).'
    result.(name) = state.(name)+step*rate.(name);
end
end

function value = coefficientError(actual,expected)
value = fieldError(actual,expected);
end

function value = fieldError(actual,expected)
value = 0;
for name = string(fieldnames(expected)).'
    a = actual.(name);
    b = expected.(name);
    value = max(value,norm(a(:)-b(:))/max(norm(b(:)),realmin));
end
end
