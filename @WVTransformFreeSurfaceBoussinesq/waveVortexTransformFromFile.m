function [wvt,ncfile] = waveVortexTransformFromFile(path,options)
% Restore resolved operators, one committed coefficient state, time and forcing.
% - Topic: Save transform state
% - Declaration: [wvt,ncfile] = waveVortexTransformFromFile(path,options)
% - Parameter path: NetCDF transform or model file
% - Parameter options.iTime: requested committed record; Inf selects the last
% - Parameter options.shouldReadOnly: open read-only by default
% - Returns wvt: reconstructed transform without a new scientific mode solve
% - Returns ncfile: open caller-owned file when requested; otherwise closed
arguments (Input)
    path char {mustBeFile}
    options.iTime (1,1) double {mustBePositive} = 1
    options.shouldReadOnly (1,1) logical = true
end
arguments (Output)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
    ncfile NetCDFFile
end
ncfile = NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
try
    wvt = WVTransformFreeSurfaceBoussinesq.transformFromGroup(ncfile);
    wvt.initFromNetCDFFile(ncfile,iTime=options.iTime,shouldDisplayInit=false);
    wvt.initForcingFromNetCDFFile(ncfile);
catch exception
    if ~isempty(ncfile.id), ncfile.close(); end
    rethrow(exception)
end
if nargout<2, ncfile.close(); end
end
