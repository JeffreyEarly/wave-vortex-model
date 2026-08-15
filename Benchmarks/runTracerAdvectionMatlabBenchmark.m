function result = runTracerAdvectionMatlabBenchmark(fixturePath,options)
% Time MATLAB WVTracer.fluxAtTime from a matched portable-runtime restart.
arguments
    fixturePath (1,1) string {mustBeFile}
    options.warmupCount (1,1) double {mustBeInteger,mustBeNonnegative} = 2
    options.sampleCount (1,1) double {mustBeInteger,mustBePositive} = 7
end

model = WVModel.modelFromFile(char(fixturePath));
cleanup = onCleanup(@()closeModel(model));
tracer = model.fluxedObservingSystemWithName("dye");
state = {tracer.phi};
time = model.wvt.t;

started = tic;
flux = tracer.fluxAtTime(time,state);
firstCallSeconds = toc(started);
checksum = sum(flux{1},"all");
for iWarmup = 1:options.warmupCount
    flux = tracer.fluxAtTime(time,state);
    checksum = checksum + sum(flux{1},"all");
end
samples = zeros(options.sampleCount,1);
for iSample = 1:options.sampleCount
    started = tic;
    flux = tracer.fluxAtTime(time,state);
    samples(iSample) = toc(started);
    checksum = checksum + sum(flux{1},"all");
end

result = struct( ...
    fixture=fixturePath, ...
    isHydrostatic=model.wvt.isHydrostatic, ...
    shape=[model.wvt.Nx model.wvt.Ny model.wvt.Nz], ...
    shouldAntialias=tracer.shouldAntialias, ...
    firstCallSeconds=firstCallSeconds, ...
    samplesSeconds=samples, ...
    medianSeconds=median(samples), ...
    checksum=checksum);
clear cleanup
end

function closeModel(model)
if ~isempty(model) && isvalid(model)
    try
        model.closeNetCDFFile();
    catch
    end
    delete(model);
end
end
