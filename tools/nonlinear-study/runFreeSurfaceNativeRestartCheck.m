function result = runFreeSurfaceNativeRestartCheck(stage,outputFolder,dependencyRoot)
% Verify variable-count native restart in separate MATLAB processes.
%
% Start each process with restoredefaultpath, add this script's folder, and
% call stage="write" followed by stage="read" against the same output folder.
% The read stage loads only WVM and non-provider dependencies before restoring
% the checkpoint. Run it once per newly written checkpoint because continuation
% appends the final record to the native file. No class definitions or mode
% provider objects are shared between the two processes.
arguments (Input)
    stage (1,1) string {mustBeMember(stage,["write","read"])}
    outputFolder (1,1) string
    dependencyRoot (1,1) string
end
configurePath(dependencyRoot,stage=="write");
checkpointPath = fullfile(outputFolder,'variable-count-checkpoint.nc');
referencePath = fullfile(outputFolder,'variable-count-reference.mat');
if stage=="write"
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    options = struct(N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,shouldCheckQuadraticAliasing=true,shouldAntialias=true);
    args = namedargs2cell(options);
    base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:});
    choices = [3;2;0];
    counts = choices(1+mod((0:numel(base.khUnique)-1).',3));
    options.waveModeCount = counts;
    args = namedargs2cell(options);
    wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},waveModeKappa=base.khUnique);
    assert(any(counts==0) && any(~wvt.activeWaveModes,'all'))
    scientific = wvt.scientificState();
    helper = freeSurfaceWeakStudyHelpers();
    seed = helper.seedState(wvt);
    seed.Aw_m = 0.35*exp(0.63i)*seed.Aw_p;
    column = find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
    xColumn = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
    seed.Aw_p(1,column) = 0.15*exp(0.43i)*seed.Aw_p(1,xColumn);
    seed.Aw_m(1,column) = 0.27*exp(-0.71i)*seed.Aw_p(1,column);
    for name = ["Aw_p","Aw_m"], seed.(name)(~wvt.activeWaveModes)=0; end
    [X,Y,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
    source = struct(uRate=1e-8*cos(2*pi*X/wvt.Lx).*(1+Z/wvt.Lz),vRate=-2e-8*sin(2*pi*Y/wvt.Ly).*(Z/wvt.Lz).^2,wRate=3e-9*cos(2*pi*(X/wvt.Lx+Y/wvt.Ly)).*(1+Z/wvt.Lz),etaRate=2e-7*(1+0.1*cos(2*pi*X/wvt.Lx)).*(1+Z/(2*wvt.Lz)),sourceCoordinates="physical",frequency=0.003,referenceTime=19,phase=0.4);
    uninterrupted = configuredModel(scientific,seed,source);
    uninterrupted.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
    expected = struct(state=uninterrupted.wvt.coefficientState(),fields=uninterrupted.wvt.reconstructFields(fieldNames()),energy=uninterrupted.wvt.nonlinearEnergy(),scientific=scientific,source=source,counts=counts,active=uninterrupted.wvt.activeWaveModes);
    checkpoint = configuredModel(scientific,seed,source);
    checkpoint.createNetCDFFileForModelOutput(checkpointPath,outputInterval=20,shouldOverwriteExisting=true);
    names = cellstr(fieldNames());
    checkpoint.eulerianObservingSystem.addNetCDFOutputVariables(names{:});
    checkpoint.integrateToTime(347,shouldShowIntegrationDiagnostics=false);
    expected.checkpointState = checkpoint.wvt.coefficientState();
    checkpoint.closeNetCDFFile();
    save(referencePath,'expected');
    result = struct(stage=stage,checkpointTime=347,finalTime=367,waveModeCounts=counts.',zeroWavePages=nnz(counts==0),inactiveWaveEntries=nnz(~wvt.activeWaveModes));
else
    assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')),'The fresh read process must not have a mode provider on its path.')
    data = load(referencePath,'expected');
    expected = data.expected;
    resumed = WVModel.modelFromFile(char(checkpointPath));
    cleanup = onCleanup(@()resumed.closeNetCDFFile());
    assert(~resumed.isDynamicsLinear && isempty(resumed.wvt.verticalModes))
    assert(isequal([resumed.wvt.t,resumed.wvt.t0],[347,-17]))
    assert(isequal(resumed.wvt.coefficientState(),expected.checkpointState))
    actualScientific = resumed.wvt.scientificState();
    for name = string(fieldnames(expected.scientific)).'
        if ~isa(expected.scientific.(name),'function_handle')
            assert(isequal(actualScientific.(name),expected.scientific.(name)),'Stored scientific operator changed: %s.',name)
        end
    end
    assert(isequal(resumed.wvt.waveModeCountByKh,expected.counts))
    assert(isequal(resumed.wvt.activeWaveModes,expected.active))
    force = resumed.wvt.forcingWithName("prescribed Boussinesq source");
    for name = string(fieldnames(expected.source)).', assert(isequal(force.(name),expected.source.(name))); end
    resumed.setupIntegrator(integratorType="fixed",deltaT=5);
    resumed.integrateToTime(367,shouldShowIntegrationDiagnostics=false);
    state = resumed.wvt.coefficientState();
    fields = resumed.wvt.reconstructFields(fieldNames());
    energy = resumed.wvt.nonlinearEnergy();
    coefficientError = relativeStructError(state,expected.state);
    physicalFieldError = relativeStructError(fields,expected.fields);
    energyError = abs(energy.totalEnergy-expected.energy.totalEnergy)/abs(expected.energy.totalEnergy);
    assert(coefficientError<2e-11 && physicalFieldError<2e-10 && energyError<2e-11)
    for name = ["Aw_p","Aw_m"], assert(all(state.(name)(~expected.active)==0)); end
    assert(isreal(state.Amda) && isempty(resumed.wvt.verticalModes))
    assert(isequal([resumed.wvt.t,resumed.wvt.t0],[367,-17]))
    assert(isempty(which('IMInternalModes')) && isempty(which('IMSolverSpectral')))
    [~,~,diagnostics] = resumed.wvt.coefficientTendency();
    assert(diagnostics.minimumLabel>-resumed.wvt.Lz && diagnostics.maximumLabel<0)
    result = struct(stage=stage,coefficientError=coefficientError,physicalFieldError=physicalFieldError,energyError=energyError,minimumLabel=diagnostics.minimumLabel,maximumLabel=diagnostics.maximumLabel,solverResidual=diagnostics.solver.relativeResidual,waveModeCounts=expected.counts.',zeroWavePages=nnz(expected.counts==0),inactiveWaveEntries=nnz(~expected.active),modeProviderAvailable=false);
    clear cleanup
end
fprintf('%s\n',jsonencode(result))
fid = fopen(fullfile(outputFolder,stage+"-result.json"),'w');
assert(fid>=0,'Cannot write restart verification result.')
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(result));
end

function model = configuredModel(scientific,seed,source)
wvt = WVTransformFreeSurfaceBoussinesq(scientific);
for name = string(fieldnames(seed)).', wvt.(name)=seed.(name); end
wvt.t = 327;
wvt.t0 = -17;
args = namedargs2cell(source);
wvt.setForcing([WVNonlinearAdvection(wvt),WVPrescribedBoussinesqSource(wvt,args{:})]);
model = WVModel(wvt);
model.setupIntegrator(integratorType="fixed",deltaT=5);
end

function names = fieldNames()
names = ["u","v","w","eta","eta_i","ssh","p_linear","p_full","w_i","z_physical"];
end

function value = relativeStructError(actual,expected)
value = 0;
for name = string(fieldnames(expected)).'
    a = actual.(name); b = expected.(name);
    value = max(value,norm(a(:)-b(:))/max(norm(b(:)),realmin));
end
end

function configurePath(dependencyRoot,includeProvider)
packages = ["ClassAnnotations-1.2.1","SplineCore-2.2.0","Distributions-2.0.0","chebfun-5.7.0","NetCDF-1.0.2"];
if includeProvider, packages(end+1)="InternalModes-2.0.0-beta.4"; end
repositoryRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
for root = [fullfile(dependencyRoot,packages),string(repositoryRoot)]
    manifestPath = fullfile(root,'resources','mpackage.json');
    if ~isfile(manifestPath), error('WVStudy:MissingDependency','Missing package manifest: %s',manifestPath); end
    manifest = jsondecode(fileread(manifestPath));
    addpath(root);
    for index = 1:numel(manifest.folders), addpath(fullfile(root,manifest.folders(index).path)); end
end
if ~includeProvider
    % Installed MATLAB packages can survive restoredefaultpath. Remove
    % their provider folders before any checkpoint object is loaded.
    entries = string(strsplit(path,pathsep));
    provider = contains(lower(entries),'internalmodes') | contains(lower(entries),'internal-modes');
    if any(provider)
        removed = cellstr(entries(provider));
        rmpath(removed{:});
    end
end
end
