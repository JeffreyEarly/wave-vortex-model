function transferFreeSurfaceForcing(source,target)
% Rebuild the source registry on a newly created target; reject generic fallback.
forces=WVForcing.empty(1,0);
for force=source.forcing
    metadata=metaclass(force);
    method=metadata.MethodList(strcmp({metadata.MethodList.Name},'forcingWithResolutionOfTransform'));
    if isempty(method) || strcmp(method.DefiningClass.Name,'WVForcing')
        error('WV:TransferForcing','Forcing %s (%s) has no resolution conversion. Remove it explicitly or implement forcingWithResolutionOfTransform.',force.name,class(force))
    end
    try
        converted=force.forcingWithResolutionOfTransform(target);
    catch exception
        failure=MException('WV:TransferForcing','Cannot transfer forcing %s (%s): %s',force.name,class(force),exception.message);
        throw(addCause(failure,exception))
    end
    if ~strcmp(class(converted),class(force)) || converted.wvt~=target || ~strcmp(converted.name,force.name)
        error('WV:TransferForcing','Forcing conversion must preserve class/name and bind to the target transform.')
    end
    if converted.priority~=force.priority || ~isequal(converted.forcingType,force.forcingType)
        error('WV:TransferForcing','Forcing conversion must preserve priority and forcing stages.')
    end
    forces(end+1)=converted;
end
target.setForcing(forces);
end
