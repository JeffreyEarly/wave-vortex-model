classdef TestThermalReadinessDiagnostics < matlab.unittest.TestCase
    methods (TestClassSetup)
        function includeAuthoringTools(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(fileparts(mfilename('fullpath'))),'tools')));
        end
    end
    methods (Test,TestTags="full")
        function sourceNormUncertaintyRejectsAnOtherwiseIdenticalDiagnosis(testCase)
            reference=manufacturedDiagnosis();candidate=reference;
            candidate.residuals.ssh.reference=1.02*reference.residuals.ssh.reference;
            [comparison,observables]=compareThermalReadinessDiagnostics(candidate,reference);
            testCase.verifyFalse(comparison.accepted);
            testCase.verifyEqual(comparison.coefficientChange,0);
            testCase.verifyEqual(comparison.residualChangeOverSource,0);
            testCase.verifyEqual(comparison.sourceNormChange,.02,AbsTol=1e-15);
            testCase.verifyFalse(observables.accepted(observables.observable=="ssh"));
            testCase.verifyEqual(height(observables),9);
            candidate=reference;candidate.coefficients.Ag_q=1i*candidate.coefficients.Ag_q;
            comparison=compareThermalReadinessDiagnostics(candidate,reference);
            testCase.verifyFalse(comparison.accepted);
            testCase.verifyEqual(comparison.coefficientChange,sqrt(2),AbsTol=1e-15);
        end
        function nearZeroReferencesKeepUnitsAndUndefinedRelativeValues(testCase)
            reference=manufacturedDiagnosis();candidate=reference;
            for name=string(fieldnames(reference.residuals)).'
                value=struct(absolute=zeros(size(reference.residuals.(name).absolute)),reference=zeros(size(reference.residuals.(name).reference)),relative=nan(size(reference.residuals.(name).relative)));
                reference.residuals.(name)=value;candidate.residuals.(name)=value;
            end
            candidate.residuals.endpointAnomalies.absolute(2)=2e-12;
            [comparison,rows]=compareThermalReadinessDiagnostics(candidate,reference);
            testCase.verifyFalse(comparison.accepted);
            testCase.verifyTrue(all(isnan(rows.referenceRelativeResidual)));
            testCase.verifyEqual(rows.sourceNormFloor(rows.observable=="qgpv"),1e-13);
            candidate=reference;candidate.coefficients.Ag_q(1)=NaN;
            comparison=compareThermalReadinessDiagnostics(candidate,reference);
            testCase.verifyFalse(comparison.accepted);
        end
        function storedBasesRestoreWithoutScientificConstruction(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4+zeros(size(z)),thermalModeCount=17,mdaModeCount=2);
            state=w.coefficientState();state.Ath(2,1)=.01+.02i;state.Amda=[.02;-.01];
            before=w.coefficientState();time=w.t;
            record=struct(caseId="small-control",recordId="manufactured",state=state,time=123,forcingMultiplier=10,seasonalPhase=0,regime="capacity-only");
            basisDirectory=fullfile(folder.Folder,'basis');
            first=qualifyThermalReadinessDiagnostics(w,record,fullfile(folder.Folder,'first'),apvModeCount=3,diagnosticBasisDirectory=basisDirectory);
            testCase.assertTrue(first.summary.basisAccepted);
            testCase.verifyEqual(first.capacity.diagnosticNz,[129;257]);
            testCase.verifyEqual(first.capacity.boundaryPageCount,2*first.capacity.retainedRadiusCount);
            testCase.verifyEqual(first.summary.status,"CONDITIONAL");
            testCase.verifyFalse(any(first.regimes.accepted(first.regimes.regime~="nonzero-mean")));
            testCase.verifyTrue(all(first.comparisons.status=="accepted"));
            testCase.verifyEqual(height(first.observables),18);
            testCase.verifyEqual(w.coefficientState(),before);testCase.verifyEqual(w.t,time);
            originalPath=path;cleanup=onCleanup(@()path(originalPath));
            providerRoot=string(fileparts(fileparts(which('IMInternalModes'))));
            paths=string(strsplit(path,pathsep));provider=startsWith(paths,providerRoot+filesep) | paths==providerRoot;
            rmpath(char(join(paths(provider),pathsep)));
            testCase.assertEmpty(which('IMInternalModes'));
            second=qualifyThermalReadinessDiagnostics(w,record,fullfile(folder.Folder,'second'),apvModeCount=3,diagnosticBasisDirectory=basisDirectory,shouldConstructMissingBases=false);
            testCase.verifyTrue(second.summary.basisAccepted);
            testCase.verifyTrue(all(second.capacity.source=="restored"));
            testCase.verifyEqual(second.capacity.basisSHA256,first.capacity.basisSHA256);
            testCase.verifyEqual(second.observables,first.observables);
            testCase.verifyEqual(w.coefficientState(),before);testCase.verifyEqual(w.t,time);
            % Changed cache bytes fail explicitly and are never reconstructed.
            filePath=second.capacity.basisPath(1);fid=fopen(filePath,'ab');fwrite(fid,uint8(0),'uint8');fclose(fid);
            third=qualifyThermalReadinessDiagnostics(w,record,fullfile(folder.Folder,'changed-cache'),apvModeCount=3,diagnosticBasisDirectory=basisDirectory,shouldConstructMissingBases=false);
            testCase.verifyEqual(third.capacity.failureIdentifier(1),"WV:ReadinessDiagnosticCache");
            testCase.verifyEqual(third.summary.status,"FAIL");
        end
    end
end

function diagnosis=manufacturedDiagnosis()
diagnosis=struct(metadata=struct(apvModeNumber=[1;2],activeEndpoint=[1;2]),coefficients=struct(Ag_q=ones(2,3),Ag_0=ones(2,3)),residuals=struct());
for name=["qgpv","buoyancy","velocity","eta","eta_i","ssh","endpointAnomalies","energyNorm"]
    count=1;if name=="endpointAnomalies",count=2;end
    diagnosis.residuals.(name)=struct(absolute=2*ones(count,1),reference=ones(count,1),relative=2*ones(count,1));
end
end
