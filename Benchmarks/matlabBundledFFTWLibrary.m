function libraryPath = matlabBundledFFTWLibrary
% Return the active MATLAB installation's bundled double-precision FFTW library.
libraryDirectory = fullfile(matlabroot,"bin",computer("arch"));
if ismac
    libraryName = "libmwfftw3.3.dylib";
elseif isunix
    libraryName = "libmwfftw3.so.3";
else
    error("WaveVortexModel:UnsupportedCompiledKernelPlatform", ...
        "The authoring compiled-kernel gateway is supported only on macOS and Linux.");
end
libraryPath = string(fullfile(libraryDirectory,libraryName));
if ~isfile(libraryPath)
    error("WaveVortexModel:MissingBundledFFTW", ...
        "MATLAB's bundled FFTW library was not found at %s.",libraryPath);
end
[status,resolvedPath] = system(sprintf('/bin/realpath "%s"',libraryPath));
if status ~= 0
    error("WaveVortexModel:BundledFFTWPathResolutionFailed", ...
        "MATLAB's bundled FFTW library path could not be resolved: %s",libraryPath);
end
libraryPath = string(strtrim(resolvedPath));
end
