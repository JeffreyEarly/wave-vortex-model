function createThreeInterfaceBenchmarkFixture(pathname,options)
% Create the matched model restart used by three-interface benchmarks.
arguments
    pathname (1,1) string
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [256 256 129]
    options.deltaT (1,1) double {mustBePositive} = 1e-3
    options.tracerShouldAntialias (1,1) logical = true
    options.isHydrostatic (1,1) logical = false
end
wvt = WVTransformConstantStratification([15000 15000 1300],options.Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=options.isHydrostatic,shouldAntialias=true);
state = initializeWaveVortexBenchmarkState(wvt,4001);
advanceWaveVortexBenchmarkState(wvt,state,0);
model = WVModel(wvt);
cleanup = onCleanup(@()closeModel(model));
outputFile = model.createNetCDFFileForModelOutput(pathname,outputInterval=options.deltaT/2,shouldOverwriteExisting=true);
model.eulerianObservingSystem.addNetCDFOutputVariables('u');
model.setFloatPositions([1000 7000],[900 6500],[-250 -850],'u',absToleranceXY=1e-8,absToleranceZ=1e-8);
tracer = WVTracer(model,name="dye",phi=sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly),shouldAntialias=options.tracerShouldAntialias);
model.addFluxedObservingSystem(tracer);
group = outputFile.outputGroupWithName(model.defaultOutputGroupName());
particles = model.fluxedObservingSystemWithName("float");
group.removeObservingSystem(particles);
particleGroup = outputFile.addNewEvenlySpacedOutputGroup("particles",outputInterval=options.deltaT/2);
particleGroup.addObservingSystem(particles);
tracerGroup = outputFile.addNewEvenlySpacedOutputGroup("tracers",outputInterval=options.deltaT/2);
tracerGroup.addObservingSystem(tracer);
group.addObservingSystem(WVMooring(model,name="mooring",x=[0 5000],y=[0 4000],trackedFieldNames={'u'}));
model.setupIntegrator(integratorType="fixed",deltaT=options.deltaT);
model.integrateToTime(options.deltaT,shouldShowIntegrationDiagnostics=false,callback=@(~)[]);
model.closeNetCDFFile();
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
