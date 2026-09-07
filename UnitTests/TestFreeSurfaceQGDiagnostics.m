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

        function publicFieldsIncludeMDAForEveryEndpointConfiguration(testCase)
            for scale = [Inf 700]
                for endpoints = [Inf Inf;.02 Inf;Inf .03;.02 .03].'
                    w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 65], ...
                        N2Function=@(z)1e-4*exp(2*z/scale),latitude=30,g0=endpoints(1),gd=endpoints(2),mdaGramTolerance=.1);
                    w.removeAllForcing();
                    w.Amda(1:3) = [.1;-.02;.03];
                    eta = w.eta;
                    expectedQ = -w.f*w.diffZ(eta);
                    [q,u,v,b] = w.quasigeostrophicSpatialState();
                    verifyIndependentInventories(testCase,w,scale);
                    testCase.verifyGreaterThan(norm(q(:)),0)
                    testCase.verifyEqual(q,w.qgpv)
                    testCase.verifyLessThan(norm(q(:)-expectedQ(:))/norm(expectedQ(:)),1e-7)
                    testCase.verifyEqual(u,zeros(size(u)),AbsTol=0)
                    testCase.verifyEqual(v,zeros(size(v)),AbsTol=0)
                    indices = [w.Nz 1];
                    testCase.verifyEqual(b,eta(:,:,indices(w.activeEndpoint)),AbsTol=1e-13)
                    for family = ["apv","zero","mixed"]
                        w.Ag_q(:) = 0; w.Ag_0(:) = 0;
                        if family~="zero", w.Ag_q(1:3,1) = 1e-8*[1;2i;-1]; end
                        if family~="apv", w.Ag_0(:,2) = 1e-11*(1:w.activeEndpointCount).'; end
                        savedMean = w.Amda;
                        if family~="mixed", w.Amda(:) = 0; end
                        [q,u,v,b] = w.quasigeostrophicSpatialState();
                        eta = w.eta;
                        expectedQ = w.diffX(v)-w.diffY(u)-w.f*w.diffZ(eta);
                        testCase.verifyEqual(q,w.qgpv)
                        testCase.verifyLessThan(norm(q(:)-expectedQ(:))/max(norm(q(:)),1e-10),1e-6)
                        expectedB = eta(:,:,indices(w.activeEndpoint));
                        if isfinite(w.g0), expectedB(:,:,1) = expectedB(:,:,1)-(w.f/w.g)*w.psi(:,:,end); end
                        testCase.verifyEqual(b,expectedB,AbsTol=1e-10)
                        verifyIndependentInventories(testCase,w,scale);
                        w.Amda = savedMean;
                    end
                end
            end
        end

        function meanReconstructionDoesNotChangeHorizontalAdvection(testCase)
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),g0=.02,gd=.03);
            w.Ag_q(1:3,1:2) = 1e-8*[1 2i;2i 1;-1 3];
            w.Ag_0(:,1:2) = 1e-11*[1 2;3 4i];
            before = w.coefficientTendency();
            w.Amda(1:3) = [.1;-.02;.03];
            after = w.coefficientTendency();
            for name = ["Ag_q","Ag_0","Amda"]
                testCase.verifyEqual(after.(name),before.(name),AbsTol=1e-20)
            end
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(fixture.Folder,'mda-fields.nc');
            nc = w.writeToFile(file); nc.close();
            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            testCase.verifyEqual(restored.qgpv,w.qgpv)
            [q,~,~,b] = w.quasigeostrophicSpatialState();
            [restoredQ,~,~,restoredB] = restored.quasigeostrophicSpatialState();
            testCase.verifyEqual(restoredQ,q)
            testCase.verifyEqual(restoredB,b)
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

function verifyIndependentInventories(testCase,w,scale)
% Integrate public fields with a separate physical-depth Gauss rule and the
% analytic coordinate map for each prescribed stratification profile.
previous = [];
for count = [129 257]
    j = (1:count-1).';
    off = j./sqrt(4*j.^2-1);
    [vectors,values] = eig(diag(off,1)+diag(off,-1),'vector');
    [nodes,order] = sort(values);
    weights = w.Lz*vectors(1,order).'.^2;
    z = (w.Lz/2)*(nodes-1);
    if isinf(scale)
        s = 1+2*z/w.Lz;
        native = 1+2*w.z/w.Lz;
    else
        s = (2*exp(z/scale)-1-exp(-w.Lz/scale))/(1-exp(-w.Lz/scale));
        native = (2*exp(w.z/scale)-1-exp(-w.Lz/scale))/(1-exp(-w.Lz/scale));
    end
    P = cos(acos(s)*(0:w.Nz-1))/cos(acos(max(-1,min(1,native)))*(0:w.Nz-1));
    fields = {w.u,w.v,w.eta,w.qgpv};
    for k = 1:4
        fields{k} = P*reshape(permute(fields{k},[3 1 2]),w.Nz,[]);
    end
    N2 = 1e-4*exp(2*z/scale);
    energy = weights.'*mean(fields{1}.^2+fields{2}.^2+N2.*fields{3}.^2,2)/2 ...
        +(w.f^2/(2*w.g))*mean(w.psi(:,:,end).^2,'all');
    enstrophy = weights.'*mean(fields{4}.^2,2)/2;
    d = w.quadraticDiagnostics();
    testCase.verifyEqual([d.totalEnergy d.potentialEnstrophy],[energy enstrophy],RelTol=1e-7,AbsTol=1e-24)
    if ~isempty(previous)
        testCase.verifyEqual([energy enstrophy],previous,RelTol=1e-10,AbsTol=1e-24)
    end
    previous = [energy enstrophy];
end
end
