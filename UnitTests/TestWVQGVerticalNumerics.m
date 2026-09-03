classdef TestWVQGVerticalNumerics < matlab.unittest.TestCase
    methods (Test)
        function projectionAndDampingContracts(testCase)
            nz=65; s=-cos(pi*(0:nz-1)'/(nz-1));
            z=1300*log(exp(-4000/1300)+(1+s)*(1-exp(-4000/1300))/2);
            o=WVQGVerticalOperators.fromGrid(z); n=nz-2;
            testCase.verifyLessThan(norm(o.qFromQuadrature*o.qToQuadrature-eye(n),'fro'),1e-11)
            testCase.verifyLessThan(norm(o.qFromPolynomial*o.qToPolynomial-eye(n),'fro'),1e-11)
            rates=o.unitDampingRates(); cutoff=floor((n-1)^.75);
            testCase.verifyEqual(rates(1:cutoff+1),zeros(cutoff+1,1))
            testCase.verifyEqual(rates(end),1)
            c=cos((1:n)')+1i*sin(2*(1:n)'); q=o.qFromPolynomial*c;
            F=-o.qFromPolynomial*(rates.*(o.qToPolynomial*q));
            testCase.verifyEqual(real(c'*(o.qToPolynomial*F)),-sum(rates.*abs(c).^2),RelTol=1e-12)
            testCase.verifyEqual(o.qFromQuadrature*(o.qToQuadrature*zeros(n,1)),zeros(n,1))
            frozen=-o.qFromPolynomial*(rates.*o.qToPolynomial);
            testCase.verifyEqual(expm(.3*frozen)*q,o.qFromPolynomial*(exp(-.3*rates).*c),AbsTol=1e-12)
        end

        function nonlinearAndDampingBudgets(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
            d=w.verticalClosureDiagnostics();
            scale=w.uvMax*max(w.khNonzero)*d.overintegratedPotentialEnstrophy;
            testCase.verifyLessThan(abs(d.advection.enstrophy)/scale,1e-10)
            testCase.verifyLessThanOrEqual(d.verticalDamping.enstrophy,0)
            testCase.verifyLessThanOrEqual(d.horizontalDamping.enstrophy,0)
            testCase.verifyLessThanOrEqual(d.horizontalDamping.physicalEnergy,0)
            testCase.verifyEqual(d.verticalDamping.endpointVariance,0,AbsTol=1e-19)
            [q,b]=w.transformStateBack(w.Ag_T);
            o=w.verticalNumerics; c=o.qToPolynomial*q;
            expected=-2*w.uvMax/w.effectiveHorizontalGridResolution*sum(o.unitDampingRates().*abs(c).^2,'all');
            testCase.verifyEqual(d.verticalDamping.enstrophy,expected,RelTol=1e-9)
            w.Ag_T=w.transformStateForward(zeros(size(q)),b);
            % Remove beta before checking the strict no-QGPV mechanism.
            w.removeAllForcing(); w.addForcing(WVNonlinearAdvection(w)); w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
            F=w.nonthermalCoefficientTendency(); [dq,~]=w.transformStateBack(F.Ag_T);
            testCase.verifyLessThan(max(abs(dq),[],'all'),1e-20)
        end

        function strictForcedNoDiffusionRunAndStrongDampingCap(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform(0);
            w.addForcing(TestWVTransformFreeSurfaceQGDiffusion.seasonal(w));
            b=.2*w.spectralField(cos(2*pi*w.X(:,:,1)/w.Lx));
            w.Ag_T=w.transformStateForward(complex(zeros(w.Nz-2,length(w.klNonzero))),b);
            % Deliberately force the timestep safeguard to bind in this
            % weak-flow, zero-QGPV control; the ordinary strength is one.
            w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=5000));
            model=WVModel(w); model.setupIntegrator(initialStep=86400,maximumStep=86400);
            captured=evalc('model.integrateToTime(2*86400,shouldShowIntegrationDiagnostics=false);');
            testCase.verifyFalse(contains(captured,'QG numerics:'))
            [q,~]=w.transformStateBack(w.Ag_T);
            testCase.verifyLessThan(max(abs(q),[],'all'),1e-15)
            testCase.verifyLessThanOrEqual(model.exponentialStatistics.maximumDampingNumber,1.2)
            % Exercise the new allowance, not only the unchanged small-step path.
            testCase.verifyGreaterThan(model.exponentialStatistics.maximumDampingNumber,.6)
        end

        function persistedOperatorsAndLegacyDefaults(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
            path=fullfile(fixture.Folder,'vertical.nc'); nc=w.writeToFile(path); nc.close();
            r=WVTransform.waveVortexTransformFromFile(path);
            for name=string(w.verticalNumerics.classRequiredPropertyNames())
                testCase.verifyEqual(r.verticalNumerics.(name),w.verticalNumerics.(name))
            end
            testCase.verifyTrue(r.shouldDealiasVertical)
            testCase.verifyEqual(r.forcingWithName('adaptive damping').verticalDampingStrength,1)
            testCase.verifyEqual(r.nonthermalCoefficientTendency(),w.nonthermalCoefficientTendency())
            r.configureVerticalNumerics(quadratureFactor=3);
            rebuilt=r.forcingWithName('adaptive damping'); o=r.verticalNumerics;
            expected=-o.qFromPolynomial*(o.unitDampingRates().*o.qToPolynomial)/r.effectiveHorizontalGridResolution;
            testCase.verifyEqual(rebuilt.verticalDamp,expected,AbsTol=1e-18)
            testCase.verifyEqual(length(o.zQuadrature),3*r.Nz)
            F=r.nonthermalCoefficientTendency(); testCase.verifyTrue(all(isfinite(F.Ag_T),'all'))
            % Reproduce the original required-property vocabulary, without
            % any new operators/flag, to test direct legacy construction.
            args=struct(); names=setdiff(w.scientificPropertyNames(),{'verticalNumerics','shouldDealiasVertical'});
            for name=string(names), args.(name)=w.(name); end
            values=namedargs2cell(args); old=WVTransformFreeSurfaceQGDiffusion(values{:});
            testCase.verifyFalse(old.shouldDealiasVertical)
            testCase.verifyEmpty(old.verticalNumerics)
            oldPath=fullfile(fixture.Folder,'old.nc');
            props=[names {'Ag_T','t','t0','forcing'}];
            nc=old.writeToFile(oldPath,props{:},shouldAddRequiredProperties=false); nc.close();
            restored=WVTransform.waveVortexTransformFromFile(oldPath);
            testCase.verifyFalse(restored.shouldDealiasVertical)
            testCase.verifyEmpty(restored.verticalNumerics)
            testCase.verifyError(@()WVAdaptiveDamping(restored,verticalDampingStrength=1),'WVAdaptiveDamping:MissingVerticalOperators')
        end
    end
end
