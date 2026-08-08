classdef TestStableAPIDocumentation < matlab.unittest.TestCase
    properties
        repositoryRoot (1,1) string
    end

    methods (TestMethodSetup)
        function locateRepository(testCase)
            testCase.repositoryRoot = string(fileparts(fileparts(mfilename("fullpath"))));
        end
    end

    methods (Test,TestTags="full")
        function abstractTransformListsStableFamilies(testCase)
            page = testCase.generatedTransformPage("wvtransform","index.md");
            stableFamilies = [
                "WVTransformConstantStratification"
                "WVTransformHydrostatic"
                "WVTransformBoussinesq"
                "WVTransformStratifiedQG"
                "WVTransformBarotropicQG"
                ];
            for family = stableFamilies'
                testCase.verifySubstring(page,"`" + family + "`");
            end
            testCase.verifyFalse(contains(page,"WVTransformSingleMode"));
            testCase.verifyFalse(contains(page,"Cartesian2DBarotropic"));
        end

        function constructorPagesUseCurrentDeclarations(testCase)
            expectations = {
                "wvtransformconstantstratification", "WVTransformConstantStratification", ["options.N0" "options.isHydrostatic"]
                "wvtransformhydrostatic", "WVTransformHydrostatic", ["options.N2Function" "options.rhoFunction"]
                "wvtransformboussinesq", "WVTransformBoussinesq", ["options.N2Function" "options.rhoFunction"]
                "wvtransformstratifiedqg", "WVTransformStratifiedQG", ["options.N2Function" "options.rhoFunction"]
                "wvtransformbarotropicqg", "WVTransformBarotropicQG", "options.h"
                };
            for iExpectation = 1:size(expectations,1)
                folder = expectations{iExpectation,1};
                className = expectations{iExpectation,2};
                page = testCase.generatedTransformPage(folder,folder + ".md");
                testCase.verifySubstring(page,"wvt = " + className + "(");
                testCase.verifySubstring(page,"new `" + className + "` instance");
                for option = expectations{iExpectation,3}
                    testCase.verifySubstring(page,"`" + option + "`");
                end
                testCase.verifyFalse(contains(page,"WaveVortexTranform"));
                if className ~= "WVTransformHydrostatic"
                    testCase.verifyFalse(contains(page,"WVTransformHydrostatic instance"), ...
                        "A copied Hydrostatic return description remains in " + className + ".");
                end
            end
        end

        function waveVortexCoefficientsAreProminent(testCase)
            abstractPage = testCase.generatedTransformPage("wvtransform","index.md");
            coefficientSection = extractBetween(abstractPage,"+ Wave-vortex coefficients","+ State variables");
            for name = ["Ap" "Am" "A0"]
                testCase.verifySubstring(coefficientSection,"[`" + name + "`]");
            end

            waveBearing = [
                "wvtransformconstantstratification"
                "wvtransformhydrostatic"
                "wvtransformboussinesq"
                ];
            for folder = waveBearing'
                page = testCase.generatedTransformPage(folder,"index.md");
                for name = ["Ap" "Am" "A0"]
                    testCase.verifySubstring(page,"wvtransform/" + lower(name) + ".html");
                end
                for name = ["Apt" "Amt" "A0t"]
                    testCase.verifySubstring(page,"[`" + name + "`]");
                end
            end

            qgTransforms = ["wvtransformstratifiedqg" "wvtransformbarotropicqg"];
            for folder = qgTransforms
                page = testCase.generatedTransformPage(folder,"index.md");
                testCase.verifySubstring(page,"wvtransform/a0.html");
                testCase.verifySubstring(page,"no active `Ap`, `Am`, `Apt`, or `Amt` content");
                testCase.verifySubstring(page,"[`A0t`]");
            end
        end

        function lowLevelCoefficientArraysAreDeveloperReference(testCase)
            page = testCase.generatedTransformPage("wvtransformconstantstratification","index.md");
            developerSection = extractAfter(page,"## Developer Topics");
            testCase.verifySubstring(developerSection,"Projection coefficients");
            testCase.verifySubstring(developerSection,"Reconstruction coefficients");
            for name = ["A0N" "A0U" "A0V" "UAp" "VAm" "NA0"]
                testCase.verifySubstring(developerSection,"[`" + name + "`]");
            end

            source = fileread(fullfile(testCase.repositoryRoot,"@WVTransform","detailedDescriptions","ApU.md"));
            testCase.verifySubstring(source,"projection coefficients");
            testCase.verifyFalse(contains(source,"sorting matrix"));
        end

        function reviewedPagesContainNoObsoleteReferenceText(testCase)
            relativePaths = [
                "classes/transforms/wvtransform/index.md"
                "classes/transforms/wvtransformconstantstratification/index.md"
                "classes/transforms/wvtransformhydrostatic/index.md"
                "classes/transforms/wvtransformboussinesq/index.md"
                "classes/transforms/wvtransformstratifiedqg/index.md"
                "classes/transforms/wvtransformbarotropicqg/index.md"
                "classes/wvmodel/index.md"
                ];
            forbidden = [
                "WVTransformSingleMode"
                "Cartesian2DBarotropic"
                "WaveVortexTranform"
                "sorting matrix"
                ];
            for relativePath = relativePaths'
                page = fileread(fullfile(testCase.repositoryRoot,"docs",relativePath));
                for phrase = forbidden'
                    testCase.verifyFalse(contains(page,phrase),relativePath + " contains " + phrase + ".");
                end
            end

            interpolationPage = testCase.generatedTransformPage("wvtransform","variableatpositionwithname.md");
            testCase.verifySubstring(interpolationPage,"`linear`");
            testCase.verifySubstring(interpolationPage,"`spline`");
            testCase.verifyFalse(contains(interpolationPage,"`exact`"));
            testCase.verifyFalse(contains(interpolationPage,"`finufft`"));
        end

        function documentedConstructorsExecute(testCase)
            Lxyz = [40e3 30e3 2e3];
            Nxyz = [8 6 5];
            N2 = @(z)(5.2e-3)^2*ones(size(z));

            transforms = {
                WVTransformConstantStratification(Lxyz,Nxyz,N0=5.2e-3,latitude=45)
                WVTransformConstantStratification(Lxyz,Nxyz,N0=5.2e-3,latitude=45,isHydrostatic=true)
                WVTransformHydrostatic(Lxyz,Nxyz,N2Function=N2,latitude=45)
                WVTransformBoussinesq(Lxyz,Nxyz,N2Function=N2,latitude=45)
                WVTransformStratifiedQG(Lxyz,Nxyz,N2Function=N2,latitude=45)
                WVTransformBarotropicQG(Lxyz(1:2),Nxyz(1:2),h=0.8,latitude=45)
                };
            expectedClasses = [
                "WVTransformConstantStratification"
                "WVTransformConstantStratification"
                "WVTransformHydrostatic"
                "WVTransformBoussinesq"
                "WVTransformStratifiedQG"
                "WVTransformBarotropicQG"
                ];
            testCase.verifyEqual(string(cellfun(@class,transforms,UniformOutput=false)),expectedClasses);

            linearModel = WVModel(transforms{1},shouldUseLinearDynamics=true);
            transforms{2}.addForcing(WVAdaptiveDamping(transforms{2}));
            nonlinearModel = WVModel(transforms{2});
            testCase.verifyTrue(linearModel.isDynamicsLinear);
            testCase.verifyFalse(nonlinearModel.isDynamicsLinear);
        end

        function coefficientClaimsMatchTransformState(testCase)
            wvt = WVTransformConstantStratification([40e3 30e3 2e3],[8 6 5],N0=5.2e-3,latitude=45);
            testCase.verifyEqual(size(wvt.Ap),size(wvt.Am));
            testCase.verifyEqual(size(wvt.Ap),size(wvt.A0));
            testCase.verifyEqual(string(wvt.propertyAnnotationWithName("Ap").units),"m/s");
            testCase.verifyEqual(string(wvt.propertyAnnotationWithName("Am").units),"m/s");
            testCase.verifyEqual(string(wvt.propertyAnnotationWithName("A0").units),"m^2 s^{-1}");
            testCase.verifyEqual(string(wvt.propertyAnnotationWithName("A0t").units),"m^2 s^{-1}");

            waveIndex = find(wvt.waveComponent.maskAp,1);
            wvt.Ap(waveIndex) = 1.25 - 0.5i;
            wvt.t0 = 7;
            wvt.t = 19;
            expected = wvt.Ap(waveIndex)*exp(1i*wvt.Omega(waveIndex)*(wvt.t-wvt.t0));
            testCase.verifyEqual(wvt.Apt(waveIndex),expected,AbsTol=10*eps(abs(expected)));
            testCase.verifyEqual(wvt.Ap(waveIndex),1.25 - 0.5i);

            wvt.initWithInertialMotions(@(z)0.1*ones(size(z)),@(z)zeros(size(z)));
            maskAp = logical(wvt.inertialComponent.maskAp);
            maskAm = logical(wvt.inertialComponent.maskAm);
            testCase.verifyEqual(wvt.Am(maskAm),conj(wvt.Ap(maskAp)));

            qg = WVTransformBarotropicQG([40e3 30e3],[8 6],h=0.8,latitude=45);
            testCase.verifyFalse(qg.hasVariableWithName("Ap"));
            testCase.verifyFalse(qg.hasVariableWithName("Am"));
            testCase.verifyTrue(qg.hasVariableWithName("A0"));
            testCase.verifyEqual(qg.A0t,qg.A0);
        end
    end

    methods (Access=private)
        function page = generatedTransformPage(testCase,folder,file)
            page = string(fileread(fullfile(testCase.repositoryRoot,"docs","classes","transforms",folder,file)));
        end
    end
end
