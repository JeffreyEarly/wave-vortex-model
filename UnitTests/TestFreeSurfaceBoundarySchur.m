classdef TestFreeSurfaceBoundarySchur < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function inverseMatchesOperatorCompositionAcrossInventoriesAndClocks(testCase)
            uniform = newTransform();
            counts = mod((0:length(uniform.khUnique)-1).',3);
            configurations = [NaN NaN;Inf NaN;NaN Inf;Inf Inf];
            stream = RandStream('mt19937ar',Seed=3981);
            for configuration = 1:size(configurations,1)
                wvt = newTransform(waveModeKappa=uniform.khUnique,waveModeCount=counts,g0=configurations(configuration,1),gd=configurations(configuration,2));
                boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
                reference = WVInternal.freeSurfaceReferenceMass(wvt);
                schur = WVInternal.freeSurfaceBoundarySchur(wvt,boundary,reference);
                initialState = wvt.coefficientState();
                vector = randn(stream,boundary.dimension,1);
                baseline = schur.solve(vector);
                for time = [0 1927 1e5]
                    wvt.t = time; wvt.t0 = 37;
                    applied = boundary.apply(reference.solve(boundary.adjoint(vector)));
                    recovered = schur.solve(applied);
                    testCase.verifyLessThan(norm(recovered-vector)/norm(vector),2e-10)
                    recomposed = boundary.apply(reference.solve(boundary.adjoint(baseline)));
                    testCase.verifyLessThan(norm(recomposed-vector)/norm(vector),2e-10)
                    testCase.verifyEqual(schur.solve(vector),baseline)
                end
                testCase.verifyEqual(wvt.coefficientState(),initialState)
                testCase.verifyEqual([wvt.t,wvt.t0],[1e5,37])
                testCase.verifyTrue(any(counts==0))
                testCase.verifyEqual(size(schur.meanBlock.upperFactor,1),length(wvt.activeEndpoint))
                testCase.verifyError(@()schur.solve(complex(vector,ones(size(vector)))),'WV:BoundarySchurCoordinates')
            end
        end

        function unsupportedMeanConstraintsFailWithoutDroppingRows(testCase)
            wvt = newTransform(mdaModeCount=1);
            boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
            reference = WVInternal.freeSurfaceReferenceMass(wvt);
            testCase.verifySize(boundary.meanBlock,[2,1])
            testCase.verifyError(@()WVInternal.freeSurfaceBoundarySchur(wvt,boundary,reference),'WV:BoundarySchurRank')
        end

        function complexPageCouplingAndEmptyConstraintsAreHandled(testCase)
            wvt = newTransform();
            boundary = WVInternal.freeSurfaceBoundaryOperator(wvt);
            reference = WVInternal.freeSurfaceReferenceMass(wvt);
            % An invertible complex change of trace coordinates exercises
            % real/imaginary coupling that the current physical traces lack.
            transform = [1,.2i,0;0,1,.1i;.1,0,1];
            for page = 1:length(boundary.blocks)
                boundary.blocks{page} = transform*boundary.blocks{page};
            end
            schur = WVInternal.freeSurfaceBoundarySchur(wvt,boundary,reference);
            stream = RandStream('mt19937ar',Seed=798);
            vector = randn(stream,boundary.dimension,1);
            recovered = schur.solve(applyMetadataSchur(vector,boundary,reference));
            testCase.verifyLessThan(norm(recovered-vector)/norm(vector),2e-11)
            boundary.names = strings(1,0);
            boundary.dimension = 0;
            boundary.meanBlock = zeros(0,size(boundary.meanBlock,2));
            for page = 1:length(boundary.blocks)
                boundary.blocks{page} = zeros(0,size(boundary.blocks{page},2));
            end
            empty = WVInternal.freeSurfaceBoundarySchur(wvt,boundary,reference);
            testCase.verifySize(empty.solve(zeros(0,1)),[0,1])
        end
    end
end

function wvt = newTransform(options)
arguments (Input)
    options.waveModeCount (:,1) double = 2
    options.waveModeKappa (:,1) double = zeros(0,1)
    options.mdaModeCount (1,1) double = 2
    options.g0 (1,1) double = NaN
    options.gd (1,1) double = NaN
end
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},N2Function=@(z)1e-4*exp(2*z/700),apvModeCount=3,inertialModeCount=2,shouldAntialias=true);
end

function result = applyMetadataSchur(vector,boundary,reference)
nTrace = length(boundary.names);
nColumn = reference.nonzeroColumnCount;
number = nTrace*nColumn;
values = reshape(complex(vector(1:number),vector(number+(1:number))),nTrace,nColumn);
result = complex(zeros(size(values)));
for page = 1:length(reference.pages)
    block = reference.pages{page};
    C = boundary.blocks{page};
    % Apply C* then H0^-1 via the independently stored triangular factors,
    % avoiding construction of the tested Schur factorization.
    covector = C'*values(:,block.columns);
    solution = (block.upperFactor\(block.upperFactor'\(covector./block.diagonalScale)))./block.diagonalScale;
    result(:,block.columns) = 2*C*solution;
end
block = reference.meanMDA;
covector = boundary.meanBlock'*vector(2*number+1:end);
solution = (block.upperFactor\(block.upperFactor'\(covector./block.diagonalScale)))./block.diagonalScale;
means = boundary.meanBlock*solution;
result = [real(result(:));imag(result(:));real(means)];
end
