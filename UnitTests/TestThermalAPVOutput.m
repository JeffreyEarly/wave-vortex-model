classdef TestThermalAPVOutput < matlab.unittest.TestCase
    % Committed read-only analysis uses the shared complete-state contract.
    properties
        scientificState
        apvPath
    end
    methods (TestClassSetup)
        function prepareScientificArrays(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'UnitTests','Fixtures')));
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            [w,apv]=construct();
            testCase.scientificState=w.scientificState;
            testCase.apvPath=fullfile(folder.Folder,'diagnostic.nc');
            file=apv.writeToFile(testCase.apvPath); file.close();
        end
    end
    methods (Test, TestTags="full")
        function snapshotAgreesAndPreservesObjectsAndBytes(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            path=fullfile(folder.Folder,'snapshot.nc'); file=w.writeToFile(path); file.close();
            sourceBefore=authoritativeState(w); diagnosticBefore=authoritativeState(apv); bytesBefore=fileBytes(path);
            expected=w.apvDecomposition(apv,quadratureCount=259);
            result=testCase.verifyWarningFree(@()analyzeThermalAPVOutput(path,apv,quadratureCount=259));
            testCase.verifyEqual(result.history.coefficients,expected.coefficients);
            testCase.verifyEqual(result.history.mean,expected.mean);
            testCase.verifyEqual(result.history.inventories,expected.inventories);
            testCase.verifyEqual(result.provenance.times,w.t);
            testCase.verifyEqual(result.provenance.selectedIndices,1);
            testCase.verifyTrue(result.provenance.isScalarSnapshot);
            testCase.verifyTrue(result.provenance.didAnalyzeAllCommittedRecords);
            testCase.verifyEqual(strlength(result.provenance.sourceSHA256),64);
            testCase.verifyEqual(strlength(result.provenance.diagnosticIdentity.sha256),64);
            testCase.verifyFalse(result.provenance.isDiagnosticConstructionAssessmentAvailable);
            testCase.verifyEqual(result.provenance.rateSource,"none");
            testCase.verifyEqual(authoritativeState(w),sourceBefore);
            testCase.verifyEqual(authoritativeState(apv),diagnosticBefore);
            testCase.verifyEqual(fileBytes(path),bytesBefore);
            testCase.verifyFalse(isfield(result.history,'reconstruction'));
            verifyReleased(testCase,path);
        end
        function basisIdentityIgnoresStateAndIncludesProjectionGrid(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            path=fullfile(folder.Folder,'snapshot.nc'); file=w.writeToFile(path); file.close();
            first=analyzeThermalAPVOutput(path,apv,quadratureCount=259);
            apv.Ag_q(1,1)=1e-6; apv.Amda(:)=.1; apv.t=1234;
            before=authoritativeState(apv);
            changed=analyzeThermalAPVOutput(path,apv,quadratureCount=259);
            testCase.verifyEqual(first.provenance.diagnosticIdentity,changed.provenance.diagnosticIdentity);
            testCase.verifyEqual(first.history.coefficients,changed.history.coefficients);
            testCase.verifyEqual(authoritativeState(apv),before);
            refined=analyzeThermalAPVOutput(path,apv,quadratureCount=513);
            testCase.verifyNotEqual(first.provenance.diagnosticIdentity.sha256,refined.provenance.diagnosticIdentity.sha256);
        end
        function nestedCommittedStreamIgnoresStagedTail(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            path=fullfile(folder.Folder,'history.nc'); writeStream(w,path,"tail"); bytesBefore=fileBytes(path);
            result=analyzeThermalAPVOutput(path,apv,indices=[3 1],quadratureCount=259);
            testCase.verifyEqual(result.provenance.coefficientGroup,"analysis/states");
            testCase.verifyEqual(result.provenance.committedRecordCount,3);
            testCase.verifyEqual(result.provenance.selectedIndices,[3 1]);
            testCase.verifyEqual(result.provenance.times,[47 17]);
            testCase.verifyFalse(result.provenance.didAnalyzeAllCommittedRecords);
            factors=[-1 1]; times=[47 17]; initial=w.coefficientState();
            for i=1:2
                state=struct(Ath=factors(i)*initial.Ath,Amda=factors(i)*initial.Amda);
                expected=w.apvDecomposition(apv,state=state,time=times(i),quadratureCount=259);
                testCase.verifyEqual(result.history(i).coefficients,expected.coefficients);
                testCase.verifyEqual(result.history(i).mean,expected.mean);
                testCase.verifyEqual(result.history(i).inventories,expected.inventories);
            end
            last=analyzeThermalAPVOutput(path,apv,indices=Inf,quadratureCount=259);
            testCase.verifyEqual(last.provenance.selectedIndices,3);
            testCase.verifyEqual(last.history.coefficients,result.history(1).coefficients);
            testCase.verifyEqual(fileBytes(path),bytesBefore);
            verifyReleased(testCase,path);
        end
        function selectionsAreExplicitAndBounded(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            path=fullfile(folder.Folder,'history.nc'); writeStream(w,path,"complete");
            result=analyzeThermalAPVOutput(path,apv,maximumRecords=2,quadratureCount=259);
            testCase.verifyEqual(result.provenance.selectedIndices,[1 2]);
            testCase.verifyFalse(result.provenance.didAnalyzeAllCommittedRecords);
            testCase.verifyError(@()analyzeThermalAPVOutput(path,apv,indices=1:3,maximumRecords=2),'WV:APVOutputRecordLimit');
            for indices={4,1.5,[1 1],[1 Inf]}
                testCase.verifyError(@()analyzeThermalAPVOutput(path,apv,indices=indices{1}),'WV:APVOutputIndices');
            end
            snapshot=fullfile(folder.Folder,'snapshot.nc'); file=w.writeToFile(snapshot); file.close();
            testCase.verifyError(@()analyzeThermalAPVOutput(snapshot,apv,indices=2),'WVTransform:SnapshotTimeIndex');
            verifyReleased(testCase,path); verifyReleased(testCase,snapshot);
        end
        function malformedStreamsPreserveSharedErrorsAndReleaseReaders(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            modes=["uncommitted","hole","duplicate","missing","noLocalTime"];
            identifiers=["WVTransform:NoCommittedRestartRecord","WVModelOutputGroup:NoncontiguousCommittedRecords", ...
                "WVTransform:AmbiguousRestartState","WVTransform:MissingRestartCoefficients","WVTransform:MissingRestartTime"];
            for i=1:numel(modes)
                path=fullfile(folder.Folder,modes(i)+".nc"); writeStream(w,path,modes(i)); before=fileBytes(path);
                testCase.verifyError(@()analyzeThermalAPVOutput(path,apv),char(identifiers(i)));
                testCase.verifyEqual(fileBytes(path),before);
                verifyReleased(testCase,path);
            end
        end
        function diagnosisFailureReleasesReader(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=populated(testCase.scientificState); apv=WVTransform.waveVortexTransformFromFile(testCase.apvPath);
            path=fullfile(folder.Folder,'snapshot.nc'); file=w.writeToFile(path); file.close(); before=fileBytes(path);
            testCase.verifyError(@()analyzeThermalAPVOutput(path,apv,quadratureCount=1),'WV:APVDiagnosticQuadrature');
            testCase.verifyEqual(fileBytes(path),before);
            verifyReleased(testCase,path);
        end
    end
    methods (Static)
        function prepareWithoutProviderStudy(folder)
            % Run with InternalModes present, then verify in a fresh process.
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            [w,apv]=construct(); w=populated(w.scientificState);
            sourcePath=fullfile(folder,'thermal.nc'); apvPath=fullfile(folder,'diagnostic.nc');
            writeStream(w,sourcePath,"tail"); file=apv.writeToFile(apvPath,shouldOverwriteExisting=true); file.close();
            reference=analyzeThermalAPVOutput(sourcePath,apv,quadratureCount=259);
            save(fullfile(folder,'reference.mat'),'reference');
        end
        function verifyWithoutProvider(folder)
            arguments (Input)
                folder (1,1) string
            end
            assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')),'InternalModes must be absent in this fresh process.');
            saved=load(fullfile(folder,'reference.mat'));
            apv=WVTransform.waveVortexTransformFromFile(char(fullfile(folder,'diagnostic.nc')));
            before=authoritativeState(apv);
            result=analyzeThermalAPVOutput(fullfile(folder,'thermal.nc'),apv,quadratureCount=259);
            for i=1:numel(result.history)
                actual=result.history(i); expected=saved.reference.history(i);
                assert(~actual.metadata.isConstructionAssessmentAvailable);
                actual.metadata=rmfield(actual.metadata,'isConstructionAssessmentAvailable');
                expected.metadata=rmfield(expected.metadata,'isConstructionAssessmentAvailable');
                assert(isequaln(actual,expected));
            end
            assert(isequal(result.provenance.sourceSHA256,saved.reference.provenance.sourceSHA256));
            assert(isequal(result.provenance.diagnosticIdentity,saved.reference.provenance.diagnosticIdentity));
            assert(saved.reference.provenance.isDiagnosticConstructionAssessmentAvailable);
            assert(~result.provenance.isDiagnosticConstructionAssessmentAvailable);
            assert(isequaln(authoritativeState(apv),before));
            fprintf('Provider-unavailable APV output analysis: %d committed records, exact saved-array diagnosis.\n',numel(result.history));
        end
    end
end

function [w,apv]=construct()
N2=@(z)1e-4+zeros(size(z));
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[8 8 65],N2Function=N2,thermalModeCount=17,mdaModeCount=3,kappa_z=1e-5);
apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=N2,latitude=w.latitude,g=w.g,rho0=w.rho0,apvModeCount=6,mdaModeCount=2,quadraticDealiasing="none");
end

function w=populated(scientificState)
w=WVTransformFreeSurfaceThermalQG(scientificState=scientificState);
thermalManufacturedState(w,[2 3 4],1000); w.Amda=[.1;-.2;.3]; w.t=17; w.t0=3;
w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7,period=1000,phase=.3));
end

function state=authoritativeState(w)
state=struct();
for name=string(w.classRequiredPropertyNames())
    if name=="forcing"
        forces=struct([]);
        for force=w.forcing
            item=struct(class=string(class(force)),name=string(force.name));
            for property=string(force.requiredProperties), item.(property)=force.(property); end
            forces=[forces;struct(configuration=item)]; %#ok<AGROW>
        end
        state.forcing=forces;
    else
        state.(name)=w.(name);
    end
end
end

function writeStream(w,path,mode)
names=setdiff(w.classRequiredPropertyNames(),{'Ath','Amda','t'});
file=w.writeToFile(char(path),names{:},shouldAddRequiredProperties=false,shouldOverwriteExisting=true);
cleanup=onCleanup(@()file.close());
parent=file.addGroup('analysis'); group=parent.addGroup('states');
hasTime=mode~="noLocalTime";
if hasTime
    attributes=containers.Map({'_FillValue','wvm_record_commit_protocol'},{NaN,'finite_time_prefix_v1'});
    group.addDimension('t',length=Inf,type='double',attributes=attributes);
end
state=w.coefficientState(); factors=[1 2 -1]; times=[17 23 47];
timeDimension={};
if hasTime, timeDimension={'t'}; end
for name=["Ath","Amda"]
    if mode=="missing" && name=="Amda", continue; end
    annotation=w.propertyAnnotationWithName(name); dimensions=[annotation.dimensions timeDimension];
    variable=group.addVariable(char(name),dimensions,type='double',isComplex=annotation.isComplex);
    if hasTime
        for i=1:3, variable.setValueAlongDimensionAtIndex(factors(i)*state.(name),'t',i); end
        if mode=="tail", variable.setValueAlongDimensionAtIndex(100*state.(name),'t',4); end
    else
        variable.value=state.(name);
    end
end
if hasTime && mode~="uncommitted"
    timeVariable=group.variableWithName('t');
    for i=1:3, timeVariable.setValueAlongDimensionAtIndex(times(i),'t',i); end
    if mode=="hole", timeVariable.setValueAlongDimensionAtIndex(67,'t',5); end
end
if mode=="duplicate"
    duplicate=file.addGroup('duplicate'); duplicate.addDimension('t',length=Inf,type='double');
    duplicate.variableWithName('t').setValueAlongDimensionAtIndex(17,'t',1);
    for name=["Ath","Amda"]
        annotation=w.propertyAnnotationWithName(name);
        variable=duplicate.addVariable(char(name),[annotation.dimensions {'t'}],type='double',isComplex=annotation.isComplex);
        variable.setValueAlongDimensionAtIndex(state.(name),'t',1);
    end
end
end

function bytes=fileBytes(path)
fid=fopen(path,'rb'); cleanup=onCleanup(@()fclose(fid)); bytes=fread(fid,Inf,'*uint8');
end

function verifyReleased(testCase,path)
file=NetCDFFile(char(path),shouldReadOnly=false); cleanup=onCleanup(@()file.close());
testCase.verifyNotEmpty(file.id);
end
