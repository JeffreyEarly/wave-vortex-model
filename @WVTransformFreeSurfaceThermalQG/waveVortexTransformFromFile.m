function [w,file]=waveVortexTransformFromFile(path,options)
% Restore a canonical thermal snapshot without a scientific mode solve.
% - Topic: Create and restore a transform
% - Parameter path: snapshot NetCDF path
% - Parameter options.iTime: snapshot index, currently 1 only
% - Parameter options.shouldReadOnly: open the returned file read-only
% - Returns w: restored thermal transform
% - Returns file: caller-owned open NetCDF file when requested
arguments
    path char {mustBeFile}
    options.iTime (1,1) double {mustBeMember(options.iTime,1)} = 1
    options.shouldReadOnly (1,1) logical = true
end
file=NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
try
    w=WVTransformFreeSurfaceThermalQG.annotatedClassFromGroup(file);
catch exception
    file.close(); rethrow(exception);
end
if nargout<2, file.close(); end
end
