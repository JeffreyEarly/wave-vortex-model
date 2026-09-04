classdef TestFreeSurfaceQGBottomFriction < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function matchingPhysicalDefaultsAndExplicitOverrides(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            N2=@(z)(5.2e-3)^2*exp(2*z/1300);
            columnGravity=integral(N2,-4000,0);
            for gd=[NaN Inf .03]
                if isnan(gd)
                    w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=N2);
                    expectedGd=columnGravity;
                else
                    w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=N2,gd=gd,latitude=30,g0=-.02);
                    expectedGd=gd;
                end
                testCase.verifyEqual(w.gd,expectedGd)
                if isnan(gd)
                    testCase.verifyEqual(w.g0,-columnGravity)
                    testCase.verifyEqual(w.latitude,24)
                    testCase.verifyEqual(w.activeEndpoint,[1;2])
                else
                    testCase.verifyEqual(w.g0,-.02)
                    testCase.verifyEqual(w.latitude,30)
                end
                file=fullfile(fixture.Folder,['non-diffusive-',num2str(gd),'.nc']);
                nc=w.writeToFile(file); nc.close();
                restored=WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
                testCase.verifyEqual(restored.gd,w.gd)
                testCase.verifyEqual(restored.g0,w.g0)
                testCase.verifyEqual(restored.latitude,w.latitude)
                testCase.verifyEqual(restored.activeEndpoint,w.activeEndpoint)
                testCase.verifyEqual(restored.apvF,w.apvF)
            end
        end

        function nondiffusiveSignedProjection(testCase)
            for weights=[-.1 .1;Inf .1;-.1 Inf;Inf Inf].'
                w=WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),latitude=30,g0=weights(1),gd=weights(2),mdaGramTolerance=.1);
                w.removeAllForcing();
                tx=zeros(1,length(w.klNonzero)); ty=tx; index=find(w.kNonzero~=0,1); ty(index)=1;
                for endpoint=["surface" "bottom"]
                    source=w.boundaryMomentumTendency(tx,ty,endpoint);
                    iz=1; if endpoint=="surface", iz=w.Nz; end
                    testCase.verifyEqual(source.Ag_q(:,index),w.apvF(iz,:).'*(1i*w.kNonzero(index)/w.Lz),RelTol=1e-14)
                    if w.activeEndpointCount>0
                        ip=w.klNonzeroKhUniqueIndex(index);
                        testCase.verifyEqual(w.zeroAPVSourceSolve(:,:,ip)\source.Ag_0(:,index),w.zeroAPVF(iz,:,ip).'*(1i*w.kNonzero(index)/w.Lz),AbsTol=1e-18)
                    end
                    testCase.verifyEqual(source.Amda,zeros(size(w.Amda)))
                end
                w.Ag_q(1,index)=1e-7;
                force=WVBottomFrictionQuadratic(w);
                source=force.addQuasigeostrophicSpectralForcing(w,struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda))));
                testCase.verifyTrue(all(isfinite(source.Ag_q),'all'))
                testCase.verifyGreaterThan(norm(source.Ag_q,'fro'),0)
            end
        end

        function dragWorkAndRestartUseCanonicalState(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for gd=[Inf .03]
                w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[16 16 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),gd=gd);
                w.removeAllForcing();
                index=find(abs(w.kNonzero-2*pi/w.Lx)<1e-12 & w.lNonzero==0,1);
                q=zeros(w.Nz,length(w.klNonzero)); b=zeros(w.activeEndpointCount,length(w.klNonzero));
                q(:,index)=-w.khNonzero(index)^2; b(1,index)=-w.f/w.g;
                [w.Ag_q,w.Ag_0]=w.transformStateForward(q,b);
                phi=w.reconstructSpectralState();
                factor=.05/(2*w.khNonzero(index)*abs(phi(1,w.klNonzero(index))));
                w.Ag_q=factor*w.Ag_q; w.Ag_0=factor*w.Ag_0;
                force=WVBottomFrictionQuadratic(w,Cd=1e-3); w.addForcing(force);
                source=w.coefficientTendency();
                [phi,eta]=w.reconstructSpectralState();
                [~,b]=w.transformStateBack(w.Ag_q,w.Ag_0);
                file=fullfile(fixture.Folder,'drag.nc'); nc=w.writeToFile(file); nc.close();
                restored=WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
                testCase.verifyEqual(restored.coefficientTendency(),source)
                blank=struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda)));
                shared=force.addQuasigeostrophicSpectralForcing(w,blank,struct(phiHat=phi(:,w.klNonzero)));
                testCase.verifyEqual(shared,source)
                w.Ag_q=source.Ag_q; w.Ag_0=source.Ag_0;
                [pt,et]=w.reconstructSpectralState();
                [~,bt]=w.transformStateBack(w.Ag_q,w.Ag_0);
                kh2=(w.k.^2+w.l.^2).';
                work=2*real(sum(w.verticalQuadratureWeights.*(kh2.*conj(phi).*pt+w.N2.*conj(eta).*et),'all'));
                work=work+2*w.f^2/w.g*real(sum(conj(phi(end,:)).*pt(end,:)));
                endpointWeights=[w.g0;w.gd];
                work=work+2*real(sum(endpointWeights(w.activeEndpoint).*conj(b).*bt,'all'));
                expected=-force.Cd*.05^3*4/(3*pi);
                testCase.verifyLessThan(abs(work/expected-1),2e-4)
                restored.forcingWithName('quadratic bottom friction').Cd=0;
                testCase.verifyEqual(restored.coefficientTendency(),blank)
                delete(file)
            end
        end

    end
end
