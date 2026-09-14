classdef TestWaveModeConvergencePreparation < matlab.unittest.TestCase
    properties (TestParameter)
        profile = {"constant","exponential","sharp"}
    end

    methods (TestClassSetup)
        function addFixtures(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename("fullpath")),"Fixtures")));
        end
    end

    methods (Test, TestTags="full")
        function pairedBatchesMatchIndependentScalarPreparation(testCase,profile)
            candidateNEVP = 36;
            referenceNEVP = 52;
            nQuadrature = 2*max(candidateNEVP,referenceNEVP)+1;
            [candidate,reference] = waveCollections(profile,900,candidateNEVP,referenceNEVP);
            candidate = withScaledNormalization(candidate,3);
            reference = withScaledNormalization(reference,1);
            candidatePages = [3 1 2 3];
            referencePages = [1 2 3 1];
            kappa = [3e-4 0 1e-9 3e-4];
            rule = IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(candidate.bases{1}.evp);
            [z,weights] = rule.nativeQuadratureRule([-900 0]);
            actualCandidate = cell(1,numel(kappa));
            actualReference = cell(1,numel(kappa));
            coverage = zeros(size(kappa));
            callbackCount = 0;

            WVInternal.prepareWaveModeConvergenceBatches(candidate,reference,z,kappa,@consume, ...
                candidatePages=candidatePages,referencePages=referencePages,candidateNEVP=candidateNEVP, ...
                referenceNEVP=referenceNEVP,nQuadrature=nQuadrature,pageChunkSize=2);

            testCase.verifyEqual(callbackCount,2)
            testCase.verifyEqual(coverage,ones(size(coverage)))
            for position = 1:numel(kappa)
                candidateBasis = candidate.bases{candidate.basisIndex(candidatePages(position))};
                referenceBasis = reference.bases{reference.basisIndex(referencePages(position))};
                expectedCandidate = scalarPrepared(candidateBasis,z,kappa(position),candidateNEVP,nQuadrature);
                expectedReference = scalarPrepared(referenceBasis,z,kappa(position),referenceNEVP,nQuadrature);
                verifyPrepared(testCase,actualCandidate{position},expectedCandidate)
                verifyPrepared(testCase,actualReference{position},expectedReference)
                actualReport = assessModeConvergence(actualCandidate{position},actualReference{position},z,weights);
                expectedReport = assessModeConvergence(expectedCandidate,expectedReference,z,weights);
                verifyStableReport(testCase,actualReport,expectedReport)
            end

            function consume(candidateChunk,referenceChunk,positions,chunkCandidatePages,chunkReferencePages)
                testCase.verifyLessThanOrEqual(numel(positions),2)
                testCase.verifySize(candidateChunk,[1 numel(positions)])
                testCase.verifySize(referenceChunk,[1 numel(positions)])
                testCase.verifyEqual(chunkCandidatePages,candidatePages(positions))
                testCase.verifyEqual(chunkReferencePages,referencePages(positions))
                actualCandidate(positions) = candidateChunk;
                actualReference(positions) = referenceChunk;
                coverage(positions) = coverage(positions)+1;
                callbackCount = callbackCount+1;
            end
        end

        function successiveCallsUseTheirOwnResolutionDomainAndGrid(testCase)
            configurations = {
                struct(profile="constant",depth=500,candidateNEVP=28,referenceNEVP=40,kappa=2e-9)
                struct(profile="exponential",depth=1400,candidateNEVP=34,referenceNEVP=48,kappa=2e-4)
                };
            for iConfiguration = 1:numel(configurations)
                configuration = configurations{iConfiguration};
                nQuadrature = 2*configuration.referenceNEVP+1;
                [candidate,reference] = singleWavePair(configuration);
                z = linspace(-configuration.depth,0,13+4*iConfiguration).';
                actualCandidate = [];
                actualReference = [];
                WVInternal.prepareWaveModeConvergenceBatches(candidate,reference,z,configuration.kappa,@consume, ...
                    candidateNEVP=configuration.candidateNEVP,referenceNEVP=configuration.referenceNEVP, ...
                    nQuadrature=nQuadrature,pageChunkSize=1);
                expectedCandidate = scalarPrepared(candidate.bases{1},z,configuration.kappa,configuration.candidateNEVP,nQuadrature);
                expectedReference = scalarPrepared(reference.bases{1},z,configuration.kappa,configuration.referenceNEVP,nQuadrature);
                verifyPrepared(testCase,actualCandidate,expectedCandidate)
                verifyPrepared(testCase,actualReference,expectedReference)
            end

            function consume(candidateChunk,referenceChunk,varargin)
                actualCandidate = candidateChunk{1};
                actualReference = referenceChunk{1};
            end
        end

        function finiteDifferenceCollectionsRetainScalarFallback(testCase)
            depth = 700;
            N2 = @(z) 7e-5*(1+0.15*exp(z/250));
            surface = IMBoundaryCondition(a=0,b=1,c=1,d=0);
            candidate = IMSolverFiniteDifference(z=linspace(-depth,0,41).').solveWaveModesAtWavenumbers(2e-4, ...
                N2=N2,zDomain=[-depth 0],f0=1e-4,g=9.81,surfaceBoundary=surface,nModes=3);
            reference = IMSolverFiniteDifference(z=linspace(-depth,0,61).').solveWaveModesAtWavenumbers(2e-4, ...
                N2=N2,zDomain=[-depth 0],f0=1e-4,g=9.81,surfaceBoundary=surface,nModes=3);
            z = linspace(-depth,0,19).';
            actualCandidate = [];
            actualReference = [];
            WVInternal.prepareWaveModeConvergenceBatches(candidate,reference,z,2e-4,@consume, ...
                candidateNEVP=41,referenceNEVP=61,nQuadrature=19,pageChunkSize=1);
            expectedCandidate = scalarPrepared(candidate.bases{1},z,2e-4,41,19);
            expectedReference = scalarPrepared(reference.bases{1},z,2e-4,61,19);
            verifyPrepared(testCase,actualCandidate,expectedCandidate)
            verifyPrepared(testCase,actualReference,expectedReference)

            function consume(candidateChunk,referenceChunk,varargin)
                actualCandidate = candidateChunk{1};
                actualReference = referenceChunk{1};
            end
        end

        function customBasisFallbackPreservesOverriddenValues(testCase)
            configuration = struct(profile="sharp",depth=600,candidateNEVP=30,referenceNEVP=42,kappa=1e-4);
            [candidate,reference] = singleWavePair(configuration);
            baseCandidate = candidate.bases{1};
            baseReference = reference.bases{1};
            candidate = withOverriddenBasis(candidate);
            reference = withOverriddenBasis(reference);
            z = linspace(-configuration.depth,0,17).';
            actualCandidate = [];
            actualReference = [];
            WVInternal.prepareWaveModeConvergenceBatches(candidate,reference,z,configuration.kappa,@consume, ...
                candidateNEVP=configuration.candidateNEVP,referenceNEVP=configuration.referenceNEVP,nQuadrature=17,pageChunkSize=1);
            verifyPrepared(testCase,actualCandidate,scalarPrepared(candidate.bases{1},z,configuration.kappa,configuration.candidateNEVP,17))
            verifyPrepared(testCase,actualReference,scalarPrepared(reference.bases{1},z,configuration.kappa,configuration.referenceNEVP,17))
            testCase.verifyEqual(actualCandidate.values.F,1.25*baseCandidate.F(z),AbsTol=1e-12)
            testCase.verifyEqual(actualCandidate.values.G,0.75*baseCandidate.G(z),AbsTol=1e-12)
            testCase.verifyEqual(actualReference.values.F,1.25*baseReference.F(z),AbsTol=1e-12)
            testCase.verifyEqual(actualReference.values.G,0.75*baseReference.G(z),AbsTol=1e-12)

            function consume(candidateChunk,referenceChunk,varargin)
                actualCandidate = candidateChunk{1};
                actualReference = referenceChunk{1};
            end
        end
    end
