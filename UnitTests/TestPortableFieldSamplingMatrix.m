classdef TestPortableFieldSamplingMatrix < matlab.unittest.TestCase
    properties (SetAccess=private)
        root (1,1) string
        folder (1,1) string
        probe (1,1) string
        providers (1,:) string
    end
    methods (TestClassSetup)
        function prepareProbe(testCase)
            testCase.root=string(fileparts(fileparts(mfilename("fullpath"))));
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.folder=string(fixture.Folder);
            stableProbe=string(getenv("WV_STABLE_FORCING_DUMP"));
            testCase.probe=string(getenv("WV_FIELD_SAMPLING_DUMP"));
            if testCase.probe=="" && stableProbe~="", testCase.probe=fullfile(fileparts(stableProbe),"WVStratifiedQGFieldDump"); end
            testCase.providers="reference";
            if getenv("WV_STABLE_FORCING_NATIVE")=="1" || getenv("WV_FIELD_SAMPLING_NATIVE")=="1", testCase.providers=["reference","native"]; end
            if testCase.probe==""
                build=fullfile(testCase.folder,"build");
                [status,output]=cleanSystem("cmake -S "+shellQuote(fullfile(testCase.root,"PortableRuntime"))+" -B "+shellQuote(build)+" -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON -DWV_ENABLE_ACCELERATE=OFF");
                testCase.assertEqual(status,0,output);
                [status,output]=cleanSystem("cmake --build "+shellQuote(build)+" --parallel 2 --target WVStratifiedQGFieldDump");
                testCase.assertEqual(status,0,output);
                testCase.probe=fullfile(build,"WVStratifiedQGFieldDump");
            end
            testCase.assertTrue(isfile(testCase.probe));
        end
    end
    methods (Test,TestTags="full")
        function declaredPortableSamplingMatchesMatlab(testCase)
            catalog=jsondecode(fileread(fullfile(testCase.root,"PortableRuntime","contracts","portable-variable-catalog-v1.json")));
            families=["constant-hydrostatic","constant-nonhydrostatic","barotropic","stratified-qg","hydrostatic","boussinesq"];
            for family=families
                for antialias=[false true]
                    configuration=family+"-aa"+double(antialias);
                    rows=catalog.contracts(string({catalog.contracts.configuration})==configuration);
                    positions={}; profiles={}; movingPositions={};
                    for row=reshape(rows,1,[])
                        if string(row.runtimeStatus)~="implemented", continue; end
                        modes=string(row.metadata.samplingModes);
                        if ismember("positions",modes), positions{end+1}=string(row.metadata.name); end %#ok<AGROW>
                        if ismember("fixedVerticalProfiles",modes), profiles{end+1}=string(row.metadata.name); end %#ok<AGROW>
                        if ismember("positions",modes) && (~startsWith(family,"constant-") || row.metadata.movingPrimitiveChannel>=0), movingPositions{end+1}=string(row.metadata.name); end %#ok<AGROW>
                    end
                    [wvt,source]=testCase.writeSource(family,antialias,configuration);
                    [x,y,z]=testCase.positionCoordinates(wvt,3);
                    request=struct(x=x,y=y,z=z,fields={positions});
                    if isempty(positions), request.fields={}; end
                    if isempty(profiles)
                        request.profiles=struct(fields={{}},xIndices=[],yIndices=[]);
                    else
                        profileOrd=0:numel(profiles)-1;
                        request.profiles=struct(fields={profiles},xIndices=1+mod(profileOrd,wvt.Nx),yIndices=1+mod(floor(profileOrd/wvt.Nx),wvt.Ny));
                    end
                    requestPath=fullfile(testCase.folder,configuration+"-request.json"); outputPath=fullfile(testCase.folder,configuration+"-output.json");
                    probeRequest=request;
                    writeJSON(requestPath,probeRequest);
                    for provider=testCase.providers
                        [status,output]=cleanSystem(shellQuote(testCase.probe)+" "+shellQuote(source)+" "+shellQuote(requestPath)+" "+shellQuote(outputPath)+" "+provider);
                        testCase.assertEqual(status,0,configuration+" "+provider+": "+output);
                        actual=jsondecode(fileread(outputPath));
                        for method=["linear","spline"]
                            for name=string(positions)
                                expected=wvt.variableAtPositionWithName(request.x,request.y,request.z,char(name),interpolationMethod=char(method));
                                tolerance=2e-11*max(abs(expected(:)))+1e-16;
                                for path=["fixed","moving","event"]
                                    if ~isfield(actual.(method).(path),name)
                                        testCase.verifyEqual(path,"moving",configuration+" "+provider+" "+method+" missing "+name+" output");
                                        testCase.verifyFalse(ismember(name,string(movingPositions)),configuration+" "+provider+" "+method+" omitted metadata-declared moving "+name);
                                        continue
                                    end
                                    if path=="moving", testCase.verifyTrue(ismember(name,string(movingPositions)),configuration+" "+provider+" "+method+" unexpectedly emitted moving "+name); end
                                    observed=actual.(method).(path).(name);
                                    testCase.verifyLessThanOrEqual(max(abs(observed(:)-expected(:))),tolerance,configuration+" "+provider+" "+method+" "+path+" "+name);
                                end
                            end
                            for name=string(profiles)
                                expected=testCase.profileColumn(wvt,name,request.profiles.xIndices(find(string(profiles)==name,1)),request.profiles.yIndices(find(string(profiles)==name,1)));
                                observed=actual.(method).profiles.(name);
                                tolerance=2e-11*max(abs(expected(:)))+1e-16;
                                testCase.verifyLessThanOrEqual(max(abs(observed(:)-expected(:))),tolerance,configuration+" "+provider+" "+method+" profile "+name);
                            end
                        end
                    end
                end
            end
        end
    end
    methods (Access=private)
        function [wvt,path]=writeSource(testCase,family,antialias,configuration)
            grid=[8 6 9]; if antialias, grid=[7 5 8]; end
            if family=="barotropic"
                wvt=WVTransformBarotropicQG([17000 11000],grid(1:2),j=1,shouldAntialias=antialias);
            elseif family=="stratified-qg"
                wvt=WVTransformStratifiedQG([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            elseif family=="hydrostatic"
                wvt=WVTransformHydrostatic([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            elseif family=="boussinesq"
                wvt=WVTransformBoussinesq([17000 11000 1000],grid,Nj=4,N2Function=@(z)1e-4*exp(z/700),shouldAntialias=antialias);
            else
                wvt=WVTransformConstantStratification([17000 11000 1000],grid,N0=5.2e-3,isHydrostatic=family=="constant-hydrostatic",shouldAntialias=antialias);
            end
            n=reshape(1:numel(wvt.A0),size(wvt.A0));
            if ismember(family,["barotropic","stratified-qg"])
                wvt.A0=1e-6*complex(sin(.7*n),cos(.3*n));
                if isprop(wvt,"K"), wvt.A0(wvt.K==0 & wvt.L==0)=0; end
            else
                wave=wvt.J>0 & (wvt.K.^2+wvt.L.^2)>0; inertial=(wvt.K.^2+wvt.L.^2)==0;
                wvt.Ap=.001*(sin(.7*n)+1i*cos(.3*n))./(1+wvt.J).*(wave|inertial);
                wvt.Am=.002*(sin(.3*n)+1i*cos(.7*n))./(1+wvt.J).*wave;
                wvt.Am(inertial)=conj(wvt.Ap(inertial));
                mda=inertial & wvt.J>0; wvt.A0(mda)=.003*sin(n(mda));
            end
            wvt.t=37; wvt.t0=17; wvt.removeAllForcing();
            model=WVModel(wvt,shouldUseLinearDynamics=family=="barotropic" || family=="constant-hydrostatic" || family=="constant-nonhydrostatic");
            path=fullfile(testCase.folder,configuration+"-source.nc"); file=model.createNetCDFFileForModelOutput(path,outputInterval=.5,shouldOverwriteExisting=true); file.outputTimesForIntegrationPeriod(37,37); file.writeTimeStepToOutputFile(37); model.closeNetCDFFile();
        end
        function [x,y,z]=positionCoordinates(~,wvt,count)
            dx=wvt.Lx/wvt.Nx; dy=wvt.Ly/wvt.Ny;
            x=[.35*dx;wvt.Lx+.35*dx;2*dx]; y=[.6*dy;-wvt.Ly+.6*dy;3*dy];
            z=zeros(count,1); if isprop(wvt,"Lz"), z=-wvt.Lz*[.23;.61;.84]; end
            if count~=3, x=x(1:count); y=y(1:count); z=z(1:count); end
        end
        function values=profileColumn(~,wvt,name,xIndex,yIndex)
            value=wvt.(name);
            values=squeeze(value(xIndex,yIndex,:));
            values=values(:);
        end
    end
end
function writeJSON(path,value)
file=fopen(path,"w"); cleanup=onCleanup(@()fclose(file)); fwrite(file,jsonencode(value,PrettyPrint=true));
end
function [status,output]=cleanSystem(command)
[status,output]=system("env -u LD_LIBRARY_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH -u DYLD_FALLBACK_LIBRARY_PATH "+command);
end
function value=shellQuote(value)
value="'"+replace(string(value),"'","'""'""'")+"'";
end
