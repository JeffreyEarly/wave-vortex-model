classdef TestThermodynamicFormulationEquivalence < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyPath(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','thermodynamic-formulation-study')));
        end
    end
    methods (Test, TestTags="full")
        function analyticPhysicalStateAndTendenciesAgree(testCase)
            for profile=["constant","exponential"]
                for amplitude=[1e-6,.01,1]
                    a=thermodynamicFormulationFixture(profile,amplitude,32,65);
                    testCase.verifyGreaterThanOrEqual(min(a.r,[],'all'),-a.D);
                    testCase.verifyLessThanOrEqual(max(a.r,[],'all'),0);
                    testCase.verifyEqual(a.continuity,zeros(size(a.continuity)),AbsTol=1e-20);
                    testCase.verifyEqual(a.wi(:,:,[1 end]),zeros(size(a.wi(:,:,[1 end]))),AbsTol=1e-18);
                    testCase.verifyEqual(a.p(:,:,end),a.rho0*a.g*a.zeta,AbsTol=1e-10);
                    for forced=[false,true]
                        r=evaluateThermodynamicEquivalence(a,forced=forced);
                        testCase.verifyLessThan(r.densityReconstructionError,5e-13);
                        testCase.verifyLessThan(r.labelInverseError,2e-12);
                        testCase.verifyLessThan(r.buoyancyError,5e-17);
                        testCase.verifyLessThan(max([r.eRateError,r.hRateError,r.dRateError]),2e-18);
                        testCase.verifyLessThan(max([r.rhoEError,r.rhoHError,r.rhoDError,r.physicalDensityError]),2e-20);
                        testCase.verifyLessThan(r.workError,1e-21);
                    end
                end
            end
        end
        function pressureSplitRequiresConversion(testCase)
            a=thermodynamicFormulationFixture("exponential",1,32,65);
            r=evaluateThermodynamicEquivalence(a);
            testCase.verifyLessThan(r.pressureConversionError,2e-9);
            testCase.verifyGreaterThan(r.wrongPressureSplitError,1);
            testCase.verifyLessThan(r.productionError,1e-12);
        end
        function surfaceDensityVariableHasDifferentLinearLimit(testCase)
            for profile=["constant","exponential"]
                a=thermodynamicFormulationFixture(profile,.01,32,65);
                b=thermodynamicFormulationFixture(profile,.001,32,65);
                % At positive crests this identity is exact for both profiles.
                crest=a.zeta>0;
                testCase.verifyEqual(a.d(crest,1,end),a.h(crest,1,end)-a.zeta(crest),AbsTol=1e-14);
                if profile=="constant"
                    testCase.verifyEqual(a.h,a.eta,AbsTol=2e-13);
                    testCase.verifyEqual(a.d,a.eta-max(a.z,0),AbsTol=2e-13);
                else
                    ratio=max(abs(a.h-a.eta),[],'all')/max(abs(b.h-b.eta),[],'all');
                    testCase.verifyEqual(ratio,100,RelTol=.001);
                end
            end
        end
        function smoothFormulationRefinesToPhysicalOracle(testCase)
            coarse=evaluateThermodynamicEquivalence(thermodynamicFormulationFixture("exponential",1,4,5),numericalDerivatives=true);
            fine=evaluateThermodynamicEquivalence(thermodynamicFormulationFixture("exponential",1,32,65),numericalDerivatives=true);
            testCase.verifyLessThan(fine.hRateError,1e-14);
            testCase.verifyLessThan(fine.hRateError,coarse.hRateError/100);
            testCase.verifyLessThan(fine.productionError,coarse.productionError/100);
            % The piecewise physical-height variable is not spectrally smooth.
            testCase.verifyGreaterThan(fine.dRateError,1e-7);
        end
    end
end
