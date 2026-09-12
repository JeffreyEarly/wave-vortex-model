classdef TestFreeSurfaceRHSScheduling < matlab.unittest.TestCase
    properties
        scientificStates
    end
    methods (TestClassSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','rhs-scheduling-study')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(root),'OceanKit','tools','profiling')));
            for profile=["constant","exponential"]
                if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=N2,apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
                testCase.scientificStates.(profile)=w.scientificState();
            end
        end
    end
    methods (Test, TestTags="full")
        function sourcesAndCallbackMatchFrozenBaseline(testCase)
            for profile=["constant","exponential"]
                scientific=testCase.scientificStates.(profile);
                actual=WVTransformFreeSurfaceBoussinesq(scientific); expected=RHSSchedulingReference(scientific);
                actual.addForcing(WVNonlinearAdvection(actual)); expected.addForcing(WVNonlinearAdvection(expected));
                study=manuscriptEvolutionOperators(actual,profile,padding=1);
                for amplitude=[1e-4 .1 1]
                    initial=study.seed("mixed",amplitude);
                    for family=[string(fieldnames(initial)).',"mixed"]
                        actual.removeAll(); expected.removeAll();
                        if family=="mixed", state=initial; else
                            state=actual.coefficientState(); state.Amda=initial.Amda; state.(family)=initial.(family);
                        end
                        assign(actual,state); assign(expected,state);
                        for time=[0 327 901]
                            actual.t=time; expected.t=time; actual.t0=-17; expected.t0=-17;
                            for mode=["cold","warm","overlap"]
                                for w={actual,expected}
                                    if mode=="cold" || mode=="overlap", w{1}.clearVariableCacheOfApAmA0DependentVariables(); end
                                    if mode=="overlap", w{1}.reconstructFields(["u_hat","p","ssh"]); end
                                end
                                [a.u,a.v,a.w,a.eta]=actual.nonlinearAdvectionSources();
                                [b.u,b.v,b.w,b.eta]=expected.nonlinearAdvectionSources();
                                testCase.verifyEqual(a,b)
                                testCase.verifyEqual(actual.coefficientTendency(),expected.coefficientTendency())
                            end
                        end
                    end
                end
            end
        end
        function invalidationAndRestartKeepExactSources(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificStates.exponential);
            study=manuscriptEvolutionOperators(w,"exponential",padding=1); assign(w,study.seed("mixed",.1));
            w.t=327; w.t0=-17; w.nonlinearAdvectionSources();
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file=fullfile(folder.Folder,'scheduling.nc'); nc=w.writeToFile(file); nc.close();
            restored=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
            reference=RHSSchedulingReference(restored.scientificState());
            for change=1:8
                if change==2, restored.t=901; elseif change==3, restored.t0=19; elseif change>3
                    names=["Aw_p","Aw_m","Ag_q","Ag_0","Aio"]; name=names(change-3); restored.(name)=1.1*restored.(name);
                end
                assign(reference,restored.coefficientState()); reference.t=restored.t; reference.t0=restored.t0;
                [a.u,a.v,a.w,a.eta]=restored.nonlinearAdvectionSources();
                [b.u,b.v,b.w,b.eta]=reference.nonlinearAdvectionSources();
                testCase.verifyEqual(a,b)
            end
        end
        function unequalWaveCountsMatchFrozenBaseline(testCase)
            base=WVTransformFreeSurfaceBoussinesq(testCase.scientificStates.exponential);
            counts=2+mod((1:numel(base.khUnique)).',3);
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4*exp(z/650),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeKappa=base.khUnique,waveModeCount=counts,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
            reference=RHSSchedulingReference(w.scientificState());
            study=manuscriptEvolutionOperators(w,"exponential",padding=1); initial=study.seed("mixed",.1);
            assign(w,initial); assign(reference,initial); w.t=901; reference.t=901;
            [a.u,a.v,a.w,a.eta]=w.nonlinearAdvectionSources();
            [b.u,b.v,b.w,b.eta]=reference.nonlinearAdvectionSources();
            testCase.verifyEqual(a,b)
            testCase.verifyEqual(w.projectSources(a),reference.projectSources(b))
        end
        function totalReconstructionAvoidsAnnotationConstruction(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificStates.constant);
            study=manuscriptEvolutionOperators(w,"constant",padding=1); assign(w,study.seed("mixed",.1));
            result=profileCodeHotspots(@()w.reconstructFields(["u_hat","v_hat","w_hat","eta","p","ssh"]),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(result.functionMetrics.functionName,'WVCoefficientAnnotation')))
            result=profileCodeHotspots(@()w.nonlinearAdvectionSources(),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(result.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
        end
    end
end
function assign(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
