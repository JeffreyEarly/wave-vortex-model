classdef TestNativeThermalAdaptiveDamping < matlab.unittest.TestCase
    % Contract tests for native thermal generalized-enstrophy damping.
    %
    % The smoke tests below deliberately use only finite manufactured matrices.
    % They protect the SVV law and the factorized generalized-invariant algebra
    % without constructing an InternalModes provider. The full tests construct
    % the small thermal fixtures lazily, so focused smoke CI remains inexpensive.

    methods (Test, TestTags="smoke")
        function sharedSVVUsesTheEstablishedCutoffLaw(testCase)
            coordinate = 0:12;
            [Q, cutoff, significant] = WVInternal.adaptiveSVVFilter(coordinate,12,1,NaN);
            expectedCutoff = 12^(3/4);
            testCase.verifyEqual(cutoff,expectedCutoff,AbsTol=10*eps(expectedCutoff));
            testCase.verifyEqual(Q,referenceSVV(coordinate,12,expectedCutoff),AbsTol=10*eps);
            testCase.verifyGreaterThan(significant,cutoff);
            testCase.verifyLessThan(significant,12);

            [explicit, explicitCutoff] = WVInternal.adaptiveSVVFilter(coordinate,12,1,.5);
            testCase.verifyEqual(explicitCutoff,6,AbsTol=10*eps);
            testCase.verifyEqual(explicit,referenceSVV(coordinate,12,6),AbsTol=10*eps);
            testCase.verifyEqual(explicit(coordinate<=6),zeros(1,nnz(coordinate<=6)));
            testCase.verifyEqual(explicit(end),1,AbsTol=10*eps);
            testCase.verifyError(@() WVInternal.adaptiveSVVFilter(coordinate,12,1,1),'WV:AdaptiveSVVCutoff');
        end

        function clusteredSelectiveRatesAreRotationInvariant(testCase)
            lambda = [.1;.4;.4;1];
            upper = [1;3;3;4];
            [Q, cutoff] = WVInternal.adaptiveSVVFilter((1:4)',4,1,.5);
            rate = clusteredRates(lambda,upper,Q);
            testCase.verifyEqual(cutoff,2,AbsTol=10*eps);
            testCase.verifyEqual(rate(1:2),[0;rate(3)],AbsTol=10*eps);
            testCase.verifyEqual(rate(3),-.4*Q(3),AbsTol=10*eps);
            testCase.verifyEqual(rate(4),-1,AbsTol=10*eps);

            angle = .37;
            rotation = [1 0 0 0;0 cos(angle) -sin(angle) 0;0 sin(angle) cos(angle) 0;0 0 0 1];
            A = diag(rate);
            testCase.verifyEqual(rotation*A*rotation',A,AbsTol=1e-14);
            testCase.verifyEqual(rate(upper==3),repmat(rate(3),2,1),AbsTol=10*eps);

            factor = WVInternal.thermalGeneralizedEnstrophyFactors(eye(4),diag(sqrt(lambda)),eye(4),diag(sqrt(lambda)),1);
            testCase.verifyEqual(factor.generalizedEigenvalues,lambda,AbsTol=1e-12);
            testCase.verifyEqual(factor.clusterUpperOrdinal,upper);
        end

        function factoredGeneralizedInvariantDissipatesWithoutAGram(testCase)
            rng(17);
            FE = randn(9,4);
            FG = randn(11,4);
            [~,R] = qr(FE,0);
            [~,S,W] = svd(FG/R,"econ");
            V = R\W;
            P = W'*R;
            lambda = diag(S).^2;
            rate = [0;-.2;-.6;-1];
            a = randn(4,1)+1i*randn(4,1);
            tendency = V*(rate.*(P*a));
            M = FE'*FE;
            H = FG'*FG;
            testCase.verifyEqual(P*V,eye(4),AbsTol=1e-12);
            testCase.verifyEqual(V'*M*V,eye(4),AbsTol=1e-12);
            testCase.verifyEqual(V'*H*V,diag(lambda),AbsTol=1e-12);
            testCase.verifyLessThanOrEqual(real(a'*M*tendency),1e-12);
            testCase.verifyLessThanOrEqual(real(a'*H*tendency),1e-12);
            testCase.verifyEqual(tendency,V*diag(rate)*P*a,AbsTol=1e-13);
            page = WVInternal.thermalGeneralizedEnstrophyFactors(FE,FG,FE,FG,1);
            testCase.verifyEqual(page.polynomialDuals*page.polynomialEigenvectors,eye(4),AbsTol=1e-10);
            testCase.verifyEqual(page.polynomialEigenvectors'*M*page.polynomialEigenvectors,eye(4),AbsTol=1e-10);
            testCase.verifyEqual(page.polynomialEigenvectors'*H*page.polynomialEigenvectors,diag(page.generalizedEigenvalues),AbsTol=1e-10);
            testCase.verifyEqual(page.generalizedEigenvalues,sort(lambda),AbsTol=1e-10);

            [monomialEnergy, monomialGeneralized, analyticEnergy, analyticGeneralized] = constantMonomialFactors();
            monomialPage = WVInternal.thermalGeneralizedEnstrophyFactors(monomialEnergy,monomialGeneralized,monomialEnergy,monomialGeneralized,3e-5);
            testCase.verifyLessThan(norm(monomialEnergy'*monomialEnergy-analyticEnergy,2)/norm(analyticEnergy,2),1e-12);
            testCase.verifyLessThan(norm(monomialGeneralized'*monomialGeneralized-analyticGeneralized,2)/norm(analyticGeneralized,2),1e-12);
            testCase.verifyEqual(monomialPage.polynomialEigenvectors'*analyticEnergy*monomialPage.polynomialEigenvectors,eye(3),AbsTol=1e-10);
            generalizedResidual = monomialPage.polynomialEigenvectors'*analyticGeneralized*monomialPage.polynomialEigenvectors-diag(monomialPage.generalizedEigenvalues);
            testCase.verifyLessThan(norm(generalizedResidual,2)/max(norm(diag(monomialPage.generalizedEigenvalues),2),realmin),1e-10);

            D = 1000;
            for power = 0:4
                analytic = D*(-1)^power/(power+1);
                testCase.verifyEqual(integral(@(z) (z/D).^power,-D,0),analytic,AbsTol=1e-11);
            end
            inverseScale = 1/1300;
            for m = 0:2
                q = @(z) -3e-10*exp(m*inverseScale*z)+(1e-8*inverseScale^2/1e-4)*m*(m-2)*exp((m-2)*inverseScale*z);
                analytic = -3e-10*exponentialMoment(m,inverseScale,D)+(1e-8*inverseScale^2/1e-4)*m*(m-2)*exponentialMoment(m-2,inverseScale,D);
                testCase.verifyEqual(integral(q,-D,0),analytic,AbsTol=1e-16);
            end
        end
    end

    methods (Test, TestTags="full")
        function factoryBuildsPositiveNativeStateAndActualProcesses(testCase)
            w = thermalTransform("constant");
            force = WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w);
            populateOneThermalBlock(w,force);
            w.addForcing(WVNonlinearAdvection(w));
            w.addForcing(force);

            state = force.thermalGeneralizedEnstrophyState;
            testCase.verifyClass(state,"WVInternal.ThermalGeneralizedEnstrophyState");
            testCase.verifyEqual(state.boundaryWeights,ones(2,1)*w.f^2/(w.Lz/4),RelTol=1e-10);
            testCase.verifyTrue(all(state.generalizedEigenvalues>0,"all"));
            testCase.verifyTrue(all(isfinite(state.eigenvalueUncertainty),"all"));
            for p = 1:numel(w.khUnique)
                [FE, FG] = constantPhysicalFactors(w,w.khUnique(p),state.constructionQuadratureCount,state.boundaryWeights);
                V = state.polynomialEigenvectors(:,:,p);
                testCase.verifyEqual(V'*(FE'*FE)*V,eye(w.thermalModeCount),AbsTol=1e-8);
                testCase.verifyEqual(V'*(FG'*FG)*V,diag(state.generalizedEigenvalues(:,p)),AbsTol=1e-8);
            end

            data = force.coefficientDampingData();
            testCase.verifyGreaterThan(data.maximumUnitSpeedRate,0);
            testCase.verifyEqual(data.nominalSelectiveCutoff,w.thermalModeCount^(3/4),RelTol=1e-12);
            for p = 1:numel(data.pages)
                page = data.pages{p};
                active = page.activeDirections;
                expected = (w.polynomialToThermal(:,:,p)*state.polynomialEigenvectors(:,active,p).*reshape(page.selectiveRates(active),1,[]))*state.polynomialDuals(active,:,p)*w.thermalToPolynomial(:,:,p);
                testCase.verifyGreaterThanOrEqual(page.activeCount,0);
                testCase.verifyTrue(all(page.eigenvalues>0));
                testCase.verifyTrue(all(page.clusterUpperOrdinal>=1 & page.clusterUpperOrdinal<=w.thermalModeCount));
                testCase.verifyTrue(all(page.selectiveRates<=0));
                if page.applicationKind == "factored"
                    actual = page.leftFactor*page.rightFactor;
                    testCase.verifyEqual(page.rightFactor*page.leftFactor,diag(page.selectiveRates(active)),AbsTol=1e-8);
                else
                    testCase.verifyNotEmpty(page.denseOperator);
                    testCase.verifyTrue(all(isfinite(page.denseOperator),"all"));
                    testCase.verifySize(page.denseOperator,[w.thermalModeCount w.thermalModeCount]);
                    actual = page.denseOperator;
                end
                testCase.verifyEqual(actual,expected,AbsTol=1e-8);
                vectors = [ones(w.thermalModeCount,1),(-1).^(0:w.thermalModeCount-1)'];
                testCase.verifyEqual(actual*vectors,expected*vectors,AbsTol=1e-8);
            end

            [~, actualSelective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=1));
            for p = 1:numel(data.pages)
                page = data.pages{p};
                active = page.activeDirections;
                expected = (w.polynomialToThermal(:,:,p)*state.polynomialEigenvectors(:,active,p).*reshape(page.selectiveRates(active),1,[]))*state.polynomialDuals(active,:,p)*w.thermalToPolynomial(:,:,p);
                columns = w.klNonzeroKhUniqueIndex==p;
                testCase.verifyEqual(actualSelective.Ath(:,columns),expected*w.Ath(:,columns),AbsTol=1e-8);
            end

            [direct, speed, processes] = w.coefficientTendency();
            testCase.verifyGreaterThan(speed,0);
            testCase.verifyEqual(processes.labels(end-1:end),["adaptive damping: horizontal","adaptive damping: generalized enstrophy"]);
            summed = sumProcesses(processes);
            testCase.verifyEqual(summed.Ath,direct.Ath,AbsTol=1e-16);
            testCase.verifyEqual(summed.Amda,direct.Amda,AbsTol=1e-16);
            [horizontal, selective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            testCase.verifyEqual(processes.tendencies(end-1),horizontal,AbsTol=1e-16);
            testCase.verifyEqual(processes.tendencies(end),selective,AbsTol=1e-16);
            testCase.verifyEqual(force.maximumExplicitDampingRate(struct(uvMax=speed)),speed*data.maximumUnitSpeedRate,RelTol=1e-12);
        end

        function exponentialStateHasEnergyAndInvariantDissipation(testCase)
            w = thermalTransform("exponential");
            force = WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w,boundaryWeightMultiplier=10);
            populateOneThermalBlock(w,force);
            data = force.coefficientDampingData();
            expectedBeff = tanh(w.inverseScale*w.Lz/2)/(2*w.inverseScale);
            testCase.verifyEqual(force.thermalGeneralizedEnstrophyState.effectiveBoundaryDepth,expectedBeff,RelTol=1e-12);
            testCase.verifyEqual(force.thermalGeneralizedEnstrophyState.boundaryWeights,10*w.f^2/expectedBeff*ones(2,1),RelTol=1e-12);
            [exponentialEnergy, exponentialGeneralized, analyticEnergy, analyticGeneralized] = exponentialMonomialFactors(w.N20,w.inverseScale,w.Lz,w.f,w.g,w.khUnique(end),force.thermalGeneralizedEnstrophyState.boundaryWeights);
            exponentialPage = WVInternal.thermalGeneralizedEnstrophyFactors(exponentialEnergy,exponentialGeneralized,exponentialEnergy,exponentialGeneralized,w.khUnique(end));
            testCase.verifyLessThan(norm(exponentialEnergy'*exponentialEnergy-analyticEnergy,2)/norm(analyticEnergy,2),1e-12);
            testCase.verifyLessThan(norm(exponentialGeneralized'*exponentialGeneralized-analyticGeneralized,2)/norm(analyticGeneralized,2),1e-12);
            testCase.verifyLessThan(norm((exponentialEnergy*exponentialPage.polynomialEigenvectors)'*(exponentialEnergy*exponentialPage.polynomialEigenvectors)-eye(3),2),1e-8);
            exponentialResidual = exponentialPage.polynomialEigenvectors'*analyticGeneralized*exponentialPage.polynomialEigenvectors-diag(exponentialPage.generalizedEigenvalues);
            testCase.verifyLessThan(norm(exponentialResidual,2)/max(exponentialPage.generalizedEigenvalues(end),realmin),1e-8);
            [horizontal, selective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=1));
            state = force.thermalGeneralizedEnstrophyState;
            [energyPower, invariantPower] = generalizedPowers(w,state,selective.Ath);
            testCase.verifyLessThanOrEqual(energyPower,1e-10*max(1,norm(w.Ath,'fro')^2));
            testCase.verifyLessThanOrEqual(invariantPower,1e-8*max(1,max(state.generalizedEigenvalues,[],"all")*norm(w.Ath,'fro')^2));
            testCase.verifyLessThanOrEqual(-energyPower,-invariantPower/minActiveEigenvalue(data)+1e-8);
            for p = 1:numel(data.pages)
                page = data.pages{p};
                if page.applicationKind == "dense"
                    thermalD = page.denseOperator;
                else
                    thermalD = page.leftFactor*page.rightFactor;
                end
                D = w.thermalToPolynomial(:,:,p)*thermalD*w.polynomialToThermal(:,:,p);
                [FE, FG] = nativePhysicalFactors(w,w.khUnique(p),state.constructionQuadratureCount,state.boundaryWeights);
                [~,R] = qr(FE,0);
                B = R*D/R;
                generalizedEnergyForm = (FG/R)'*(FG/R);
                V = state.polynomialEigenvectors(:,:,p);
                testCase.verifyLessThan(norm((FE*V)'*(FE*V)-eye(w.thermalModeCount),2),1e-8);
                generalizedResidual = (FG*V)'*(FG*V)-diag(state.generalizedEigenvalues(:,p));
                testCase.verifyLessThan(norm(generalizedResidual,2)/max(state.generalizedEigenvalues(end,p),realmin),1e-8);
                maximumRate = max(abs(page.selectiveRates));
                energyHermitian = (B+B')/2;
                invariantHermitian = (generalizedEnergyForm*B+B'*generalizedEnergyForm)/2;
                selectivityHermitian = invariantHermitian/minActiveEigenvalue(data)-(B+B')/2;
                testCase.verifyLessThanOrEqual(max(eig(energyHermitian)),1e-10*maximumRate);
                testCase.verifyLessThanOrEqual(max(eig(invariantHermitian)),1e-8*state.generalizedEigenvalues(end,p)*maximumRate);
                testCase.verifyLessThanOrEqual(max(eig(selectivityHermitian)),1e-8*maximumRate);
            end
            testCase.verifyEqual(selective.Amda,zeros(size(w.Amda)));
            testCase.verifyEqual(horizontal.Amda,zeros(size(w.Amda)));
        end

        function cacheAndTransferRetainCanonicalScience(testCase)
            w = thermalTransform("constant");
            force = WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w);
            populateOneThermalBlock(w,force);
            first = force.coefficientDampingData();
            initialBuilds = first.cacheBuildCount;
            [stageHorizontal, stageSelective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=.3));
            [fallbackHorizontal, fallbackSelective] = force.quasigeostrophicDampingContributions(w);
            [zeroHorizontal, zeroSelective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=0));
            testCase.verifyEqual(stageHorizontal.Ath,.3/w.uvMax*fallbackHorizontal.Ath,RelTol=1e-12,AbsTol=1e-16);
            testCase.verifyEqual(stageSelective.Ath,.3/w.uvMax*fallbackSelective.Ath,RelTol=1e-12,AbsTol=1e-16);
            testCase.verifyEqual(zeroHorizontal.Ath,zeros(size(w.Ath)));
            testCase.verifyEqual(zeroSelective.Ath,zeros(size(w.Ath)));
            testCase.verifyEqual(stageHorizontal.Amda,zeros(size(w.Amda)));
            testCase.verifyEqual(stageSelective.Amda,zeros(size(w.Amda)));
            for j = 1:numel(w.klNonzero)
                partner = w.dftConjugateIndices2D(w.klNonzero(j));
                partner = find(w.klNonzero==partner,1);
                if ~isempty(partner)
                    testCase.verifyEqual(stageHorizontal.Ath(:,partner),conj(stageHorizontal.Ath(:,j)),AbsTol=1e-14);
                    testCase.verifyEqual(stageSelective.Ath(:,partner),conj(stageSelective.Ath(:,j)),AbsTol=1e-14);
                end
            end
            testCase.verifyEqual(force.coefficientDampingData().cacheBuildCount,initialBuilds);
            force.generalizedEnstrophyCutoffFraction = .5;
            changed = force.coefficientDampingData();
            testCase.verifyGreaterThan(changed.cacheBuildCount,initialBuilds);
            for cutoff = [.9 0]
                force.generalizedEnstrophyCutoffFraction = cutoff;
                branch = force.coefficientDampingData();
                [~, selective] = force.quasigeostrophicDampingContributions(w,struct(uvMax=1));
                for p = 1:numel(branch.pages)
                    page = branch.pages{p};
                    active = page.activeDirections;
                    expected = (w.polynomialToThermal(:,:,p)*force.thermalGeneralizedEnstrophyState.polynomialEigenvectors(:,active,p).*reshape(page.selectiveRates(active),1,[]))*force.thermalGeneralizedEnstrophyState.polynomialDuals(active,:,p)*w.thermalToPolynomial(:,:,p);
                    columns = w.klNonzeroKhUniqueIndex==p;
                    testCase.verifyEqual(selective.Ath(:,columns),expected*w.Ath(:,columns),AbsTol=1e-8);
                    if cutoff == .9
                        testCase.verifyEqual(page.applicationKind,"factored");
                    else
                        testCase.verifyEqual(page.applicationKind,"dense");
                    end
                end
            end
            force.generalizedEnstrophyCutoffFraction = .5;

            target = w.withDiffusivity(0);
            copy = force.forcingWithResolutionOfTransform(target);
            testCase.verifyEqual(copy.thermalGeneralizedEnstrophyState,force.thermalGeneralizedEnstrophyState);
            testCase.verifyEqual(copy.generalizedEnstrophyCutoffFraction,.5);
            testCase.verifyTrue(isnan(copy.apvCutoffFraction));
            testCase.verifyError(@() WVAdaptiveDamping(w),'WVAdaptiveDamping:ThermalStateRequired');
            testCase.verifyError(@() WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w,boundaryWeightMultiplier=0),'MATLAB:validators:mustBePositive');
            oneModeQG = WVTransformFreeSurfaceQG([1e5 1e5 1000],[4 4 65],N2Function=@(z) 1e-4+zeros(size(z)),apvModeCount=1,mdaModeCount=2);
            oneModeDamping = WVAdaptiveDamping(oneModeQG,apvCutoffFraction=.5);
            testCase.verifyEqual(oneModeDamping.j_no_damp,.5,AbsTol=10*eps);
        end

        function persistenceAndAdaptiveSingleDirectionEvolution(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w = thermalTransform("constant");
            force = WVAdaptiveDamping.fromThermalGeneralizedEnstrophy(w,generalizedEnstrophyCutoffFraction=0);
            [column, amplitude] = populateOneThermalBlock(w,force);
            w.addForcing(force);
            [closure, speed] = w.coefficientTendency(linearDynamics=true);
            unitRate = -real(amplitude'*closure.Ath(:,column))/(speed*sum(abs(amplitude).^2));
            testCase.verifyGreaterThan(unitRate,0);

            path = fullfile(fixture.Folder,'native-thermal-damping.nc');
            nc = w.writeToFile(path); nc.close();
            disabledPath = fullfile(fileparts(mfilename('fullpath')),'Fixtures','ThermalScienceDisabled');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(disabledPath));
            testCase.verifyError(@() WVInternal.buildThermalGeneralizedEnstrophyState(w,1),'TestNativeThermalAdaptiveDamping:ScientificConstructionDisabled');
            restored = WVTransform.waveVortexTransformFromFile(path);
            copy = restored.forcingWithName("adaptive damping");
            testCase.verifyClass(copy,"WVAdaptiveDamping");
            testCase.verifyEqual(copy.thermalGeneralizedEnstrophyState,force.thermalGeneralizedEnstrophyState);
            testCase.verifyEqual(restored.coefficientTendency(linearDynamics=true),w.coefficientTendency(linearDynamics=true),AbsTol=1e-15);
            direct = WVAdaptiveDamping(w,apvCutoffFraction=NaN,generalizedEnstrophyCutoffFraction=force.generalizedEnstrophyCutoffFraction,thermalGeneralizedEnstrophyState=force.thermalGeneralizedEnstrophyState);
            testCase.verifyEqual(direct.thermalGeneralizedEnstrophyState,force.thermalGeneralizedEnstrophyState);
            testCase.verifyEqual(direct.coefficientDampingData().maximumUnitSpeedRate,force.coefficientDampingData().maximumUnitSpeedRate,AbsTol=1e-14);

            qg = WVTransformFreeSurfaceQG([1e5 1e5 1000],[4 4 65],N2Function=@(z) 1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2);
            qg.addForcing(WVAdaptiveDamping(qg));
            legacyPath = fullfile(fixture.Folder,'legacy-adaptive.nc');
            nc = qg.writeToFile(legacyPath); nc.close();
            legacy = WVTransform.waveVortexTransformFromFile(legacyPath).forcingWithName("adaptive damping");
            testCase.verifyTrue(isempty(legacy.thermalGeneralizedEnstrophyState));
            testCase.verifyTrue(isnan(legacy.generalizedEnstrophyCutoffFraction));

            oldPath = fullfile(fixture.Folder,'old-adaptive-forcing.nc');
            oldForce = WVAdaptiveDamping(qg);
            nc = oldForce.writeToFile(oldPath,'apvCutoffFraction',shouldAddRequiredProperties=false); nc.close();
            oldGroup = NetCDFFile(oldPath); cleanup = onCleanup(@() oldGroup.close());
            old = WVForcing.forcingFromGroup(oldGroup,qg);
            testCase.verifyTrue(isnan(old.apvCutoffFraction));
            testCase.verifyTrue(isnan(old.generalizedEnstrophyCutoffFraction));
            testCase.verifyTrue(isempty(old.thermalGeneralizedEnstrophyState));

            dampingNumber = .25;
            duration = dampingNumber/(unitRate*speed);
            model = WVModel(w);
            model.setupIntegrator(integratorType="exponential",initialStep=duration/100,maximumStep=duration/100,exponentialAdaptive=false,thermalLinearDynamics=true);
            resumed = WVModel(restored);
            resumed.setupIntegrator(integratorType="exponential",initialStep=duration/100,maximumStep=duration/100,exponentialAdaptive=false,thermalLinearDynamics=true);
            model.integrateToTime(duration,shouldShowIntegrationDiagnostics=false);
            resumed.integrateToTime(duration,shouldShowIntegrationDiagnostics=false);
            expected = amplitude/(1+dampingNumber);
            testCase.verifyEqual(w.Ath(:,column),expected,RelTol=2e-5,AbsTol=1e-14);
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState(),RelTol=2e-12,AbsTol=1e-14);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            fixed = thermalTransform("constant");
            fixedForce = ThermalFixedSpeedAdaptiveDamping(fixed,fixedSpeed=fixed.uvMax,generalizedEnstrophyCutoffFraction=0,thermalGeneralizedEnstrophyState=force.thermalGeneralizedEnstrophyState);
            [fixedColumn, fixedAmplitude] = populateOneThermalBlock(fixed,fixedForce);
            fixedForce.fixedSpeed = fixed.uvMax;
            fixed.addForcing(fixedForce);
            [fixedTendency, fixedSpeed] = fixed.coefficientTendency(linearDynamics=true);
            fixedRate = -real(fixedAmplitude'*fixedTendency.Ath(:,fixedColumn))/(fixedSpeed*sum(abs(fixedAmplitude).^2));
            fixedDuration = dampingNumber/(fixedRate*fixedSpeed);
            fixedModel = WVModel(fixed);
            fixedModel.setupIntegrator(integratorType="exponential",initialStep=fixedDuration/100,maximumStep=fixedDuration/100,exponentialAdaptive=false,thermalLinearDynamics=true);
            fixedModel.integrateToTime(fixedDuration,shouldShowIntegrationDiagnostics=false);
            testCase.verifyEqual(fixed.Ath(:,fixedColumn),fixedAmplitude*exp(-dampingNumber),RelTol=2e-5,AbsTol=1e-14);
        end
    end
end

function value = referenceSVV(coordinate,maximum,cutoff)
value = zeros(size(coordinate));
active = coordinate>cutoff;
value(active) = exp(-((coordinate(active)-maximum)./(coordinate(active)-cutoff)).^2);
value(coordinate>=maximum & active) = 1;
end

function rate = clusteredRates(lambda,upper,Q)
rate = zeros(size(lambda));
for j = 1:numel(lambda)
    b = upper(j);
    rate(j) = -(lambda(b)/lambda(end))*Q(b);
end
end

function value = exponentialMoment(exponent,inverseScale,depth)
if exponent == 0
    value = depth;
else
    value = -expm1(-exponent*inverseScale*depth)/(exponent*inverseScale);
end
end

function [energy,generalized,M,H] = constantMonomialFactors()
% Analytic constant-N2 reference for psi={1,z/D,(z/D)^2}.
depth = 1000;
N2 = 1e-4;
f = 1e-4;
g = 9.81;
kh = 3e-5;
alpha = [2;3]*f^2/(depth/4);
[x,weights] = legpts(9);
x = (x(:)-1)/2;
weights = weights(:)*depth/2;
psi = [ones(size(x)),x,x.^2];
psiZ = [zeros(size(x)),ones(size(x))/depth,2*x/depth];
psiZZ = [zeros(size(x)),zeros(size(x)),2*ones(size(x))/depth^2];
eta = -f/N2*psiZ;
q = -kh^2*psi+f^2/N2*psiZZ;
etaSurface = [-f/g,-f/(N2*depth),0];
etaBottom = [0,-f/(N2*depth),2*f/(N2*depth)];
energy = [sqrt(weights)*kh.*psi;sqrt(weights*N2).*eta;sqrt(g)*(f/g)*[1 0 0]];
generalized = [sqrt(weights).*q;sqrt(alpha).*[etaSurface;etaBottom]];

M = zeros(3);
Q = zeros(3);
for i = 0:2
    for j = 0:2
        M(i+1,j+1) = kh^2*monomialIntegral(i+j,depth);
        if i>0 && j>0
            M(i+1,j+1) = M(i+1,j+1)+f^2/N2*i*j/depth^2*monomialIntegral(i+j-2,depth);
        end
    end
end
M(1,1) = M(1,1)+f^2/g;
for j = 0:2
    Q(j+1,j+1) = -kh^2;
    if j>=2, Q(j-1,j+1) = Q(j-1,j+1)+f^2/N2*j*(j-1)/depth^2; end
end
J = zeros(3);
for i = 0:2
    for j = 0:2, J(i+1,j+1) = monomialIntegral(i+j,depth); end
end
H = Q'*J*Q+alpha(1)*(etaSurface'*etaSurface)+alpha(2)*(etaBottom'*etaBottom);
end

function value = monomialIntegral(power,depth)
value = depth*(-1)^power/(power+1);
end

function [energy,generalized,M,H] = exponentialMonomialFactors(N20,inverseScale,depth,f,g,kh,boundaryWeights)
% Analytic exponential-N2 reference for psi_m=exp(m*a*z), m=0:2.
m = 0:2;
[x,weights] = legpts(9);
z = depth*(x(:)-1)/2;
weights = weights(:)*depth/2;
psi = exp(z*inverseScale*m);
eta = -(f/N20)*(inverseScale*m).*exp(z*inverseScale*(m-2));
q = -kh^2*psi+(f^2*inverseScale^2/N20)*(m.*(m-2)).*exp(z*inverseScale*(m-2));
etaSurface = -(f/N20)*inverseScale*m-f/g;
etaBottom = -(f/N20)*inverseScale*m.*exp(-inverseScale*depth*(m-2));
N2 = N20*exp(2*inverseScale*z);
energy = [sqrt(weights)*kh.*psi;sqrt(weights.*N2).*eta;sqrt(g)*(f/g)*ones(1,3)];
generalized = [sqrt(weights).*q;sqrt(boundaryWeights).*[etaSurface;etaBottom]];

M = zeros(3);
H = zeros(3);
qCoefficient = [zeros(3,1),-kh^2*ones(3,1)];
for j = 1:3
    qCoefficient(j,1) = (f^2*inverseScale^2/N20)*m(j)*(m(j)-2);
    qCoefficient(j,2) = -kh^2;
end
for i = 1:3
    for j = 1:3
        M(i,j) = kh^2*exponentialMoment(m(i)+m(j),inverseScale,depth) + ...
            (f^2*inverseScale^2/N20)*m(i)*m(j)*exponentialMoment(m(i)+m(j)-2,inverseScale,depth) + f^2/g;
        for r = 1:2
            for s = 1:2
                exponent = (m(i)-2*(2-r))+(m(j)-2*(2-s));
                H(i,j) = H(i,j)+qCoefficient(i,r)*qCoefficient(j,s)*exponentialMoment(exponent,inverseScale,depth);
            end
        end
    end
end
H = H+boundaryWeights(1)*(etaSurface'*etaSurface)+boundaryWeights(2)*(etaBottom'*etaBottom);
end

function [energy,generalized] = constantPhysicalFactors(w,kh,count,boundaryWeights)
% Independent constant-N2 Legendre factors for the native polynomial space.
[x,weights] = legpts(count);
z = w.Lz*(x(:)-1)/2;
weights = weights(:)*w.Lz/2;
[P,P1,P2] = legendreTrial(x(:),w.thermalModeCount);
psiZ = 2/w.Lz*P1;
psiZZ = (2/w.Lz)^2*P2;
eta = -w.f/w.N20*psiZ;
etaZ = -w.f/w.N20*psiZZ;
etaInterior = eta-(1+z/w.Lz)*(w.f/w.g);
q = -kh^2*P-w.f*etaZ;
[~,P1Endpoint] = legendreTrial([1;-1],w.thermalModeCount);
etaEndpoint = -w.f/w.N20*(2/w.Lz*P1Endpoint)-[1;0]*(w.f/w.g);
energy = [sqrt(weights)*kh.*P;sqrt(weights*w.N20).*eta;sqrt(w.g)*w.f/w.g*ones(1,w.thermalModeCount)];
generalized = [sqrt(weights).*q;sqrt(boundaryWeights).*etaEndpoint];
assert(all(isfinite(etaInterior),'all'));
end

function [energy,generalized] = nativePhysicalFactors(w,kh,count,boundaryWeights)
% Independent Legendre/WKB factors, including total eta and eta_i endpoints.
if w.inverseScale == 0
    [energy,generalized] = constantPhysicalFactors(w,kh,count,boundaryWeights);
    return
end
[x,weights] = legpts(count);
z = w.Lz*(x(:)-1)/2;
weights = weights(:)*w.Lz/2;
[P,P1,P2] = legendreTrial(wkbCoordinate(z,w.inverseScale,w.Lz),w.thermalModeCount);
denominator = -expm1(-w.inverseScale*w.Lz);
sz = 2*w.inverseScale*exp(w.inverseScale*z)/denominator;
psiZ = sz.*P1;
psiZZ = sz.^2.*P2+w.inverseScale*sz.*P1;
N2 = w.N20*exp(2*w.inverseScale*z);
eta = -w.f./N2.*psiZ;
etaZ = -w.f./N2.*(psiZZ-2*w.inverseScale*psiZ);
q = -kh^2*P-w.f*etaZ;
zEndpoint = [0;-w.Lz];
[~,P1Endpoint] = legendreTrial(wkbCoordinate(zEndpoint,w.inverseScale,w.Lz),w.thermalModeCount);
szEndpoint = 2*w.inverseScale*exp(w.inverseScale*zEndpoint)/denominator;
N2Endpoint = w.N20*exp(2*w.inverseScale*zEndpoint);
etaEndpoint = -w.f./N2Endpoint.*(szEndpoint.*P1Endpoint)-[1;0]*(w.f/w.g);
energy = [sqrt(weights)*kh.*P;sqrt(weights.*N2).*eta;sqrt(w.g)*w.f/w.g*ones(1,w.thermalModeCount)];
generalized = [sqrt(weights).*q;sqrt(boundaryWeights).*etaEndpoint];
end

function coordinate = wkbCoordinate(z,inverseScale,depth)
coordinate = 1+2*expm1(inverseScale*z)/(-expm1(-inverseScale*depth));
end

function [P,P1,P2] = legendreTrial(x,count)
P = zeros(numel(x),count);
P1 = P;
P2 = P;
P(:,1) = 1;
P(:,2) = x;
P1(:,2) = 1;
for j = 2:count-1
    P(:,j+1) = ((2*j-1)*x.*P(:,j)-(j-1)*P(:,j-1))/j;
    P1(:,j+1) = ((2*j-1)*(P(:,j)+x.*P1(:,j))-(j-1)*P1(:,j-1))/j;
    P2(:,j+1) = ((2*j-1)*(2*P1(:,j)+x.*P2(:,j))-(j-1)*P2(:,j-1))/j;
end
end

function w = thermalTransform(profile)
if profile == "constant"
    N2 = @(z) 1e-4+zeros(size(z));
    count = 9;
else
    N2 = @(z) 1e-4*exp(2*z/1300);
    count = 11;
end
w = WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=N2,thermalModeCount=count,mdaModeCount=2,kappa_z=0,shouldCheckQuadraticAliasing=true);
end

function [column, amplitude] = populateOneThermalBlock(w,force)
data = force.coefficientDampingData();
pageIndex = find(cellfun(@(page) page.activeCount>0,data.pages),1,"last");
page = data.pages{pageIndex};
direction = page.activeDirections(end);
column = find(w.klNonzeroKhUniqueIndex==pageIndex,1);
amplitude = w.polynomialToThermal(:,:,pageIndex)*force.thermalGeneralizedEnstrophyState.polynomialEigenvectors(:,direction,pageIndex);
w.Ath(:) = 0;
w.Ath(:,column) = amplitude;
partner = w.dftConjugateIndices2D(w.klNonzero(column));
conjugateColumn = find(w.klNonzero==partner,1);
if ~isempty(conjugateColumn) && conjugateColumn~=column, w.Ath(:,conjugateColumn) = conj(amplitude); end
end

function [energyPower, invariantPower] = generalizedPowers(w,state,tendency)
energyPower = 0;
invariantPower = 0;
for p = 1:numel(w.khUnique)
    columns = w.klNonzeroKhUniqueIndex==p;
    polynomial = w.thermalToPolynomial(:,:,p)*w.Ath(:,columns);
    polynomialTendency = w.thermalToPolynomial(:,:,p)*tendency(:,columns);
    [energy,generalized] = nativePhysicalFactors(w,w.khUnique(p),state.constructionQuadratureCount,state.boundaryWeights);
    energyPower = energyPower+real(sum(conj(polynomial).*(energy'*energy*polynomialTendency),"all"));
    invariantPower = invariantPower+real(sum(conj(polynomial).*(generalized'*generalized*polynomialTendency),"all"));
end
end

function value = minActiveEigenvalue(data)
value = Inf;
for p = 1:numel(data.pages)
    page = data.pages{p};
    if ~isempty(page.activeDirections), value = min(value,min(page.eigenvalues(page.activeDirections))); end
end
end

function total = sumProcesses(processes)
total = processes.tendencies(1);
for j = 2:numel(processes.tendencies)
    total.Ath = total.Ath+processes.tendencies(j).Ath;
    total.Amda = total.Amda+processes.tendencies(j).Amda;
end
end
