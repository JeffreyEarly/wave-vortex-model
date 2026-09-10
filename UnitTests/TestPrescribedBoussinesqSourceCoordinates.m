classdef TestPrescribedBoussinesqSourceCoordinates < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function declaredPatternsAndAbsoluteClockAreUnchanged(testCase)
            wvt = newTransform([8 8 33]);
            wvt.t = 371;
            wvt.t0 = -113;
            wvt.Aw_p(1,1) = 0.02+0.01i;
            original = wvt.coefficientState();
            options = sourceOptions(wvt);
            args = namedargs2cell(options);
            default = WVPrescribedBoussinesqSource(wvt,args{:});
            testCase.verifyEqual(default.sourceCoordinates,"reference")
            annotations = default.classDefinedPropertyAnnotations();
            testCase.verifyTrue(ismember('sourceCoordinates',{annotations.name}))
            testCase.verifyTrue(ismember('sourceCoordinates',default.classRequiredPropertyNames()))
            for coordinates = ["reference","physical"]
                source = WVPrescribedBoussinesqSource(wvt,args{:},sourceCoordinates=coordinates);
                testCase.verifyEqual(source.sourceCoordinates,coordinates)
                verifyCallback(testCase,wvt,source,options)
                wvt.t0 = 107;
                verifyCallback(testCase,wvt,source,options)
                wvt.t = 913;
                verifyCallback(testCase,wvt,source,options)
            end
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyError(@()WVPrescribedBoussinesqSource(wvt,sourceCoordinates="automatic"),'MATLAB:validators:mustBeMember')
            % The default continues through the existing linear projector.
            wvt.setForcing(default);
            rates = declaredRates(wvt,options);
            testCase.verifyEqual(wvt.coefficientTendency(),wvt.projectSources(rates))
        end

        function nativeRestorePreservesCoordinatesPatternsAndClock(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            wvt = newTransform([8 8 33]);
            wvt.t = 713;
            wvt.t0 = -51;
            options = sourceOptions(wvt);
            args = namedargs2cell(options);
            for coordinates = ["reference","physical"]
                source = WVPrescribedBoussinesqSource(wvt,args{:},sourceCoordinates=coordinates);
                wvt.setForcing(source);
                path = fullfile(fixture.Folder,coordinates+".nc");
                file = wvt.writeToFile(path);
                file.close();
                restored = WVTransform.waveVortexTransformFromFile(path);
                force = restored.forcingWithName(source.name);
                testCase.verifyClass(force,'WVPrescribedBoussinesqSource')
                testCase.verifyEqual(force.sourceCoordinates,coordinates)
                testCase.verifyTrue(force.wvt==restored)
                testCase.verifyEqual([restored.t,restored.t0],[713,-51])
                for name = string(fieldnames(options)).'
                    testCase.verifyEqual(force.(name),options.(name))
                end
                verifyCallback(testCase,restored,force,options)
                restored.t = 1729;
                restored.t0 = 299;
                verifyCallback(testCase,restored,force,options)
            end
        end

        function resolutionTransferPreservesDeclaredCoordinates(testCase)
            sourceTransform = newTransform([8 8 33]);
            target = newTransform([10 8 49]);
            sourceTransform.t = 317;
            sourceTransform.t0 = -57;
            target.t = 991;
            target.t0 = 73;
            options = sourceOptions(sourceTransform);
            expected = sourceOptions(target);
            args = namedargs2cell(options);
            for coordinates = ["reference","physical"]
                source = WVPrescribedBoussinesqSource(sourceTransform,args{:},sourceCoordinates=coordinates);
                converted = source.forcingWithResolutionOfTransform(target);
                testCase.verifyTrue(converted.wvt==target)
                testCase.verifyTrue(source.wvt==sourceTransform)
                testCase.verifyEqual(converted.sourceCoordinates,coordinates)
                for name = ["frequency","referenceTime","phase"]
                    testCase.verifyEqual(converted.(name),options.(name))
                end
                for name = ["uRate","vRate","wRate","etaRate"]
                    testCase.verifyEqual(converted.(name),expected.(name),AbsTol=1e-17)
                    testCase.verifyEqual(source.(name),options.(name))
                end
                verifyCallback(testCase,target,converted,expected,1e-17)
            end
            testCase.verifyEqual([sourceTransform.t,sourceTransform.t0,target.t,target.t0],[317,-57,991,73])
        end
    end
end

function wvt = newTransform(Nxyz)
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],Nxyz,N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,waveModeCount=2,inertialModeCount=2,shouldAntialias=true);
end

function options = sourceOptions(wvt)
[X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
options = struct(uRate=1e-7*(1+0.2*cos(2*pi*X/wvt.Lx)).*(1+Z/wvt.Lz),vRate=2e-7*sin(2*pi*Y/wvt.Ly).*(Z/wvt.Lz).^2,wRate=3e-8*cos(2*pi*(X/wvt.Lx+Y/wvt.Ly)).*(1+Z/wvt.Lz),etaRate=1e-6*(1+0.1*cos(2*pi*X/wvt.Lx)).*(1+Z/(2*wvt.Lz)),frequency=0.003,referenceTime=29,phase=0.4);
end

function rates = declaredRates(wvt,options)
scale = cos(options.frequency*(wvt.t-options.referenceTime)+options.phase);
for name = ["u","v","w","eta"]
    rates.(name) = scale*options.(name+"Rate");
end
end

function verifyCallback(testCase,wvt,source,options,tolerance)
arguments (Input)
    testCase
    wvt
    source
    options
    tolerance = 0
end
initial = 2e-8+zeros(wvt.spatialMatrixSize);
[actual.u,actual.v,actual.w,actual.eta] = source.addNonhydrostaticSpatialForcing(wvt,initial,2*initial,3*initial,4*initial);
expected = declaredRates(wvt,options);
names = ["u","v","w","eta"];
for index = 1:numel(names)
    name = names(index);
    testCase.verifyEqual(actual.(name),index*initial+expected.(name),AbsTol=tolerance)
end
end
