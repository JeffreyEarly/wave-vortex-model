classdef TestPortableForcingContracts < matlab.unittest.TestCase
    properties
        wvt
    end

    methods (TestMethodSetup)
        function createTransform(testCase)
            testCase.wvt = WVTransformConstantStratification([1000 1000 100],[8 6 5],N0=5.2e-3,latitude=45,isHydrostatic=false);
        end
    end

    methods (Test, TestTags={'full'})
        function baseClassIsUnavailable(testCase)
            forcing = WVForcing(testCase.wvt,"base forcing",WVForcingType("Spectral"));
            contract = forcing.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"unavailable");
            testCase.verifyEqual(contract.typeIdentifier,"WVForcing");
        end

        function supportedForcingsReturnExactVersionedContracts(testCase)
            fixed = WVFixedAmplitudeForcing(testCase.wvt,name="fixed");
            pseudo = WVPseudoTopographicWaveGeneration(testCase.wvt,topographicHeight=zeros(testCase.wvt.Nx,testCase.wvt.Ny),barotropicVelocityAmplitude=[0.01;0],frequency=1e-4);
            forcings = {
                WVNonlinearAdvection(testCase.wvt), ...
                WVAdaptiveDamping(testCase.wvt), ...
                fixed, ...
                WVBottomFrictionQuadratic(testCase.wvt), ...
                pseudo, ...
                WVBetaPlanePVAdvection(testCase.wvt)};
            expected = ["WVNonlinearAdvection" "WVAdaptiveDamping" "WVFixedAmplitudeForcing" "WVBottomFrictionQuadratic" "WVPseudoTopographicWaveGeneration" "WVBetaPlanePVAdvection"];
            for iForcing = 1:numel(forcings)
                contract = forcings{iForcing}.portableImplementationContract();
                testCase.verifyEqual(contract.schemaIdentifier,"wave-vortex-portable-pair-v1");
                testCase.verifyEqual(contract.schemaVersion,uint32(1));
                testCase.verifyEqual(contract.typeIdentifier,expected(iForcing));
                testCase.verifyEqual(contract.contractVersion,uint32(1));
                testCase.verifyEqual(contract.capabilityStatus,"supported");
                testCase.verifyEqual(contract.reason,"");
                testCase.verifyTrue(isscalar(contract));
            end
        end

        function inheritedContractCannotAdvertiseParentClass(testCase)
            forcing = WVTestUnregisteredFixedAmplitudeForcing(testCase.wvt);
            contract = forcing.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"invalidContract");
            testCase.verifyEqual(contract.typeIdentifier,"WVTestUnregisteredFixedAmplitudeForcing");
        end

        function testPairUsesDistinctIdentity(testCase)
            forcing = WVTestPortableFixedAmplitudeForcing(testCase.wvt);
            contract = forcing.portableImplementationContract();
            testCase.verifyEqual(contract.capabilityStatus,"supported");
            testCase.verifyEqual(contract.typeIdentifier,"WVTestPortableFixedAmplitudeForcing");
        end
    end
end
