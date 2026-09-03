classdef TestWVQGVerticalNumerics < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function fixturePath(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
        end
    end
    methods (Test)
        function fourierDealiasingMatchesNativeGridProducts(testCase)
            for shouldAntialias=[false true]
                w=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 400e3 4000],[12 8 33],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),kappaT=1e-5,shouldAntialias=shouldAntialias);
                index=reshape(1:numel(w.Ag_T),size(w.Ag_T));
                initial=1e-3*(sin(index)+1i*cos(2*index));
                for factor=[2 3]
                    w.configureVerticalNumerics(quadratureFactor=factor);
                    for amplitude=[0 1]
                        w.Ag_T=amplitude*initial;
                        [q,u,v,b,ub,vb,qHat,phiHat]=w.quasigeostrophicSpatialState();
                        physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,qInteriorHat=qHat,phiHat=phiHat);
                        [expectedQ,expectedB,expectedSpeed]=ThermalNativeGridTransform.advectionFourierReference(w,physical);
                        [actualQ,actualB,speed]=w.dealiasedAdvectionFourierTendency(physical);
                        testCase.verifyLessThan(norm(actualQ-expectedQ,'fro')/max(norm(expectedQ,'fro'),realmin),1e-11)
                        testCase.verifyEqual(actualB,expectedB)
                        testCase.verifyEqual(speed,expectedSpeed,RelTol=1e-12,AbsTol=1e-20)
                        % Missing shared spectra must still use the caller's fields.
                        native=rmfield(physical,{'qInteriorHat','phiHat'});
                        [fallbackQ,fallbackB,fallbackSpeed]=w.dealiasedAdvectionFourierTendency(native);
                        testCase.verifyEqual(fallbackQ,expectedQ,RelTol=1e-10,AbsTol=1e-23)
                        testCase.verifyEqual(fallbackB,expectedB)
                        testCase.verifyEqual(fallbackSpeed,expectedSpeed)
                    end
                end
            end
        end

        function earlyProjectionPreservesSpatialCallbackSemantics(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            index=reshape(1:numel(w.Ag_T),size(w.Ag_T));
            w.Ag_T=w.Ag_T+1e-3*(sin(index)+1i*cos(2*index));
            w.addForcing(ThermalSpatialTendencyMultiplier(w));
            w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
            testCase.verifyClass(w.spatialFluxForcing(end),'ThermalSpatialTendencyMultiplier')
            expected=thermalQGUnsharedTendency(w); actual=w.nonthermalCoefficientTendency();
            testCase.verifyEqual(actual.Ag_T,expected.Ag_T,RelTol=1e-10,AbsTol=1e-21)
            % Confirm this fixture really detects projection before its callback.
            [q,u,v,b,ub,vb]=w.quasigeostrophicSpatialState();
            physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb);
            [Fq,Fb]=w.dealiasedAdvection(physical);
            force=w.forcingWithName('spatial tendency multiplier');
            [fullQ,fullB]=force.addQuasigeostrophicSpatialForcing(w,Fq,Fb,physical);
            [cutQ,cutB]=force.addQuasigeostrophicSpatialForcing(w,w.spatialField(w.spectralField(Fq)),w.spatialField(w.spectralField(Fb)),physical);
            full=w.projectQuasigeostrophicSpatialTendency(fullQ,fullB);
            cut=w.projectQuasigeostrophicSpatialTendency(cutQ,cutB);
            testCase.verifyGreaterThan(norm(full.Ag_T-cut.Ag_T,'fro')/norm(full.Ag_T,'fro'),1e-6)
        end

        function fourierTendencyPreservesEnstrophyAndEndpointBudgets(testCase)
            w=TestWVTransformFreeSurfaceQGDiffusion.transform();
            TestWVTransformFreeSurfaceQGDiffusion.initializeNonlinear(w);
            [q,u,v,b,ub,vb,qHat,phiHat]=w.quasigeostrophicSpatialState();
            physical=struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,qInteriorHat=qHat,phiHat=phiHat);
            [dq,db,speed]=w.dealiasedAdvectionFourierTendency(physical);
            o=w.verticalNumerics; c=o.qToPolynomial*qHat;
            power=2*real(sum(conj(c).*(o.qToPolynomial*dq),'all'));
            scale=speed*max(w.khNonzero)*sum(abs(c).^2,'all');
            testCase.verifyLessThan(abs(power)/scale,1e-10)
            bHat=w.spectralField(b);
            endpointPower=2*real(sum(conj(bHat).*db,'all'));
            testCase.verifyLessThan(abs(endpointPower)/(speed*max(w.khNonzero)*sum(abs(bHat).^2,'all')),1e-10)
        end

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
