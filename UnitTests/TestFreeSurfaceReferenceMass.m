classdef TestFreeSurfaceReferenceMass < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function inverseRecoversMixedStatesAcrossClocksAndActivePrefixes(testCase)
            uniform = newTransform();
            counts = mod((0:length(uniform.khUnique)-1).',4);
            wvt = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts);
            original = wvt.coefficientState();
            context = WVInternal.freeSurfaceReferenceMass(wvt);
            metric = flatMetric(wvt);
            variation = randomVariation(wvt,24719);
            for time = [0 2718 1e5]
                wvt.t = time; wvt.t0 = 17;
                covector = WVInternal.freeSurfaceWeakMassAction(wvt,variation,metric);
                recovered = context.solve(covector);
                for family = string(fieldnames(variation)).'
                    expected = variation.(family);
                    testCase.verifyLessThan(norm(recovered.(family)-expected,'fro')/max(norm(expected,'fro'),realmin),2e-9)
                end
                reapplied = WVInternal.freeSurfaceWeakMassAction(wvt,recovered,metric);
                testCase.verifyLessThan(covectorError(reapplied,covector),2e-10)
                testCase.verifyEqual(recovered.Aw_p(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
                testCase.verifyEqual(recovered.Aw_m(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
            end
            testCase.verifyTrue(any(counts==0))
            testCase.verifyLessThan(length(context.pages),context.nonzeroColumnCount)
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t wvt.t0],[1e5 17])
            invalid = covector;
            invalid.Aw_p(find(~wvt.activeWaveModes,1)) = 1;
            testCase.verifyError(@()context.solve(invalid),'WV:ReferenceMassCovector')
            invalid = covector; invalid.Amda = complex(invalid.Amda,ones(size(invalid.Amda)));
            testCase.verifyError(@()context.solve(invalid),'WV:ReferenceMassCovector')
        end

        function sharedPageWhiteningMatchesEveryReconstructedOrientation(testCase)
            wvt = newTransform(Nxyz=[8 8 33],apvModeCount=2,waveModeCount=2,inertialModeCount=2);
            wvt.t = 0; wvt.t0 = 0;
            context = WVInternal.freeSurfaceReferenceMass(wvt);
            offDiagonalBalanced = 0;
            for page = 1:length(context.pages)
                block = context.pages{page};
                for column = block.columns.'
                    gram = reconstructedColumnGram(wvt,block,column);
                    whitened = block.whitening'*gram*block.whitening;
                    testCase.verifyLessThan(norm(whitened-eye(size(whitened)),2),5e-11)
                    nq = block.familySizes(1);
                    n0 = block.familySizes(2);
                    normalized = gram./sqrt(real(diag(gram))*real(diag(gram)).');
                    offDiagonalBalanced = max(offDiagonalBalanced,norm(normalized(1:nq,nq+(1:n0)),'fro'));
                end
            end
            % This fixture would detect discarding the APV/endpoint cross terms.
            testCase.verifyGreaterThan(offDiagonalBalanced,1e-3)
        end

        function emptyWaveAndEndpointFamiliesAndMeanBlocksRemainExact(testCase)
            wvt = newTransform(Nxyz=[4 4 33],waveModeCount=0,apvModeCount=2,inertialModeCount=2,g0=Inf,gd=Inf,latitude=-30);
            wvt.t = 731; wvt.t0 = -15;
            context = WVInternal.freeSurfaceReferenceMass(wvt);
            metric = flatMetric(wvt);
            variation = randomVariation(wvt,982);
            covector = WVInternal.freeSurfaceWeakMassAction(wvt,variation,metric);
            recovered = context.solve(covector);
            testCase.verifyEmpty(recovered.Aw_p)
            testCase.verifyEmpty(recovered.Aw_m)
            testCase.verifyEmpty(recovered.Ag_0)
            for family = ["Ag_q","Aio","Amda"]
                testCase.verifyEqual(recovered.(family),variation.(family),RelTol=2e-10,AbsTol=1e-14)
            end
            ioGram = 4*wvt.inertialF'*(wvt.verticalQuadratureWeights.*wvt.inertialF);
            mdaSSH = wvt.mdaPressureMode(end,:)/wvt.g;
            mdaGram = wvt.mdaG'*((wvt.verticalQuadratureWeights.*wvt.N2).*wvt.mdaG)+wvt.g*(mdaSSH'*mdaSSH);
            testCase.verifyEqual(context.meanInertial.whitening'*ioGram*context.meanInertial.whitening,eye(size(ioGram)),AbsTol=5e-13)
            testCase.verifyEqual(context.meanMDA.whitening'*mdaGram*context.meanMDA.whitening,eye(size(mdaGram)),AbsTol=5e-13)
        end
    end
end

function wvt = newTransform(options)
arguments (Input)
    options.Nxyz (1,3) double = [8 8 65]
    options.waveModeCount (:,1) double = 3
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.apvModeCount (1,1) double = 3
    options.inertialModeCount (1,1) double = 3
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
    options.latitude (1,1) double = 30
end
Nxyz = options.Nxyz; options = rmfield(options,'Nxyz');
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],Nxyz,args{:},N2Function=@(z)1e-4*exp(2*z/700),mdaModeCount=2,shouldAntialias=true);
end

function metric = flatMetric(wvt)
metric = struct(gamma=ones(wvt.Nx,wvt.Ny),betaX=zeros(wvt.Nx,wvt.Ny,wvt.Nz),betaY=zeros(wvt.Nx,wvt.Ny,wvt.Nz),displacementWeight=repmat(reshape(wvt.N2,1,1,[]),wvt.Nx,wvt.Ny,1));
end

function state = randomVariation(wvt,seed)
state = structfun(@(value)zeros(size(value)),wvt.coefficientState(),UniformOutput=false);
stream = RandStream('mt19937ar',Seed=seed);
for family = string(fieldnames(state)).'
    scale = .1;
    if ismember(family,["Ag_q","Ag_0"]), scale=1e-8; end
    state.(family) = scale*randn(stream,size(state.(family)));
    if family~="Amda", state.(family)=state.(family)+1i*scale*randn(stream,size(state.(family))); end
    if ismember(family,["Aw_p","Aw_m"]), state.(family)(~wvt.activeWaveModes)=0; end
end
end

function gram = reconstructedColumnGram(wvt,block,column)
zero = structfun(@(value)zeros(size(value)),wvt.coefficientState(),UniformOutput=false);
count = sum(block.familySizes);
matrix = complex(zeros(4*wvt.Nz+1,count));
weights = wvt.verticalQuadratureWeights;
index = 0;
for familyIndex = 1:length(block.familyOrder)
    family = block.familyOrder(familyIndex);
    for mode = 1:block.familySizes(familyIndex)
        state = zero; state.(family)(mode,column)=1;
        spectral = wvt.reconstructSpectralState(state=state);
        sourceColumn = wvt.klNonzero(column);
        index = index+1;
        matrix(:,index) = [sqrt(weights).*spectral.u(:,sourceColumn);sqrt(weights).*spectral.v(:,sourceColumn);sqrt(weights).*spectral.w(:,sourceColumn);sqrt(weights.*wvt.N2).*spectral.eta(:,sourceColumn);sqrt(wvt.g)*spectral.ssh(end,sourceColumn)];
    end
end
gram = 2*(matrix'*matrix);
end

function value = covectorError(actual,expected)
value = 0;
for family = string(fieldnames(expected)).'
    value = max(value,norm(actual.(family)-expected.(family),'fro')/max(norm(expected.(family),'fro'),realmin));
end
end
