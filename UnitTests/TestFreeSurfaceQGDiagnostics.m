classdef TestFreeSurfaceQGDiagnostics < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function physicalInventoriesMatchIndependentSpatialIntegrals(testCase)
            endpoints = [Inf Inf;0.02 Inf;Inf 0.03;0.02 0.03];
            for endpoint = endpoints.'
                w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33], ...
                    N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=endpoint(1),gd=endpoint(2),mdaGramTolerance=.1);
                w.removeAllForcing();
                w.Ag_q(1:3,1) = 1e-8*[1;2i;-1];
                w.Ag_0(:,1) = 1e-11*(1:w.activeEndpointCount).';
                w.Amda(1:3) = [.1;-.02;.03];
                [psi,eta,q] = w.reconstructSpectralState();
                meanIndex = find(hypot(w.k,w.l)==0,1);
                q(:,meanIndex) = -w.f*w.verticalDerivativeMatrix*(w.mdaG*w.Amda);
                eta = w.transformToSpatialDomainWithFourier(eta);
                q = w.transformToSpatialDomainWithFourier(q);
                psi = w.transformToSpatialDomainWithFourier(psi);
                volumeEnergy = sum(w.verticalQuadratureWeights.*squeeze(mean(w.u.^2+w.v.^2+reshape(w.N2,1,1,[]).*eta.^2,[1 2])))/2;
                surfaceEnergy = w.f^2/(2*w.g)*mean(psi(:,:,end).^2,'all');
                enstrophy = sum(w.verticalQuadratureWeights.*squeeze(mean(q.^2,[1 2])))/2;
                [d,byWavenumber] = w.quadraticDiagnostics();
                testCase.verifyEqual(d.totalEnergy,volumeEnergy+surfaceEnergy,RelTol=1e-7)
                testCase.verifyEqual(d.surfacePotentialEnergy,surfaceEnergy,RelTol=1e-11,AbsTol=1e-25)
                testCase.verifyEqual(d.potentialEnstrophy,enstrophy,RelTol=1e-7)
                testCase.verifyEqual(w.totalEnergy,d.totalEnergy)
                testCase.verifyEqual(w.totalPotentialEnstrophy,d.potentialEnstrophy)
                testCase.verifyGreaterThan(d.totalEnergy,sum(byWavenumber.totalEnergy))
                testCase.verifyGreaterThan(d.potentialEnstrophy,sum(byWavenumber.potentialEnstrophy))
                metrics = w.physicalMetricOperators();
                testCase.verifyEqual(metrics.apvPotentialEnstrophy,w.Lz*eye(w.apvModeCount))
                testCase.verifyEqual(byWavenumber.potentialEnstrophy,w.Lz*sum(abs(w.Ag_q).^2,1),RelTol=8*eps)
                w.Ag_q = 2*w.Ag_q;
                w.t = 123;
                testCase.verifyEqual(w.physicalMetricOperators(),metrics)
                copy = metrics; copy.pages{1}.kineticEnergy(:) = 0;
                testCase.verifyEqual(w.physicalMetricOperators(),metrics)
                testCase.verifyEmpty(w.forcingNames())
            end
        end

        function tendencyBudgetsMatchDirectionalDerivative(testCase)
            w = WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300));
            w.removeAllForcing();
            state = struct(Ag_q=reshape(sin(1:numel(w.Ag_q)),size(w.Ag_q))*1e-9, ...
                Ag_0=reshape(cos(1:numel(w.Ag_0)),size(w.Ag_0))*1e-12,Amda=sin((1:w.mdaModeCount).')*.01);
            tendency = struct(Ag_q=1i*state.Ag_q+.2e-9,Ag_0=-.3*state.Ag_0,Amda=cos((1:w.mdaModeCount).')*.01);
            plus = state; minus = state; h = 1e-4;
            for name = ["Ag_q" "Ag_0" "Amda"]
                plus.(name) = state.(name)+h*tendency.(name);
                minus.(name) = state.(name)-h*tendency.(name);
            end
            d = w.quadraticDiagnostics(state=state,tendency=tendency);
            dp = w.quadraticDiagnostics(state=plus);
            dm = w.quadraticDiagnostics(state=minus);
            for name = ["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "totalEnergy" "potentialEnstrophy"]
                testCase.verifyEqual(d.(name+"Tendency"),(dp.(name)-dm.(name))/(2*h),RelTol=1e-7)
            end
            testCase.verifyEqual(w.Amda,zeros(size(w.Amda)))
            testCase.verifyEqual(w.Ag_q,complex(zeros(size(w.Ag_q))))
        end

        function dampingContributionsFollowConfigurationAndRebuild(testCase)
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)));
            w.removeAllForcing();
            w.Ag_q(:) = 1e-8; w.Ag_0(:) = 1e-11; w.Amda(:) = .01;
            force = WVAdaptiveDamping(w,apvCutoffFraction=.7); w.addForcing(force);
            physical = struct(uvMax=.05);
            blank = struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda)));
            for cutoff = [.7 .5]
                force.apvCutoffFraction = cutoff;
                [horizontal,vertical] = force.quasigeostrophicDampingContributions(w,physical);
                total = force.addQuasigeostrophicSpectralForcing(w,blank,physical);
                for name = ["Ag_q" "Ag_0" "Amda"]
                    testCase.verifyEqual(total.(name),horizontal.(name)+vertical.(name))
                end
                testCase.verifyEqual(vertical.Ag_q(w.apvMode<=cutoff*w.apvModeCount,:),zeros(nnz(w.apvMode<=cutoff*w.apvModeCount),length(w.klNonzero)),AbsTol=1e-28)
                testCase.verifyEqual(force.j_no_damp,cutoff*w.apvModeCount)
                force.buildDampingOperator();
                [rebuiltHorizontal,rebuiltVertical] = force.quasigeostrophicDampingContributions(w,physical);
                testCase.verifyEqual(rebuiltHorizontal,horizontal)
                testCase.verifyEqual(rebuiltVertical,vertical)
            end
            testCase.verifyError(@()WVAdaptiveDamping(w,apvCutoffFraction=1),'WVAdaptiveDamping:APVCutoff')
        end
    end
end
