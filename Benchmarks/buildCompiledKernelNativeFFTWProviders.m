function result = buildCompiledKernelNativeFFTWProviders(options)
% Build the pinned issue #137 native FFTW providers and MEX gateways.
arguments
    options.providerIds (1,:) string = ["native-plain-pthreads" "native-neon-pthreads" "native-simd128-pthreads" "native-neon-openmp"]
    options.cacheRoot (1,1) string = fullfile(fileparts(fileparts(mfilename("fullpath"))),".fftw-cache","issue137")
    options.shouldBuildMex (1,1) logical = true
    options.shouldForceRebuild (1,1) logical = false
    options.jobs (1,1) double {mustBeInteger,mustBePositive} = maxNumCompThreads
end
if ~ismac || string(computer("arch")) ~= "maca64"
    error("WaveVortexModel:NativeFFTWUnsupportedPlatform","Issue #137 native providers require macOS maca64.");
end
allProviders = compiledKernelNativeFFTWProviders;
selected = allProviders(ismember([allProviders.id],options.providerIds));
if numel(selected) ~= numel(options.providerIds)
    unknown = setdiff(options.providerIds,[allProviders.id]);
    error("WaveVortexModel:NativeFFTWUnknownProvider","Unknown issue #137 provider: %s",strjoin(unknown,", "));
end
if ~isfolder(options.cacheRoot), mkdir(options.cacheRoot); end
compiler = compilerRecord;
archives = sourceArchives(options.cacheRoot);
verifyArchive(archives.fftw);
if any([selected.requiresOpenMP])
    verifyArchive(archives.llvm);
    verifyArchive(archives.cmake);
    openmp = buildOpenMPRuntime(options.cacheRoot,archives,compiler,options.jobs,options.shouldForceRebuild);
else
    openmp = emptyOpenMPRecord;
end

builds = repmat(emptyBuild,0,1);
for iProvider = 1:numel(selected)
    builds(end+1,1) = buildProvider(selected(iProvider),options.cacheRoot,archives.fftw,openmp,compiler,options); %#ok<AGROW>
end
result = struct( ...
    "schemaVersion","1.0.0", ...
    "cacheRoot",options.cacheRoot, ...
    "compiler",compiler, ...
    "archives",archives, ...
    "openmp",openmp, ...
    "providers",builds);
end

function build = buildProvider(provider,cacheRoot,archive,openmp,compiler,options)
keyInput = strjoin([provider.sourceSHA256 provider.configureFlags provider.compilerFlags computer("arch") compiler.identity openmp.sourceSHA256],"|");
buildKey = extractBefore(sha256Text(keyInput),17);
buildRoot = fullfile(cacheRoot,"providers",provider.id+"-"+buildKey);
sourceRoot = fullfile(buildRoot,"source");
sourceDirectory = fullfile(sourceRoot,"fftw-3.3.11");
installDirectory = fullfile(buildRoot,"install");
logDirectory = fullfile(buildRoot,"logs");
stampPath = fullfile(buildRoot,"complete.json");
if options.shouldForceRebuild && isfolder(buildRoot), rmdir(buildRoot,"s"); end
if ~isfolder(logDirectory), mkdir(logDirectory); end

