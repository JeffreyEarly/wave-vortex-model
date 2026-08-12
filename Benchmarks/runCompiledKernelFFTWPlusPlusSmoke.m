function result = runCompiledKernelFFTWPlusPlusSmoke(options)
% Exercise pinned FFTW++ convolution correctness and lifecycle on small grids.
arguments
    options.module (1,1) string = "wv_compiled_transform_mex_fftwpp"
    options.mexDirectory (1,1) string
    options.runtimeLibrary (1,1) string
    options.sizes (:,3) double {mustBeInteger,mustBePositive} = [8 6 7; 9 7 7]
    options.hydrostatic (1,:) logical = [true false]
    options.variants (1,:) string = ["fftwpp-implicit" "fftwpp-hybrid"]
    options.threadCount (1,1) double {mustBeInteger,mustBePositive} = 1
end
repositoryRoot = fileparts(fileparts(mfilename("fullpath")));
originalPath = path; cleanup = onCleanup(@()path(originalPath));
addRepositoryPaths(repositoryRoot,options.mexDirectory);
moduleInfo = feval(options.module,'moduleInfo',char(options.runtimeLibrary));
records = repmat(struct("variant","","Nxyz",[],"isHydrostatic",false,"relativeInfinityError",NaN,"actualMaximum",NaN,"expectedMaximum",NaN,"leastSquaresScale",NaN,"zeroStateMaximum",NaN,"lifecyclePassed",false,"metrics",struct()),0,1);
for variant = options.variants
    for iSize = 1:size(options.sizes,1)
        for isHydrostatic = options.hydrostatic
            wvt = WVTransformConstantStratification([15000 12000 1300],options.sizes(iSize,:),isHydrostatic=isHydrostatic,shouldAntialias=true);
            initializeWaveVortexBenchmarkState(wvt,128000+iSize+100*isHydrostatic);
            before = feval(options.module,'moduleMetrics');
            handle = feval(options.module,'createConvolution',kernelConfiguration(wvt),options.threadCount,char(variant));
            handleCleanup = onCleanup(@()deleteHandle(options.module,handle));
            [actualFp,actualFm,actualF0] = feval(options.module,'nonlinearFlux',handle,wvt.Ap,wvt.Am,wvt.A0,wvt.t,wvt.t0);
            [expectedFp,expectedFm,expectedF0] = wvt.nonlinearFlux();
            relativeInfinityError = max([relativeError(actualFp,expectedFp) relativeError(actualFm,expectedFm) relativeError(actualF0,expectedF0)]);
            actualVector = [actualFp(:);actualFm(:);actualF0(:)]; expectedVector = [expectedFp(:);expectedFm(:);expectedF0(:)];
            actualMaximum = max(abs(actualVector)); expectedMaximum = max(abs(expectedVector)); leastSquaresScale = real(expectedVector'*actualVector)/real(expectedVector'*expectedVector);
            zerosState = complex(zeros(size(wvt.Ap)));
            [zeroFp,zeroFm,zeroF0] = feval(options.module,'nonlinearFlux',handle,zerosState,zerosState,zerosState,wvt.t,wvt.t0);
            zeroStateMaximum = max(abs([zeroFp(:);zeroFm(:);zeroF0(:)]));
            metrics = feval(options.module,'metrics',handle);
            clear handleCleanup
            after = feval(options.module,'moduleMetrics');
            lifecyclePassed = after.kernelCount == before.kernelCount && after.activePlans == before.activePlans && after.outstandingPlanningBytes == 0 && after.totalPlansCreated-after.totalPlansDestroyed == after.activePlans;
            records(end+1,1) = struct("variant",variant,"Nxyz",options.sizes(iSize,:),"isHydrostatic",isHydrostatic,"relativeInfinityError",relativeInfinityError,"actualMaximum",actualMaximum,"expectedMaximum",expectedMaximum,"leastSquaresScale",leastSquaresScale,"zeroStateMaximum",zeroStateMaximum,"lifecyclePassed",lifecyclePassed,"metrics",metrics); %#ok<AGROW>
            delete(wvt);
        end
    end
end
result = struct("status",conditional(all([records.relativeInfinityError]<=1e-12) && all([records.zeroStateMaximum]==0) && all([records.lifecyclePassed]),"complete","failed"),"moduleInfo",moduleInfo,"records",records);
end

function configuration = kernelConfiguration(wvt)
configuration = struct("Nx",wvt.Nx,"Ny",wvt.Ny,"Nz",wvt.Nz,"Nj",wvt.Nj,"Lx",wvt.Lx,"Ly",wvt.Ly,"Lz",wvt.Lz,"N0",wvt.N0,"rho0",wvt.rho0,"g",wvt.g,"planetaryRadius",wvt.planetaryRadius,"rotationRate",wvt.rotationRate,"latitude",wvt.latitude,"isHydrostatic",wvt.isHydrostatic,"shouldAntialias",wvt.shouldAntialias);
end

function value = relativeError(actual,expected)
value = max(abs(actual(:)-expected(:)),[],'omitmissing')/max(max(abs(expected(:)),[],'omitmissing'),realmin);
end

function deleteHandle(module,handle)
try
    feval(module,'delete',handle);
catch
end
end

function addRepositoryPaths(repositoryRoot,mexDirectory)
addpath(repositoryRoot,fullfile(repositoryRoot,"Benchmarks"),mexDirectory);
metadata = jsondecode(fileread(fullfile(repositoryRoot,"resources","mpackage.json")));
for iFolder = 1:numel(metadata.folders)
    folder = fullfile(repositoryRoot,metadata.folders(iFolder).path);
    if isfolder(folder), addpath(folder); end
end
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end
