classdef TestBoussinesqRHSAssessment < matlab.unittest.TestCase
    properties
        states
    end
    methods (TestClassSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            for profile=["constant","exponential"]
                if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
                testCase.states.(profile)=w.scientificState();
            end
        end
    end
    methods (Test, TestTags="full")
        function nativeSourcesAndDualsMatchAllFamilies(testCase)
            for profile=["constant","exponential"]
                w=WVTransformFreeSurfaceBoussinesq(testCase.states.(profile));
                study=manuscriptEvolutionOperators(w,profile,padding=1); initial=study.seed("mixed",.1);
                for family=[string(fieldnames(initial)).',"mixed"]
                    w.removeAll(); w.Amda=initial.Amda;
                    if family=="mixed", assign(w,initial); else, w.(family)=initial.(family); end
                    for time=[327 901]
                        w.t=time; w.t0=-17;
                        p=WVInternal.prepareBoussinesqRHSAssessment(w);
                        e=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33]);
                        [s.u,s.v,s.w,s.eta]=w.nonlinearAdvectionSources(); rate=w.projectSources(s);
                        for name=string(fieldnames(rate)).'
                            testCase.verifyEqual(e.tendency.(name),rate.(name),AbsTol=3e-10*max(abs(rate.(name)),[],'all')+1e-18)
                        end
                        for name=["u","v","w","eta"]
                            testCase.verifyEqual(e.source.(name),w.transformFromSpatialDomainWithFourier(s.(name)),AbsTol=1e-17)
                        end
                    end
                end
            end
        end
        function unequalAndZeroWavePagesKeepTheProjection(testCase)
            base=WVTransformFreeSurfaceBoussinesq(testCase.states.constant);
            counts=mod((0:numel(base.khUnique)-1).',5);
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=3,waveModeCount=counts,waveModeKappa=base.khUnique,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
            study=manuscriptEvolutionOperators(base,"constant",padding=1); initial=study.seed("mixed",.01);
            initial.Aw_p=initial.Aw_p.*w.activeWaveModes; initial.Aw_m=initial.Aw_m.*w.activeWaveModes;
            assign(w,initial); w.t=901;
            p=WVInternal.prepareBoussinesqRHSAssessment(w); e=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33]);
            [source.u,source.v,source.w,source.eta]=w.nonlinearAdvectionSources(); expected=w.projectSources(source);
            for name=string(fieldnames(expected)).'
                testCase.verifyEqual(e.tendency.(name),expected.(name),AbsTol=3e-10*max(abs(expected.(name)),[],'all')+1e-18)
            end
            testCase.verifyEqual(e.tendency.Aw_p(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
        end
        function analyticPolynomialTransportIsRecovered(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.states.constant);
            p=WVInternal.prepareBoussinesqRHSAssessment(w); k=2*pi/w.Lx; U=.2;
            [X,~,Z]=ndgrid(w.x,w.y,w.z); s=1+Z/w.Lz;
            h=struct(u=U*cos(k*X).*(2*s-1),v=zeros(size(X)),w=U*k*w.Lz*sin(k*X).*(s.^2-s),eta=zeros(size(X)),p=zeros(size(X)));
            for name=["u","v","w","eta","p"], p.spectral.(name)=w.transformFromSpatialDomainWithFourier(h.(name)); end
            e=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 17]);
            [X,~,Z]=ndgrid(w.x,w.y,e.z); s=1+Z/w.Lz;
            exact=struct(u=U^2*k*cos(k*X).*sin(k*X).*(2*s.^2-2*s+1),v=zeros(size(X)),w=-U^2*k^2*w.Lz*(2*s-1).*(s.^2-s),eta=zeros(size(X)));
            g=WVGeometryDoublyPeriodic([w.Lx w.Ly],[8 6],Nz=17,shouldAntialias=false,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            for name=["u","v","w","eta"]
                expected=g.transformFromSpatialDomainWithFourier(exact.(name));
                testCase.verifyEqual(e.source.(name),expected,AbsTol=3e-12*max(abs(expected),[],'all')+1e-19)
            end
        end
        function snapshotAndReferenceQualificationStaySeparate(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.states.constant);
            study=manuscriptEvolutionOperators(w,"constant",padding=1); assign(w,study.seed("mixed",.1));
            state=w.coefficientState(); p=WVInternal.prepareBoussinesqRHSAssessment(w);
            e=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33]);
            w.Aw_p=2*w.Aw_p; w.t=w.t+10;
            again=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 6 33]);
            testCase.verifyEqual(again.tendency,e.tendency)
            testCase.verifyEqual(p.transform.coefficientState(),state)
            testCase.verifyFalse(w.shouldCheckQuadraticAliasing)
            h=e; h.grid=[16 12 33]; v=e; v.grid=[8 6 65];
            report=WVInternal.assessBoussinesqRHSResolution(e,e,{h,v}); testCase.verifyTrue(report.accepted)
            report=WVInternal.assessBoussinesqRHSResolution(e,e,{h}); testCase.verifyEqual(report.status,"reference-inconclusive")
            h.tendency.Aw_p(:)=NaN;
            report=WVInternal.assessBoussinesqRHSResolution(e,e,{h,v}); testCase.verifyEqual(report.status,"reference-inconclusive")
            h=e; h.grid=[16 12 33]; changed=e; changed.tendency.Aw_p=2*e.tendency.Aw_p;
            report=WVInternal.assessBoussinesqRHSResolution(changed,e,{h,v}); testCase.verifyEqual(report.status,"rejected")
            other=WVInternal.prepareBoussinesqRHSAssessment(w); changed.snapshot=other.transform;
            testCase.verifyError(@()WVInternal.assessBoussinesqRHSResolution(changed,e,{h,v}),'WV:AssessmentInventoryMismatch')
        end
    end
end
function assign(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
