classdef TestThermalQGBottomFriction < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function matchingPhysicalDefaultsAndExplicitOverrides(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            N2=@(z)(5.2e-3)^2*exp(2*z/1300);
            columnGravity=integral(N2,-4000,0);
            for gd=[NaN Inf .03]
                if isnan(gd)
                    w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=N2);
                    thermal=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[8 8 65],N2Function=N2,kappaT=0);
                    expectedGd=columnGravity;
                else
                    w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=N2,gd=gd,latitude=30,g0=-.02);
                    thermal=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[8 8 65],N2Function=N2,kappaT=0,gd=gd,latitude=30,g0=-.02);
                    expectedGd=gd;
                end
                for name=["g0" "gd" "latitude" "g" "rotationRate" "planetaryRadius" "activeEndpoint"]
                    testCase.verifyEqual(w.(name),thermal.(name))
                end
                testCase.verifyEqual(w.f,thermal.f,RelTol=4*eps)
                testCase.verifyEqual(w.gd,expectedGd)
                testCase.verifyEqual(thermal.thermalDecayRate,zeros(size(thermal.thermalDecayRate)))
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

        function legacyFileWithoutEndpointWeights(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=TestThermalQGBottomFriction.transform(Inf);
            file=fullfile(fixture.Folder,'legacy.nc'); nc=w.writeToFile(file); nc.close();
            id=netcdf.open(file,'WRITE'); cleanup=onCleanup(@()netcdf.close(id));
            netcdf.reDef(id);
            netcdf.renameVar(id,netcdf.inqVarID(id,'g0'),'unused_g0');
            netcdf.renameVar(id,netcdf.inqVarID(id,'gd'),'unused_gd');
            netcdf.endDef(id); clear cleanup
            restored=WVTransformFreeSurfaceQGDiffusion.waveVortexTransformFromFile(file);
            testCase.verifyEqual(restored.activeEndpointCount,1)
            testCase.verifyEqual(restored.gd,Inf)
            testCase.verifyEqual(restored.g0,-sum(w.verticalQuadratureWeights.*w.N2))
            testCase.verifyEqual(restored.phiModes,w.phiModes)
        end

        function seasonalSourceWithTwoEndpoints(testCase)
            for kappa=[0 1e-5]
                w=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[16 16 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),kappaT=kappa);
                w.removeAllForcing();
                pattern=repmat(sin(2*pi*w.y.'/w.Ly),w.Nx,1);
                force=WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=1e-7);
                w.t=force.period/4;
                [Fq,Fb]=force.addQuasigeostrophicSpatialForcing(w,zeros(w.spatialMatrixSize),zeros(w.Nx,w.Ny,2),struct());
                source=w.projectQuasigeostrophicSpatialTendency(Fq,Fb);
                [q,b]=w.transformStateBack(source.Ag_T);
                testCase.verifyLessThan(norm(q,'fro'),1e-22)
                testCase.verifyEqual(b(1,:),w.spectralField(1e-7*pattern),AbsTol=1e-20)
                testCase.verifyLessThan(norm(b(2,:))/norm(b(1,:)),1e-10)
                w.t=0; w.addForcing(force);
                model=WVModel(w); model.setupIntegrator(maximumStep=86400);
                model.integrateToTime(2*86400,shouldShowIntegrationDiagnostics=false);
                testCase.verifyEqual(w.Ag_T,force.exactThermalResponse(w,w.t))
                if kappa==0
                    [q,b]=w.transformStateBack(w.Ag_T);
                    testCase.verifyLessThan(norm(q,'fro'),1e-15)
                    testCase.verifyLessThan(norm(b(2,:)),1e-11)
                end
                w.addForcing(WVAdaptiveDamping(w,verticalDampingStrength=1));
                tendency=w.nonthermalCoefficientTendency();
                testCase.verifyTrue(all(isfinite(tendency.Ag_T),'all'))
                norms=w.physicalErrorNorms(w.Ag_T);
                testCase.verifyTrue(all(isfinite(norms)))
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

        function signedBoundaryPairing(testCase)
            for gd=[Inf NaN]
                w=TestThermalQGBottomFriction.transform(gd);
                for endpoint=["surface" "bottom"]
                    tx=zeros(1,length(w.klNonzero)); ty=tx;
                    index=find(w.kNonzero~=0,1); ty(index)=1;
                    source=w.boundaryMomentumTendency(tx,ty,endpoint);
                    ip=w.klNonzeroKhUniqueIndex(index);
                    phi=w.phiModes(:,:,ip); eta=w.etaModes(:,:,ip);
                    b=w.scaledStateFromModes(w.Nz-1:end,:,ip);
                    weights=[w.g0 w.gd]; weights=weights(w.activeEndpoint);
                    H=phi'*(w.verticalQuadratureWeights*w.khUnique(ip)^2.*phi)+eta'*(w.verticalQuadratureWeights.*w.N2.*eta);
                    H=H+w.f^2/w.g*(phi(end,:)'*phi(end,:))+b'*(weights(:).*b);
                    iz=1; if endpoint=="surface", iz=w.Nz; end
                    expected=-phi(iz,:)'*(1i*w.kNonzero(index));
                    testCase.verifyLessThan(norm(H*source.Ag_T(:,index)-expected)/norm(expected),1e-10)
                    zero=w.boundaryMomentumTendency(w.kNonzero.',w.lNonzero.',endpoint);
                    testCase.verifyEqual(zero.Ag_T,zeros(size(w.Ag_T)))
                end
            end
        end

        function endpointState(testCase)
            w=TestThermalQGBottomFriction.transform(NaN);
            testCase.verifyEqual(w.activeEndpoint,[1;2])
            testCase.verifyEqual(w.Nj,w.Nz)
            testCase.verifyEqual(w.g0,-integral(@(z)(5.2e-3)^2*exp(2*z/1300),-w.Lz,0))
            testCase.verifyEqual(w.gd,-w.g0)
            q=zeros(w.Nz-2,length(w.klNonzero)); b=zeros(2,length(w.klNonzero)); b(:,1)=[1;2];
            w.Ag_T=w.transformStateForward(q,b);
            [qr,br]=w.transformStateBack(w.Ag_T);
            testCase.verifyLessThan(norm(qr,'fro'),1e-14)
            testCase.verifyEqual(br,b,AbsTol=1e-11)
            [phi,eta]=w.reconstructSpectralState();
            testCase.verifyEqual(eta(end,:)-w.f/w.g*phi(end,:),br(1,:),AbsTol=1e-10)
            testCase.verifyEqual(eta(1,:),br(2,:),AbsTol=1e-10)
            testCase.verifyEqual(w.bottomAnomaly,w.spatialField(br(2,:)))
            w.addForcing(WVNonlinearAdvection(w));
            tendency=w.nonthermalCoefficientTendency();
            testCase.verifyTrue(all(isfinite(tendency.Ag_T),'all'))
        end

        function restartRebuildsTheSameProjection(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for gd=[Inf NaN]
                w=TestThermalQGBottomFriction.transform(gd);
                TestThermalQGBottomFriction.initialize(w);
                w.addForcing(WVBottomFrictionQuadratic(w,Cd=1.5e-3));
                expected=w.nonthermalCoefficientTendency();
                file=fullfile(fixture.Folder,'bottom-drag.nc'); nc=w.writeToFile(file); nc.close();
                restored=WVTransformFreeSurfaceQGDiffusion.waveVortexTransformFromFile(file);
                testCase.verifyEqual(restored.g0,w.g0)
                testCase.verifyEqual(restored.gd,w.gd)
                testCase.verifyEqual(restored.Ag_T,w.Ag_T)
                testCase.verifyEqual(restored.phiModes,w.phiModes)
                actual=restored.nonthermalCoefficientTendency();
                testCase.verifyEqual(actual.Ag_T,expected.Ag_T,RelTol=1e-12)
                force=restored.forcingWithName('quadratic bottom friction'); force.Cd=0;
                zero=restored.nonthermalCoefficientTendency();
                testCase.verifyEqual(zero.Ag_T,zeros(size(w.Ag_T)))
                delete(file)
            end
        end

        function dragUsesSignedWorkAndSharedReconstruction(testCase)
            w=TestThermalQGBottomFriction.transform(NaN);
            TestThermalQGBottomFriction.initialize(w);
            force=WVBottomFrictionQuadratic(w,Cd=1e-3);
            source=force.addQuasigeostrophicSpectralForcing(w,struct(Ag_T=zeros(size(w.Ag_T))));
            [phi,eta]=w.reconstructSpectralState(); [pt,et]=w.reconstructSpectralState(source.Ag_T);
            [~,b]=w.transformStateBack(w.Ag_T); [~,bt]=w.transformStateBack(source.Ag_T);
            work=2*real(sum(w.verticalQuadratureWeights.*(w.khNonzero.'.^2.*conj(phi).*pt+w.N2.*conj(eta).*et),'all'));
            work=work+2*w.f^2/w.g*real(sum(conj(phi(end,:)).*pt(end,:)));
            work=work+2*real(sum([w.g0;w.gd].*conj(b).*bt,'all'));
            expected=-force.Cd*.05^3*4/(3*pi);
            testCase.verifyLessThan(abs(work/expected-1),2e-4)
            shared=force.addQuasigeostrophicSpectralForcing(w,struct(Ag_T=zeros(size(w.Ag_T))),struct(phiHat=phi));
            testCase.verifyEqual(shared.Ag_T,source.Ag_T)
            force.Cd=2e-3;
            doubled=force.addQuasigeostrophicSpectralForcing(w,struct(Ag_T=zeros(size(w.Ag_T))));
            testCase.verifyEqual(doubled.Ag_T,2*source.Ag_T)
        end
    end
    methods (Static)
        function w=transform(gd)
            w=WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[16 16 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),gd=gd);
            w.removeAllForcing();
        end
        function initialize(w)
            index=find(abs(w.kNonzero-2*pi/w.Lx)<1e-12 & w.lNonzero==0,1);
            q=zeros(w.Nz-2,length(w.klNonzero)); b=zeros(w.activeEndpointCount,length(w.klNonzero));
            q(:,index)=-w.khNonzero(index)^2; b(1,index)=-w.f/w.g;
            w.Ag_T=w.transformStateForward(q,b);
            phi=w.reconstructSpectralState();
            w.Ag_T=w.Ag_T*(.05/(2*w.khNonzero(index)*abs(phi(1,index))));
        end
    end
end
