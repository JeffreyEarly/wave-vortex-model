function results = runPerKappaWaveCountBenchmark(outputPath,options)
% Compare bounded construction, reconstruction, and rectangular storage costs.
%
% Uniform and varying prefixes retain the same maximum count. The varying
% case cycles through counts 0, 2, 4, and 1 over sorted physical kappa pages.
% This measures two different retained workloads, not an implementation
% regression. No additional accuracy-reference solve is requested. Storage
% includes the three sampled wave operators, h, omega, and both coefficient
% signs; it excludes shared geometry and balanced/inertial families. The
% active-only value is a storage lower bound, not a packed implementation.
%
% - Topic: Developer utilities
% - Parameter outputPath: optional CSV output file; empty leaves no artifact
% - Parameter options.horizontalSizes: bounded square Fourier grid sizes
% - Parameter options.repetitions: measured repetitions after warm-up
% - Returns results: one row per grid, count policy, and repetition
% - Developer: true
arguments (Input)
    outputPath (1,1) string = ""
    options.horizontalSizes (1,:) double {mustBeInteger,mustBePositive} = [16 32]
    options.repetitions (1,1) double {mustBeInteger,mustBePositive} = 3
end
arguments (Output)
    results table
end
rows = struct([]);
for horizontalSize = options.horizontalSizes
    uniform = construct(horizontalSize,[],4);
    kappa = uniform.khUnique;
    patterns = [0;2;4;1];
    variedCounts = patterns(mod((0:numel(kappa)-1).',4)+1);
    varying = construct(horizontalSize,kappa,variedCounts);
    initialize(uniform); initialize(varying);
    uniform.reconstructFields(["u","v","w","eta","ssh"]);
    varying.reconstructFields(["u","v","w","eta","ssh"]);
    for repetition = 1:options.repetitions
        % Alternate ordering to avoid assigning every first-run cost to one policy.
        policies = ["uniform","varying"];
        if mod(repetition,2)==0, policies=fliplr(policies); end
        for policy = policies
            if policy=="uniform", keys=[]; counts=4; else, keys=kappa; counts=variedCounts; end
            timer = tic;
            w = construct(horizontalSize,keys,counts);
            constructionSeconds = toc(timer);
            initialize(w);
            timer = tic;
            fields = w.reconstructFields(["u","v","w","eta","ssh"]);
            reconstructionSeconds = toc(timer);
            if ~all(isfinite(fields.u),'all') || ~all(isfinite(fields.w),'all')
                error('WVBenchmark:InvalidReconstruction','The benchmark produced nonfinite fields.')
            end
            paddedWaveBytes = 0;
            for name = ["waveF","waveG","waveGForward","waveEquivalentDepth","waveFrequency","Aw_p","Aw_m"]
                value = w.(name); %#ok<NASGU> Inspected by whos below.
                storage = whos('value'); paddedWaveBytes = paddedWaveBytes+storage.bytes;
            end
            activeColumns = sum(w.activeWaveModes,'all');
            activePageModes = sum(w.waveModeCountByKh);
            activeWaveBytes = 8*(3*w.Nz+2)*activePageModes+32*activeColumns;
            row = struct(horizontalSize=horizontalSize,verticalSize=w.Nz,policy=policy,repetition=repetition,nEVP=w.nEVP,kappaPages=numel(w.khUnique),solvedPositivePages=nnz(w.waveModeCountByKh),maximumWaveCount=numel(w.waveMode),activePageModes=activePageModes,paddedPageModes=numel(w.waveMode)*numel(w.khUnique),activeCoefficientCount=2*activeColumns,paddedCoefficientCount=numel(w.Aw_p)+numel(w.Aw_m),constructionSeconds=constructionSeconds,reconstructionSeconds=reconstructionSeconds,paddedWaveBytes=paddedWaveBytes,activeWaveBytes=activeWaveBytes);
            rows = [rows;row]; %#ok<AGROW>
        end
    end
end
results = struct2table(rows);
if outputPath~="", writetable(results,outputPath); end
end

function w = construct(n,kappa,counts)
w = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[n n 65],N2Function=@(z)1e-4*exp(2*z/700),waveModeKappa=kappa,waveModeCount=counts);
end

function initialize(w)
ordinal = reshape(1:numel(w.Aw_p),size(w.Aw_p));
w.Aw_p = .002*exp(1i*ordinal)./(1+ordinal).*w.activeWaveModes;
w.Aw_m = conj(w.Aw_p)/2;
w.Aio(:) = .001;
end
