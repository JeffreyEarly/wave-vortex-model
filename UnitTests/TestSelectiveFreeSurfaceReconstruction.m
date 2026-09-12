classdef TestSelectiveFreeSurfaceReconstruction < matlab.unittest.TestCase
    properties
        scientificState
    end
    methods (TestClassSetup)
        function setup(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'UnitTests','ReferenceImplementations')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(root),'OceanKit','tools','profiling')));
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 6 33],N2Function=@(z)1e-4*exp(z/650),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,shouldAntialias=true);
            testCase.scientificState=w.scientificState();
        end
    end
    methods (Test, TestTags="full")
        function everyFamilyAndRequestMatchesFrozenReference(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState);
            initial=seed(w);
            names=["ssh","ssu","ssv","u","v","w","u_hat","v_hat","w_hat","w_i","eta","eta_i","p","qgpv","z_physical"];
            for family=[string(fieldnames(initial)).',"mixed"]
                w.removeAll();
                if family=="mixed", assign(w,initial); else, w.(family)=initial.(family); end
                for time=[0 327 901]
                    w.t=time;
                    reference=fullBoussinesqFieldReference(w,names);
                    for name=names
                        actual=w.reconstructFields(name);
                        verifyFields(testCase,actual,reference,name)
                    end
                    w.clearVariableCacheOfApAmA0DependentVariables();
                    verifyFields(testCase,w.reconstructFields(names),reference,names)
                end
            end
        end

        function cacheMissesStayOnSurfaceAndWarmReadsDoNoSynthesis(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState); assign(w,seed(w));
            expected=fullBoussinesqFieldReference(w,["ssh","ssu","ssv"]);
            testCase.verifyEqual(w.ssh,expected.ssh,AbsTol=1e-13)
            testCase.verifyFalse(any(isKey(w.variableCache,{'u','v','w','p','eta','u_hat','v_hat','w_hat'})))
            warm=profileCodeHotspots(@()w.variableWithName('ssh'),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(warm.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
            [ssh,ssu]=w.variableWithName('ssh','ssu');
            testCase.verifyEqual(ssh,expected.ssh,AbsTol=1e-13)
            testCase.verifyEqual(ssu,expected.ssu,AbsTol=1e-13)
            testCase.verifyFalse(any(isKey(w.variableCache,{'u','v','w','p','eta','u_hat'})))
            direct=profileCodeHotspots(@()w.reconstructFields(["ssh","ssu"]),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(direct.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
            w.u_hat;
            w.removeFromVariableCache('ssu');
            dependency=profileCodeHotspots(@()w.variableWithName('ssu'),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(dependency.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
            w.clearVariableCacheOfApAmA0DependentVariables();
            w.p;
            pressure=profileCodeHotspots(@()w.variableWithName('ssh'),projectRoots=fileparts(fileparts(mfilename('fullpath'))));
            testCase.verifyFalse(any(contains(pressure.functionMetrics.functionName,'freeSurfaceSelectedSpectralFields')))
            w.t=w.t+123;
            testCase.verifyFalse(isKey(w.variableCache,'ssh'))
            testCase.verifyFalse(isKey(w.variableCache,'ssu'))
            w.ssh; w.t0=w.t0+1;
            testCase.verifyFalse(isKey(w.variableCache,'ssh'))
            w.ssh; w.Aw_p=2*w.Aw_p;
            testCase.verifyFalse(isKey(w.variableCache,'ssh'))
        end

        function componentGeometryAndCustomOperationsRemainDistinct(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState); assign(w,seed(w));
            names=["ssh","ssu","ssv","u","v","w","eta_i"];
            for label=["wave","apv","zeroapv","balanced","inertial","mda"]
                component=w.flowComponentWithName(char(label));
                reference=fullBoussinesqFieldReference(w,names,flowComponent=component);
                for name=names
                    actual=w.variableWithName(char(name+"_"+label));
                    testCase.verifyEqual(actual,reference.(name),AbsTol=2e-12*max(1,max(abs(reference.(name)),[],'all')))
                end
            end
            other=WVFlowComponent(w,coefficientMasks=struct(Amda=true));
            other.abbreviatedName='wave';
            expected=fullBoussinesqFieldReference(w,"eta",flowComponent=other);
            verifyFields(testCase,w.reconstructFields("eta",flowComponent=other),expected,"eta")
            custom=WVVariableAnnotation('custom',{'x','y'},'m','custom operation');
            w.addOperation(WVOperation('custom',custom,@(wvt)2*wvt.ssh));
            testCase.verifyEqual(w.variableWithName('custom'),2*w.ssh)
            w.t=1000;
            component=w.flowComponentWithName('balanced');
            expected=fullBoussinesqFieldReference(w,["ssu","u"],flowComponent=component);
            testCase.verifyEqual(w.ssu_balanced,expected.ssu,AbsTol=1e-13)
            testCase.verifyEqual(w.u_balanced,expected.u,AbsTol=1e-13)
        end

        function restartRebuildsSurfaceGeometryAndSharesGroupedCache(testCase)
            w=WVTransformFreeSurfaceBoussinesq(testCase.scientificState); assign(w,seed(w));
            w.t=327; w.t0=-17;
            names=["ssh","ssu","ssv","p","eta","w"];
            expected=w.reconstructFields(names);
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file=fullfile(folder.Folder,'selective.nc'); nc=w.writeToFile(file); nc.close();
            restored=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
            testCase.verifyEmpty(restored.verticalModes)
            verifyFields(testCase,restored.reconstructFields(names),expected,names)
            restored.clearVariableCacheOfApAmA0DependentVariables();
            restored.ssh;
            operation=restored.operationForKnownVariable('ssh','ssu');
            [ssh,ssu]=restored.performOperation(operation);
            testCase.verifyEqual(ssh,expected.ssh,AbsTol=1e-13)
            testCase.verifyEqual(ssu,expected.ssu,AbsTol=1e-13)
            testCase.verifyFalse(isKey(restored.variableCache,'u_hat'))
        end
    end
end

function state=seed(w)
state=w.coefficientState();
for name=string(fieldnames(state)).'
    a=state.(name); ordinal=reshape(1:numel(a),size(a));
    if name=="Ag_q" || name=="Ag_0", scale=1e-8; else, scale=.002; end
    if name=="Amda", a=scale*cos(ordinal); else, a=scale*exp(1i*ordinal)./(1+ordinal); end
    state.(name)=a;
end
end
function assign(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
function verifyFields(testCase,actual,expected,names)
for name=names
    testCase.verifyEqual(actual.(name),expected.(name),AbsTol=2e-12*max(1,max(abs(expected.(name)),[],'all')))
end
end
