function [wvt,ncfile] = waveVortexTransformFromFile(path,options)
% Restore modal arrays, committed state, and forcing without an eigensolve.
% - Topic: Create and restore a transform
arguments
    path char {mustBeFile}
    options.iTime (1,1) double {mustBePositive} = 1
    options.shouldReadOnly (1,1) logical = true
end
ncfile=NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
try
    names=WVTransformFreeSurfaceQGDiffusion.scientificPropertyNames();
    optional={'verticalNumerics','shouldDealiasVertical'};
    values=CAAnnotatedClass.propertyValuesFromGroup(ncfile,setdiff(names,optional));
    for name=string(optional)
        if ncfile.hasGroupWithName(name) || ncfile.hasVariableWithName(name)
            additional=CAAnnotatedClass.propertyValuesFromGroup(ncfile,{char(name)});
            values.(name)=additional.(name);
        end
    end
    args=namedargs2cell(values);
    wvt=WVTransformFreeSurfaceQGDiffusion(args{:});
    wvt.initFromNetCDFFile(ncfile,iTime=options.iTime);
    wvt.initForcingFromNetCDFFile(ncfile);
catch exception
    ncfile.close();
    rethrow(exception)
end
if nargout<2, ncfile.close(); end
end
