classdef TestManuscriptEvolutionDiagnostics < matlab.unittest.TestCase
    properties
        transform
        study
        state
    end
    methods (TestClassSetup)
        function prepare(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4*exp(z/650),apvModeCount=4,waveModeCount=6,mdaModeCount=4,inertialModeCount=4,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
            w.t0=-17;
            testCase.transform=w;
            testCase.study=manuscriptEvolutionOperators(w,"exponential");
            testCase.state=testCase.study.seed("mixed",1);
        end
    end
    methods (Test, TestTags="full")
        function physicalBudgetDerivativesMatchIndependentTimeDifferences(testCase)
            s=testCase.study; A=testCase.state; time=327;
            rate=s.rhs(time,A); [d,detail]=s.observe(time,A,rate);
            dt=.01; plus=A; minus=A;
            for name=string(fieldnames(A)).'
                plus.(name)=A.(name)+dt*rate.(name); minus.(name)=A.(name)-dt*rate.(name);
            end
            [dp,fp]=s.observe(time+dt,plus,rate); [dm,fm]=s.observe(time-dt,minus,rate);
            testCase.verifyEqual((dp.energy-dm.energy)/(2*dt),d.energyRate,AbsTol=2e-10)
            testCase.verifyEqual((dp.label2-dm.label2)/(2*dt),d.label2Rate,AbsTol=2e-5)
            testCase.verifyEqual((dp.apv2-dm.apv2)/(2*dt),d.apv2Rate,AbsTol=2e-19)
            testCase.verifyEqual((fp.apv-fm.apv)/(2*dt),detail.apvRate,AbsTol=2e-13)
            testCase.verifyEqual((fp.label-fm.label)/(2*dt),detail.labelRate,AbsTol=2e-9)
            finiteSSH=(fp.hatted.ssh-fm.hatted.ssh)/(2*dt)-detail.hatted.w(:,:,end);
            testCase.verifyEqual(finiteSSH,detail.Rssh,AbsTol=3e-10)
            testCase.verifyLessThan(d.sshIdentityError,1e-12)
            % Physical residual work plus moving-boundary flux accounts for
            % the derivative; this does not assert exact conservation.
            testCase.verifyEqual(d.energyRate,d.energyWork,AbsTol=1e-10)
            testCase.verifyEqual(d.label2Rate,d.label2Work,AbsTol=1e-9)
            testCase.verifyEqual(d.apv2Rate,d.apv2Work,AbsTol=1e-23)
        end

        function waveAndInertialRatesHaveNoBoundaryAnomaly(testCase)
            w=testCase.transform; s=testCase.study;
            rate=s.rhs(327,testCase.state);
            for family=["Aw_p","Aw_m","Aio"]
                selected=w.coefficientState(); selected.(family)=rate.(family);
                h=s.sample(327,selected,2);
                testCase.verifyEqual(h.eta(:,:,end)-h.ssh,zeros(size(h.ssh)),AbsTol=2e-12)
                testCase.verifyEqual(h.eta(:,:,1),zeros(size(h.ssh)),AbsTol=2e-12)
            end
            selected=w.coefficientState(); selected.Amda=rate.Amda;
            h=s.sample(327,selected,2);
            testCase.verifyEqual(h.ssh,zeros(size(h.ssh)),AbsTol=2e-12)
            testCase.verifyGreaterThan(max(abs(h.eta(:,:,end)),[],'all'),1e-9)
        end

        function sourceEndpointAdvectionMatchesMaterialBoundaryLaw(testCase)
            % For a wave fixture the mean boundary offsets are spatially
            % constant. Its exact advected anomalies have zero tendency.
            s=testCase.study; A=s.seed("waves",1);
            [~,terms,h]=s.rhs(327,A);
            testCase.verifyEqual(h.eta(:,:,end)-h.ssh,2*ones(size(h.ssh)),AbsTol=2e-10)
            testCase.verifyEqual(h.eta(:,:,1),-2*ones(size(h.ssh)),AbsTol=2e-10)
            testCase.verifyEqual(terms.source.eta(:,:,end),zeros(size(h.ssh)),AbsTol=2e-10)
            testCase.verifyEqual(terms.source.eta(:,:,1),zeros(size(h.ssh)),AbsTol=2e-10)
        end

        function physicalReferenceCheckpointRespectsWKBMapping(testCase)
            s=testCase.study;
            [value,mn,mx]=s.checkpoint(327,testCase.state);
            testCase.verifyTrue(all(isfinite(value)))
            testCase.verifyGreaterThan(mn,-testCase.transform.Lz)
            testCase.verifyLessThan(mx,0)
        end

        function sourceToStateDefectDependsOnTheSSHRate(testCase)
            % The time operator differentiates four bulk fields. Its source
            % functional equals the state inverse only when SSH_t supplied
            % by the coefficient derivative is zero. Cancel that trace with
            % an external-mode state, without changing the source projector.
            w=testCase.transform; s=testCase.study;
            rate=s.rhs(327,testCase.state);
            spectral=w.reconstructSpectralState(state=rate);
            trace=w.coefficientState();
            for column=1:numel(w.klNonzero)
                unit=w.coefficientState(); unit.Aw_p(1,column)=1;
                response=w.reconstructSpectralState(state=unit);
                index=w.klNonzero(column);
                trace.Aw_p(1,column)=spectral.ssh(end,index)/response.ssh(end,index);
            end
            zeroSSH=rate;
            for name=string(fieldnames(rate)).', zeroSSH.(name)=rate.(name)-trace.(name); end
            h=s.sample(327,zeroSSH,1);
            testCase.verifyEqual(h.ssh,zeros(size(h.ssh)),AbsTol=1e-13)
            projected=w.projectSources(struct(u=h.u,v=h.v,w=h.w,eta=h.eta));
            reconstructed=s.sample(327,projected,1);
            for name=["u","v","w","eta"]
                scale=max(abs(h.(name)),[],'all');
                testCase.verifyEqual(reconstructed.(name),h.(name),AbsTol=2e-8*scale+1e-13)
            end
        end
    end
end
