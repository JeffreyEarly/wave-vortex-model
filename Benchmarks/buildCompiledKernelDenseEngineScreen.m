function result = buildCompiledKernelDenseEngineScreen(options)
% Build the pinned issue #129 dense-engine screening executable.
arguments
    options.cacheRoot (1,1) string = fullfile(fileparts(fileparts(mfilename("fullpath"))),".pffft-cache","issue129")
    options.fftwCacheRoot (1,1) string = ""
    options.pffftSource (1,1) string = ""
    options.shouldForceRebuild (1,1) logical = false
end
if ~ismac || string(computer("arch")) ~= "maca64"
    error("WaveVortexModel:DenseEngineUnsupportedPlatform","Issue #129 requires macOS maca64.");
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
sourcePath = fullfile(repositoryRoot,"Benchmarks","compiled-kernel","issue129_dense_engine_screen.cpp");
if ~isfolder(options.cacheRoot), mkdir(options.cacheRoot); end
options.cacheRoot = canonicalPath(options.cacheRoot);
pffftCommit = "a4b03590cc2a4bea56f9721996e3057835799179";
if strlength(options.fftwCacheRoot) == 0, options.fftwCacheRoot = locateFFTWCache(repositoryRoot); end
if strlength(options.pffftSource) == 0
    options.pffftSource = fullfile(options.cacheRoot,"source","pffft");
end
ensurePFFFTSource(options.pffftSource,pffftCommit);
fftwBuild = buildCompiledKernelNativeFFTWProviders(providerIds="native-neon-pthreads",cacheRoot=options.fftwCacheRoot,shouldBuildMex=false);
provider = fftwBuild.providers(1);
compiler = fftwBuild.compiler;
buildKey = extractBefore(sha256Text(strjoin([sha256File(sourcePath) pffftCommit provider.baseLibrarySha256 compiler.identity "PFFFT_ENABLE_NEON=1"],"|")),17);
buildRoot = fullfile(options.cacheRoot,"build",buildKey);
executable = fullfile(buildRoot,"issue129_dense_engine_screen");
if options.shouldForceRebuild && isfolder(buildRoot), rmdir(buildRoot,"s"); end
if ~isfolder(buildRoot), mkdir(buildRoot); end
if ~isfile(executable)
    includeFlags = "-I"+shellQuote(fullfile(options.pffftSource,"include"))+" -I"+shellQuote(fullfile(options.pffftSource,"include","pffft"))+" -I"+shellQuote(fullfile(options.pffftSource,"src"))+" -I"+shellQuote(provider.includeDirectory);
    commonFlags = "-O3 -mcpu=native -DPFFFT_ENABLE_NEON=1 -mmacosx-version-min=13.3 -isysroot "+shellQuote(compiler.sdkPath)+" "+includeFlags;
    doubleObject = fullfile(buildRoot,"pffft_double.o");
    commonObject = fullfile(buildRoot,"pffft_common.o");
    runCommand(shellQuote(compiler.path)+" -std=c11 "+commonFlags+" -c "+shellQuote(fullfile(options.pffftSource,"src","pffft_double.c"))+" -o "+shellQuote(doubleObject),"compile PFFFT double source");
    runCommand(shellQuote(compiler.path)+" -std=c11 "+commonFlags+" -c "+shellQuote(fullfile(options.pffftSource,"src","pffft_common.c"))+" -o "+shellQuote(commonObject),"compile PFFFT common source");
    libraryDirectory = fileparts(provider.baseLibrary);
    link = shellQuote(compiler.cxxPath)+" -std=c++20 "+commonFlags+" "+shellQuote(sourcePath)+" "+shellQuote(doubleObject)+" "+shellQuote(commonObject)+" "+shellQuote(provider.threadLibrary)+" "+shellQuote(provider.baseLibrary)+" -Wl,-rpath,"+shellQuote(libraryDirectory)+" -framework Accelerate -o "+shellQuote(executable);
    runCommand(link,"link issue #129 dense-engine screen");
end
result = struct("schemaVersion","1.0.0","executable",string(canonicalPath(executable)),"executableSha256",sha256File(executable),"source",string(sourcePath),"sourceSha256",sha256File(sourcePath),"pffft",struct("repository","marton78/pffft","commit",pffftCommit,"source",string(canonicalPath(options.pffftSource))),"fftw",provider,"compiler",compiler,"buildKey",buildKey);
end

function cacheRoot = locateFFTWCache(repositoryRoot)
candidates = [fullfile(repositoryRoot,".fftw-cache","issue137"); string(fullfile(fileparts(repositoryRoot),"wave-vortex-model-issue-137",".fftw-cache","issue137"))];
for candidate = candidates'
    if isfile(fullfile(candidate,"downloads","fftw-3.3.11.tar.gz")), cacheRoot = candidate; return; end
end
error("WaveVortexModel:NativeFFTWCacheMissing","The pinned issue #137 FFTW cache was not found. Supply fftwCacheRoot explicitly.");
end

function ensurePFFFTSource(sourceDirectory,commit)
if ~isfolder(sourceDirectory)
    parent = fileparts(sourceDirectory); if ~isfolder(parent), mkdir(parent); end
    runCommand("git clone --filter=blob:none https://github.com/marton78/pffft.git "+shellQuote(sourceDirectory),"clone PFFFT");
end
[status,head] = system("git -C "+shellQuote(sourceDirectory)+" rev-parse HEAD");
if status ~= 0, error("WaveVortexModel:PFFFTSourceInvalid","Unable to inspect PFFFT source."); end
if string(strtrim(head)) ~= commit
    runCommand("git -C "+shellQuote(sourceDirectory)+" fetch origin "+commit,"fetch pinned PFFFT commit");
    runCommand("git -C "+shellQuote(sourceDirectory)+" checkout --detach "+commit,"check out pinned PFFFT commit");
end
[status,dirty] = system("git -C "+shellQuote(sourceDirectory)+" status --porcelain");
if status ~= 0 || strlength(strtrim(string(dirty))) ~= 0, error("WaveVortexModel:PFFFTSourceDirty","Pinned PFFFT source is not clean."); end
end

function runCommand(command,description)
[status,output] = system(command);
if status ~= 0, error("WaveVortexModel:DenseEngineBuildFailed","Unable to %s.%s%s",description,newline,output); end
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
pathname = string(tempname); cleanup = onCleanup(@()delete(pathname)); fileId=fopen(pathname,"w"); fwrite(fileId,value); fclose(fileId); hash=sha256File(pathname); clear cleanup
end

function pathname = canonicalPath(pathname)
[status,output] = system("/bin/realpath "+shellQuote(pathname));
if status ~= 0, error("WaveVortexModel:PathResolutionFailed","Unable to resolve %s: %s",pathname,output); end
pathname = string(strtrim(output));
end
