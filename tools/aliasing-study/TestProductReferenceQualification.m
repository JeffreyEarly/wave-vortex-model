classdef TestProductReferenceQualification < matlab.unittest.TestCase
    methods (Test)
        function tinyOverlapNeedsExplicitAbsoluteBudget(testCase)
            context=struct(active=true,majorantGram=1);
            low=struct(productNormSquared=1e-28,referenceCoefficients={{1e-14}});
            high=struct(productNormSquared=1e-30,referenceCoefficients={{1e-15}});
            q=WVInternal.qualifyProductReferences(context,low,high,1,1,1e-4,1e-10);
            testCase.verifyLessThan(q.allowanceFraction,1)
            testCase.verifyTrue(q.usesAbsoluteAllowance)
            testCase.verifyGreaterThan(q.relativeError,1)
            strict=WVInternal.qualifyProductReferences(context,low,high,1,1,1e-4,0);
            testCase.verifyGreaterThan(strict.allowanceFraction,1)
        end
        function materialCoefficientAndNormErrorsStillFail(testCase)
            context=struct(active=true,majorantGram=1);
            high=struct(productNormSquared=1e-28,referenceCoefficients={{1e-14}});
            low=high; low.referenceCoefficients={1e-3};
            q=WVInternal.qualifyProductReferences(context,low,high,1,1,1e-4,1e-10);
            testCase.verifyGreaterThan(q.allowanceFraction,1)
            low=high; low.productNormSquared=1e-6;
            q=WVInternal.qualifyProductReferences(context,low,high,1,1,1e-4,1e-10);
            testCase.verifyGreaterThan(q.allowanceFraction,1)
        end
        function rescalingInputsDoesNotChangeQualification(testCase)
            context=struct(active=true,majorantGram=1);
            values=zeros(1,3);
            for j=1:3
                scales=[1e-120 1 1e120]; s=scales(j);
                low=struct(productNormSquared=(2e-14*s)^2,referenceCoefficients={{2e-14*s}});
                high=struct(productNormSquared=(1e-14*s)^2,referenceCoefficients={{1e-14*s}});
                q=WVInternal.qualifyProductReferences(context,low,high,1,s,1e-4,1e-10);
                values(j)=q.allowanceFraction;
            end
            testCase.verifyEqual(values,repmat(values(2),1,3),RelTol=1e-12)
        end
        function physicalScaleIncludesSignedEndpointsAndDerivativeFactor(testCase)
            context=struct(volumeWeights=[1;2],endpointMetric=[-3;4]);
            a=[1;2]; b=[3;4]; ea=[2;1]; eb=[5;6];
            scale=WVInternal.productReferenceScale(context,a,b,ea,eb);
            productNorm=sqrt(sum(context.volumeWeights.*abs(a.*b).^2)+sum(abs(context.endpointMetric).*abs(ea.*eb).^2));
            testCase.verifyGreaterThanOrEqual(scale,productNorm)
            scaled=WVInternal.productReferenceScale(context,7i*a,11*b,7i*ea,11*eb);
            testCase.verifyEqual(scaled,77*scale,RelTol=1e-14)
            volume=WVInternal.productReferenceScale(struct(volumeWeights=[1;2],endpointMetric=[0;0]),a,b,ea,eb);
            testCase.verifyGreaterThan(scale,volume)
        end
        function zeroAndUnmeasurableReferencesAreNotConfused(testCase)
            context=struct(active=true,majorantGram=1);
            zero=struct(productNormSquared=0,referenceCoefficients={{0}});
            q=WVInternal.qualifyProductReferences(context,zero,zero,1,0,1e-4,1e-10);
            testCase.verifyEqual(q.allowanceFraction,0)
            bad=zero; bad.referenceCoefficients={NaN};
            q=WVInternal.qualifyProductReferences(context,bad,zero,1,0,1e-4,1e-10);
            testCase.verifyEqual(q.allowanceFraction,Inf)
        end
    end
end
