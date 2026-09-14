function report = benchmarkPinnedThermalReadinessAPV(outputDirectory,options)
% Measure the pinned APV implementation on the shared deterministic cold start.
%
% In a fresh MATLAB process, run the historical experiment's setupExperiment
% against clean isolated pinned checkouts, then add only this authoring tools
% directory. This function verifies the resolved WVM 4ec072 and InternalModes
% beta.4 commits before constructing anything. It never changes paths, pins,
% checkouts or the historical experiment runner. ThermalReadinessInventoryObserver
% is a passive authoring observer shared by the two workload measurements.
%
% The physical seed is the same once-normalized three-mode 1 cm RMS surface
% anomaly used by thermalReadinessCase(kind="cold"). Initial QGPV, bottom
% anomaly and MDA are zero. Both endpoints, scalar insulating diffusion,
% strict seasonal M10 source and quadratic bottom drag are retained. No
% optional adaptive damping is registered. Explicit counts of 217 APV and 321 MDA
% retain the historical default-grid selection; they are not the offline 64-mode band.
%
% This cold-start control does not establish mature seasonal throughput or
% equal discretization error. Compare against the same thermal cold seed,
% four threads, h=900s, duration, output cadences and nonadaptive policy. The
% pinned adaptive controller supports four floors; separate bottom error
% control is unavailable and irrelevant to these nonadaptive timing samples.
%
% - Topic: Developer utilities
% - Parameter outputDirectory: new destination for immutable baseline evidence
% - Parameter options.duration: model seconds per sample; default six hours
% - Parameter options.maximumWallSeconds: cooperative total budget including setup
% - Returns report: exact provenance, initial fit, setup and workload measurements
arguments (Input)
    outputDirectory (1,1) string
    options.duration (1,1) double {mustBePositive,mustBeFinite} = 6*3600
    options.maximumWallSeconds (1,1) double {mustBePositive,mustBeFinite} = 600
end
arguments (Output)
    report (1,1) struct
end
if isfile(fullfile(outputDirectory,'pinned-contract.json'))
    error('WV:ReadinessPinnedEvidence','Use a new directory; historical baseline evidence is immutable.');
end
if ~isfolder(outputDirectory),mkdir(outputDirectory);end
contract=struct(schema="pinned-apv-cold-workload-v1",waveVortexModelCommit="4ec07256476ee57ceee23d70422baec65d1f31a4", ...
    internalModesCommit="f2ce3c143744ae00fbb25bd9d7b8c73fb358ca51",internalModesVersion="2.0.0-beta.4", ...
    gridSize=[64 64 513],domainSize=[5e5 5e5 4000],apvModeCount=217,mdaModeCount=321,latitude=24, ...
    N0=5.2e-3,inverseScale=1/1300,g=9.81,kappa_z=1e-5,Cd=1e-3,forcingMultiplier=10, ...
    seasonalPeriod=365.25*86400,seasonalPhase=0,seasonalMode=5,seedRMS=.01,seedModes=[1 0;0 2;1 1], ...
    step=900,threadCount=4,repetitions=2,duration=options.duration,maximumWallSeconds=options.maximumWallSeconds, ...
    exponentialAdaptive=false,physicalAbsoluteTolerance=[1e-13 1e-11 1e-8 1e-8],relativeTolerance=1e-5, ...
    scope="matched cold-start workload only; mature seasonal and cross-representation accuracy remain unqualified", ...
    outputScope="sample coefficients at duration/2 and four physical inventories at duration/4; production cadence differs", ...
    diffusionScope="public WVVerticalDiffusivity Galerkin density diffusion, both insulating active endpoints, mean diffusion enabled");