baseLibrary = fullfile(installDirectory,"lib","libfftw3.3.dylib");
threadLibrary = fullfile(installDirectory,"lib",provider.expectedThreadLibraryName);
if ~(isfile(stampPath) && isfile(baseLibrary) && isfile(threadLibrary))
    if ~isfolder(sourceDirectory)
        if ~isfolder(sourceRoot), mkdir(sourceRoot); end
        runCommand("/usr/bin/tar -xzf "+shellQuote(archive.path)+" -C "+shellQuote(sourceRoot),"extract FFTW",fullfile(logDirectory,"extract.log"));
    end
    compilerPath = compiler.path;
    if provider.requiresOpenMP
        compilerPath = writeOpenMPCompilerWrapper(buildRoot,compiler.path,openmp);
    end
    compileFlags = provider.compilerFlags+" -isysroot "+compiler.sdkPath;
    linkFlags = "-mmacosx-version-min="+provider.deploymentTarget+" -isysroot "+compiler.sdkPath+" -Wl,-headerpad_max_install_names";
    commonEnvironment = "env SDKROOT="+shellQuote(compiler.sdkPath)+" MACOSX_DEPLOYMENT_TARGET="+provider.deploymentTarget+" CC="+shellQuote(compilerPath)+" CFLAGS="+shellQuote(compileFlags)+" LDFLAGS="+shellQuote(linkFlags);
    configure = "cd "+shellQuote(sourceDirectory)+" && "+commonEnvironment+" ./configure --prefix="+shellQuote(installDirectory)+" "+provider.configureFlags;
    runCommand(configure,"configure "+provider.id,fullfile(logDirectory,"configure.log"));
    configureText = string(fileread(fullfile(logDirectory,"configure.log")));
    cycleCounterPassed = contains(configureText,"checking whether a cycle counter is available... yes");
    if ~cycleCounterPassed || contains(lower(configureText),"warning: no cycle counter")
        error("WaveVortexModel:NativeFFTWCycleCounter","%s did not validate an Apple ARM cycle counter.",provider.id);
    end
    runCommand("cd "+shellQuote(sourceDirectory)+" && /usr/bin/make -j"+options.jobs,"compile "+provider.id,fullfile(logDirectory,"make.log"));
    runCommand("cd "+shellQuote(sourceDirectory)+" && /usr/bin/make check","test "+provider.id,fullfile(logDirectory,"check.log"));
    runCommand("cd "+shellQuote(sourceDirectory)+" && /usr/bin/make install","install "+provider.id,fullfile(logDirectory,"install.log"));
    if ~isfile(baseLibrary) || ~isfile(threadLibrary)
        error("WaveVortexModel:NativeFFTWLibraryMissing","%s did not produce the expected FFTW libraries.",provider.id);
    end
    writeText(stampPath,jsonencode(struct("provider",provider.id,"buildKey",buildKey,"completedAtUTC",utcTimestamp),PrettyPrint=true));
else
    configureText = string(fileread(fullfile(logDirectory,"configure.log")));
    cycleCounterPassed = contains(configureText,"checking whether a cycle counter is available... yes");
end

if provider.requiresOpenMP
    providerRuntimeLibrary = fullfile(installDirectory,"lib","libwvissue137omp.dylib");
    if ~isfile(providerRuntimeLibrary)
        copyfile(openmp.library,providerRuntimeLibrary);
        runCommand("/usr/bin/install_name_tool -id @loader_path/libwvissue137omp.dylib "+shellQuote(providerRuntimeLibrary),"assign the provider OpenMP runtime identity",fullfile(logDirectory,"openmp-runtime-identity.log"));
    end
    dependencies = string(runCommandWithOutput("/usr/bin/otool -L "+shellQuote(threadLibrary),"inspect "+provider.id+" OpenMP dependencies"));
    if contains(dependencies,"@rpath/libomp.dylib")
        runCommand("/usr/bin/install_name_tool -change @rpath/libomp.dylib @loader_path/libwvissue137omp.dylib "+shellQuote(threadLibrary),"bind "+provider.id+" to the pinned OpenMP runtime",fullfile(logDirectory,"openmp-link.log"));
        dependencies = string(runCommandWithOutput("/usr/bin/otool -L "+shellQuote(threadLibrary),"reinspect "+provider.id+" OpenMP dependencies"));
    end
    if ~contains(dependencies,"@loader_path/libwvissue137omp.dylib"), error("WaveVortexModel:NativeFFTWOpenMPIdentity","%s does not depend on the pinned OpenMP runtime.",provider.id); end
end
linkLibraries = [string(threadLibrary) string(baseLibrary)];
rpathDirectories = string(fullfile(installDirectory,"lib"));
runtimeLibrary = "";
if provider.requiresOpenMP
    runtimeLibrary = string(providerRuntimeLibrary);
    rpathDirectories(end+1) = string(fileparts(runtimeLibrary));
