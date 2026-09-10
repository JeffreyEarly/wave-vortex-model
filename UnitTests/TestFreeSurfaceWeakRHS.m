classdef TestFreeSurfaceWeakRHS < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyHelpers(testCase)
            sourceRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(sourceRoot,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function nonflatCovectorAndConstrainedRateMatchDenseStudy(testCase)
            [wvt,helper,context,basis,T,state,hatted] = studyFixture();
            [~,~,H,~,physical,buoyancy] = helper.energyGeometry(basis,state,context);
            metric = stageMetric(hatted,context);
            boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
            [actual,target,diagnostics] = WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,buoyancy,wvt.g*hatted.ssh,context.derivative,boundary);
            actualDense = T'*studyCovector(actual);
            rhs = WVInternal.freeSurfaceMappedTendency(hatted,zeros(context.shape),buoyancy,wvt.z,wvt.Lz,wvt.f,wvt.rho0,context.derivative);
            momentum = helper.metricApply(physical,rhs,context);
            momentum.eta = physical.gamma.*rhs.eta;
            expected = helper.physicalPair(basis,momentum,context)-wvt.g*basis.w(context.top,:)'*(context.surfaceWeights.*hatted.ssh(:))+wvt.g*basis.ssh'*(context.surfaceWeights.*hatted.w(context.top));
            testCase.verifyLessThan(norm(actualDense-expected)/norm(expected),2e-12)

            thetaSurface = hatted.eta(:,:,end)-hatted.ssh;
            thetaBottom = hatted.eta(:,:,1);
            targets = struct(ssh=hatted.w(:,:,end),surface=-physical.u(:,:,end).*context.derivative.x(thetaSurface)-physical.v(:,:,end).*context.derivative.y(thetaSurface),bottom=-physical.u(:,:,1).*context.derivative.x(thetaBottom)-physical.v(:,:,1).*context.derivative.y(thetaBottom));
            [expectedTarget,expectedDiscarded] = boundary.projectTarget(targets);
            testCase.verifyEqual(target,expectedTarget,AbsTol=2e-14)
            testCase.verifyEqual(diagnostics.discardedBoundaryTargetRMS,expectedDiscarded,AbsTol=2e-14)
            testCase.verifyGreaterThan(expectedDiscarded,1e-9)

            Kfull = [basis.ssh;basis.eta(context.top,:)-basis.ssh;basis.eta(context.bottom,:)];
            [left,singular,~] = svd(Kfull,'econ');
            rankValue = sum(diag(singular)>1e-10*max(diag(singular)));
            left = left(:,1:rankValue); K = left'*Kfull;
            study = struct(basis=basis,context=context,Kfull=Kfull,left=left,K=K);
            expectedRate = helper.weakTendency(study,state);
            fields = diagnostics.boundaryTargetFields;
            physicalTarget = [fields.ssh(:);fields.surface(:);fields.bottom(:)];
            rate = helper.constrainedSolve(H,actualDense,K,left'*physicalTarget);
            testCase.verifyLessThan(norm(rate-expectedRate)/norm(expectedRate),2e-12)
            [minimumLabel,maximumLabel] = helper.labelBounds(hatted,context);
            testCase.verifyGreaterThan(minimumLabel,-wvt.Lz)
            testCase.verifyLessThan(maximumLabel,0)

            % Independently vary supplied surface pressure and check its
            % virtual work, without changing the volume RHS or reference.
            load = .03*cos(2*pi*wvt.x/wvt.Lx)*ones(1,wvt.Ny);
            loaded = WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,buoyancy,wvt.g*hatted.ssh+load,context.derivative,boundary);
            actualWork = state'*(T'*(studyCovector(loaded)-studyCovector(actual)));
            expectedWork = -mean(hatted.w(:,:,end).*load,'all');
            testCase.verifyEqual(actualWork,expectedWork,AbsTol=1e-12*norm(state)*norm(T'*studyCovector(actual)))
        end

        function linearDirectionalLimitMatchesAnalyticalMixedModes(testCase)
            [wvt,helper,context,~,T,~,~] = studyFixture();
            wvt.t = 1837; wvt.t0 = 71;
            seed = helper.seedState(wvt);
            seed.Aw_m = .4*exp(.63i)*seed.Aw_p;
            rate = structfun(@(value)zeros(size(value)),seed,UniformOutput=false);
            frequency = wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
            rate.Aw_p = 1i*frequency.*seed.Aw_p;
            rate.Aw_m = -1i*frequency.*seed.Aw_m;
            rate.Aio = 1i*wvt.f*seed.Aio;
            hatted = helper.sampledState(wvt,seed,context);
            flat = stageMetric(struct(ssh=zeros(wvt.Nx,wvt.Ny)),context);
            expected = WVInternal.freeSurfaceWeakMassAction(wvt,rate,flat);
            boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
            expectedTarget = boundary.apply(rate);
            epsilon = 1e-4;
            sides = cell(2,1); targets = cell(2,1);
            for side = 1:2
                amplitude = (3-2*side)*epsilon;
                fields = structfun(@(value)amplitude*value,hatted,UniformOutput=false);
                metric = stageMetric(fields,context);
                % Supplied linear buoyancy isolates the analytic derivative;
                % this is not a pointwise plus-reference amplitude claim.
                [sides{side},targets{side}] = WVInternal.freeSurfaceWeakRHS(wvt,fields,metric,-context.N2*fields.eta,wvt.g*fields.ssh,context.derivative,boundary);
            end
            actual = (studyCovector(sides{1})-studyCovector(sides{2}))/(2*epsilon);
            expected = studyCovector(expected);
            testCase.verifyLessThan(norm(T'*(actual-expected))/norm(T'*expected),3e-8)
            actualTarget = (targets{1}-targets{2})/(2*epsilon);
            testCase.verifyLessThan(norm(actualTarget-expectedTarget)/norm(expectedTarget),3e-8)
            testCase.verifyEqual([wvt.t,wvt.t0],[1837,71])
        end
    end
end

function [wvt,helper,context,basis,T,state,hatted] = studyFixture()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,waveModeCount=3,mdaModeCount=2,inertialModeCount=2,nEVP=128);
wvt.t = 0; wvt.t0 = 0;
helper = freeSurfaceWeakStudyHelpers();
context = helper.buildContext(wvt,1);
basis = helper.globalBasis(wvt,context);
H0 = helper.gram(basis,context);
scale = sqrt(diag(H0));
upper = chol(H0./(scale*scale.'));
T = diag(1./scale)/upper;
for name = ["u","v","w","eta","ssh"], basis.(name)=basis.(name)*T; end
seed = helper.seedState(wvt);
xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
yColumn = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
seed.Aw_p(1,yColumn) = .3*exp(.41i)*seed.Aw_p(1,xColumn);
state = helper.physicalPair(basis,helper.sampledState(wvt,seed,context),context);
hatted = helper.stateFromVector(basis,state,context);
end

function metric = stageMetric(hatted,context)
alpha = reshape(1+context.xi/context.D,1,1,[]);
metric.gamma = 1+hatted.ssh/context.D;
metric.betaX = alpha.*context.derivative.x(hatted.ssh)./metric.gamma;
metric.betaY = alpha.*context.derivative.y(hatted.ssh)./metric.gamma;
metric.displacementWeight = context.N2*repmat(metric.gamma,1,1,context.shape(3));
end

function vector = studyCovector(covector)
% The study's global basis interleaves real/imaginary entries per family.
vector = zeros(0,1);
for family = ["Ag_q","Ag_0","Aw_p","Aw_m","Aio","Amda"]
    values = covector.(family)(:);
    if family=="Amda"
        vector = [vector;values]; %#ok<AGROW>
    else
        vector = [vector;reshape([real(values).';imag(values).'],[],1)]; %#ok<AGROW>
    end
end
end
