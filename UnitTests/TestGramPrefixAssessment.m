classdef TestGramPrefixAssessment < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function prefixDiagnosticsPreserveCutoffSemantics(testCase)
            tolerance = 0.125;
            belowTolerance = tolerance-eps(tolerance)/2;
            aboveTolerance = tolerance+eps(tolerance);

            grams = cell(7,1);
            grams{1} = zeros(0);
            grams{2} = 1;
            grams{3} = eye(2); grams{3}(1,2) = belowTolerance;
            grams{4} = eye(2); grams{4}(1,2) = aboveTolerance;
            grams{5} = eye(5); grams{5}(1,2) = belowTolerance; grams{5}(3,4) = aboveTolerance;
            grams{6} = eye(3); grams{6}(1:2,1:2) = [1 1-eps(1); 1-eps(1) 1];
            grams{7} = eye(4); grams{7}(1,1) = 1+eps(1); grams{7}(2,2) = 1-eps(1)/2; grams{7}(3,4) = eps(1);
            counts = cellfun(@length,grams);

            inertialGram = eye(4);
            inertialGram(1,2) = belowTolerance;
            inertialGram(3,4) = aboveTolerance;
            state = craftedState(grams,inertialGram,tolerance);
            bases = realBasisCollection();
            activePages = find(counts>0);

            [actualAssessment,actualReference,actualConvergence] = WVInternal.assessWaveModeConstruction(state,bases,activePages,[],1e-6);
            % These block-diagonal/off-diagonal residuals have known singular values.
            expectedPrefixes = {zeros(0,1);0;[0;belowTolerance];[0;aboveTolerance]; ...
                [0;belowTolerance;belowTolerance;aboveTolerance;aboveTolerance]; ...
                [0;1-eps(1);1-eps(1)];eps(1)*ones(4,1)};
            testCase.verifyEqual(actualAssessment.prefixGramError,expectedPrefixes)
            testCase.verifyEqual(actualAssessment.inertial.prefixGramError,[0;belowTolerance;belowTolerance;aboveTolerance])
            testCase.verifyEmpty(actualReference)
            testCase.verifyTrue(all(cellfun(@isempty,actualConvergence.pages)))
            testCase.verifyEmpty(actualConvergence.inertial)
            testCase.verifyEqual(actualAssessment.pages.requestedCount,[0;1;2;2;5;3;4],AbsTol=0)
            testCase.verifyEqual(actualAssessment.pages.gridSupportedCount,[0;1;2;1;3;1;4],AbsTol=0)
            testCase.verifyEqual(actualAssessment.inertial.requestedCount,4,AbsTol=0)
            testCase.verifyEqual(actualAssessment.inertial.gridSupportedCount,3,AbsTol=0)
            testCase.verifyLessThan(actualAssessment.prefixGramError{3}(2),tolerance)
            testCase.verifyGreaterThan(actualAssessment.prefixGramError{4}(2),tolerance)
            testCase.verifyEmpty(actualAssessment.prefixGramError{1})
        end
    end
end

function state = craftedState(grams,inertialGram,tolerance)
counts = cellfun(@length,grams);
np = numel(grams);
nw = max(counts);
nz = max(nw,size(inertialGram,1))+2;
state = struct;
state.khUnique = (1:np).';
state.waveModeCountByKh = counts;
state.waveG = zeros(nz,nw,np);
state.waveGForward = zeros(nw,nz,np);
for p = 1:np
    count = counts(p);
    if count == 0, continue; end
    state.waveG(1:count,1:count,p) = eye(count);
    state.waveGForward(1:count,1:count,p) = grams{p};
end
inertialCount = size(inertialGram,1);
state.inertialMode = (1:inertialCount).';
state.inertialF = zeros(nz,inertialCount);
state.inertialF(1:inertialCount,:) = eye(inertialCount);
state.inertialFForward = zeros(inertialCount,nz);
state.inertialFForward(:,1:inertialCount) = inertialGram;
state.inertialGramError = norm(inertialGram-eye(inertialCount),2);
state.gramTolerance = tolerance;
state.nEVP = 16;
end

function bases = realBasisCollection()
solver = IMSolverSpectral(nEVP=16,coordinateKind="wkb");
bases = solver.solveWaveModesAtWavenumbers([0 1e-4],N2=@(z)1e-4*ones(size(z)),zDomain=[-1000 0],f0=1e-4,g=9.81, ...
    surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0),nModes=1,nInertialModes=1);
end