end
module = "wv_compiled_transform_mex_"+replace(provider.id,"-","_");
providerDescriptor = struct("id",provider.id,"version",provider.version,"threadBackend",provider.threadBackend,"includeDirectory",string(fullfile(installDirectory,"include")),"linkLibraries",linkLibraries,"rpathDirectories",unique(rpathDirectories,"stable"));
mexPath = ""; mexSha256 = "";
if options.shouldBuildMex
    mexDirectory = fullfile(buildRoot,"mex");
    [mexPath,mexBuild] = buildCompiledKernelTransformMex(outputDirectory=mexDirectory,outputName=module,provider=providerDescriptor);
    mexSha256 = mexBuild.mexSha256;
end
build = struct( ...
    "id",provider.id,"description",provider.description,"version",provider.version,"threadBackend",provider.threadBackend,"simplicityRank",provider.simplicityRank, ...
    "buildKey",buildKey,"buildRoot",string(buildRoot),"installDirectory",string(installDirectory),"includeDirectory",string(fullfile(installDirectory,"include")), ...
    "baseLibrary",string(baseLibrary),"threadLibrary",string(threadLibrary),"runtimeLibrary",runtimeLibrary,"configureFlags",provider.configureFlags,"compilerFlags",provider.compilerFlags, ...
    "cycleCounterPassed",cycleCounterPassed,"checkPassed",isfile(fullfile(sourceDirectory,"tests","bench")),"module",module,"mexPath",string(mexPath),"mexSha256",mexSha256, ...
    "baseLibrarySha256",sha256File(baseLibrary),"threadLibrarySha256",sha256File(threadLibrary),"logs",struct("configure",string(fullfile(logDirectory,"configure.log")),"make",string(fullfile(logDirectory,"make.log")),"check",string(fullfile(logDirectory,"check.log")),"install",string(fullfile(logDirectory,"install.log"))));
end

function openmp = buildOpenMPRuntime(cacheRoot,archives,compiler,jobs,shouldForce)
keyInput = strjoin([archives.llvm.sha256 archives.cmake.sha256 compiler.identity computer("arch")],"|");
buildKey = extractBefore(sha256Text(keyInput),17);
root = fullfile(cacheRoot,"openmp","llvm-22.1.8-"+buildKey);
sourceParent = fullfile(root,"source");
sourceDirectory = fullfile(sourceParent,"llvm-project-22.1.8.src","openmp");
buildDirectory = fullfile(root,"build");
installDirectory = fullfile(root,"install");
logDirectory = fullfile(root,"logs");
installedLibrary = fullfile(installDirectory,"lib","libomp.dylib");
library = fullfile(installDirectory,"lib","libwvissue137omp.22.1.8.dylib");
if shouldForce && isfolder(root), rmdir(root,"s"); end
if ~isfolder(logDirectory), mkdir(logDirectory); end
cmakeRoot = fullfile(cacheRoot,"tools","cmake-4.1.0");
cmakeExecutable = fullfile(cmakeRoot,"cmake-4.1.0-macos-universal","CMake.app","Contents","bin","cmake");
if ~isfile(cmakeExecutable)
    if ~isfolder(cmakeRoot), mkdir(cmakeRoot); end
    runCommand("/usr/bin/tar -xzf "+shellQuote(archives.cmake.path)+" -C "+shellQuote(cmakeRoot),"extract CMake",fullfile(logDirectory,"cmake-extract.log"));
end
if ~isfolder(sourceDirectory)
    if ~isfolder(sourceParent), mkdir(sourceParent); end
    runCommand("/usr/bin/tar -xJf "+shellQuote(archives.llvm.path)+" -C "+shellQuote(sourceParent),"extract LLVM OpenMP",fullfile(logDirectory,"llvm-extract.log"));
