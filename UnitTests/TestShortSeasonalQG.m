classdef TestShortSeasonalQG < matlab.unittest.TestCase
    properties (TestParameter)
        checkpointDay = {32,31}
    end
    methods (TestMethodSetup)
        function examplePath(testCase)
            folder=fullfile(fileparts(fileparts(mfilename('fullpath'))),'Documentation','Examples');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (Test, TestTags="full")
        function initialStateAndProcessAccounting(testCase)
            model=makeShortSeasonalQGModel(); w=model.wvt;
            testCase.verifyEqual(w.activeEndpoint,[1;2])
            testCase.verifyEqual(w.Ag_q,zeros(size(w.Ag_q)))
            testCase.verifyEqual(w.Amda,zeros(size(w.Amda)))
            [~,endpoint]=w.transformStateBack(w.Ag_q,w.Ag_0);
            testCase.verifyEqual(sqrt(2*sum(abs(endpoint(1,:)).^2)),.01,RelTol=1e-12)
            testCase.verifyLessThan(norm(endpoint(2,:)),1e-12)
            testCase.verifyError(@()makeShortSeasonalQGModel(gridSize=[12 12 65]),'ShortSeasonalQG:UnresolvedPattern')
            % Inspect a nonzero source phase without advancing or reseeding.
            w.t=365.25*86400/4;
            names=w.forcingNames(); source=w.coefficientTendency(excludingForcing=reshape(setdiff(names,"seasonal surface anomaly"),1,[]));
            testCase.verifyEqual(source.Ag_q,zeros(size(w.Ag_q)))
            testCase.verifyEqual(source.Amda,zeros(size(w.Amda)))
            [~,boundary]=w.transformStateBack(source.Ag_q,source.Ag_0);
            forcing=w.forcingWithName('seasonal surface anomaly');
            field=zeros(w.spatialMatrixSize); field(:,:,1)=forcing.amplitude*forcing.pattern;
            spectrum=w.transformFromSpatialDomainWithFourier(field);
            testCase.verifyEqual(boundary(1,:),spectrum(1,w.klNonzero),AbsTol=1e-20)
            testCase.verifyLessThan(norm(boundary(2,:)),1e-18)
            w.t=0;
            model.setupIntegrator(integratorType="exponential",initialStep=86400,maximumStep=86400,exponentialAdaptive=false);
            model.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false);
            [budget,tendencies]=processBudgets(w);
            total=w.coefficientTendency(); sumState=total;
            for name=string(fieldnames(total)).'
                sumState.(name)=sum(cat(3,tendencies.(name)),3);
                testCase.verifyLessThan(norm(sumState.(name)-total.(name),'fro'),1e-12*max(norm(total.(name),'fro'),realmin))
            end
            full=w.quadraticDiagnostics(tendency=total);
            for name=["totalEnergy","generalizedEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"]
                rates=budget.(name+"Tendency"); scale=max(sum(abs(rates)),realmin);
                testCase.verifyLessThan(abs(sum(rates)-full.(name+"Tendency"))/scale,1e-12)
            end
            testCase.verifyGreaterThan(budget.tendencyNorm,zeros(height(budget),1))
            testCase.verifyEqual(w.Amda,zeros(size(w.Amda)))
            testCase.verifyGreaterThan(w.uvMax,.01)
            testCase.verifyGreaterThan(norm(w.Ag_q,'fro'),1e-10)
        end
        function standardRestartContinuesCompleteCase(testCase,checkpointDay)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            result=restartCase(string(fixture.Folder),checkpointDay);
            testCase.verifyLessThan(result.stateError,1e-6)
            testCase.verifyLessThan(result.outputError,1e-6)
        end
        function actualTimeStepRefinement(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            result=timeStudy(string(fixture.Folder));
            testCase.verifyTrue(all(diff(result.stateError(1:3))<0))
            testCase.verifyLessThan(result.stateError(3),result.stateError(1)/20)
        end
    end
    methods (Static)
        function runStudy(folder)
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            timeStudy(folder);
            rows=[restartCase(folder,32);restartCase(folder,31)];
            writetable(struct2table(rows),fullfile(folder,'issue-353-restart.csv'));
            mechanismStudy(folder);
        end
        function verifyRestartWithoutProvider(folder)
            assert(isempty(which('IMSolverSpectral')));
            for day=[32 31]
                key="restart-"+day; reference=load(fullfile(folder,key+".mat"));
                model=WVModel.modelFromFile(char(fullfile(folder,key+".nc"))); cleanup=onCleanup(@()model.closeNetCDFFile());
                assert(snapshotError(snapshot(model.wvt),reference.checkpoint)<1e-12);
                model.setupIntegrator(integratorType="exponential",initialStep=2*86400,maximumStep=2*86400,exponentialAdaptive=false);
                model.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false);
                residual=snapshotError(snapshot(model.wvt),reference.final); assert(residual<1e-6);
                model.closeNetCDFFile(); clear cleanup
                outputError=compareOutput(fullfile(folder,key+".nc"),fullfile(folder,key+"-control.nc")); assert(outputError<1e-6);
                fprintf('day %g provider-free state/output %.9g %.9g\n',day,residual,outputError);
            end
        end
    end
