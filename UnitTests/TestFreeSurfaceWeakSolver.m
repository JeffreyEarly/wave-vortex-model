classdef TestFreeSurfaceWeakSolver < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function coupledSolutionMatchesIndependentPhysicalGram(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfaceWeakSolver(wvt);
            initial = wvt.coefficientState();
            stream = RandStream('mt19937ar',Seed=75411);
            for time = [0,1371]
                wvt.t = time;
                metric = nonflatMetric(wvt);
                H = physicalGram(wvt,solver.layout,metric);
                n = solver.layout.dimension;
                K = zeros(solver.boundary.dimension,n);
                for index = 1:n
                    e = zeros(n,1); e(index)=1;
                    K(:,index) = solver.boundary.apply(solver.layout.unpack(e));
                end
                % An independent sample-space Gram specifies the exact
                % solution and a nonzero constraint reaction at this stage.
                expected = randn(stream,n,1)./sqrt(diag(H));
                multiplier = randn(stream,size(K,1),1);
                rhs = H*expected+K.'*multiplier;
                target = K*expected;
                [actual,report] = solver.solve(solver.layout.unpack(rhs),target,metric,tolerance=1e-11);
                difference = solver.layout.pack(actual)-expected;
                testCase.verifyLessThan(sqrt(difference.'*H*difference/(expected.'*H*expected)),2e-9)
                testCase.verifyLessThan(norm(K*solver.layout.pack(actual)-target)/norm(target),2e-12)
                testCase.verifyLessThan(norm(report.multiplier-multiplier)/norm(multiplier),2e-8)
                testCase.verifyLessThan(report.relativeResidual,5e-11)
                testCase.verifyLessThan(report.iterations,35)
                testCase.verifyEqual(wvt.coefficientState(),initial)
            end
            testCase.verifyEqual(wvt.t,1371)
        end

        function referenceMetricConvergesInOneStepWithVariableWaveCounts(testCase)
            uniform = newTransform(Nxyz=[8 8 33]);
            counts = mod((0:numel(uniform.khUnique)-1).',3);
            wvt = newTransform(Nxyz=[8 8 33],waveModeKappa=uniform.khUnique,waveModeCount=counts);
            solver = WVInternal.freeSurfaceWeakSolver(wvt);
            wvt.t = 329;
            wvt.t0 = -17;
            metric = flatMetric(wvt);
            stream = RandStream('mt19937ar',Seed=17731);
            rhs = solver.layout.unpack(randn(stream,solver.layout.dimension,1));
            target = zeros(solver.boundary.dimension,1);
            [actual,report] = solver.solve(rhs,target,metric,tolerance=1e-10);
            testCase.verifyLessThanOrEqual(report.iterations,1)
            testCase.verifyLessThan(report.relativeResidual,5e-10)
            testCase.verifyLessThan(norm(solver.boundary.apply(actual)),1e-9)
            testCase.verifyEqual(actual.Aw_p(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
            testCase.verifyEqual(actual.Aw_m(~wvt.activeWaveModes),zeros(nnz(~wvt.activeWaveModes),1))
            zero = solver.layout.unpack(zeros(solver.layout.dimension,1));
            [actual,report] = solver.solve(zero,target,metric);
            testCase.verifyEqual(actual,zero)
            testCase.verifyEqual(report.iterations,0)
            testCase.verifyEqual(report.relativeResidual,0)
            testCase.verifyEqual([wvt.t,wvt.t0],[329,-17])
        end

        function incompleteSolveAndInvalidTargetFailExplicitly(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfaceWeakSolver(wvt);
            stream = RandStream('mt19937ar',Seed=427);
            rhs = solver.layout.unpack(randn(stream,solver.layout.dimension,1));
            target = zeros(solver.boundary.dimension,1);
            metric = nonflatMetric(wvt);
            testCase.verifyError(@()solver.solve(rhs,target,metric,maxIterations=1,tolerance=1e-12),'WV:WeakSolverConvergence')
            testCase.verifyError(@()solver.solve(rhs,[target;0],metric),'WV:WeakSolverTarget')
        end
    end
end

function wvt = newTransform(options)
arguments (Input)
    options.Nxyz (1,3) double = [4 4 33]
    options.waveModeCount (:,1) double = 2
    options.waveModeKappa (:,1) double = zeros(0,1)
end
Nxyz = options.Nxyz;
options = rmfield(options,'Nxyz');
args = namedargs2cell(options);
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],Nxyz,args{:},N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,shouldAntialias=true);
end

function metric = flatMetric(wvt)
metric = struct(gamma=ones(wvt.Nx,wvt.Ny),betaX=zeros(wvt.Nx,wvt.Ny,wvt.Nz),betaY=zeros(wvt.Nx,wvt.Ny,wvt.Nz),displacementWeight=repmat(reshape(wvt.N2,1,1,[]),wvt.Nx,wvt.Ny,1));
end

function metric = nonflatMetric(wvt)
[X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
k = 2*pi/wvt.Lx; l = 2*pi/wvt.Ly;
metric.gamma = 1+0.3*cos(k*X(:,:,1)).*cos(l*Y(:,:,1));
metric.betaX = -0.3*wvt.Lz*k*(1+Z/wvt.Lz).*sin(k*X).*cos(l*Y)./metric.gamma;
metric.betaY = -0.3*wvt.Lz*l*(1+Z/wvt.Lz).*cos(k*X).*sin(l*Y)./metric.gamma;
metric.displacementWeight = metric.gamma.*1e-4.*(1+0.3*cos(k*X).*sin(l*Y));
end

function gram = physicalGram(wvt,layout,metric)
weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
velocityWeight = sqrt(weights.*metric.gamma);
etaWeight = sqrt(weights.*metric.displacementWeight);
numberSamples = 4*wvt.Nx*wvt.Ny*wvt.Nz+wvt.Nx*wvt.Ny;
matrix = zeros(numberSamples,layout.dimension);
for index = 1:layout.dimension
    vector = zeros(layout.dimension,1); vector(index)=1;
    spectral = wvt.reconstructSpectralState(state=layout.unpack(vector));
    fields = struct();
    for name = ["u","v","w","eta","ssh"]
        fields.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
    end
    u = velocityWeight.*fields.u./metric.gamma;
    v = velocityWeight.*fields.v./metric.gamma;
    w = velocityWeight.*(fields.w+metric.betaX.*fields.u+metric.betaY.*fields.v);
    eta = etaWeight.*fields.eta;
    ssh = sqrt(wvt.g/(wvt.Nx*wvt.Ny))*fields.ssh(:,:,end);
    matrix(:,index) = [u(:);v(:);w(:);eta(:);ssh(:)];
end
gram = matrix.'*matrix;
end
