classdef TestPortableCompatibilityMatrix < matlab.unittest.TestCase
    properties
        root
        matrix
    end
    methods (TestClassSetup)
        function prepare(testCase)
            testCase.root=string(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(testCase.root,'tools'));
            testCase.matrix=portableCompatibilityDefinition(testCase.root);
        end
    end
    methods (Test, TestTags={'full'})
        function authoritativeInventoryAndTrackedGaps(testCase)
            result=validatePortableCompatibilityMatrix(testCase.matrix,repositoryRoot=testCase.root,expected=testCase.matrix);
            testCase.verifyGreaterThan(result.rowCount,666);
            testCase.verifyGreaterThan(result.unqualifiedCount,0);
            testCase.verifyFalse(testCase.matrix.readiness.standardParityReady);
            testCase.verifyError(@()validatePortableCompatibilityMatrix(testCase.matrix,repositoryRoot=testCase.root,expected=testCase.matrix,requireComplete=true),'WaveVortexModel:CompatibilityIncomplete');
        end
        function generatedAssemblyMatchesCommittedFiles(testCase)
            output=string(tempname); mkdir(output); cleanup=onCleanup(@()rmdir(output,'s'));
            result=generatePortableCompatibilityMatrix(repositoryRoot=testCase.root,outputRoot=output);
            testCase.verifyTrue(isequal(fileread(result.catalogPath),fileread(fullfile(testCase.root,'PortableRuntime/contracts/portable-compatibility-matrix-v1.json'))),'Regenerate the compatibility JSON from the final source files.');
            testCase.verifyTrue(isequal(fileread(result.documentationPath),fileread(fullfile(testCase.root,'PortableRuntime/COMPATIBILITY.md'))),'Regenerate COMPATIBILITY.md from the final assembly.');
        end
        function removedAndDuplicateRowsAreRejected(testCase)
            candidate=testCase.matrix; candidate.rows(1)=[]; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.rows(end+1)=candidate.rows(1); testCase.reject(candidate);
        end
        function staleAuthorityAndInventoriesAreRejected(testCase)
            candidate=testCase.matrix; candidate.sources(1).sha256=repmat("0",1,64); testCase.reject(candidate);
            candidate=testCase.matrix; candidate.versions(1).version=999; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.inventory.observers(end+1)="WVNewObserver"; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.inventory.variables(end+1)="new_registered_field"; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.inventory.configurations(end+1)="new-transform-aa0"; testCase.reject(candidate);
        end
        function unresolvedAndContradictoryFixturesAreRejected(testCase)
            candidate=testCase.matrix; candidate.rows(1).fixtures="missing-fixture"; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.witnesses(1).symbol="missingMethod"; testCase.reject(candidate);
            candidate=testCase.matrix;
            index=find(arrayfun(@(w)~isempty(w.coverage.rowIds),candidate.witnesses),1);
            candidate.witnesses(index).coverage.rowIds(1)=[]; testCase.reject(candidate);
        end
        function movingSamplingStagesRemainExplicit(testCase)
            rows=testCase.matrix.rows;
            moving=rows(string({rows.reason})=="matlab-supported-moving-sampling-not-implemented");
            testCase.verifyNumElements(moving,40);
            for row=reshape(moving,1,[])
                testCase.verifyEqual(row.status,"unqualified");
                testCase.verifyEqual(row.issue,454);
                testCase.verifyEqual(row.axes.stage,"moving");
                base=rows(string({rows.id})==erase(row.id,"/moving"));
                testCase.assertNumElements(base,1);
                testCase.verifyEqual(base.status,"supported");
                testCase.verifyEqual(base.axes.stage,"fixed-and-event");
            end
        end
        function unqualifiedSamplingCannotBecomeAnExclusion(testCase)
            candidate=testCase.matrix;
            index=find(string({candidate.rows.reason})=="matlab-supported-sampling-not-implemented",1);
            testCase.assertNotEmpty(index);
            candidate.rows(index).status="intentional-incompatibility"; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.rows(index).issue=0; testCase.reject(candidate);
            candidate=testCase.matrix; candidate.readiness.standardParityReady=true; testCase.reject(candidate);
        end
    end
    methods (Access=private)
        function reject(testCase,candidate)
            testCase.verifyError(@()validatePortableCompatibilityMatrix(candidate,repositoryRoot=testCase.root,expected=testCase.matrix),'WaveVortexModel:InvalidCompatibilityMatrix');
        end
    end
end
