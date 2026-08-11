function providers = compiledKernelNativeFFTWProviders
% Describe the pinned issue #137 FFTW build matrix.
common = struct( ...
    "version","3.3.11", ...
    "sourceURL","https://fftw.org/pub/fftw/fftw-3.3.11.tar.gz", ...
    "sourceSHA256","5630c24cdeb33b131612f7eb4b1a9934234754f9f388ff8617458d0be6f239a1", ...
    "deploymentTarget","13.3", ...
    "compilerFlags","-O3 -mcpu=native -mmacosx-version-min=13.3", ...
    "threadBackend","pthreads", ...
    "expectedThreadLibraryName","libfftw3_threads.3.dylib", ...
    "requiresOpenMP",false, ...
    "simplicityRank",1);
providers = repmat(common,4,1);
providers(1).id = "native-plain-pthreads";
providers(1).configureFlags = "--enable-threads --disable-fortran --disable-openmp --enable-shared --disable-static";
providers(1).description = "Historical issue #41 native control without an explicit SIMD switch.";

providers(2).id = "native-neon-pthreads";
providers(2).configureFlags = "--host=aarch64-apple-darwin --enable-neon --enable-threads --disable-fortran --disable-openmp --enable-shared --disable-static";
providers(2).description = "Explicit Apple ARM NEON with POSIX threads.";

providers(3).id = "native-simd128-pthreads";
providers(3).configureFlags = "--host=aarch64-apple-darwin --enable-generic-simd128 --enable-threads --disable-fortran --disable-openmp --enable-shared --disable-static";
providers(3).description = "Generic compiler-vector 128-bit SIMD with POSIX threads.";
providers(3).simplicityRank = 2;

providers(4).id = "native-neon-openmp";
providers(4).configureFlags = "--host=aarch64-apple-darwin --enable-neon --disable-threads --enable-openmp --disable-fortran --enable-shared --disable-static";
providers(4).description = "Explicit Apple ARM NEON with the pinned local LLVM OpenMP runtime.";
providers(4).threadBackend = "openmp";
providers(4).expectedThreadLibraryName = "libfftw3_omp.3.dylib";
providers(4).requiresOpenMP = true;
providers(4).simplicityRank = 3;
end
