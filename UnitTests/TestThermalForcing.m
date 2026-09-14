classdef TestThermalForcing < matlab.unittest.TestCase
    properties
        states
    end
    methods (TestClassSetup)
        function setup(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
            for a=[0 1/1300]
                w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[16 16 65],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4,kappa_z=0,shouldCheckQuadraticAliasing=true);
                testCase.states{end+1}=w.scientificState;
            end
        end
    end
    methods (Test, TestTags="full")
        function endpointAndStressWeakWork(testCase)
            for s=testCase.states
                w=WVTransformFreeSurfaceThermalQG(scientificState=s{1}); thermalManufacturedState(w,[2 3 4],1000);
                fields=w.reconstructFields("psi"); spectral=w.transformFromSpatialDomainWithFourier(fields.psi);
                for endpoint=["surface" "bottom"]
                    iz=w.Nz; if endpoint=="bottom", iz=1; end
                    testCase.verifyEqual(w.boundaryStreamfunction(endpoint),spectral(iz,w.klNonzero),AbsTol=1e-11);
                    psi=w.boundaryStreamfunction(endpoint); k=w.k(w.klNonzero).'; l=w.l(w.klNonzero).';
                    tx=1e-4*(1+2i)*(-1i*l.*psi); ty=1e-4*(2-1i)*(1i*k.*psi);
                    source=w.boundaryMomentumTendency(tx,ty,endpoint);
                    weights=ones(size(k)); weights(w.dftPrimaryIndices2D(w.klNonzero)~=w.dftConjugateIndices2D(w.klNonzero))=2;
                    expected=sum(weights.*real(conj(-1i*l.*psi).*tx+conj(1i*k.*psi).*ty));
                    testCase.verifyEqual(energyRate(w,source),expected,RelTol=1e-10,AbsTol=1e-18);
                    [physical,~]=physicalRates(w,source);
                    testCase.verifyEqual(physical,expected,RelTol=1e-10,AbsTol=1e-18);
                    testCase.verifyEqual(source.Amda,zeros(size(w.Amda)));
                    testCase.verifyGreaterThan(norm(source.Ath,'fro'),0);
                end
                testCase.verifyError(@()w.boundaryMomentumTendency(0,0,"bottom"),'WV:ThermalStressSize');
            end
        end
        function refinedQuadraticStress(testCase)
            for s=testCase.states
                w=WVTransformFreeSurfaceThermalQG(scientificState=s{1}); thermalManufacturedState(w,[2 3 4],1000);
                force=WVBottomFrictionQuadratic(w,Cd=1e-3);
                blank=struct(Ath=zeros(size(w.Ath)),Amda=zeros(size(w.Amda)));
                source=force.addQuasigeostrophicSpectralForcing(w,blank);
                work=energyRate(w,source); [physical,enstrophy]=physicalRates(w,source);
                testCase.verifyEqual(physical,work,RelTol=1e-10);
                testCase.verifyTrue(isfinite(enstrophy));
                [expected,reference]=stressReference(w,8,force.Cd);
                [medium,coarse]=stressReference(w,4,force.Cd);
                testCase.verifyLessThan(work,0);
                testCase.verifyLessThan(abs(work-expected)/abs(expected),5e-4);
                testCase.verifyLessThan(abs(medium-expected)/abs(expected),1e-5);
                testCase.verifyLessThan(norm(reference.Ath-coarse.Ath,'fro')/norm(reference.Ath,'fro'),2e-4);
                fprintf('T5 stress a=%g: work %.16g, refined %.16g, relative %.3g, enstrophy rate %.16g.\n',w.inverseScale,work,expected,abs(work/expected-1),enstrophy);
                force.Cd=0; testCase.verifyEqual(force.addQuasigeostrophicSpectralForcing(w,blank),blank);
                testCase.verifyError(@()WVBottomFrictionQuadratic(w,Cd=Inf),'MATLAB:validators:mustBeFinite');
                testCase.verifyNotEqual(string(force.portableImplementationContract().capabilityStatus),"supported");
            end
        end
        function actualProcessesAndLazyReconstruction(testCase)
            w=ThermalReconstructionCounter(testCase.states{1}); thermalManufacturedState(w,[2 3 4],1000);
            drag=WVBottomFrictionQuadratic(w); w.addForcing(drag);
            [direct,~,p]=w.coefficientTendency(linearDynamics=true);
            testCase.verifyEqual(w.nativeCalls,0); testCase.verifyEqual(w.nonlinearCalls,0);
            testCase.verifyEqual(p.labels,["density diffusion","quadratic bottom friction"]);
            testCase.verifyEqual(sumProcesses(p),direct);
            w.addForcing(WVNonlinearAdvection(w)); w.addForcing(seasonal(w)); w.t=1234;
            [full,qualifiedSpeed,p]=w.coefficientTendency();
            testCase.verifyEqual(w.nativeCalls,0); testCase.verifyEqual(w.nonlinearCalls,1);
            testCase.verifyEqual(sumProcesses(p).Ath,full.Ath,AbsTol=1e-18);
            f=ThermalProcessForcing(w); w.addForcing(f); w.nativeSpeedMultiplier=100;
            [doubled,withCallbackSpeed,p]=w.coefficientTendency();
            testCase.verifyEqual(withCallbackSpeed,qualifiedSpeed);
            testCase.verifyEqual(f.lastSpeed,qualifiedSpeed);
            testCase.verifyEqual(doubled.Ath,2*full.Ath,AbsTol=1e-18);
            testCase.verifyEqual(p.labels(end),string(f.name));
            testCase.verifyEqual(p.tendencies(end).Ath,full.Ath,AbsTol=1e-18);
            testCase.verifyEqual(sumProcesses(p).Ath,doubled.Ath,AbsTol=1e-18);
            [excluded,~,p]=w.coefficientTendency(excludingForcing=[string(f.name),"seasonal surface anomaly"],excludingHomogeneousEvolution=true);
            testCase.verifyFalse(any(ismember(p.labels,[string(f.name),"density diffusion","seasonal surface anomaly"])));
            testCase.verifyEqual(sumProcesses(p).Ath,excluded.Ath,AbsTol=1e-18);
            f.invalidFamily=true;
            testCase.verifyError(@()w.coefficientTendency(),'WV:ThermalForcingTendency');
        end
        function strictSourceAndConfiguration(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.states{1}); f=seasonal(w);
            annualPeriod=365.25*86400; annualPattern=repmat(sin(10*pi*w.y'/w.Ly),w.Nx,1);
            for magnitude=[10 100]
                annual=WVSeasonalSurfaceAnomalyForcing(w,pattern=annualPattern,amplitude=magnitude*pi/annualPeriod);
                for time=[0 annualPeriod/8 annualPeriod/4 3*annualPeriod/4]
                    w.t=time;
                    [annualQ,annualB]=annual.addQuasigeostrophicSpatialForcing(w,zeros(w.spatialMatrixSize),zeros(w.Nx,w.Ny,2),struct());
                    testCase.verifyEqual(annualQ,zeros(w.spatialMatrixSize));
                    testCase.verifyEqual(annualB(:,:,2),zeros(w.Nx,w.Ny));
                    testCase.verifyEqual(annualB(:,:,1),(magnitude*pi/annualPeriod)*sin(2*pi*time/annualPeriod)*annualPattern);
                end
            end
            for t=[0 1234 f.period/4 f.period]
                w.t=t; q=zeros(w.spatialMatrixSize); b=zeros(w.Nx,w.Ny,2);
                [q,b]=f.addQuasigeostrophicSpatialForcing(w,q,b,struct());
                testCase.verifyEqual(q,zeros(size(q))); testCase.verifyEqual(b(:,:,2),zeros(w.Nx,w.Ny));
                testCase.verifyEqual(b(:,:,1),f.amplitude*sin(2*pi*t/f.period+f.phase)*f.pattern);
                testCase.verifyLessThan(abs(mean(b(:,:,1),'all')),1e-22);
                d=w.projectQuasigeostrophicSpatialTendency(q,b); w.Ath=d.Ath;
                reconstructed=w.reconstructFields(["endpointAnomalies","qgpv"]);
                testCase.verifyLessThan(max(abs(reconstructed.endpointAnomalies(:,:,1)-b(:,:,1)),[],'all'),1e-12);
                testCase.verifyLessThan(max(abs(reconstructed.endpointAnomalies(:,:,2)),[],'all'),1e-12);
                testCase.verifyLessThan(max(abs(reconstructed.qgpv),[],'all'),1e-14);
            end
            w.Ath(:)=0; w.t=1234; w.addForcing(f); w.addForcing(WVBottomFrictionQuadratic(w,Cd=.003));
            changed=w.withDiffusivity(1e-5);
            for force=w.forcing
                copy=force.forcingWithResolutionOfTransform(changed); changed.addForcing(copy);
                testCase.verifyEqual(copy.wvt,changed);
            end
            testCase.verifyEqual(changed.forcingWithName('quadratic bottom friction').Cd,.003);
            copied=changed.forcingWithName('seasonal surface anomaly');
            testCase.verifyEqual(copied.pattern,f.pattern); testCase.verifyEqual(copied.amplitude,f.amplitude);
            testCase.verifyEqual(copied.period,f.period); testCase.verifyEqual(copied.phase,f.phase);
            apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny w.Nz],N2Function=@(z)w.N20*ones(size(z)));
            cross=f.forcingWithResolutionOfTransform(apv);
            testCase.verifyEqual(cross.pattern,f.pattern); testCase.verifyEqual(cross.phase,f.phase);
            crossDrag=changed.forcingWithName('quadratic bottom friction').forcingWithResolutionOfTransform(apv);
            testCase.verifyEqual(crossDrag.Cd,.003); testCase.verifyEqual(crossDrag.wvt,apv);
            file=fullfile(fixture.Folder,'forcing.nc'); nc=w.writeToFile(file); nc.close();
            restored=WVTransform.waveVortexTransformFromFile(file);
            testCase.verifyEqual(restored.forcingWithName('quadratic bottom friction').Cd,.003);
            testCase.verifyEqual(restored.coefficientTendency(linearDynamics=true),w.coefficientTendency(linearDynamics=true));
            testCase.verifyError(@()WVSeasonalSurfaceAnomalyForcing(w,pattern=ones(w.Nx,w.Ny),amplitude=1e-7),'WVSeasonalSurfaceAnomalyForcing:MeanUnsupported');
        end
    end
