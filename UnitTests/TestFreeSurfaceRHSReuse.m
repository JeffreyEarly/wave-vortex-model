classdef TestFreeSurfaceRHSReuse < matlab.unittest.TestCase
    properties
        scientificState
    end
    methods (TestClassSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'UnitTests','ReferenceImplementations')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(root),'OceanKit','tools','profiling')));
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4*exp(z/650),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,shouldAntialias=true);
            testCase.scientificState=w.scientificState();
        end
    end
    methods (Test, TestTags="full")
        function sourcesAndProjectionMatchAcrossStates(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState);
            initial=seed(w); context=WVInternal.freeSurfaceThermodynamics(w);
            for family=[string(fieldnames(initial)).',"mixed"]
                w.removeAll();
                if family=="mixed", assign(w,initial); else, w.Amda=initial.Amda; w.(family)=initial.(family); end
                for time=[0 327 901]
                    w.t=time;
                    [expected.u,expected.v,expected.w,expected.eta]=fullBoussinesqNonlinearReference(w,context);
                    reference=fullBoussinesqProjectionReference(w,expected);
                    paired=w.projectSources(expected);
                    for name=string(fieldnames(reference)).'
                        testCase.verifyEqual(paired.(name),reference.(name),AbsTol=2e-12*max(abs(reference.(name)),[],'all')+1e-22)
                    end
                    for request=["cold","warm","overlap"]
                        if request=="overlap"
                            w.clearVariableCacheOfApAmA0DependentVariables();
                            w.reconstructFields(["u_hat","p","ssh"]);
                        end
                        [actual.u,actual.v,actual.w,actual.eta]=w.nonlinearAdvectionSources();
                        for name=["u","v","w","eta"]
                            testCase.verifyEqual(actual.(name),expected.(name),AbsTol=3e-10*max(abs(expected.(name)),[],'all')+1e-17)
                        end
                        rate=w.projectSources(actual);
                        % Symmetry-zero projections need an absolute roundoff floor.
                        for name=string(fieldnames(reference)).'
                            testCase.verifyEqual(rate.(name),reference.(name),AbsTol=3e-10*max(abs(reference.(name)),[],'all')+1e-18)
                        end
                        testCase.verifyFalse(isKey(w.variableCache,'qgpv'))
                    end
                end
            end
        end
        function warmRHSReusesReconstructionAndRestart(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState); assign(w,seed(w));
            w.t=327; w.t0=-17;
            w.nonlinearAdvectionSources();
            profile=profileCodeHotspots(@()w.nonlinearAdvectionSources(),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(profile.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file=fullfile(folder.Folder,'rhs.nc'); nc=w.writeToFile(file); nc.close();
            restored=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
            for change=1:3
                if change==2, restored.t0=19; end
                if change==3, restored.Aw_p=2*restored.Aw_p; end
                [expected.u,expected.v,expected.w,expected.eta]=fullBoussinesqNonlinearReference(restored);
                [actual.u,actual.v,actual.w,actual.eta]=restored.nonlinearAdvectionSources();
                for name=["u","v","w","eta"]
                    testCase.verifyEqual(actual.(name),expected.(name),AbsTol=3e-10*max(abs(expected.(name)),[],'all')+1e-17)
                end
            end
        end
    end
end

function state=seed(w)
% Mean endpoint offsets keep parcel labels valid for each family control.
study=manuscriptEvolutionOperators(w,"exponential",padding=1);
state=study.seed("mixed",1);
end
function assign(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