end
ninja = string(fullfile(matlabroot,"toolbox","shared","coder","ninja","maca64","ninja"));
if ~isfile(ninja), error("WaveVortexModel:NativeFFTWNinjaMissing","MATLAB's bundled Ninja executable is unavailable."); end
if ~isfile(installedLibrary)
    configure = shellQuote(cmakeExecutable)+" -S "+shellQuote(sourceDirectory)+" -B "+shellQuote(buildDirectory)+" -G Ninja -DCMAKE_MAKE_PROGRAM="+shellQuote(ninja)+" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="+shellQuote(compiler.path)+" -DCMAKE_CXX_COMPILER="+shellQuote(compiler.cxxPath)+" -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3 -DCMAKE_INSTALL_PREFIX="+shellQuote(installDirectory)+" -DOPENMP_ENABLE_LIBOMPTARGET=OFF -DLIBOMP_OMPT_SUPPORT=OFF -DLIBOMP_ENABLE_SHARED=ON";
    runCommand(configure,"configure LLVM OpenMP",fullfile(logDirectory,"configure.log"));
    runCommand(shellQuote(cmakeExecutable)+" --build "+shellQuote(buildDirectory)+" --parallel "+jobs,"compile LLVM OpenMP",fullfile(logDirectory,"build.log"));
    runCommand(shellQuote(cmakeExecutable)+" --install "+shellQuote(buildDirectory),"install LLVM OpenMP",fullfile(logDirectory,"install.log"));
end
if ~isfile(installedLibrary), error("WaveVortexModel:NativeFFTWOpenMPLibraryMissing","The pinned LLVM OpenMP build did not produce libomp.dylib."); end
if ~isfile(library)
    copyfile(installedLibrary,library);
    runCommand("/usr/bin/install_name_tool -id "+shellQuote(library)+" "+shellQuote(library),"assign the pinned OpenMP runtime a unique install identity",fullfile(logDirectory,"identity.log"));
end
includeDirectory = fullfile(installDirectory,"include");
openmp = struct("version","22.1.8","sourceURL",archives.llvm.url,"sourceSHA256",archives.llvm.sha256,"cmakeVersion","4.1.0","cmakeSHA256",archives.cmake.sha256,"buildKey",buildKey,"root",string(root),"installDirectory",string(installDirectory),"includeDirectory",string(includeDirectory),"library",string(library),"librarySha256",sha256File(library));
end

function wrapper = writeOpenMPCompilerWrapper(buildRoot,compilerPath,openmp)
wrapper = fullfile(buildRoot,"apple-clang-openmp");
lines = ["#!/bin/bash";"translated=()";"for argument in ""$@""; do";"  if [[ ""$argument"" == ""-fopenmp"" ]]; then";"    translated+=(""-Xpreprocessor"" ""-fopenmp"")";"  else";"    translated+=(""$argument"")";"  fi";"done";"exec "+shellQuote(compilerPath)+" ""${translated[@]}"" -I"+shellQuote(openmp.includeDirectory)+" -L"+shellQuote(fileparts(openmp.library))+" -Wl,-rpath,"+shellQuote(fileparts(openmp.library))+" -lomp"];
writeText(wrapper,join(lines,newline)+newline);
[status,output] = system("/bin/chmod +x "+shellQuote(wrapper));
if status ~= 0, error("WaveVortexModel:NativeFFTWOpenMPWrapper","Unable to make the OpenMP compiler wrapper executable: %s",output); end
end

function archives = sourceArchives(cacheRoot)
downloads = fullfile(cacheRoot,"downloads");
archives.fftw = archiveRecord("fftw-3.3.11",fullfile(downloads,"fftw-3.3.11.tar.gz"),"https://fftw.org/pub/fftw/fftw-3.3.11.tar.gz","5630c24cdeb33b131612f7eb4b1a9934234754f9f388ff8617458d0be6f239a1");
archives.llvm = archiveRecord("llvm-project-22.1.8",fullfile(downloads,"llvm-project-22.1.8.src.tar.xz"),"https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/llvm-project-22.1.8.src.tar.xz","922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888");
archives.cmake = archiveRecord("cmake-4.1.0",fullfile(downloads,"cmake-4.1.0-macos-universal.tar.gz"),"https://github.com/Kitware/CMake/releases/download/v4.1.0/cmake-4.1.0-macos-universal.tar.gz","08cbe0b807799a90216923acf457481538c8d0608a19ba9203219387427a4055");
end

