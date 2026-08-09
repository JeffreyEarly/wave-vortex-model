classdef TestWVVerticalTransformConstantStratification < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSupportPaths(testCase)
            repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(repositoryRoot,"UnitTests","Support")));
            workspaceRoot = string(fileparts(repositoryRoot));
            fftwTransformsRoot = fullfile(workspaceRoot,"fftw-transforms");
            if isfolder(fftwTransformsRoot)
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fftwTransformsRoot));
            end
        end
    end

    methods (Test,TestTags="full")
        function classIsVisibleSealedAndGeometryPropertyIsReadOnly(testCase)
            metadata = meta.class.fromName("WVVerticalTransformConstantStratification");
            testCase.verifyNotEmpty(metadata);
            testCase.verifyTrue(metadata.Sealed);
            testCase.verifyFalse(metadata.Hidden);
            property = metadata.PropertyList(strcmp({metadata.PropertyList.Name},"backendIdentifier"));
            testCase.verifyEqual(string(property.SetAccess),"private");

            geometryMetadata = meta.class.fromName("WVGeometryDoublyPeriodicStratifiedConstant");
            verticalProperty = geometryMetadata.PropertyList(strcmp({geometryMetadata.PropertyList.Name},"verticalTransform"));
            testCase.verifyEqual(string(verticalProperty.SetAccess),"private");
        end

        function builtinNeverQueriesFFTWAndUsesExactMatrices(testCase)
            services = MockWVVerticalTransformServices(struct());
            strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"builtin",services.serviceRecord());
            cleanup = onCleanup(@()delete(strategy));
            rng(7301,"twister");
            realValues = randn(7,4);
            complexValues = complex(realValues,randn(7,4));
            [DCT,iDCT,DST,iDST] = testCase.fallbackMatrices(7,5);

            testCase.verifyEqual(strategy.transformForward(realValues,"cosine",DCT),DCT*realValues,AbsTol=0);
            testCase.verifyEqual(strategy.transformForward(complexValues,"sine",DST),DST*complexValues,AbsTol=0);
            coefficients = randn(5,4)+1i*randn(5,4);
            testCase.verifyEqual(strategy.transformBack(coefficients,"cosine",iDCT),iDCT*coefficients,AbsTol=0);
            testCase.verifyEqual(strategy.transformBack(coefficients,"sine",iDST),iDST*coefficients,AbsTol=0);
            testCase.verifyEqual(services.queryCount,0);
            testCase.verifyEqual(services.planConstructionCount,0);
            testCase.verifyTrue(all([strategy.dispatchRecords().implementation] == "matrix"));
            clear cleanup
        end

        function dispatchMatchesAllIssue43RecordsAndInclusiveBounds(testCase)
            capabilities = testCase.actualIssue43Capabilities();
            records = capabilities.eligibility.realToReal.records;
            testCase.verifyNumElements(records,40);
            for Nz = capabilities.eligibility.realToReal.testedNz
                services = MockWVVerticalTransformServices(capabilities);
                strategy = WVVerticalTransformConstantStratification.createWithServices(Nz,Nz-1,"fftw",services.serviceRecord());
                cleanup = onCleanup(@()delete(strategy));
                nzRecords = records([records.Nz] == Nz);
                for expected = nzRecords'
                    if expected.eligible
                        minimum = expected.intervals.minimumBatchCount;
                        maximum = expected.intervals.maximumBatchCount;
                        atMinimum = strategy.dispatchForConfiguration(minimum,expected.dataType,expected.transformType,expected.direction);
                        atMaximum = strategy.dispatchForConfiguration(maximum,expected.dataType,expected.transformType,expected.direction);
                        testCase.verifyTrue(atMinimum.isEligible);
                        testCase.verifyTrue(atMaximum.isEligible);
                        if minimum > 1
                            below = strategy.dispatchForConfiguration(minimum-1,expected.dataType,expected.transformType,expected.direction);
                            testCase.verifyFalse(below.isEligible);
                            testCase.verifyEqual(below.reason.code,"batch-outside-eligibility");
                        end
                        above = strategy.dispatchForConfiguration(maximum+1,expected.dataType,expected.transformType,expected.direction);
                        testCase.verifyFalse(above.isEligible);
                        testCase.verifyEqual(above.reason.code,"batch-outside-eligibility");
                    else
                        rejected = strategy.dispatchForConfiguration(8320,expected.dataType,expected.transformType,expected.direction);
                        testCase.verifyFalse(rejected.isEligible);
                        testCase.verifyEqual(rejected.reason.code,"eligibility-record-ineligible");
                    end
                end
                clear cleanup
            end
        end

        function realAndComplexDCTDSTUseExactTruncationAndPadding(testCase)
            capabilities = testCase.smallEligibleCapabilities(7,1,16);
            services = MockWVVerticalTransformServices(capabilities);
            strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",services.serviceRecord());
            cleanup = onCleanup(@()delete(strategy));
            [DCT,iDCT,DST,iDST] = testCase.fallbackMatrices(7,5);
            rng(7302,"twister");

            for isComplex = [false true]
                values = randn(7,4);
                coefficients = randn(5,4);
                if isComplex
                    values = complex(values,randn(7,4));
                    coefficients = complex(coefficients,randn(5,4));
                end
                cosineForward = strategy.transformForward(values,"cosine",DCT);
                sineForward = strategy.transformForward(values,"sine",DST);
                cosineBack = strategy.transformBack(coefficients,"cosine",iDCT);
                sineBack = strategy.transformBack(coefficients,"sine",iDST);
                testCase.verifyLessThanOrEqual(testCase.relativeError(cosineForward,DCT*values),1e-12);
                testCase.verifyLessThanOrEqual(testCase.relativeError(sineForward,DST*values),1e-12);
                testCase.verifyEqual(sineForward(1,:),zeros(1,4,"like",sineForward),AbsTol=0);
                testCase.verifyLessThanOrEqual(testCase.relativeError(cosineBack,iDCT*coefficients),1e-12);
                testCase.verifyLessThanOrEqual(testCase.relativeError(sineBack,iDST*coefficients),1e-12);
                testCase.verifyEqual(sineBack([1 end],:),zeros(2,4,"like",sineBack),AbsTol=0);
            end

            records = strategy.dispatchRecords();
            testCase.verifyNumElements(records,8);
            testCase.verifyTrue(all([records.isEligible]));
            testCase.verifyTrue(all([records.implementation] == "fftw"));
            testCase.verifyEqual(services.planConstructionCount,4,"Forward and inverse must share each family/data-type plan.");
            testCase.verifyEqual(sum([records.planCreationCount]),4);
            testCase.verifyEqual(sum([records.planReuseCount]),4);
            clear cleanup
            testCase.verifyEqual(services.planDeletionCount,4);
        end

        function ordinaryIneligibilityFallsBackSilently(testCase)
            capabilities = testCase.smallEligibleCapabilities(7,8,16);
            services = MockWVVerticalTransformServices(capabilities);
            strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",services.serviceRecord());
            cleanup = onCleanup(@()delete(strategy));
            [DCT,~,~,~] = testCase.fallbackMatrices(7,5);
            values = randn(7,4);
            output = testCase.verifyWarningFree(@()strategy.transformForward(values,"cosine",DCT));
            testCase.verifyEqual(output,DCT*values,AbsTol=0);
            record = strategy.dispatchRecords();
            testCase.verifyEqual(record.reason.code,"batch-outside-eligibility");
            testCase.verifyEqual(services.planConstructionCount,0);
            clear cleanup
        end

        function invalidCapabilityCriteriaRejectWithoutPlans(testCase)
            mutations = { ...
                @(c)setNestedTwo(c,"provider","id","native"), ...
                @(c)setNestedThree(c,"modules","r2r","identityValidated",false), ...
                @(c)setNestedThree(c,"features","dct1","isAvailable",false), ...
                @(c)setNestedThree(c,"features","dct1","maximumRelativeError",1e-9)};
            expectedCodes = ["provider-mismatch" "r2r-library-identity-failed" "vertical-feature-unavailable" "vertical-self-test-failed"];
            for iMutation = 1:numel(mutations)
                capabilities = mutations{iMutation}(testCase.smallEligibleCapabilities(7,1,16));
                services = MockWVVerticalTransformServices(capabilities);
                strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",services.serviceRecord());
                cleanup = onCleanup(@()delete(strategy));
                record = strategy.dispatchForConfiguration(4,"real","cosine","forward");
                testCase.verifyFalse(record.isEligible);
                testCase.verifyEqual(record.reason.code,expectedCodes(iMutation));
                testCase.verifyEqual(services.planConstructionCount,0);
                clear cleanup
            end
        end

        function querySchemaPlanAndExecutionFailuresWarnOnceAndRecover(testCase)
            [DCT,~,~,~] = testCase.fallbackMatrices(7,5);
            values = randn(7,4);

            queryServices = MockWVVerticalTransformServices(struct());
            queryServices.queryException = MException("WaveVortexModel:InjectedQueryFailure","Injected query failure.");
            queryStrategy = [];
            testCase.verifyWarning(@createQueryStrategy,"WaveVortexModel:FFTWVerticalTransformUnavailable");
            queryCleanup = onCleanup(@()delete(queryStrategy));
            testCase.verifyWarningFree(@()queryStrategy.transformForward(values,"cosine",DCT));
            testCase.verifyEqual(queryStrategy.dispatchRecords().reason.code,"vertical-capability-query-failed");
            clear queryCleanup

            schemaCapabilities = testCase.smallEligibleCapabilities(7,1,16);
            schemaCapabilities.eligibility.realToReal.schemaVersion = "future-schema";
            schemaServices = MockWVVerticalTransformServices(schemaCapabilities);
            schemaStrategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",schemaServices.serviceRecord());
            schemaCleanup = onCleanup(@()delete(schemaStrategy));
            testCase.verifyWarning(@()schemaStrategy.transformForward(values,"cosine",DCT),"WaveVortexModel:FFTWVerticalTransformUnavailable");
            testCase.verifyWarningFree(@()schemaStrategy.transformForward(values,"cosine",DCT));
            testCase.verifyEqual(schemaServices.planConstructionCount,0);
            testCase.verifyEqual(double(schemaStrategy.cacheDiagnostics().failedConfigurationCount),1);
            clear schemaCleanup

            planServices = MockWVVerticalTransformServices(testCase.smallEligibleCapabilities(7,1,16));
            planServices.planException = MException("WaveVortexModel:InjectedPlanFailure","Injected plan failure.");
            planStrategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",planServices.serviceRecord());
            planCleanup = onCleanup(@()delete(planStrategy));
            testCase.verifyWarning(@()planStrategy.transformForward(values,"cosine",DCT),"WaveVortexModel:FFTWVerticalTransformUnavailable");
            testCase.verifyWarningFree(@()planStrategy.transformForward(values,"cosine",DCT));
            testCase.verifyEqual(planServices.planConstructionCount,1);
            testCase.verifyEqual(double(planStrategy.cacheDiagnostics().failedConfigurationCount),1);
            clear planCleanup

            executionServices = MockWVVerticalTransformServices(testCase.smallEligibleCapabilities(7,1,16));
            executionServices.failForward = true;
            executionStrategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",executionServices.serviceRecord());
            executionCleanup = onCleanup(@()delete(executionStrategy));
            testCase.verifyWarning(@()executionStrategy.transformForward(values,"cosine",DCT),"WaveVortexModel:FFTWVerticalTransformUnavailable");
            testCase.verifyWarningFree(@()executionStrategy.transformForward(values,"cosine",DCT));
            testCase.verifyEqual(executionServices.planConstructionCount,1);
            testCase.verifyEqual(executionServices.planDeletionCount,1);
            testCase.verifyEqual(double(executionStrategy.cacheDiagnostics().planCount),0);
            clear executionCleanup

            function createQueryStrategy()
                queryStrategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",queryServices.serviceRecord());
            end
        end

        function dispatchMetadataIsStableCompleteAndJSONSafe(testCase)
            capabilities = testCase.smallEligibleCapabilities(7,1,16);
            services = MockWVVerticalTransformServices(capabilities);
            strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"fftw",services.serviceRecord());
            cleanup = onCleanup(@()delete(strategy));
            [DCT,iDCT,~,~] = testCase.fallbackMatrices(7,5);
            values = randn(7,4);
            coefficients = strategy.transformForward(values,"cosine",DCT);
            strategy.transformBack(coefficients,"cosine",iDCT);
            strategy.transformForward(values,"cosine",DCT);
            records = strategy.dispatchRecords();
            testCase.verifyEqual(string({records.direction}),["forward" "inverse"]);
            forward = records(1);
            testCase.verifyEqual(forward.callCount,2);
            testCase.verifyEqual(forward.planCreationCount,1);
            testCase.verifyEqual(forward.planReuseCount,1);
            testCase.verifyEqual(forward.minimumBatchCount,1);
            testCase.verifyEqual(forward.maximumBatchCount,16);
            testCase.verifyEqual(forward.sourceIssue,43);
            decoded = jsondecode(jsonencode(records));
            testCase.verifyEqual(numel(decoded),2);
            testCase.verifyEqual(string(decoded(1).implementation),"fftw");
            clear cleanup
        end

        function invalidCanonicalShapesAreRejected(testCase)
            services = MockWVVerticalTransformServices(struct());
            strategy = WVVerticalTransformConstantStratification.createWithServices(7,5,"builtin",services.serviceRecord());
            cleanup = onCleanup(@()delete(strategy));
            [DCT,iDCT,~,~] = testCase.fallbackMatrices(7,5);
            testCase.verifyError(@()strategy.transformForward(zeros(6,4),"cosine",DCT),"WaveVortexModel:InvalidVerticalTransformShape");
            testCase.verifyError(@()strategy.transformForward(zeros(7,4),"cosine",zeros(4,7)),"WaveVortexModel:InvalidVerticalFallbackShape");
            testCase.verifyError(@()strategy.transformBack(zeros(4,4),"cosine",iDCT),"WaveVortexModel:InvalidVerticalTransformShape");
            testCase.verifyError(@()strategy.transformBack(zeros(5,4),"cosine",zeros(6,5)),"WaveVortexModel:InvalidVerticalFallbackShape");
            clear cleanup
        end
    end

    methods (Static, Access=private)
        function capabilities = actualIssue43Capabilities()
            capabilities = FFTWBackend.capabilities();
            capabilities.provider.id = "matlab-bundled";
            capabilities.modules.r2r.identityValidated = true;
            capabilities.features.dct1.isAvailable = true;
            capabilities.features.dct1.maximumRelativeError = 0;
            capabilities.features.dst1.isAvailable = true;
            capabilities.features.dst1.maximumRelativeError = 0;
        end

        function capabilities = smallEligibleCapabilities(Nz,minimumBatchCount,maximumBatchCount)
            capabilities = TestWVVerticalTransformConstantStratification.actualIssue43Capabilities();
            records = capabilities.eligibility.realToReal.records;
            template = records(1);
            combinations = { ...
                "real","cosine","forward"; "real","cosine","inverse"; ...
                "real","sine","forward"; "real","sine","inverse"; ...
                "complex","cosine","forward"; "complex","cosine","inverse"; ...
                "complex","sine","forward"; "complex","sine","inverse"};
            records = repmat(template,8,1);
            for iRecord = 1:8
                records(iRecord).Nz = Nz;
                records(iRecord).dataType = combinations{iRecord,1};
                records(iRecord).transformType = combinations{iRecord,2};
                records(iRecord).direction = combinations{iRecord,3};
                records(iRecord).eligible = true;
                records(iRecord).intervals = struct("minimumBatchCount",minimumBatchCount,"maximumBatchCount",maximumBatchCount);
            end
            capabilities.eligibility.realToReal.records = records;
            capabilities.eligibility.realToReal.sourceIssue = 43;
            capabilities.eligibility.realToReal.sourceArtifact = "issue43-test-artifact.json";
        end

        function [DCT,iDCT,DST,iDST] = fallbackMatrices(Nz,Nj)
            DCT = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformForwardMatrix(Nz);
            DCT = DCT(1:Nj,:);
            iDCT = WVGeometryDoublyPeriodicStratifiedConstant.CosineTransformBackMatrix(Nz);
            iDCT = iDCT(:,1:Nj);
            DST = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformForwardMatrix(Nz);
            DST = [zeros(1,Nz); DST];
            DST = DST(1:Nj,:);
            iDST = WVGeometryDoublyPeriodicStratifiedConstant.SineTransformBackMatrix(Nz);
            iDST = [zeros(Nz,1) iDST];
            iDST = iDST(:,1:Nj);
        end

        function error = relativeError(actual,expected)
            denominator = max(norm(expected(:),Inf),eps);
            error = norm(actual(:)-expected(:),Inf)/denominator;
        end
    end
end

function output = setNestedTwo(input,first,second,value)
input.(first).(second) = value;
output = input;
end

function output = setNestedThree(input,first,second,third,value)
input.(first).(second).(third) = value;
output = input;
end