writeJSON(fullfile(outputDirectory,'pinned-contract.json'),contract);
report=struct(contract=contract,status="NOT RUN",reason="",provenance=struct(),setup=table(),initialFit=table(),integration=table(),io=table());
timer=tic;originalThreads=maxNumCompThreads;threadCleanup=onCleanup(@()maxNumCompThreads(originalThreads));
try
    report.provenance.wvm=verifyPinnedSymbol("WVModel",contract.waveVortexModelCommit);
    report.provenance.internalModes=verifyPinnedSymbol("IMSolverSpectral",contract.internalModesCommit);
    report.provenance.matlab=string(version);report.provenance.platform=string(computer);
    maxNumCompThreads(4);checkBudget(timer,options.maximumWallSeconds);
    clock=tic;
    w=WVTransformFreeSurfaceQG(contract.domainSize,contract.gridSize,N2Function=@(z)contract.N0^2*exp(2*contract.inverseScale*z), ...
        latitude=contract.latitude,g=contract.g,apvModeCount=contract.apvModeCount,mdaModeCount=contract.mdaModeCount,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
    transformCleanup=onCleanup(@()releaseTransform(w));
    constructionSeconds=toc(clock);checkBudget(timer,options.maximumWallSeconds);
    if w.apvModeCount~=217 || w.mdaModeCount~=321 || ~isequal(w.activeEndpoint,[1;2])
        error('WV:ReadinessPinnedRepresentation','The pinned historical band and both active endpoints must be retained.');
    end
    w.removeAllForcing();
    w.addForcing(WVNonlinearAdvection(w));
    [X,Y]=ndgrid(w.x,w.y);
    w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=sin(10*pi*Y/w.Ly),amplitude=10*pi/contract.seasonalPeriod,period=contract.seasonalPeriod,phase=0));
    w.addForcing(WVBottomFrictionQuadratic(w,Cd=contract.Cd));
    w.addForcing(WVVerticalDiffusivity(w,kappa_z=contract.kappa_z,shouldForceMeanDensityAnomaly=true));
    expected=sort(["nonlinear advection";"seasonal surface anomaly";"quadratic bottom friction";"vertical diffusivity"]);
    names=w.forcingNames();
    if ~isequal(sort(names(:)),expected)
        error('WV:ReadinessPinnedPhysics','The baseline must register exactly the four declared physical processes.');
    end
    factor=.01/sqrt((1+.49+.09)/2);
    seed=factor*(cos(2*pi*X/w.Lx)+.7*sin(4*pi*Y/w.Ly)+.3*cos(2*pi*(X/w.Lx+Y/w.Ly)));
    field=zeros(w.spatialMatrixSize);field(:,:,1)=seed;
    spectral=w.transformFromSpatialDomainWithFourier(field);clear field
    desired=zeros(2,numel(w.klNonzero));desired(1,:)=spectral(1,w.klNonzero);clear spectral
    [w.Ag_q,w.Ag_0]=w.transformStateForward(zeros(w.Nz,numel(w.klNonzero)),desired);w.Amda=zeros(size(w.Amda));w.t=0;w.t0=0;
    [~,actual]=w.transformStateBack(w.Ag_q,w.Ag_0);
    endpointError=sqrt(2*sum(abs(actual-desired).^2,2));
    q=w.reconstructFields("qgpv");qRMS=sqrt(mean(q.qgpv.^2,'all'));clear q
    seedRMS=sqrt(mean(seed.^2,'all'));
    report.initialFit=table(qRMS,endpointError(1),endpointError(2),seedRMS,max(abs(w.Amda)), ...
        VariableNames={'qgpvRMS','surfaceAnomalyErrorRMS','bottomAnomalyErrorRMS','surfaceSeedRMS','maximumMeanCoefficient'});
    writetable(report.initialFit,fullfile(outputDirectory,'initial-fit.csv'));
    if any(~isfinite([qRMS;endpointError;seedRMS])) || qRMS>1e-12 || any(endpointError>1e-9) || abs(seedRMS-.01)>1e-12 || any(w.Amda~=0)
        error('WV:ReadinessPinnedInitialFit','The shared cold-state QGPV, endpoint or mean fit failed.');
    end
    initial=struct(Ag_q=w.Ag_q,Ag_0=w.Ag_0,Amda=w.Amda);
    assessment=w.constructionAssessment;save(fullfile(outputDirectory,'construction.mat'),'assessment');
    clock=tic;file=w.writeToFile(char(fullfile(outputDirectory,'initial-state.nc')));snapshotCleanup=onCleanup(@()closeSnapshot(file));
    file.close();initialWriteSeconds=toc(clock);clear snapshotCleanup file
    model=WVModel(w);cleanup=onCleanup(@()closeModel(model));clock=tic;configure(model,contract);integratorSetupSeconds=toc(clock);
    clock=tic;model.explicitFlux();firstRhsSeconds=toc(clock);clear cleanup model
    report.setup=table(constructionSeconds,initialWriteSeconds,integratorSetupSeconds,firstRhsSeconds,4,217,321, ...
        VariableNames={'constructionSeconds','initialStateWriteSeconds','integratorSetupSeconds','firstRhsSeconds','threads','apvModeCount','mdaModeCount'});
    writetable(report.setup,fullfile(outputDirectory,'setup.csv'));
    for withOutput=[false true]
        for repetition=1:2
            checkBudget(timer,options.maximumWallSeconds);
            w.Ag_q=initial.Ag_q;w.Ag_0=initial.Ag_0;w.Amda=initial.Amda;w.t=0;w.t0=0;
            model=WVModel(w);cleanup=onCleanup(@()closeModel(model));configure(model,contract);
            path=fullfile(outputDirectory,sprintf('sample-output-%d.nc',repetition));
            outputSetupSeconds=0;initialBytes=NaN;scalarInterval=NaN;coefficientInterval=NaN;
            if withOutput
                clock=tic;coefficientInterval=options.duration/2;scalarInterval=options.duration/4;
                file=model.createNetCDFFileForModelOutput(char(path),outputInterval=coefficientInterval);
                group=file.addNewEvenlySpacedOutputGroup('scalar',initialTime=0,outputInterval=scalarInterval,finalTime=options.duration);
                group.addObservingSystem(ThermalReadinessInventoryObserver(model));
                model.outputTimesForIntegrationPeriod(0,options.duration);model.writeTimeStepToNetCDFFile(0);file.ncfile.sync();
                outputSetupSeconds=toc(clock);info=dir(path);initialBytes=info.bytes;
            end
            clock=tic;accepted=0;rejected=0;rhs=0;outputRhs=0;steps=[];maximumCFL=0;maximumDampingNumber=0;
            while w.t<options.duration && toc(timer)<options.maximumWallSeconds
                model.integrateToTime(min(options.duration,w.t+2*contract.step),shouldShowIntegrationDiagnostics=false);
                s=model.exponentialStatistics;accepted=accepted+s.acceptedSteps;rejected=rejected+s.rejectedSteps;
                rhs=rhs+s.rhsEvaluations;outputRhs=outputRhs+s.outputRhsEvaluations;steps=[steps s.acceptedStepSeconds]; %#ok<AGROW>
                maximumCFL=max(maximumCFL,s.maximumCFL);maximumDampingNumber=max(maximumDampingNumber,s.maximumDampingNumber);
            end
            closeClock=tic;model.closeNetCDFFile();outputCloseSeconds=toc(closeClock);wallSeconds=toc(clock);
            minimumStep=NaN;maximumStep=NaN;if ~isempty(steps),minimumStep=min(steps);maximumStep=max(steps);end
            status="complete";if w.t<options.duration,status="wall-budget";end
            row=table(withOutput,repetition,4,w.t,wallSeconds,w.t/wallSeconds,accepted,rejected,rhs,outputRhs,minimumStep,maximumStep,maximumCFL,maximumDampingNumber,outputSetupSeconds,outputCloseSeconds,scalarInterval,coefficientInterval,status, ...
                VariableNames={'withOutput','repeat','threads','simulatedSeconds','wallSeconds','simulatedSecondsPerWallSecond','acceptedSteps','rejectedSteps','rhsEvaluations','outputRhsEvaluations','minimumStep','maximumStep','maximumCFL','maximumDampingNumber','outputSetupSeconds','outputCloseSeconds','scalarInterval','coefficientInterval','status'});
            report.integration=[report.integration;row];writetable(report.integration,fullfile(outputDirectory,'integration.csv'));
            if withOutput && isfile(path)
                info=dir(path);payload=16*(numel(w.Ag_q)+numel(w.Ag_0))+8*numel(w.Amda)+8;
                row=table(repetition,info.bytes,initialBytes,info.bytes-initialBytes,payload,40, ...
                    VariableNames={'repeat','sampleFileBytes','initialFileBytesIncludingFirstRecords','additionalSampleBytes','coefficientRecordPayloadBytes','scalarRecordPayloadBytes'});
                report.io=[report.io;row];writetable(report.io,fullfile(outputDirectory,'io.csv'));
            end
            clear cleanup model file group
        end
    end
    isComplete=height(report.integration)==2*contract.repetitions && all(report.integration.status=="complete") && all(report.integration.simulatedSeconds==options.duration);
    if isComplete
        report.status="MEASURED CONTROL";report.reason="Cold-state workload only; separate thermal comparison and evolved-flow qualification remain required.";
    else
        report.status="PARTIAL CONTROL";report.reason="The bounded run did not complete every requested sample at the declared duration; retain partial timings without claiming a complete control.";
    end
