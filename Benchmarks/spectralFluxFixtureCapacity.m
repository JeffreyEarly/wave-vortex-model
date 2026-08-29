function capacity = spectralFluxFixtureCapacity(options)
% Estimate deterministic storage for one spectral-flux fixture export.
%
% The estimate uses WVM's horizontal mode selection and floating
% K-squared grouping without constructing the variable-stratification
% vertical operators. Byte counts named `estimated` describe explicit
% MATLAB arrays owned by the exporter and transform; MATLAB runtime,
% eigensolver, FFT, Java, and allocator overhead remain unaccounted.
arguments (Input)
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [256 256 129]
    options.Lxyz (1,3) double {mustBePositive} = [15e3 15e3 1300]
end
arguments (Output)
    capacity (1,1) struct
end

if options.Nxyz(1) ~= options.Nxyz(2) || options.Lxyz(1) ~= options.Lxyz(2)
    error("WaveVortexBenchmark:SpectralFluxFixtureRequiresSquareDomain","The spectral-flux fixture requires equal horizontal grid counts and domain lengths.")
end
if mod(options.Nxyz(1),2) ~= 0 || options.Nxyz(3) < 4
    error("WaveVortexBenchmark:InvalidSpectralFluxFixtureSize","The spectral-flux fixture requires an even horizontal grid and Nz >= 4.")
end

benchmarkFolder = string(fileparts(mfilename("fullpath")));
repositoryRoot = string(fileparts(benchmarkFolder));
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(repositoryRoot,benchmarkFolder);

Nx = options.Nxyz(1);
Ny = options.Nxyz(2);
Nz = options.Nxyz(3);
Nj = floor(2*(Nz-1)/3);
geometry = WVGeometryDoublyPeriodic(options.Lxyz(1:2),options.Nxyz(1:2),Nz=1,shouldAntialias=true,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
K2 = reshape(sqrt(geometry.k.^2+geometry.l.^2).^2,[],1);
Nkl = geometry.Nkl;
groupCount = numel(unique(K2));

bytesPerDouble = 8;
bytesPerComplex = 16;
operatorPayloadBytes = 2*2*Nz*Nj*groupCount*bytesPerDouble;
modalInputBytes = Nj*15*Nkl*bytesPerComplex;
modalTargetBytes = Nj*4*Nkl*bytesPerComplex;
metadataPayloadBytes = 2*Nkl*4+Nj*4+Nkl*4+groupCount*8;
sourcePayloadBytes = operatorPayloadBytes+modalInputBytes+modalTargetBytes+metadataPayloadBytes;

QGwgBytes = Nj*Nj*groupCount*bytesPerDouble;
preconditionerBytes = 2*Nj*groupCount*bytesPerDouble;
groupModeBytes = Nj*groupCount*bytesPerDouble;
expandedModeBytes = Nj*Nkl*bytesPerDouble;
wvBufferBytes = Nz*Nkl*bytesPerDouble;
estimatedTransformResidentBytes = operatorPayloadBytes+QGwgBytes+preconditionerBytes+groupModeBytes+expandedModeBytes+wvBufferBytes;

realVolumeBytes = Nx*Ny*Nz*bytesPerDouble;
complexSpectrumBytes = Nz*Nkl*bytesPerComplex;
chunkWorkspaceBytes = 3*(2^20)*bytesPerDouble;
estimatedExporterAdditionalLiveBytes = modalInputBytes+modalTargetBytes+8*realVolumeBytes+2*complexSpectrumBytes+chunkWorkspaceBytes;
estimatedExporterPeakBytes = estimatedTransformResidentBytes+estimatedExporterAdditionalLiveBytes;

capacity = struct( ...
    "schema","spectral-flux-fixture-capacity-v1", ...
    "workload",struct("Nx",Nx,"Ny",Ny,"Nz",Nz,"Nkl",Nkl,"Nj",Nj,"groupCount",groupCount), ...
    "payloadBytes",struct("metadata",metadataPayloadBytes,"verticalOperators",operatorPayloadBytes,"modalInputs",modalInputBytes,"modalTargets",modalTargetBytes,"sourceFixtureTotal",sourcePayloadBytes,"preparedFixtureApproximate",sourcePayloadBytes,"sourceAndPreparedApproximate",2*sourcePayloadBytes), ...
    "exporterBytes",struct("estimatedWvmTransformResident",estimatedTransformResidentBytes,"estimatedAdditionalLive",estimatedExporterAdditionalLiveBytes,"estimatedPeak",estimatedExporterPeakBytes,"recommendedPhysicalMemory",ceil(1.25*estimatedExporterPeakBytes)), ...
    "diskBytes",struct("recommendedFreeForSourceAndPrepared",ceil(1.10*2*sourcePayloadBytes)), ...
    "limitations","Estimated explicit MATLAB arrays only; runtime, eigensolver, FFT, Java, allocator, temporary copy, filesystem, and benchmark-provider overhead are excluded.");
clear pathCleanup
end
