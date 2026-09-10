classdef TestFreeSurfaceThermodynamics < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function constantStratificationMatchesClosedForms(testCase)
            wvt = newTransform(@(z)1e-4+zeros(size(z)));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            [z,eta,ssh] = admissibleFields(wvt);
            fields = context.evaluate(z,eta,ssh);
            N2 = 1e-4;
            testCase.verifyEqual(fields.buoyancy,-N2*eta,AbsTol=2e-15)
            testCase.verifyEqual(fields.ape,0.5*N2*eta.^2,AbsTol=1e-11)
            testCase.verifyEqual(fields.pressureSurface,wvt.g*ssh-0.5*N2*ssh.^2,AbsTol=1e-12)
            testCase.verifyEqual(fields.energySurface,0.5*wvt.g*ssh.^2-N2*ssh.^3/6,AbsTol=1e-12)
            testCase.verifyEqual(fields.N2AtLabel,N2+zeros(size(z)),AbsTol=1e-17)
            testCase.verifyEqual(fields.apeEta,N2*eta,AbsTol=1e-15)
            testCase.verifyEqual(fields.apeZ,zeros(size(z)),AbsTol=3e-15)
            testCase.verifyEqual(fields.density,wvt.rho0*(1-N2*(z-eta)/wvt.g),AbsTol=5e-13)
        end

        function variableProfileAndExplicitContinuationMatchAnalyticIntegrals(testCase)
            rate = 2/700; N2 = 1e-4;
            wvt = newTransform(@(z)N2*exp(rate*z));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            [z,eta,ssh] = admissibleFields(wvt);
            r = z-eta;
            I = @(x)N2*expm1(rate*x)/rate;
            J = @(x)N2*(expm1(rate*x)-rate*x)/rate^2;
            K = @(x)N2*(expm1(rate*x)-rate*x-0.5*(rate*x).^2)/rate^3;
            referenceI = I(z); referenceI(z>0)=N2*z(z>0);
            referenceJ = J(z); referenceJ(z>0)=0.5*N2*z(z>0).^2;
            surfaceJ = J(ssh); surfaceJ(ssh>0)=0.5*N2*ssh(ssh>0).^2;
            surfaceK = K(ssh); surfaceK(ssh>0)=N2*ssh(ssh>0).^3/6;
            fields = context.evaluate(z,eta,ssh);
            testCase.verifyEqual(fields.buoyancy,I(r)-referenceI,AbsTol=2e-15)
            testCase.verifyEqual(fields.ape,-eta.*I(r)-J(r)+referenceJ,AbsTol=1e-11)
            testCase.verifyEqual(fields.apeEta,eta.*N2.*exp(rate*r),AbsTol=2e-15)
            testCase.verifyEqual(fields.apeZ,-eta.*N2.*exp(rate*r)-I(r)+referenceI,AbsTol=3e-15)
            testCase.verifyEqual(fields.pressureSurface,wvt.g*ssh-surfaceJ,AbsTol=1e-12)
            testCase.verifyEqual(fields.energySurface,0.5*wvt.g*ssh.^2-surfaceK,AbsTol=1e-11)
            testCase.verifyEqual(fields.referencePressure,wvt.rho0*(-wvt.g*z+referenceJ),AbsTol=1e-9)
            % The factory freezes profile/constants and does not depend on
            % modal phase clocks or prognostic coefficient mutations.
            wvt.t = 951; wvt.t0 = -33;
            testCase.verifyEqual(context.evaluate(z,eta,ssh),fields)
        end

        function highDegreeProfileUsesSufficientIntegralQuadrature(testCase)
            D = 1000; N2 = 1e-4; degree = 18; a = 0.3;
            wvt = newTransform(@(z)N2*(1+a*(1+z/D).^degree));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            [z,eta,ssh] = admissibleFields(wvt);
            r = z-eta;
            I = @(x)N2*(x+a*D/(degree+1)*((1+x/D).^(degree+1)-1));
            J = @(x)N2*(x.^2/2+a*D^2/((degree+1)*(degree+2))*((1+x/D).^(degree+2)-1-(degree+2)*x/D));
            referenceI = I(z); referenceI(z>0)=N2*(1+a)*z(z>0);
            referenceJ = J(z); referenceJ(z>0)=0.5*N2*(1+a)*z(z>0).^2;
            fields = context.evaluate(z,eta,ssh);
            testCase.verifyEqual(fields.buoyancy,I(r)-referenceI,AbsTol=3e-15)
            testCase.verifyEqual(fields.ape,-eta.*I(r)-J(r)+referenceJ,AbsTol=1e-11)
        end

        function tinyDisplacementsRetainQuadraticEnergyAccuracy(testCase)
            wvt = newTransform(@(z)1e-4+zeros(size(z)));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            eta = reshape([1e-3,-1e-3,1e-7,-1e-7,1e-11,-1e-11,0,0],2,2,2);
            z = -500+zeros(size(eta));
            fields = context.evaluate(z,eta,zeros(2));
            testCase.verifyEqual(fields.buoyancy,-1e-4*eta,RelTol=2e-14)
            testCase.verifyEqual(fields.ape,0.5e-4*eta.^2,RelTol=2e-14)
        end

        function outOfDomainLabelsAndInvalidGeometryFailExplicitly(testCase)
            wvt = newTransform(@(z)1e-4+zeros(size(z)));
            context = WVInternal.freeSurfaceThermodynamics(wvt);
            [z,eta,ssh] = admissibleFields(wvt);
            bad = eta; bad(1)=z(1)+wvt.Lz+1e-8;
            testCase.verifyError(@()context.evaluate(z,bad,ssh),'WV:ParcelLabelDomain')
            bad = eta; bad(end)=z(end)-1e-8;
            testCase.verifyError(@()context.evaluate(z,bad,ssh),'WV:ParcelLabelDomain')
            badSSH = ssh; badSSH(1)=-wvt.Lz;
            testCase.verifyError(@()context.evaluate(z,eta,badSSH),'WV:ThermodynamicGeometry')
        end
    end
end

function wvt = newTransform(profile)
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 33],N2Function=profile,apvModeCount=2,waveModeCount=2,mdaModeCount=2,inertialModeCount=2,shouldAntialias=true);
end

function [z,eta,ssh] = admissibleFields(wvt)
[X,Y,Xi] = ndgrid(wvt.x,wvt.y,wvt.z);
ssh = 5*cos(2*pi*X(:,:,1)/wvt.Lx).*cos(2*pi*Y(:,:,1)/wvt.Ly);
s = 1+Xi/wvt.Lz;
z = Xi+s.*ssh;
% Compress labels into [-980,-20], leaving strict endpoint margins.
r = -20+(1-40/wvt.Lz)*Xi;
eta = z-r;
end