end

function [candidate,reference] = waveCollections(profile,depth,candidateNEVP,referenceNEVP)
N2 = stratification(profile,depth);
surface = IMBoundaryCondition(a=0,b=1,c=1,d=0);
candidate = IMSolverSpectral(nEVP=candidateNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers([0 1e-9 3e-4], ...
    N2=N2,zDomain=[-depth 0],f0=1e-4,g=9.81,surfaceBoundary=surface,nModes=[3 2],nInertialModes=2);
reference = IMSolverSpectral(nEVP=referenceNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers([3e-4 0 1e-9], ...
    N2=N2,zDomain=[-depth 0],f0=1e-4,g=9.81,surfaceBoundary=surface,nModes=[2 3],nInertialModes=2);
end

function [candidate,reference] = singleWavePair(configuration)
N2 = stratification(configuration.profile,configuration.depth);
surface = IMBoundaryCondition(a=0,b=1,c=1,d=0);
solverArguments = {"N2",N2,"zDomain",[-configuration.depth 0],"f0",1e-4,"g",9.81,"surfaceBoundary",surface,"nModes",3};
candidate = IMSolverSpectral(nEVP=configuration.candidateNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers(configuration.kappa,solverArguments{:});
reference = IMSolverSpectral(nEVP=configuration.referenceNEVP,coordinateKind="wkb").solveWaveModesAtWavenumbers(configuration.kappa,solverArguments{:});
end

function N2 = stratification(profile,depth)
switch profile
    case "constant"
        N2 = @(z) 8e-5*ones(size(z));
    case "exponential"
        N2 = @(z) 1e-4*exp(2*z/(0.7*depth));
    case "sharp"
        N2 = @(z) 2e-5+8e-5*(1+tanh((z+0.42*depth)/(0.04*depth)))/2;
end
end

function collection = withScaledNormalization(collection,page)
bases = collection.bases;
iBasis = collection.basisIndex(page);
basis = bases{iBasis}.addNormalization("scaled",@(b,j) (2+0.1*j).*b.innerProductNormFactor(j));
basis.normalization = "scaled";
bases{iBasis} = basis;
collection = IMBasisCollection(bases,kappa=collection.kappa,basisIndex=collection.basisIndex,sourcePage=collection.sourcePage);
end

function collection = withOverriddenBasis(collection)
bases = collection.bases;
bases{1} = OverriddenWaveModeBasis(bases{1});
collection = IMBasisCollection(bases,kappa=collection.kappa,basisIndex=collection.basisIndex,sourcePage=collection.sourcePage);
end

function prepared = scalarPrepared(basis,z,kappa,nEVP,nQuadrature)
factors = basis.normalizationFactors(basis.normalization);
dG = basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
dF = basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors.*basis.h(:).';
identity = struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
provenance = struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=nEVP,quadratureCount=nQuadrature,source="explicit construction basis");
prepared = struct(identity=identity,values=struct(F=basis.F(z),G=basis.G(z)),derivatives=struct(F=dF,G=dG),equivalentDepths=basis.h,provenance=provenance);
end

function verifyPrepared(testCase,actual,expected)
testCase.verifyEqual(string(fieldnames(actual)),string(fieldnames(expected)))
testCase.verifyEqual(actual.identity,expected.identity)
testCase.verifyEqual(actual.equivalentDepths,expected.equivalentDepths,AbsTol=0)
testCase.verifyEqual(actual.provenance,expected.provenance)
for group = ["values" "derivatives"]
    testCase.verifyEqual(string(fieldnames(actual.(group))),string(fieldnames(expected.(group))))
    for quantity = string(fieldnames(expected.(group))).'
        testCase.verifyEqual(actual.(group).(quantity),expected.(group).(quantity),char(group+"."+quantity), ...
            AbsTol=5e-10,RelTol=5e-11)
    end
end
end

function verifyStableReport(testCase,actual,expected)
testCase.verifyEqual(actual.identity,expected.identity)
testCase.verifyEqual(actual.matches,expected.matches)
testCase.verifyEqual(removevars(actual.measurements,"value"),removevars(expected.measurements,"value"))
testCase.verifyEqual(isnan(actual.measurements.value),isnan(expected.measurements.value))
measured = isfinite(expected.measurements.value);
testCase.verifyEqual(actual.measurements.value(measured),expected.measurements.value(measured),AbsTol=1e-12)
testCase.verifyEqual(actual.provenance,expected.provenance)
testCase.verifyEqual(actual.coverage,expected.coverage)
end
