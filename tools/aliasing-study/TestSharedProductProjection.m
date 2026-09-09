classdef TestSharedProductProjection < matlab.unittest.TestCase
    methods (Test)
        function prescribedSignedDualMatchesOriginalAlgebra(testCase)
            context = exampleContext();
            sampled = [0 1i 2;0 2i 3;0 3i 4];
            reference = [0 2i 1;0 3i 2;0 4i 3;0 5i 4];
            endpoints = [0 1i 2;0 2i 1];
            counts = [1 2 3];
            expected = originalProjection(context,sampled,reference,endpoints,counts);
            prepared = prepareProductProjections(context,counts);
            actual = measureProductProjection(context,sampled,reference,endpoints,counts,projections=prepared);
            testCase.verifyEqual(actual,expected,AbsTol=1e-13)
            testCase.verifyEqual(measureProductProjection(context,sampled,reference,endpoints,counts),actual)
            testCase.verifyEqual(prepared{end}.projectionKind,"prescribedDual")
            testCase.verifyFalse(prepared{end}.supportsGramAssessment)
            testCase.verifyEqual(prepared{end}.activeColumnMask,[true true false])
            testCase.verifyEqual(prepared{end}.provenance.kind,"wvmStudyPrescribedDual")
            changed = context; changed.sampleMetric = 2*context.sampleMetric;
            rebuilt = measureProductProjection(changed,sampled,reference,endpoints,counts);
            testCase.verifyEqual(rebuilt,originalProjection(changed,sampled,reference,endpoints,counts),AbsTol=1e-13)
            testCase.verifyNotEqual(rebuilt.sampleCoefficients{end},actual.sampleCoefficients{end})
        end

        function illConditionedPrefixesRetainRejectionSentinels(testCase)
            context = exampleContext(); context.sampleGram(2,2) = 1e-14;
            result = measureProductProjection(context,ones(3,1),ones(4,1),zeros(2,1),[1 2 3]);
            testCase.verifyTrue(isfinite(result.error(1)))
            testCase.verifyEqual(result.error(2:3),[Inf;Inf])
            testCase.verifyTrue(all(isnan(result.sampleCoefficients{2})))
            testCase.verifyTrue(all(isnan(result.referenceCoefficients{3})))
        end

        function referenceComparisonUsesSameNormalization(testCase)
            context = exampleContext();
            low = measureProductProjection(context,ones(3,1),ones(4,1),zeros(2,1),[1 2]);
            high = measureProductProjection(context,ones(3,1),2*ones(4,1),zeros(2,1),[1 2]);
            expected = abs(sqrt(low.productNormSquared/high.productNormSquared)-1);
            for j = 1:2
                delta = low.referenceCoefficients{j}-high.referenceCoefficients{j};
                expected = max(expected,sqrt(real(delta'*context.majorantGram(1:j,1:j)*delta)/high.productNormSquared));
            end
            testCase.verifyEqual(compareProductReferences(context,low,high,[1 2]),expected,AbsTol=1e-14)
        end
    end
end

function context = exampleContext()
context = struct(sampleValues=[1 1i 0;2 3i 0;4 2i 0],sampleMetric=diag([.2 .3 .5]),sampleGram=diag([1.1 -1.8 0]),targetGram=diag([1 -2 0]),majorantGram=diag([1 2 0]),active=[true true false],referenceValues=[1 2i 0;2 1i 0;3 3i 0;4 4i 0],volumeWeights=[.1;.2;.3;.4],endpointValues=[1 2i 0;2 1i 0],endpointMetric=[.2;-.1]);
end

function result = originalProjection(context,sampled,reference,endpoints,counts)
% Independent pre-adoption algebra: solve after pairing each product.
sampledPairings = context.sampleValues'*(context.sampleMetric*sampled);
referencePairings = context.referenceValues'*(context.volumeWeights.*reference)+context.endpointValues'*(context.endpointMetric.*endpoints);
normSquared = real(sum(conj(reference).*(context.volumeWeights.*reference),1)+sum(abs(context.endpointMetric).*abs(endpoints).^2,1));
isZero = all(reference==0,1) & all(endpoints==0,1);
errors = zeros(numel(counts),size(sampled,2));
sampleCoefficients = cell(numel(counts),1); referenceCoefficients = sampleCoefficients;
for j = 1:numel(counts)
    active = find(context.active(1:counts(j)));
    sampleCoefficients{j} = context.sampleGram(active,active)\sampledPairings(active,:);
    referenceCoefficients{j} = context.targetGram(active,active)\referencePairings(active,:);
    delta = sampleCoefficients{j}-referenceCoefficients{j};
    numerator = real(sum(conj(delta).*(context.majorantGram(active,active)*delta),1));
    errors(j,~isZero) = sqrt(max(0,numerator(~isZero))./normSquared(~isZero));
end
result = struct(error=errors,productNormSquared=normSquared,isZero=isZero,sampleCoefficients={sampleCoefficients},referenceCoefficients={referenceCoefficients});
end
