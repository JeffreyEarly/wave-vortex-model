classdef TestSeasonalResponseAssessment < matlab.unittest.TestCase
    % Public response estimates preserve the resolved modal state contract.
    properties
        transforms
    end
    methods (TestClassSetup)
        function createReferences(testCase)
            testCase.transforms = cell(1,3);
            counts = [17 33 65];
            for j = 1:3
                testCase.transforms{j} = WVTransformFreeSurfaceQG([100e3 100e3 4000],[4 4 counts(j)], ...
                    N2Function=@(z)ones(size(z))*2.704e-5,latitude=24,g0=-.10816,gd=.10816,shouldAntialias=false);
            end
        end
    end
    methods (Test, TestTags="full")
        function decompositionAndReferenceEvidence(testCase)
            [d,f] = testCase.problem();
            r = d.assessSeasonalResponse(f,[0 .25 .7]*f.period,referenceTransforms=testCase.transforms(2:3));
            testCase.verifyEqual(r.configuration.N2Profiles,cellfun(@(w)w.N2,testCase.transforms,UniformOutput=false))
            testCase.verifyEmpty(r.acceptance)
            testCase.verifyEmpty(r.reference.acceptance)
            testCase.verifyEqual(r.total.absolute{1,2:end},zeros(1,9),AbsTol=0)
            testCase.verifyEqual(r.total.relative{1,2:end},zeros(1,9),AbsTol=0)
            testCase.verifyGreaterThan(r.representation.absolute.qgpv(2),0)
            testCase.verifyGreaterThan(r.evolution.absolute.qgpv(2),0)
            testCase.verifyGreaterThan(r.reference.convergence.absolute.qgpv(2),0)
            testCase.verifyEqual(r.total.absolute.qgpv.^2, ...
                r.representation.absolute.qgpv.^2+r.evolution.absolute.qgpv.^2,RelTol=1e-10,AbsTol=1e-30)
            testCase.verifyLessThan(max(r.representation.absolute.surfaceAnomaly),1e-12)
            testCase.verifyLessThan(max(r.representation.absolute.bottomAnomaly),1e-12)
            testCase.verifyEqual(r.total.absolute.surfaceAnomaly,r.evolution.absolute.surfaceAnomaly,AbsTol=1e-12)
        end
        function exactUndiffusedEndpointResponse(testCase)
            [d,f] = testCase.problem();
            d.kappa_z = 0;
            time = .31*f.period;
            r = d.assessSeasonalResponse(f,time,referenceTransforms=testCase.transforms(2:3));
            integral = f.amplitude*f.period/(2*pi)*(cos(f.phase)-cos(2*pi*time/f.period+f.phase));
            expected = abs(integral)*sqrt(mean(f.pattern.^2,'all'));
            testCase.verifyEqual(r.total.referenceMagnitude.surfaceAnomaly,expected,RelTol=1e-12)
            testCase.verifyLessThan(r.total.absolute.surfaceAnomaly,1e-12*expected)
            testCase.verifyLessThan(r.total.referenceMagnitude.bottomAnomaly,1e-12*expected)
            testCase.verifyLessThan(r.total.referenceMagnitude.qgpv,1e-17)
        end
        function zeroSourceAndOptionalTolerances(testCase)
            [d,f] = testCase.problem(0);
            r = d.assessSeasonalResponse(f,[0 f.period/4],referenceTransforms=testCase.transforms(2:3), ...
                absoluteTolerance=struct(qgpv=0),referenceRelativeTolerance=struct(energy=0));
            testCase.verifyEqual(r.total.absolute{:,2:end},zeros(2,9),AbsTol=0)
            testCase.verifyEqual(r.total.relative{:,2:end},zeros(2,9),AbsTol=0)
            testCase.verifyTrue(all(r.acceptance.qgpv))
            testCase.verifyTrue(all(r.reference.acceptance.energy))
            [d,f] = testCase.problem();
            r = d.assessSeasonalResponse(f,f.period/4,referenceTransforms=testCase.transforms(2:3), ...
                absoluteTolerance=struct(qgpv=0),relativeTolerance=struct(energy=1e6));
            testCase.verifyFalse(r.acceptance.qgpv)
            testCase.verifyTrue(r.acceptance.energy)
        end
        function multimodeAmplitudeAndWavenumberAccounting(testCase)
            [d,f] = testCase.problem();
            a = d.assessSeasonalResponse(f,f.period/4,referenceTransforms=testCase.transforms(2:3));
            [d,f] = testCase.problem(2e-7);
            b = d.assessSeasonalResponse(f,f.period/4,referenceTransforms=testCase.transforms(2:3));
            testCase.verifyEqual(b.total.absolute{:,2:6},2*a.total.absolute{:,2:6},RelTol=1e-12)
            testCase.verifyEqual(b.total.absolute{:,7:10},4*a.total.absolute{:,7:10},RelTol=1e-12)
            parts = arrayfun(@(p)p.total.absolute.qgpv,a.perWavenumber);
            testCase.verifyEqual(a.total.absolute.qgpv^2,sum(parts.^2),RelTol=1e-12)
            testCase.verifyGreaterThan(nnz([a.perWavenumber.forcingPower]>1e-20),1)
        end
        function validatesReferencesAndTolerances(testCase)
            [d,f] = testCase.problem();
            testCase.verifyError(@()d.assessSeasonalResponse(f,1),'WV:ResponseReferences')
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms=testCase.transforms([2 2])),'WV:ResponseReferences')
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms=testCase.transforms(2:3), ...
                absoluteTolerance=struct(typo=1)),'WV:ResponseTolerance')
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms=testCase.transforms(2:3), ...
                relativeTolerance=struct(qgpv=-1)),'WV:ResponseTolerance')
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms=testCase.transforms(2:3),quadratureCount=10),'WV:ResponseQuadrature')
            other = WVVerticalDiffusivity(testCase.transforms{2});
            testCase.verifyError(@()other.assessSeasonalResponse(f,1,referenceTransforms=testCase.transforms(2:3)),'WV:ResponseTransform')
        end
        function incompatiblePhysicsAndUnresolvedForcing(testCase)
            [d,f] = testCase.problem();
            bad = WVTransformFreeSurfaceQG([100e3 100e3 4000],[4 4 65], ...
                N2Function=@(z)ones(size(z))*2.8e-5,latitude=24,g0=-.10816,gd=.10816,shouldAntialias=false);
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms={testCase.transforms{2},bad}),'WV:ResponseStratification')
            bad = WVTransformFreeSurfaceQG([100e3 100e3 4000],[4 4 65], ...
                N2Function=@(z)ones(size(z))*2.704e-5,latitude=25,g0=-.10816,gd=.10816,shouldAntialias=false);
            testCase.verifyError(@()d.assessSeasonalResponse(f,1,referenceTransforms={testCase.transforms{2},bad}),'WV:ResponseCompatibility')
            w = testCase.transforms{1};
            unresolved = WVSeasonalSurfaceAnomalyForcing(w,pattern=cos(4*pi*w.X(:,:,1)/w.Lx),amplitude=1e-7);
            testCase.verifyError(@()d.assessSeasonalResponse(unresolved,1,referenceTransforms=testCase.transforms(2:3)),'WV:ResponseHorizontalResolution')
        end
        function currentStateAndSnapshotDoNotAffectPreflight(testCase)
            [d,f] = testCase.problem();
            w = testCase.transforms{1};
            baseline = d.assessSeasonalResponse(f,f.period/4,referenceTransforms=testCase.transforms(2:3));
            oldQ = w.Ag_q;
            oldTime = w.t;
            cleanup = onCleanup(@()restore(w,oldQ,oldTime));
            w.Ag_q = ones(size(w.Ag_q))*1e-8;
            w.t = 12345;
            state = w.Ag_q;
            r = d.assessSeasonalResponse(f,f.period/4,referenceTransforms=testCase.transforms(2:3));
            testCase.verifyEqual(r,baseline)
            testCase.verifyEqual(w.Ag_q,state)
            testCase.verifyEqual(w.t,12345)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(fixture.Folder,'assessment.nc');
            nc = w.writeToFile(file); nc.close();
            restored = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            file = fullfile(fixture.Folder,'reference.nc');
            nc = testCase.transforms{3}.writeToFile(file); nc.close();
            restoredReference = WVTransformFreeSurfaceQG.waveVortexTransformFromFile(file);
            restoredForcing = f.forcingWithResolutionOfTransform(restored);
            restoredDiffusion = WVVerticalDiffusivity(restored,kappa_z=d.kappa_z);
            r = restoredDiffusion.assessSeasonalResponse(restoredForcing,f.period/4,referenceTransforms={testCase.transforms{2},restoredReference});
            testCase.verifyEqual(r.total.absolute,baseline.total.absolute)
            clear cleanup
        end
    end
    methods
        function [d,f] = problem(testCase,amplitude)
            if nargin<2, amplitude = 1e-7; end
            w = testCase.transforms{1};
            pattern = cos(2*pi*w.Y(:,:,1)/w.Ly)+.3*cos(2*pi*(w.X(:,:,1)/w.Lx+w.Y(:,:,1)/w.Ly));
            f = WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=amplitude,phase=.37);
            d = WVVerticalDiffusivity(w,kappa_z=1e-5);
        end
    end
end
function restore(w,q,time)
w.Ag_q = q;
w.t = time;
end
