function value=thermalReadinessForcingState(w)
% Capture registered forcing metadata and authoritative required properties.
% Preserve registry order, property order and numeric types so existing
% restart forcing identities remain unchanged. Derived numerical caches
% are reconstructed by the forcing and integrator interfaces.
% - Topic: Developer utilities
% - Parameter w: transform whose registered forcing state is captured
% - Returns value: row cell of data-only forcing records in registry order
arguments (Input)
    w (1,1) WVTransform
end
arguments (Output)
    value (1,:) cell
end
value=cell(1,numel(w.forcing));
for j=1:numel(w.forcing)
    f=w.forcing(j); entry=struct(class=string(class(f)),name=string(f.name),priority=f.priority);
    for name=string(f.requiredProperties), entry.(name)=f.(name); end
    value{j}=entry;
end
end
