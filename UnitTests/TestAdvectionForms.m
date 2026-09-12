classdef TestAdvectionForms < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            for name=["advection-form-study","thermodynamic-formulation-study","nonlinear-study"]
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools',name)));
            end
        end
    end
    methods (Test, TestTags="full")
        function analyticContinuumSources(testCase)
            for profile=["constant","exponential"]
                a=thermodynamicFormulationFixture(profile,.4,64,65);
                D=a.derivative; D.adjointXi=D.xi; % This control only tests the continuum forms.
                remainder=-a.buoyancy-a.q.*a.eta;
                expected.u=a.hatted.u.*a.ux+(a.wi.*a.gamma).*a.uz-a.b/a.D.*a.u;
                expected.v=a.hatted.u.*a.vx+(a.wi.*a.gamma).*a.vz-a.b/a.D.*a.v;
                Pu=(a.zeta/a.D.*a.px-a.s.*a.zx.*a.pz)/a.rho0;
                Hu=-expected.u+a.f*a.hatted.v-a.px/a.rho0-Pu;
                logX=a.zx./(a.D*a.gamma);
                bx=(a.bx.*a.gamma-a.b.*a.zx/a.D)./(a.D*a.gamma.^2);
                expected.w=(a.hatted.u.*a.wx+a.wi.*a.gamma.*a.wz)./a.gamma+a.D*a.s.*(Hu.*logX+a.hatted.u.*bx);
                expected.eta=(a.hatted.u.*a.etax+a.wi.*a.gamma.*a.etaz-a.s.*a.hatted.u.*a.zx)./a.gamma;
                for form=["divergence","advective","split"]
                    result=advectionFormTerms(a.hatted,a.p,a.xi(:),a.D,a.f,a.rho0,a.q(:),remainder,D,form);
                    for field=["u","v","w","eta"]
                        testCase.verifyEqual(result.N.(field),expected.(field),AbsTol=2e-14);
                    end
                end
            end
        end
        function compatibleScalarBudgetIncludesEndpoints(testCase)
            % Arbitrary arrays expose aliasing; the algebra must hold even unresolved.
            rng(483); n=17; a=thermodynamicFormulationFixture("constant",.1,16,n);
            z=a.xi(:); x=1+2*z/a.D; V=cos(acos(x)*(0:n-1));
            moments=zeros(n,1); moments(1:2:end)=a.D./(1-(0:2:n-1).^2);
            weights=V.'\moments;
            points=z-z'; points(1:n+1:end)=1; bw=(-1).^(0:n-1)'; bw([1 end])=bw([1 end])/2;
            Dz=(bw'./bw)./points; Dz(1:n+1:end)=0; Dz(1:n+1:end)=-sum(Dz,2);
            B=zeros(n); B(1,1)=-1; B(end,end)=1;
            adj=(B-Dz'.*weights')./weights;
            D=a.derivative; D.adjointXi=@(f)reshape(reshape(f,[],n)*adj',size(f));
            q=randn(16,1,n); u=randn(size(q)); v=zeros(size(q)); w=randn(size(q)); c=randn(size(q));
            M=advectionTransport(q,u,v,w,c,D,"compatible");
            lhs=sum(reshape(weights,1,1,n).*q.*M,'all');
            rhs=.5*sum(w(:,:,end).*q(:,:,end).^2-w(:,:,1).*q(:,:,1).^2,'all')-.5*sum(reshape(weights,1,1,n).*c.*q.^2,'all');
            testCase.verifyEqual(lhs,rhs,AbsTol=2e-11);
        end
        function divergenceMatchesProductionAllFamiliesAndClocks(testCase)
            for profile=["constant","exponential"]
                w=makeAdvectionStudyTransform(profile,[8 33 3 4 2 3]);
                seed=manuscriptEvolutionOperators(w,profile,padding=1); a=seed.seed("mixed",.1);
                production=thermodynamicComparisonOperators(w,profile,"displacement");
                candidate=advectionStudyOperators(w,profile,"divergence");
                for time=[327 901]
                    expected=production.rhs(time,a); actual=candidate.rhs(time,a);
                    for family=string(fieldnames(a)).'
                        testCase.verifyEqual(actual.(family),expected.(family),AbsTol=2e-18+1e-11*max(abs(expected.(family)),[],'all'));
                    end
                end
            end
        end
    end
end