end

function model=newCase(step)
model=makeShortSeasonalQGModel(timeStep=step);
end

function value=snapshot(w)
value=struct(time=w.t,state=w.coefficientState(),fields=w.reconstructFields(["u","v","eta","ssh","qgpv"]),inventory=w.quadraticDiagnostics());
[~,value.endpoints]=w.transformStateBack(w.Ag_q,w.Ag_0);
value.forcing=cell(1,length(w.forcing));
for i=1:length(w.forcing)
    f=w.forcing(i); config=struct(class=string(class(f)));
    for name=string(f.requiredProperties), config.(name)=f.(name); end
    value.forcing{i}=config;
end
value.operators=struct();
for name=["g0","gd","activeEndpoint","apvF","apvG","apvMu","zeroAPVF","zeroAPVG","mdaG","verticalQuadratureWeights","verticalDerivativeMatrix"]
    value.operators.(name)=w.(name);
end
end

function residual=snapshotError(actual,expected)
assert(actual.time==expected.time && isequaln(actual.forcing,expected.forcing) && isequaln(actual.operators,expected.operators));
residual=0;
for category=["state","fields"]
    for name=string(fieldnames(expected.(category))).'
        residual=max(residual,relativeDifference(actual.(category).(name),expected.(category).(name)));
    end
end
residual=max(residual,relativeDifference(actual.endpoints,expected.endpoints));
for name=string(fieldnames(expected.inventory)).'
    scale=abs(expected.inventory.(name));
    if name=="generalizedEnergy"
        scale=expected.inventory.totalEnergy+abs(expected.operators.g0)*expected.inventory.surfaceAnomalyVariance+abs(expected.operators.gd)*expected.inventory.bottomAnomalyVariance;
    end
    residual=max(residual,abs(actual.inventory.(name)-expected.inventory.(name))/max(scale,realmin));
end
end

function residual=relativeDifference(actual,expected)
assert(isequal(size(actual),size(expected)));
residual=norm(actual(:)-expected(:))/max(norm(expected(:)),realmin);
end

function [tableValue,tendencies]=processBudgets(w)
names=reshape(w.forcingNames(),1,[]); tendencies=struct([]);
for name=names
    tendencies=[tendencies w.coefficientTendency(excludingForcing=setdiff(names,name))]; %#ok<AGROW>
end
values=w.quadraticDiagnostics(tendency=tendencies);
tableValue=table(names.',VariableNames="process");
for name=string(fieldnames(values)).'
    if endsWith(name,"Tendency"), tableValue.(name)=values.(name)(:); end
end
for k=1:length(names)
    tableValue.tendencyNorm(k)=norm([tendencies(k).Ag_q(:);tendencies(k).Ag_0(:);tendencies(k).Amda(:)]);
end
end

function result=restartCase(folder,day)
key="restart-"+day; controlPath=fullfile(folder,key+"-control.nc");
control=newCase(2*86400); configureOutput(control,controlPath);
control.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false); final=snapshot(control.wvt); control.closeNetCDFFile();
path=fullfile(folder,key+".nc"); model=newCase(2*86400); configureOutput(model,path);
model.integrateToTime(day*86400,shouldShowIntegrationDiagnostics=false); checkpoint=snapshot(model.wvt); model.closeNetCDFFile();
save(fullfile(folder,key+".mat"),'checkpoint','final');
continued=fullfile(folder,key+"-continued.nc"); copyfile(path,continued);
restored=WVModel.modelFromFile(char(continued)); cleanup=onCleanup(@()restored.closeNetCDFFile());
assert(snapshotError(snapshot(restored.wvt),checkpoint)<1e-12);
restored.setupIntegrator(integratorType="exponential",initialStep=2*86400,maximumStep=2*86400,exponentialAdaptive=false);
restored.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false);
stateError=snapshotError(snapshot(restored.wvt),final);
[budget,~]=processBudgets(restored.wvt); writetable(budget,fullfile(folder,key+"-budgets.csv"));
restored.closeNetCDFFile(); clear cleanup
outputError=compareOutput(continued,controlPath);
result=struct(checkpointDay=day,stateError=stateError,outputError=outputError);
end