catch exception
    report.reason=string(exception.identifier)+": "+string(exception.message);
    if ~isempty(report.integration),report.status="PARTIAL CONTROL";end
end
clear cleanup snapshotCleanup model file group
clear transformCleanup w
report.wallSeconds=toc(timer);
save(fullfile(outputDirectory,'pinned-report.mat'),'report');
writeJSON(fullfile(outputDirectory,'pinned-summary.json'),struct(status=report.status,reason=report.reason,wallSeconds=report.wallSeconds));
end

function configure(model,c)
model.setupIntegrator(integratorType="exponential",initialStep=c.step,maximumStep=c.step,exponentialAdaptive=false,relTolerance=c.relativeTolerance,physicalAbsTolerance=c.physicalAbsoluteTolerance);
end

function closeModel(model)
% Repetition models share the transform owned by the outer benchmark.
if isempty(model) || ~isvalid(model),return;end
cleanup=onCleanup(@()delete(model));
model.closeNetCDFFile();
end

function releaseTransform(w)
if ~isempty(w) && isvalid(w),delete(w);end
end

function closeSnapshot(file)
if ~isempty(file) && isvalid(file) && ~isempty(file.id),file.close();end
end

function checkBudget(timer,limit)
if toc(timer)>=limit,error('WV:ReadinessPinnedWallBudget','The cooperative historical baseline budget expired; no further work was started.');end
end

