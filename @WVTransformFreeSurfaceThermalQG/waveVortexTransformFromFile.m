function [w,file]=waveVortexTransformFromFile(path,options)
% Restore thermal scientific state, a committed coefficient record and forcing.
% Stored generators rebuild numerical caches on integrator attachment; no
% scientific mode construction or qualification is performed by restoration.
% - Topic: Create and restore a transform
% - Parameter path: snapshot or model-output NetCDF path
% - Parameter options.iTime: committed record index; Inf selects the last
% - Parameter options.shouldReadOnly: open the returned file read-only
% - Returns w: restored thermal transform
% - Returns file: caller-owned open NetCDF file when requested
arguments (Input)
    path char {mustBeFile}
    options.iTime (1,1) double {mustBeReal,mustBePositive} = 1
    options.shouldReadOnly (1,1) logical = true
end
arguments (Output)
    w (1,1) WVTransformFreeSurfaceThermalQG
    file NetCDFFile
end
if ~isinf(options.iTime) && options.iTime~=fix(options.iTime)
    error('WVTransform:InvalidRestartIndex','iTime must be a positive integer or Inf.');
end
file=NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
try
    w=WVTransformFreeSurfaceThermalQG.annotatedClassFromGroup(file);
    w.initFromNetCDFFile(file,iTime=options.iTime,shouldRequireCoefficientState=true);
    w.initForcingFromNetCDFFile(file);
catch exception
    if ~isempty(file.id), file.close(); end
    rethrow(exception)
end
if nargout<2, file.close(); end
end
