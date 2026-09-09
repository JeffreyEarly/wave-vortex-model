classdef TestPerKappaWaveAssessment < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function defaultReferenceChecksEveryRequestedPrefix(testCase)
            [w,a]=newTransform();
            testCase.verifyEqual(a.pages.requestedCount,w.waveModeCountByKh)
            testCase.verifyEqual(a.pages.selectedCount,w.waveModeCountByKh)
            testCase.verifyEqual(a.pages.status,repmat("accepted",numel(w.khUnique),1))
            testCase.verifyEqual(a.pages.convergedCount,w.waveModeCountByKh)
            testCase.verifyNotEmpty(a.referenceNEVP)
            testCase.verifyNotEmpty(a.inertial.convergence)
        end

        function explicitReferenceAssessesActualPageIdentities(testCase)
            baseline = newTransform();
            counts = mod(2*(0:numel(baseline.khUnique)-1).',5);
            [w,a] = newTransform(waveModeKappa=flipud(baseline.khUnique),waveModeCount=flipud(counts),referenceNEVP=128);
            testCase.verifyEqual(a.pages.requestedCount,counts)
            testCase.verifyEqual(a.pages.convergedCount,counts)
            testCase.verifyEqual(a.pages.gridSupportedCount,counts)
            testCase.verifyEqual(a.pages.usableCount,counts)
            testCase.verifyEqual(a.pages.candidateLimitReached,counts>0)
            for p = 1:numel(counts)
                if counts(p)==0
                    testCase.verifyEqual(a.pages.status(p),"not-requested")
                    testCase.verifyEmpty(a.modeConvergence{p})
                    testCase.verifyEmpty(a.prefixGramError{p})
                else
                    report = a.modeConvergence{p};
                    testCase.verifyEqual(report.identity.kappa,w.khUnique(p))
                    testCase.verifyEqual(report.identity.columnLabels,string(w.waveModeNumber(1:counts(p))).')
                    testCase.verifyEqual(report.provenance.candidate.nEVP,w.nEVP)
                    testCase.verifyEqual(report.provenance.reference.nEVP,128)
                    testCase.verifyEqual(report.provenance.candidate.source,"explicit construction basis")
                    testCase.verifyEqual(report.coverage.requestedColumnCount,counts(p))
                    testCase.verifyFalse(report.coverage.absoluteAccuracyGuarantee)
                    testCase.verifyEqual(a.pages.status(p),"accepted")
                end
            end
            testCase.verifyEqual(a.inertial.requestedCount,numel(w.inertialMode))
            testCase.verifyEqual(a.inertial.convergence.identity.kappa,0)
            testCase.verifyEqual(a.inertial.convergence.identity.columnLabels,string(w.inertialModeNumber).')
            rows = ismember(a.inertial.convergence.measurements.quantity,["h1","equivalentDepth"]);
            testCase.verifyLessThan(max(a.inertial.convergence.measurements.value(rows)),1e-6)
        end

        function convergenceToleranceIsAConstructionRequirement(testCase)
            testCase.verifyError(@()newTransform(referenceNEVP=128,modeConvergenceTolerance=1e-16),'WV:UnconvergedBalancedModes')
            [w,a]=newTransform(referenceNEVP=128); plain=newTransform();
            original=w.scientificState(); without=plain.scientificState();
            testCase.verifyEqual(rmfield(original,{'N2Function','rhoFunction'}),rmfield(without,{'N2Function','rhoFunction'}))
            testCase.verifyTrue(all(a.pages.status=="accepted"))
        end

        function absentWavesStillAssessIndependentInertialFamily(testCase)
            [w,a] = newTransform(waveModeCount=0,referenceNEVP=128);
            testCase.verifyEmpty(w.waveMode)
            testCase.verifyEqual(a.pages.status,repmat("not-requested",numel(w.khUnique),1))
            testCase.verifyEqual(a.pages.usableCount,zeros(numel(w.khUnique),1))
            testCase.verifyFalse(any(a.pages.candidateLimitReached))
            testCase.verifyEqual(a.inertial.convergence.coverage.requestedColumnCount,3)
        end

        function referenceResolutionMustActuallyRefine(testCase)
            for resolution = {32,64,[96;128]}
                testCase.verifyError(@()newTransform(referenceNEVP=resolution{1}),'WVTransformFreeSurfaceBoussinesq:InvalidReferenceResolution')
            end
        end
    end
end

function [w,a] = newTransform(options)
arguments (Input)
    options.waveModeCount (:,1) double = 4
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.referenceNEVP (:,1) double = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double = 1e-6
end
args = namedargs2cell(options);
[w,a] = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},shouldAntialias=true,N2Function=@(z)1e-4*exp(2*z/700),apvModeCount=3,mdaModeCount=2,inertialModeCount=3);
end