end
function force=seasonal(w)
force=WVSeasonalSurfaceAnomalyForcing(w,pattern=repmat(sin(2*pi*w.y'/w.Ly),w.Nx,1),amplitude=1e-7,period=1e5,phase=.7);
end
function value=energyRate(w,d)
value=0; weights=ones(1,numel(w.klNonzero)); weights(w.dftPrimaryIndices2D(w.klNonzero)~=w.dftConjugateIndices2D(w.klNonzero))=2;
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    value=value+w.Lz*sum(weights(columns).*real(sum(conj(w.Ath(:,columns)).*(w.thermalEnergyGram(:,:,p)*d.Ath(:,columns)),1)));
end
end
function [work,tendency]=stressReference(w,factor,Cd)
g=WVGeometryDoublyPeriodic([w.Lx w.Ly],factor*[w.Nx w.Ny],Nz=1,shouldAntialias=false,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
[found,indices]=ismember(round([w.k(w.klNonzero)*w.Lx,w.l(w.klNonzero)*w.Ly]/(2*pi)),round([g.k*w.Lx,g.l*w.Ly]/(2*pi)),'rows'); assert(all(found));
psi=complex(zeros(1,g.Nkl)); psi(indices)=w.boundaryStreamfunction("bottom");
u=g.transformToSpatialDomainWithFourier(-1i*g.l.'.*psi); v=g.transformToSpatialDomainWithFourier(1i*g.k.'.*psi);
speed=hypot(u,v); work=-Cd*mean(speed.^3,'all');
tx=g.transformFromSpatialDomainWithFourier(-Cd*speed.*u); ty=g.transformFromSpatialDomainWithFourier(-Cd*speed.*v);
tendency=w.boundaryMomentumTendency(tx(indices),ty(indices),"bottom");
end
function value=sumProcesses(processes)
value=processes.tendencies(1);
for i=2:numel(processes.tendencies)
    for name=string(fieldnames(value)).'
        value.(name)=value.(name)+processes.tendencies(i).(name);
    end
end
end

function [energy,enstrophy]=physicalRates(w,d)
[x,weights]=legpts(1025); z=w.Lz*(x-1)/2; weights=weights(:)*w.Lz/2;
energy=0; enstrophy=0;
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p; kh=w.khUnique(p);
    r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,kh,w.f,w.g);
    c=w.thermalToPolynomial(:,:,p)*w.Ath(:,columns); dc=w.thermalToPolynomial(:,:,p)*d.Ath(:,columns);
    psi=r.psi*c; psiT=r.psi*dc; eta=r.eta*c; etaT=r.eta*dc;
    energy=energy+2*real(sum(weights.*(kh^2*conj(psi).*psiT+w.N20*exp(2*w.inverseScale*z).*conj(eta).*etaT),'all'));
    energy=energy+2*w.g*real(sum(conj(r.ssh*c).*(r.ssh*dc),'all'));
    enstrophy=enstrophy+2*real(sum(weights.*conj(r.qgpv*c).*(r.qgpv*dc),'all'));
end
end
