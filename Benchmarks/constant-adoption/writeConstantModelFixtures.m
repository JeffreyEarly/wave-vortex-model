function manifest = writeConstantModelFixtures(folder)
% Write deterministic constant-stratification adoption fixtures and references.
arguments
    folder (1,1) string = string(tempname)
end
entries = dir(folder); entries = entries(~ismember({entries.name},{'.','..'}));
if isfolder(folder) && ~isempty(entries)
    error("WaveVortexModel:FixtureFolderExists","Refusing to overwrite nonempty fixture folder: %s",folder)
end
if ~isfolder(folder), mkdir(folder); end

profiles = ["constant-hydrostatic-coefficient-only" "constant-hydrostatic-composite" ...
    "constant-nonhydrostatic-coefficient-only" "constant-nonhydrostatic-composite"];
generatorPath = string(which("writeConstantModelFixtures"));
sourceHead = string(strtrim(runCommand("git -C "+quote(fileparts(fileparts(fileparts(generatorPath))))+" rev-parse HEAD")));
records = repmat(struct("id","","sourcePath","","referencePath","","requestPath","","sourceSHA256","","referenceSHA256","","requestSHA256","","isHydrostatic",false,"composite",false,"outputCounts",struct()),numel(profiles),1);
for index = 1:numel(profiles)
    id = profiles(index); composite = endsWith(id,"composite"); hydrostatic = startsWith(id,"constant-hydrostatic-");
    sourcePath = fullfile(folder,id+"-source.nc"); referencePath = fullfile(folder,id+"-reference.nc"); requestPath = fullfile(folder,id+"-request.json");
    model = makeModel(hydrostatic,composite); writeInitial(model,sourcePath,composite); model.closeNetCDFFile();
    copyfile(sourcePath,referencePath); reference = WVModel.modelFromFile(referencePath); reference.outputTimesForIntegrationPeriod(0,32); reference.setupIntegrator(integratorType="fixed",deltaT=.5); reference.integrateToTime(32,shouldShowIntegrationDiagnostics=false,callback=@(~)[]); reference.closeNetCDFFile();
    WVModel.writePortableRunRequest(requestPath,sourcePath,method="fixed-rk4",finalTime=32,initialStep=.5,fftProvider="native-fftw",threads=16,reportPath=fullfile(folder,id+"-report.json"));
    records(index)=struct("id",id,"sourcePath",sourcePath,"referencePath",referencePath,"requestPath",requestPath,"sourceSHA256",sha256(sourcePath),"referenceSHA256",sha256(referencePath),"requestSHA256",sha256(requestPath),"isHydrostatic",hydrostatic,"composite",composite,"outputCounts",counts(composite));
    clear model reference
end
manifest=struct("schema","wvm-constant-model-fixtures-v1","generatorPath",generatorPath,"generatorSHA256",sha256(generatorPath),"sourceHEAD",sourceHead,"matlabVersion",string(version),"parameters",struct("Nxyz",[32 24 33],"Lxyz",[150e3 100e3 1000],"N0",5.2e-3,"shouldAntialias",true,"finalTime",32,"initialStep",.5,"outputInterval",2,"denseOutputInterval",.5,"threads",16,"forcing","WVNonlinearAdvection","fields",{{"u","v","w","eta"}},"particleX",[10e3 70e3],"particleY",[9e3 65e3],"particleZ",[-250 -850],"tracer","dye"),"profiles",records);
saveJSON(fullfile(folder,"manifest.json"),manifest);
end

function model=makeModel(hydrostatic,composite)
wvt=WVTransformConstantStratification([150e3 100e3 1000],[32 24 33],N0=5.2e-3,isHydrostatic=hydrostatic,shouldAntialias=true);
n=reshape(1:numel(wvt.A0),size(wvt.A0)); wvt.A0=1e-6*(sin(.7*n)+1i*cos(.3*n))./(1+wvt.J); wvt.A0(:,wvt.k==0 & wvt.l==0)=0;
wave=wvt.J>0 & (wvt.K.^2+wvt.L.^2)>0; inertial=(wvt.K.^2+wvt.L.^2)==0; wvt.Ap=.001*(sin(.7*n)+1i*cos(.3*n))./(1+wvt.J).*(wave|inertial); wvt.Am=.002*(sin(.3*n)+1i*cos(.7*n))./(1+wvt.J).*wave; wvt.Am(inertial)=conj(wvt.Ap(inertial)); wvt.A0(inertial & wvt.J>0)=.003*sin(n(inertial & wvt.J>0)); wvt.t=0; wvt.t0=0; wvt.setForcing(WVNonlinearAdvection(wvt));
model=WVModel(wvt);
if composite, model.eulerianObservingSystem.addNetCDFOutputVariables('u','v','w','eta'); model.setFloatPositions([10e3 70e3],[9e3 65e3],[-250 -850],'u'); model.addTracer(sin(2*pi*wvt.X/wvt.Lx).*cos(2*pi*wvt.Y/wvt.Ly),"dye"); end
end

function writeInitial(model,path,composite)
file=model.createNetCDFFileForModelOutput(path,outputInterval=2,shouldOverwriteExisting=true);
if composite
    group=file.outputGroupWithName(model.defaultOutputGroupName()); particles=model.fluxedObservingSystemWithName("float"); tracer=model.fluxedObservingSystemWithName("dye"); group.removeObservingSystem([particles tracer]);
    dense=file.addNewEvenlySpacedOutputGroup("dense",outputInterval=.5,initialTime=0,finalTime=32); dense.addObservingSystem(WVEulerianFields(model,fieldNames={'u','v','w','eta'}));
    particleGroup=file.addNewEvenlySpacedOutputGroup("particles",outputInterval=2,initialTime=0,finalTime=32); particleGroup.addObservingSystem(particles);
    tracerGroup=file.addNewEvenlySpacedOutputGroup("tracers",outputInterval=2,initialTime=0,finalTime=32); tracerGroup.addObservingSystem(tracer);
end
file.outputTimesForIntegrationPeriod(0,32); file.writeTimeStepToOutputFile(0);
end

function value=counts(composite)
value=struct("waveVortex",17,"dense",double(composite)*65,"particles",double(composite)*17,"tracers",double(composite)*17);
end

function value=sha256(path)
value=extractBefore(string(strtrim(runCommand("/usr/bin/shasum -a 256 "+quote(path))))," ");
end

function value=runCommand(command)
[status,value]=system(command); if status~=0, error("WaveVortexModel:FixtureCommand","Command failed: %s",value); end
end

function value=quote(path)
value="'"+replace(string(path),"'","'""'""'")+"'";
end

function saveJSON(path,value)
file=fopen(path,"w"); if file<0, error("WaveVortexModel:FixtureWrite","Unable to write %s",path); end
cleanup=onCleanup(@()fclose(file)); fwrite(file,jsonencode(value)); fwrite(file,newline);
end
