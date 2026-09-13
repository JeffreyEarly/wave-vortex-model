classdef TestBuoyancyCrossingProjection < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function constantLayerMomentsMatchAnalyticIntegrals(testCase)
            D=1000; n=33; xi=-D*(1+cos(pi*(0:n-1)'/(n-1)))/2;
            [~,q]=chebpts(n,[-D 0]); q=q(:);
            context=WVInternal.prepareBuoyancyCrossingProjection(@(z)1e-4+zeros(size(z)),xi,q,D);
            ssh=[-.1 0 1e-8 .03 3 200];
            correction=reshape(context.apply(ssh),[],n);
            for degree=0:5
                phi=(xi/D).^degree; crest=max(ssh(:),0); gamma=1+crest/D;
                sample=1e-4*max(xi.'+(1+xi.'/D).*ssh(:),0);
                actual=(sample+correction)*(q.*phi);
                expected=1e-4*(-1)^degree*crest.^(degree+2)./(gamma.^(degree+1)*D^degree*(degree+1)*(degree+2));
                testCase.verifyEqual(actual,expected,AbsTol=2e-11*max(abs(expected))+1e-24)
            end
            testCase.verifyEqual(correction(1:2,:),zeros(2,n))
        end
        function smoothRemainderPreservesSmallAmplitudeAndPhysicalFields(testCase)
            for N2={@(z)1e-4+zeros(size(z)),@(z)1e-4*(1+z/2000)}
                context=WVInternal.freeSurfaceThermodynamicContext(N2{1},1000,9.81,1025);
                xi=reshape([-1000 -500 0],1,1,[]); reference=N2{1}(xi(:));
                for amplitude=[1 1e-8 1e-12]
                    ssh=[amplitude,-amplitude,0]; z=xi+(1+xi/1000).*ssh; eta=z-xi;
                    regular=context.evaluateNonlinear(z,eta,ssh,reference);
                    split=context.evaluateCrossingSplit(z,eta,ssh,reference);
                    for name=string(fieldnames(regular)).', testCase.verifyEqual(regular.(name),split.(name)); end
                    if reference(1)==reference(end)
                        expected=zeros(size(z));
                    else
                        expected=.5*(1e-4/2000)*eta.^2;
                    end
                    testCase.verifyEqual(split.smoothBuoyancyRemainder,expected,AbsTol=2e-12*max(abs(expected),[],'all')+1e-40)
                end
            end
        end
        function variableProfileMatchesIndependentWeightedIntegral(testCase)
            D=1000; N2=@(z)1e-4*(1+z/(2*D));
            problem=IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=9.81,g0=9.81,gd=9.81,surfaceBoundary="freeSurface");
            solver=IMSolverSpectral(nEVP=33,coordinateKind="wkb").configuredForEVP(problem);
            [xi,q]=solver.nativeDifferentiationRule([-D 0]); q=q*(D/sum(q));
            context=WVInternal.prepareBuoyancyCrossingProjection(N2,xi,q,D,16);
            ssh=[-.1 0 .03 3 100]; gamma=1+ssh(:)/D;
            z=xi.'+(1+xi.'/D).*ssh(:); z=max(z,0);
            J=@(z)1e-4*(z+z.^2/(4*D));
            x=@(z)2*((1+z/(2*D)).^1.5-(.5)^1.5)/(1-(.5)^1.5)-1;
            correction=reshape(context.apply(ssh),[],numel(xi));
            for degree=0:5
                phi=cos(degree*acos(x(xi)));
                actual=(J(z)+correction)*(q.*phi);
                expected=zeros(numel(ssh),1);
                for j=find(ssh>0)
                    expected(j)=integral(@(z)cos(degree*acos(x((z-ssh(j))/gamma(j)))).*J(z)/gamma(j),0,ssh(j),AbsTol=1e-18,RelTol=1e-12);
                end
                testCase.verifyEqual(actual,expected,AbsTol=3e-12*max(abs(expected))+1e-20)
            end
        end
        function unequalWaveCountsAndParcelGuardsRemainEffective(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            base=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
            counts=mod((0:numel(base.khUnique)-1).',5);
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=3,waveModeCount=counts,waveModeKappa=base.khUnique,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
            study=manuscriptEvolutionOperators(base,"constant",padding=1); initial=study.seed("mixed",.01);
            initial.Aw_p=initial.Aw_p.*w.activeWaveModes; initial.Aw_m=initial.Aw_m.*w.activeWaveModes;
            for name=string(fieldnames(initial)).', w.(name)=initial.(name); end
            w.t=901; p=WVInternal.prepareBoussinesqRHSAssessment(w);
            a=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33],crossingOrder=8);
            b=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 65],crossingOrder=16);
            for family=string(fieldnames(a.tendency)).'
                testCase.verifyEqual(a.tendency.(family),b.tendency.(family),AbsTol=1e-8*max(abs(b.tendency.(family)),[],'all')+1e-18)
            end
            testCase.verifyEqual(a.tendency.Aw_p(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
            testCase.verifyEqual(a.tendency.Aw_m(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
            p.spectral.eta(:)=0; p.spectral.eta(:,w.k==0 & w.l==0)=-1;
            testCase.verifyError(@()WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33],crossingOrder=8),'WV:ParcelLabelDomain')
        end
        function projectionLeavesPointwiseSourcesAndOtherFamiliesUnchanged(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            for profile=["constant","exponential"]
                if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
                study=manuscriptEvolutionOperators(w,profile,padding=1); state=study.seed("mixed",.01);
                for name=string(fieldnames(state)).', w.(name)=state.(name); end
                for time=[327 901]
                    w.t=time; w.t0=-17; p=WVInternal.prepareBoussinesqRHSAssessment(w);
                    a=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 17]);
                    b=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 17],crossingOrder=8);
                    c=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 17],crossingOrder=16);
                    testCase.verifyEqual(a.source,b.source)
                    for family=["Ag_q","Ag_0","Amda","Aio"], testCase.verifyEqual(a.tendency.(family),b.tendency.(family)); end
                    for family=["Aw_p","Aw_m"]
                        testCase.verifyEqual(b.tendency.(family),c.tendency.(family),AbsTol=1e-18)
                        phase=exp(1i*w.waveFrequency(:,w.klNonzeroKhUniqueIndex)*(w.t-w.t0));
                        if family=="Aw_p", deltaP=(b.tendency.Aw_p-a.tendency.Aw_p).*phase; else, deltaM=(b.tendency.Aw_m-a.tendency.Aw_m)./phase; end
                    end
                    testCase.verifyEqual(deltaP,deltaM,AbsTol=1e-18)
                end
            end
        end
    end
end
