classdef TestReleaseVerification < matlab.unittest.TestCase
    properties
        repositoryRoot (1,1) string
    end

    methods (TestMethodSetup)
        function locateRepository(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
        end
    end

    methods (Test,TestTags="full")
        function releaseCallerUsesImmutablePilot(testCase)
            workflow = testCase.readFile(fullfile(".github","workflows","release-mpm.yml"));
            testCase.verifySubstring(workflow, ...
                "JeffreyEarly/OceanKit/.github/workflows/reusable-mpm-release.yml@mpm-release-v0.1.0");
            testCase.verifySubstring(workflow,"documentationPackageSpecifier: ClassDocumentation@1.3.0");
            testCase.verifySubstring(workflow,"shouldCheckWebsiteDocumentation: true");
            testCase.verifySubstring(workflow,"documentationCheckTask: docs:check");
            testCase.verifySubstring(workflow, ...
                "shouldPromoteUnreleased: ${{ github.event.inputs.bump != 'none' }}");
            testCase.verifySubstring(workflow,"shouldBuildWebsiteDocumentation:");
            testCase.verifySubstring(workflow,"shouldPackageForDistribution:");
        end

        function runtimeManifestExcludesAuthoringTests(testCase)
            manifest = jsondecode(testCase.readFile(fullfile("resources","mpackage.json")));
            folders = string({manifest.folders.path});
            testCase.verifyFalse(any(folders == "UnitTests"));
            testCase.verifyFalse(any(folders == "Benchmarks"));
            testCase.verifyFalse(any(folders == "DeveloperExperiments"));

            dependencies = string({manifest.dependencies.name});
            compatibleVersions = string({manifest.dependencies.compatibleVersions});
            expected = dictionary( ...
                ["ClassAnnotations" "InternalModes" "NetCDF" "SplineCore" "chebfun"], ...
                ["^1.2.1" "1.3.0" "^1.0.2" "^2.2.0" ""]);
            testCase.verifyEqual(sort(reshape(dependencies,[],1)),sort(reshape(keys(expected),[],1)));
            for iDependency = 1:numel(dependencies)
                testCase.verifyEqual(compatibleVersions(iDependency),expected(dependencies(iDependency)));
            end
            testCase.verifyEqual(string(manifest.releaseCompatibility),">=R2024b");
            testCase.verifyEqual(string(manifest.version),"4.2.0");
        end

        function packageWorkflowHasIsolatedR2024bGates(testCase)
            workflow = testCase.readFile(fullfile(".github","workflows","release-verification.yml"));
            tools = testCase.readFile(fullfile("tools","verifyWaveVortexModelPackage.m")) + ...
                testCase.readFile(fullfile("tools","prepareWaveVortexModelReleaseCandidate.m"));
            contract = workflow + tools;
            for required = [
                    "Clean install / MATLAB R2024b"
                    "Exported package / MATLAB R2024b"
                    "release: R2024b"
                    "contents: read"
                    "eb6141e837b2a2d52db675d449ed0ac4c9a64bb5"
                    "MATLAB_PREFDIR"
                    "Temporary=true"
                    "ClassDocumentation@1.3.0"
                    "prepareWaveVortexModelReleaseCandidate"
                    "verifyWaveVortexModelPackage"
                    "checkCIWorkspaceCleanliness.sh"
                    ]'
                testCase.verifySubstring(contract,required);
            end
            testCase.verifySubstring(workflow,"workflow_dispatch:");
            testCase.verifySubstring(workflow,"pull_request:");
            testCase.verifyFalse(contains(workflow,newline + "  push:"));
            testCase.verifyFalse(contains(workflow,'- "UnitTests/**"'));
            testCase.verifyFalse(contains(workflow,'- "Benchmarks/**"'));
            testCase.verifyFalse(contains(workflow,'- "DeveloperExperiments/**"'));
            testCase.verifyFalse(contains(workflow,"contents: write"));
        end

        function routineWorkflowsUsePilotDependencySnapshot(testCase)
            for path = [
                    fullfile(".github","workflows","ci.yml")
                    fullfile(".github","workflows","extended-ci.yml")
                    ]'
                workflow = testCase.readFile(path);
                testCase.verifySubstring(workflow,"eb6141e837b2a2d52db675d449ed0ac4c9a64bb5");
                testCase.verifyFalse(contains(workflow,"eb71bc7b05e74776afd678b27c964cf53cd9d547"));
            end
        end

        function releaseDocumentationMatchesCanonicalSources(testCase)
            canonicalCI = testCase.readFile(fullfile("Documentation","WebsiteDocumentation", ...
                "developers-guide","continuous-integration.md"));
            generatedCI = testCase.readFile(fullfile("docs","developers-guide","continuous-integration.md"));
            canonicalChecklist = testCase.readFile(fullfile("Documentation","WebsiteDocumentation", ...
                "developers-guide","release-checklist.md"));
            generatedChecklist = testCase.readFile(fullfile("docs","developers-guide","release-checklist.md"));
            testCase.verifyEqual(generatedCI,canonicalCI);
            testCase.verifyEqual(generatedChecklist,canonicalChecklist);
            for phrase = [
                    "Native-package CI: Clean install and Exported package on MATLAB R2024b"
                    "promote the complete `Unreleased` body"
                    "authoring commit first"
                    "OceanKit package snapshot second"
                    "immutable version tag third"
                    "GitHub release last"
                    ]'
                testCase.verifySubstring(generatedChecklist,phrase);
            end
            testCase.verifySubstring(canonicalCI,"package schemas are forward compatible");
            testCase.verifyFalse(contains(canonicalCI,"cannot construct a package from the schema 1.1 manifest"));
        end

        function generatedVersionHistoryIncludesCurrentReleaseRecords(testCase)
            changelog = testCase.readFile("CHANGELOG.md");
            versionHistory = testCase.readFile(fullfile("docs","version-history.md"));
            releaseGateRecord = "Pinned releases to the immutable OceanKit release pilot";
            compactMappingRecord = "Replaced vertically replicated horizontal Fourier mappings";
            for record = [releaseGateRecord compactMappingRecord]
                testCase.verifySubstring(changelog,record);
                testCase.verifySubstring(versionHistory,record);
            end
        end
    end

    methods (Access=private)
        function contents = readFile(testCase,path)
            if ~isfile(path)
                path = fullfile(testCase.repositoryRoot,path);
            end
            contents = string(fileread(path));
        end
    end
end