function provenance=verifyPinnedSymbol(symbol,expected)
resolved=string(which(symbol));
if resolved=="",error('WV:ReadinessPinnedEnvironment','Missing pinned symbol %s; configure the isolated historical environment first.',symbol);end
folder=string(fileparts(resolved));
[status,root]=system("git -C "+shellQuote(folder)+" rev-parse --show-toplevel");
if status~=0,error('WV:ReadinessPinnedEnvironment','The resolved %s is not in an authoring Git checkout.',symbol);end
root=string(strtrim(root));
[status,head]=system("git -C "+shellQuote(root)+" rev-parse HEAD");
if status~=0 || string(strtrim(head))~=expected,error('WV:ReadinessPinnedEnvironment','%s must resolve to exact commit %s.',symbol,expected);end
[status,dirty]=system("git -C "+shellQuote(root)+" status --porcelain");
if status~=0 || strlength(strtrim(dirty))>0,error('WV:ReadinessPinnedEnvironment','The pinned %s checkout must be clean.',symbol);end
provenance=struct(symbol=symbol,resolvedPath=resolved,repository=root,commit=expected,isClean=true);
end

function value=shellQuote(value)
quote=string(char(39));value=quote+replace(string(value),quote,quote+string(char(34))+quote+string(char(34))+quote)+quote;
end

function writeJSON(file,value)
fid=fopen(file,'w');if fid<0,error('WV:ReadinessPinnedEvidence','Cannot write baseline evidence: %s.',file);end
cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,PrettyPrint=true));
end