function record = archiveRecord(id,path,url,sha256)
record = struct("id",id,"path",string(path),"url",url,"sha256",sha256);
end

function verifyArchive(record)
if ~isfile(record.path), error("WaveVortexModel:NativeFFTWArchiveMissing","Missing pinned archive %s. Download it from %s.",record.path,record.url); end
actual = sha256File(record.path);
if actual ~= record.sha256, error("WaveVortexModel:NativeFFTWChecksumMismatch","%s SHA-256 was %s; expected %s.",record.id,actual,record.sha256); end
end

function record = compilerRecord
[status,path] = system("/usr/bin/xcrun --find clang");
if status ~= 0, error("WaveVortexModel:NativeFFTWCompilerMissing","Apple Clang is unavailable."); end
[status,cxxPath] = system("/usr/bin/xcrun --find clang++");
if status ~= 0, error("WaveVortexModel:NativeFFTWCompilerMissing","Apple Clang++ is unavailable."); end
[status,identity] = system(strtrim(path)+" --version");
if status ~= 0, error("WaveVortexModel:NativeFFTWCompilerMissing","Unable to query Apple Clang."); end
[status,sdkPath] = system("/usr/bin/xcrun --show-sdk-path");
if status ~= 0 || ~isfolder(strtrim(sdkPath)), error("WaveVortexModel:NativeFFTWSDKMissing","The macOS SDK is unavailable."); end
record = struct("path",string(strtrim(path)),"cxxPath",string(strtrim(cxxPath)),"sdkPath",string(strtrim(sdkPath)),"identity",string(strtrim(identity)));
end

function runCommand(command,description,logPath)
wrapped = command+" > "+shellQuote(logPath)+" 2>&1";
[status,output] = system(wrapped);
if status ~= 0
    details = string(output);
    if isfile(logPath), details = string(fileread(logPath)); end
    error("WaveVortexModel:NativeFFTWBuildFailed","Unable to %s.%s%s",description,newline,details);
end
end

function output = runCommandWithOutput(command,description)
[status,output] = system(command);
if status ~= 0, error("WaveVortexModel:NativeFFTWBuildFailed","Unable to %s.%s%s",description,newline,output); end
end

function quoted = shellQuote(value)
quoted = "'"+replace(string(value),"'","'""'""'")+"'";
end

function hash = sha256File(pathname)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:HashFailure","Unable to hash %s.",pathname); end
hash = extractBefore(string(strtrim(output))," ");
end

function hash = sha256Text(value)
pathname = string(tempname); cleanup = onCleanup(@()deleteIfPresent(pathname)); writeText(pathname,value); hash = sha256File(pathname); clear cleanup
end

function writeText(pathname,value)
fileId = fopen(pathname,"w");
if fileId < 0, error("WaveVortexModel:FileWriteFailed","Unable to write %s.",pathname); end
cleanup = onCleanup(@()fclose(fileId)); fprintf(fileId,"%s",value); clear cleanup
end

function deleteIfPresent(pathname)
if isfile(pathname), delete(pathname); end
end

function value = utcTimestamp
value = string(datetime("now","TimeZone","UTC","Format","yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function value = emptyOpenMPRecord
value = struct("version","","sourceURL","","sourceSHA256","","cmakeVersion","","cmakeSHA256","","buildKey","","root","","installDirectory","","includeDirectory","","library","","librarySha256","");
end

function value = emptyBuild
value = struct("id","","description","","version","","threadBackend","","simplicityRank",NaN,"buildKey","","buildRoot","","installDirectory","","includeDirectory","","baseLibrary","","threadLibrary","","runtimeLibrary","","configureFlags","","compilerFlags","","cycleCounterPassed",false,"checkPassed",false,"module","","mexPath","","mexSha256","","baseLibrarySha256","","threadLibrarySha256","","logs",struct());
end