function configureOutput(model,path)
file=model.createNetCDFFileForModelOutput(char(path),outputInterval=86400,shouldOverwriteExisting=true);
model.addNetCDFOutputVariables('ssh','qgpv','eta');
group=file.addNewEvenlySpacedOutputGroup('fields',initialTime=86400/2,outputInterval=3*86400);
group.addObservingSystem(WVEulerianFields(model,fieldNames={'u','v','ssh'}));
end

function residual=compareOutput(path,reference)
a=NetCDFFile(char(path)); ca=onCleanup(@()a.close());
b=NetCDFFile(char(reference)); cb=onCleanup(@()b.close()); residual=0;
for name=["wave-vortex","fields"]
    A=a.groupWithName(name); B=b.groupWithName(name);
    assert(isequal(A.readVariables('t'),B.readVariables('t')));
    for v=reshape(B.realVariables,1,[])
        if ismember('t',{v.dimensions.name}), residual=max(residual,relativeDifference(A.readVariables(v.name),B.readVariables(v.name))); end
    end
end
end

function result=timeStudy(folder)
steps=[8 4 2 1]*86400; final=cell(1,4); rows=struct([]);
for i=1:4
    m=newCase(steps(i)); m.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false);
    final{i}=snapshot(m.wvt); statistics=m.exponentialStatistics;
    assert(all(statistics.acceptedStepSeconds==steps(i)),'The control must exercise the declared actual timestep.');
    rows=[rows;struct(stepDays=steps(i)/86400,acceptedSteps=statistics.acceptedSteps,minStep=min(statistics.acceptedStepSeconds),maxStep=max(statistics.acceptedStepSeconds),stateError=0,physicalEnergyNormError=0,qgpvError=0,sshError=0)]; %#ok<AGROW>
end
for i=1:4
    rows(i).stateError=snapshotError(final{i},final{4});
    delta=final{i}.state;
    for name=string(fieldnames(delta)).', delta.(name)=delta.(name)-final{4}.state.(name); end
    d=m.wvt.quadraticDiagnostics(state=delta);
    rows(i).physicalEnergyNormError=sqrt(d.totalEnergy/final{4}.inventory.totalEnergy);
    rows(i).qgpvError=relativeDifference(final{i}.fields.qgpv,final{4}.fields.qgpv);
    rows(i).sshError=relativeDifference(final{i}.fields.ssh,final{4}.fields.ssh);
end
result=struct2table(rows); writetable(result,fullfile(folder,'issue-353-time.csv')); disp(result)
end

function mechanismStudy(folder)
reference=load(fullfile(folder,'restart-32.mat')); rows=struct([]);
for excluded=["nonlinear advection","seasonal surface anomaly","quadratic bottom friction","adaptive damping","vertical diffusivity"]
    m=newCase(2*86400); w=m.wvt;
    if excluded=="vertical diffusivity"
        w.forcingWithName(excluded).kappa_z=0;
    else
        w.removeForcing(w.forcingWithName(excluded));
    end
    m.setupIntegrator(integratorType="exponential",initialStep=2*86400,maximumStep=2*86400,exponentialAdaptive=false);
    m.integrateToTime(64*86400,shouldShowIntegrationDiagnostics=false);
    actual=snapshot(w); delta=actual.state;
    for name=string(fieldnames(delta)).', delta.(name)=delta.(name)-reference.final.state.(name); end
    d=w.quadraticDiagnostics(state=delta);
    rows=[rows;struct(excluded=excluded,physicalEnergyNormDifference=sqrt(d.totalEnergy/reference.final.inventory.totalEnergy),qgpvDifference=relativeDifference(actual.fields.qgpv,reference.final.fields.qgpv),sshDifference=relativeDifference(actual.fields.ssh,reference.final.fields.ssh))]; %#ok<AGROW>
end
result=struct2table(rows); writetable(result,fullfile(folder,'issue-353-mechanisms.csv')); disp(result)
end
