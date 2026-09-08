classdef TestProductProjection < matlab.unittest.TestCase
    methods (Test)
        function reproducesProviderTrigonometricCutoff(testCase)
            N2 = @(z) 1e-4*ones(size(z));
            basis = IMSolverSpectral(nEVP=160).solveEVP(IMInternalModes.hydrostaticFModes(N2=N2,zDomain=[-1000 0]),nModes=10);
            z = linspace(-1000,0,13).';
            weights = [0.5;ones(11,1);0.5]*(1000/12);
            [transform,assessment] = basis.discreteTransform(z=z,weights=weights,nModes=10,variables=["F","G"],gramTolerance=10,quadraticAliasingTolerance=10);
            errors = independentChannels(basis,transform,257);
            testCase.verifyEqual(errors,assessment.prefixDiagnostics.quadraticAliasingError,AbsTol=1e-9)
            testCase.verifyLessThan(errors(8),1e-8)
            testCase.verifyGreaterThan(errors(9),0.9)
        end

        function signedAPVPreservesTheProviderPairing(testCase)
            N2 = @(z) 1e-4*ones(size(z));
            evp = IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-4000 0],g0=-1,gd=-1,surfaceBoundary="rigidLid");
            basis = IMSolverSpectral(nEVP=160).solveEVP(evp,nModes=4);
            z = linspace(-4000,0,25).';
            weights = [0.5;ones(23,1);0.5]*(4000/24);
            [transform,assessment] = basis.discreteTransform(z=z,weights=weights,nModes=4,variables=["F","G"],gramTolerance=10,quadraticAliasingTolerance=10);
            testCase.verifyFalse(transform.targetGramIsPositiveDefinite(variable="G"))
            testCase.verifyEqual(independentChannels(basis,transform,513),assessment.prefixDiagnostics.quadraticAliasingError,AbsTol=1e-8)
        end

        function zeroAndComplexProductsUsePositiveNorm(testCase)
            context = struct(sampleValues=1,sampleMetric=1,sampleGram=1,targetGram=1,majorantGram=1,active=true,referenceValues=1,volumeWeights=1,endpointValues=zeros(2,1),endpointMetric=[0;0]);
            result = measureProductProjection(context,[0 2i],[0 1i],zeros(2,2),1);
            testCase.verifyEqual(result.error,[0 1])
            testCase.verifyEqual(result.isZero,[true false])
            testCase.verifyError(@()measureProductProjection(context,1,0,zeros(2,1),1),'WVStudy:InvalidReferenceNorm')
        end

        function exteriorContentIsNotAliasing(testCase)
            z = linspace(-1,1,5).';
            weights = [.25;.5;.5;.5;.25];
            context = struct(sampleValues=ones(5,1),sampleMetric=diag(weights),sampleGram=2,targetGram=2,majorantGram=2,active=true,referenceValues=ones(5,1),volumeWeights=weights,endpointValues=ones(2,1),endpointMetric=[0;0]);
            result = measureProductProjection(context,z,z,[-1;1],1);
            testCase.verifyEqual(result.error,0,AbsTol=1e-15)
            testCase.verifyGreaterThan(result.productNormSquared,0)
        end
    end
end

function errors = independentChannels(basis,transform,order)
n = length(transform.modeNumber);
solver = IMSolverSpectral(nEVP=order).configuredForEVP(basis.evp);
[z,w] = solver.nativeQuadratureRule(basis.zDomain);
S = struct(F=transform.inverseMatrix(variable="F"),G=transform.inverseMatrix(variable="G"));
R = struct(F=basis.F(z),G=basis.G(z));
E = struct(F=basis.F(basis.zDomain(:)),G=basis.G(basis.zDomain(:)));
[i,j] = ndgrid(1:n); i=i(:).'; j=j(:).';
channels = ["F" "F" "F";"G" "G" "F";"F" "G" "G"];
errors = zeros(n,1);
for c = 1:3
    a=channels(c,1); b=channels(c,2); target=channels(c,3);
    context = prepareProductProjection(basis,transform,target,z,w);
    result = measureProductProjection(context,S.(a)(:,i).*S.(b)(:,j),R.(a)(:,i).*R.(b)(:,j),E.(a)(:,i).*E.(b)(:,j),1:n);
    for count = 1:n
        errors(count) = max(errors(count),max(result.error(count,max(i,j)<=count)));
    end
end
end
