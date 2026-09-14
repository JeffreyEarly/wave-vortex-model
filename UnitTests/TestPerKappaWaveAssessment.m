classdef TestPerKappaWaveAssessment < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function defaultReferenceChecksEveryRequestedPrefix(testCase)
            [w,a]=newTransform();
            testCase.verifyEqual(a.pages.requestedCount,w.waveModeCountByKh)
            testCase.verifyEqual(a.pages.selectedCount,w.waveModeCountByKh)
            testCase.verifyEqual(a.pages.status,repmat("accepted",numel(w.khUnique),1))
            testCase.verifyEqual(a.pages.convergedCount,w.waveModeCountByKh)
            testCase.verifyNotEmpty(a.referenceNEVP)
            testCase.verifyNotEmpty(a.inertial.convergence)
        end

        function explicitReferenceAssessesActualPageIdentities(testCase)
            baseline = newTransform();
            counts = mod(2*(0:numel(baseline.khUnique)-1).',5);
            [w,a] = newTransform(waveModeKappa=flipud(baseline.khUnique),waveModeCount=flipud(counts),referenceNEVP=128);
            testCase.verifyEqual(a.pages.requestedCount,counts)
            testCase.verifyEqual(a.pages.convergedCount,counts)
            testCase.verifyEqual(a.pages.gridSupportedCount,counts)
            testCase.verifyEqual(a.pages.usableCount,counts)
            testCase.verifyEqual(a.pages.candidateLimitReached,counts>0)
            for p = 1:numel(counts)
                if counts(p)==0
                    testCase.verifyEqual(a.pages.status(p),"not-requested")
                    testCase.verifyEmpty(a.modeConvergence{p})
                    testCase.verifyEmpty(a.prefixGramError{p})
                else
                    report = a.modeConvergence{p};
                    testCase.verifyEqual(report.identity.kappa,w.khUnique(p))
                    testCase.verifyEqual(report.identity.columnLabels,string(w.waveModeNumber(1:counts(p))).')
                    testCase.verifyEqual(report.provenance.candidate.nEVP,w.nEVP)
                    testCase.verifyEqual(report.provenance.reference.nEVP,128)
                    testCase.verifyEqual(report.provenance.candidate.source,"explicit construction basis")
                    testCase.verifyEqual(report.coverage.requestedColumnCount,counts(p))
                    testCase.verifyFalse(report.coverage.absoluteAccuracyGuarantee)
                    testCase.verifyEqual(a.pages.status(p),"accepted")
                end
            end
            testCase.verifyEqual(a.inertial.requestedCount,numel(w.inertialMode))
            testCase.verifyEqual(a.inertial.convergence.identity.kappa,0)
            testCase.verifyEqual(a.inertial.convergence.identity.columnLabels,string(w.inertialModeNumber).')
            rows = ismember(a.inertial.convergence.measurements.quantity,["h1","equivalentDepth"]);
            testCase.verifyLessThan(max(a.inertial.convergence.measurements.value(rows)),1e-6)
        end

        function convergenceToleranceIsAConstructionRequirement(testCase)
            testCase.verifyError(@()newTransform(referenceNEVP=128,modeConvergenceTolerance=1e-16),'WV:UnconvergedBalancedModes')
            [w,a]=newTransform(referenceNEVP=128); plain=newTransform();
            original=w.scientificState(); without=plain.scientificState();
            testCase.verifyEqual(rmfield(original,{'N2Function','rhoFunction'}),rmfield(without,{'N2Function','rhoFunction'}))
            testCase.verifyTrue(all(a.pages.status=="accepted"))
        end

        function absentWavesStillAssessIndependentInertialFamily(testCase)
            [w,a] = newTransform(waveModeCount=0,referenceNEVP=128);
            testCase.verifyEmpty(w.waveMode)
            testCase.verifyEqual(a.pages.status,repmat("not-requested",numel(w.khUnique),1))
            testCase.verifyEqual(a.pages.usableCount,zeros(numel(w.khUnique),1))
            testCase.verifyFalse(any(a.pages.candidateLimitReached))
            testCase.verifyEqual(a.inertial.convergence.coverage.requestedColumnCount,3)
        end

        function commonQuadraturePreservesIndependentPageReports(testCase)
            configurations = {
                struct(Lxyz=[1e5 1e5 1000],N2Function=@(z)1e-4*exp(2*z/700),referenceNEVP=96)
                struct(Lxyz=[1e5 1e5 700],N2Function=@(z)8e-5*ones(size(z)),referenceNEVP=112)
                };
            for iConfiguration = 1:numel(configurations)
                configuration = configurations{iConfiguration};
                w = newTransform(Lxyz=configuration.Lxyz,Nxyz=[8 8 33],N2Function=configuration.N2Function,waveModeCount=3,referenceNEVP=configuration.referenceNEVP);
                counts = zeros(size(w.khUnique));
                active = unique([1;ceil(numel(counts)/2);numel(counts)]);
                counts(active) = (1:numel(active)).';
                [state,bases] = assessmentFixture(w,counts);
                [actual,reference] = WVInternal.assessWaveModeConstruction(state,bases,active,configuration.referenceNEVP,w.modeConvergenceTolerance);
                testCase.verifyEqual(actual.pages.status(active),repmat("accepted",numel(active),1))
                testCase.verifyEqual(actual.pages.status(counts==0),repmat("not-requested",nnz(counts==0),1))
                testCase.verifyEqual(actual.pages.convergedCount(active),counts(active))
                testCase.verifyTrue(all(cellfun(@isempty,actual.modeConvergence(counts==0))))
                for p = reshape(active,1,[])
                    page = find(active==p)+1;
                    expected = independentPageReport(bases.bases{bases.basisIndex(page)},reference.bases{reference.basisIndex(page)},state.khUnique(p),state.nEVP,configuration.referenceNEVP);
                    verifyStableReport(testCase,actual.modeConvergence{p},expected)
                end
                expected = independentPageReport(bases.bases{bases.basisIndex(1)},reference.bases{reference.basisIndex(1)},0,state.nEVP,configuration.referenceNEVP);
                verifyStableReport(testCase,actual.inertial.convergence,expected)
                testCase.verifyEqual(actual.inertial.convergedCount,numel(state.inertialMode))
            end

            [withoutReference,reference] = WVInternal.assessWaveModeConstruction(state,bases,active,[],w.modeConvergenceTolerance);
            testCase.verifyEmpty(reference)
            testCase.verifyEqual(withoutReference.pages.status(active),repmat("reference-not-requested",numel(active),1))
            testCase.verifyEqual(withoutReference.pages.status(counts==0),repmat("not-requested",nnz(counts==0),1))
            testCase.verifyTrue(all(isnan(withoutReference.pages.convergedCount(active))))
            testCase.verifyTrue(all(isnan(withoutReference.pages.usableCount(active))))
            testCase.verifyTrue(all(cellfun(@isempty,withoutReference.modeConvergence)))
            testCase.verifyEmpty(withoutReference.inertial.convergence)
            testCase.verifyTrue(isnan(withoutReference.inertial.convergedCount))

            [state,bases] = assessmentFixture(w,zeros(size(w.khUnique)));
            [inertialOnly,reference] = WVInternal.assessWaveModeConstruction(state,bases,zeros(0,1),configuration.referenceNEVP,w.modeConvergenceTolerance);
            testCase.verifyEqual(inertialOnly.pages.status,repmat("not-requested",numel(w.khUnique),1))
            testCase.verifyTrue(all(cellfun(@isempty,inertialOnly.modeConvergence)))
            expected = independentPageReport(bases.bases{bases.basisIndex(1)},reference.bases{reference.basisIndex(1)},0,state.nEVP,configuration.referenceNEVP);
            verifyStableReport(testCase,inertialOnly.inertial.convergence,expected)
            testCase.verifyEqual(inertialOnly.inertial.convergedCount,numel(state.inertialMode))
            testCase.verifyEqual(inertialOnly.inertial.usableCount,numel(state.inertialMode))
        end

        function referenceResolutionMustActuallyRefine(testCase)
            for resolution = {32,64,[96;128]}
                testCase.verifyError(@()newTransform(referenceNEVP=resolution{1}),'WVTransformFreeSurfaceBoussinesq:InvalidReferenceResolution')
            end
        end
    end
end

function [w,a] = newTransform(options)
arguments (Input)
    options.Lxyz (1,3) double = [1e5 1e5 1000]
    options.Nxyz (1,3) double = [8 8 65]
    options.N2Function function_handle = @(z)1e-4*exp(2*z/700)
    options.waveModeCount (:,1) double = 4
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.referenceNEVP (:,1) double = zeros(0,1)
    options.modeConvergenceTolerance (1,1) double = 1e-6
end
Lxyz = options.Lxyz;
Nxyz = options.Nxyz;
N2Function = options.N2Function;
options = rmfield(options,{'Lxyz','Nxyz','N2Function'});
args = namedargs2cell(options);
[w,a] = WVTransformFreeSurfaceBoussinesq.fromStratification(Lxyz,Nxyz,args{:},shouldAntialias=true,N2Function=N2Function,apvModeCount=3,mdaModeCount=2,inertialModeCount=3);
end

function [state,bases] = assessmentFixture(w,counts)
state = w.scientificState();
state.waveModeCountByKh = counts;
options = struct(rotationRate=w.rotationRate,latitude=w.latitude,g=w.g,nEVP=w.nEVP,inertialModeCount=numel(w.inertialMode));
[state,bases] = WVInternal.buildFreeSurfaceWaveState(state,options);
end

function report = independentPageReport(candidate,reference,kappa,nEVP,referenceNEVP)
nQuadrature = 2*max(nEVP,referenceNEVP)+1;
rule = IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(candidate.evp);
[z,weights] = rule.nativeQuadratureRule(candidate.zDomain);
report = assessModeConvergence(prepare(candidate,nEVP),prepare(reference,referenceNEVP),z,weights);

    function value = prepare(basis,basisNEVP)
        factors = basis.normalizationFactors(basis.normalization);
        dG = basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
        dF = basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors.*basis.h(:).';
        identity = struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber),normalization=string(basis.normalization),zDomain=basis.zDomain,kappa=kappa);
        provenance = struct(solverClass="IMSolverSpectral",coordinateKind="wkb",nEVP=basisNEVP,quadratureCount=nQuadrature,source="explicit construction basis");
        value = struct(identity=identity,values=struct(F=basis.F(z),G=basis.G(z)),derivatives=struct(F=dF,G=dG),equivalentDepths=basis.h,provenance=provenance);
    end
end

function verifyStableReport(testCase,actual,expected)
testCase.verifyEqual(string(fieldnames(actual)),string(fieldnames(expected)))
testCase.verifyEqual(actual.identity,expected.identity)
testCase.verifyEqual(actual.matches,expected.matches)
testCase.verifyEqual(removevars(actual.measurements,"value"),removevars(expected.measurements,"value"))
testCase.verifyEqual(isnan(actual.measurements.value),isnan(expected.measurements.value))
measured = isfinite(expected.measurements.value);
testCase.verifyEqual(actual.measurements.value(measured),expected.measurements.value(measured),AbsTol=1e-12)
testCase.verifyEqual(actual.provenance,expected.provenance)
testCase.verifyEqual(actual.coverage,expected.coverage)
testCase.verifyEqual(string(fieldnames(actual.costs)),string(fieldnames(expected.costs)))
end
