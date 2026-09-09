classdef TestFreeSurfaceBulkConstruction < matlab.unittest.TestCase
    % Compare exact bulk construction with independently solved wave pencils.
    properties (TestParameter)
        profile = {"constant","exponential"}
    end

    methods (Test, TestTags="full")
        function bulkConstructionPreservesResolvedRepresentation(testCase,profile)
            if profile == "constant"
                N2 = @(z) 1e-4*ones(size(z));
                waveCount = 3; inertialCount = 5;
            else
                N2 = @(z) 1e-4*exp(2*z/700);
                waveCount = 4; inertialCount = 2;
            end
            bulk = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 8e4 1000],[16 12 65],N2Function=N2,waveModeCount=waveCount,inertialModeCount=inertialCount,apvModeCount=3,mdaModeCount=2);
            testCase.verifyGreaterThan(numel(bulk.khUnique),16)
            testCase.verifySize(bulk.Aw_p,[waveCount numel(bulk.klNonzero)])
            testCase.verifySize(bulk.Aio,[inertialCount 1])
            scalarState = independentlySolvedState(bulk);
            scalar = WVTransformFreeSurfaceBoussinesq(scalarState);
            bulkState = bulk.scientificState();
            changed = ["waveF","waveG","waveGForward","waveEquivalentDepth","waveFrequency","waveGramError","inertialF","inertialFForward","inertialEquivalentDepth","inertialGramError"];
            for name = string(fieldnames(bulkState)).'
                if ismember(name,changed)
                    actual = bulkState.(name); expected = scalarState.(name);
                    if endsWith(name,"GramError")
                        testCase.verifyEqual(actual,expected,name,AbsTol=1e-9)
                    else
                        testCase.verifyLessThan(norm(actual(:)-expected(:))/max(norm(expected(:)),realmin),1e-9,name)
                    end
                else
                    testCase.verifyEqual(bulkState.(name),scalarState.(name),name)
                end
            end
            state = bulk.coefficientState();
            for name = string(fieldnames(state)).'
                ordinal = reshape(1:numel(state.(name)),size(state.(name)));
                if startsWith(name,"Ag_"), scale = 1e-9; else, scale = 1e-3; end
                if name == "Amda", value = scale*cos(ordinal); else, value = scale*exp(1i*ordinal)./(1+ordinal); end
                bulk.(name) = value; scalar.(name) = value;
            end
            for t = [0 1234]
                bulk.t = t; scalar.t = t;
                actual = bulk.reconstructFields(["u","v","w","eta","p","ssh"]);
                expected = scalar.reconstructFields(["u","v","w","eta","p","ssh"]);
                for name = string(fieldnames(actual)).'
                    actualField = actual.(name); expectedField = expected.(name);
                    testCase.verifyLessThan(norm(actualField(:)-expectedField(:))/max(norm(expectedField(:)),realmin),1e-8,name)
                end
                testCase.verifyEqual(bulk.totalEnergy,scalar.totalEnergy,RelTol=1e-8)
                sources = rmfield(expected,{'p','ssh'});
                actualTendency = bulk.projectSources(sources);
                expectedTendency = scalar.projectSources(sources);
                for name = string(fieldnames(actualTendency)).'
                    testCase.verifyEqual(actualTendency.(name),expectedTendency.(name),name,AbsTol=1e-11,RelTol=1e-8)
                end
            end
            testCase.verifyEmpty(bulk.verticalModes)
        end
    end
end

function state = independentlySolvedState(wvt)
% The previous constructor already deduplicated horizontal wavenumbers.
% Solve each distinct pencil separately to check shared preparation/evaluation.
state = wvt.scientificState();
solver = IMSolverSpectral(nEVP=wvt.nEVP,coordinateKind="wkb");
for p = 0:numel(wvt.khUnique)
    if p == 0, kh = 0; count = numel(wvt.inertialMode); else, kh = wvt.khUnique(p); count = numel(wvt.waveMode); end
    evp = IMInternalModes.waveModesAtWavenumber(N2=wvt.N2Function,zDomain=[-wvt.Lz 0],k=kh,f0=wvt.f,g=wvt.g,surfaceBoundary=IMBoundaryCondition(a=0,b=1,c=1,d=0));
    basis = solver.solveEVP(evp,nModes=count);
    F = basis.F(wvt.z); G = basis.G(wvt.z); h = basis.h(:);
    if p == 0
        state.inertialF = F;
        state.inertialFForward = (F'.*wvt.verticalQuadratureWeights.')./h;
        state.inertialEquivalentDepth = h;
        state.inertialModeNumber = basis.modeNumber(:);
        state.inertialGramError = norm(state.inertialFForward*F-eye(count),2);
    else
        forward = G'.*(wvt.verticalQuadratureWeights.*((wvt.N2Function(wvt.z)-wvt.f^2)/wvt.g)).';
        forward(:,end) = forward(:,end)+G(end,:).';
        state.waveF(:,:,p) = F; state.waveG(:,:,p) = G;
        state.waveGForward(:,:,p) = forward; state.waveEquivalentDepth(:,p) = h;
        state.waveFrequency(:,p) = sqrt(wvt.f^2+wvt.g*h*kh^2);
        state.waveGramError(p) = norm(forward*G-eye(count),2);
        if p == 1, state.waveModeNumber = basis.modeNumber(:); end
    end
end
end
