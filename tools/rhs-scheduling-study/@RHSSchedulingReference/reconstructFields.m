function fields = reconstructFields(self,variableNames,options)
% Reconstruct selected fields on the reference samples and moving mesh.
%
% u/v/w are physical velocities; u_hat/v_hat/w_hat are the modal variables.
% The existing z axis remains the fixed reference coordinate, while
% z_physical is the moving mesh. eta is total displacement and
% eta_i=eta-(1+z/Lz)*ssh. p is reconstructed modal pressure,
% including hydrostatic MDA. It supplies the quadratic-order pressure
% approximation in the manuscript nonlinear terms.
%
% Component velocities use the total state's geometry, so disjoint component
% contributions add to the full velocity. z_physical has no
% component partition. Mean SSH retains the existing zero-mean gauge.
%
% - Topic: Reconstruct and project fields
% - Declaration: fields = reconstructFields(variableNames,options)
% - Parameter variableNames: row of supported field names
% - Parameter options.flowComponent: component of this transform; empty selects all
% - Returns fields: named Nx by Ny by Nz arrays; surface fields are Nx by Ny
arguments (Input)
    self (1,1) RHSSchedulingReference
    variableNames (1,:) string {mustBeNonempty}
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
arguments (Output)
    fields (1,1) struct
end
if any(~ismember(variableNames,string(self.namesOfTransformVariables())))
    error('WVTransform:UnknownVariable','Request fields listed by namesOfTransformVariables.')
end
if ~isempty(options.flowComponent) && any(ismember(variableNames,"z_physical"))
    error('WVTransform:TotalStateVariable','z_physical describes the total state and has no component partition.')
end
component = options.flowComponent;
if ~isempty(component) && (~isscalar(component) || component.wvt ~= self)
    error('WVTransform:InvalidComponent','Select one component belonging to this transform.')
end
fields = struct();
needed = variableNames;
hasValue = false(size(variableNames));
for index = 1:numel(variableNames)
    name=variableNames(index);
    [found,value] = cached(name,component);
    if found, fields.(name)=value; hasValue(index)=true; end
end
needed=needed(~hasValue);
if isempty(needed), return; end
rawNames = ["u","v","w","eta","p","qgpv"];
volume = false(1,6); surface = false(1,6);
for name = needed
    switch name
        case {"u","u_hat"}, volume(1)=true;
        case {"v","v_hat"}, volume(2)=true;
        case "w", volume(1:3)=true;
        case {"w_hat","w_i"}, volume(3)=true;
        case {"eta","eta_i"}, volume(4)=true;
        case "p", volume(5)=true;
        case "qgpv", volume(6)=true;
        case "ssu", surface(1)=true;
        case "ssv", surface(2)=true;
    end
end
needsGeometry = any(needed.'==["u","v","w","ssu","ssv","w_i","z_physical"],'all');
needsSSH = any(needed.'==["ssh","eta_i"],'all') || (needsGeometry && isempty(component));
sampled = struct(); endpoint = struct();
for index = find(volume | surface)
    name=rawNames(index);
    key=sampleName(name);
    if any(needed==key), continue; end
    [found,value] = cached(key,component);
    if found, sampled.(name)=value; volume(index)=false; end
end
for name = rawNames(surface)
    if isfield(sampled,name)
        endpoint.(name)=sampled.(name)(:,:,end);
    end
end
if needsSSH
    [found,ssh] = cached("ssh",component);
    if found
        endpoint.ssh=ssh;
    else
        if ~isfield(sampled,'p') && ~volume(5)
            [found,pressure]=cached("p",component);
            if found, sampled.p=pressure; end
        end
        if isfield(sampled,'p')
            endpoint.ssh=sampled.p(:,:,end)/(self.rho0*self.g);
        else
            surface(5)=true;
        end
    end
end
for index = find(surface)
    if volume(index) || isfield(endpoint,rawNames(index)), surface(index)=false; end
end
volumeNames=rawNames(volume); surfaceNames=rawNames(surface);
if ~isempty(volumeNames) || ~isempty(surfaceNames)
    state = self.coefficientState(flowComponent=component);
    if ~isempty(volumeNames)
        spectral = WVInternal.freeSurfaceSelectedSpectralFields(self,state,volumeNames,1:self.Nz);
        for name = volumeNames
            sampled.(name)=self.transformToSpatialDomainWithFourier(spectral.(name));
            if any(needed==sampleName(name)), remember(sampleName(name),sampled.(name),component); end
        end
    end
    if ~isempty(surfaceNames)
        spectral = WVInternal.freeSurfaceSelectedSpectralFields(self,state,surfaceNames,self.Nz);
        geometry = self.surfaceGeometry();
        for name = surfaceNames, endpoint.(name)=geometry.transformToSpatialDomainWithFourier(spectral.(name)); end
    end
end
for name = ["u","v"]
    if isfield(sampled,name), endpoint.(name)=sampled.(name)(:,:,end); end
end
if needsSSH && ~isfield(endpoint,'ssh')
    if isfield(sampled,'p'), endpoint.p=sampled.p(:,:,end); end
    endpoint.ssh=endpoint.p/(self.rho0*self.g);
end
if needsSSH, remember("ssh",endpoint.ssh,component); end
if needsGeometry
    if isempty(component)
        totalSSH=endpoint.ssh;
    else
        [found,totalSSH]=cached("ssh",WVFlowComponent.empty(0,0));
        if ~found
            total = WVInternal.freeSurfaceSelectedSpectralFields(self,self.coefficientState(),"p",self.Nz);
            geometry=self.surfaceGeometry();
            totalSSH=geometry.transformToSpatialDomainWithFourier(total.p)/(self.rho0*self.g);
            remember("ssh",totalSSH,WVFlowComponent.empty(0,0));
        end
    end
    gamma=1+totalSSH/self.Lz;
    if any(~isfinite(gamma) | gamma<=0,'all')
        error('WV:InvalidFreeSurfaceGeometry','Surface height must be finite and greater than minus the reference depth everywhere.')
    end
end
if any(needed.'==["w","w_i","z_physical","eta_i"],'all'), alpha=reshape(1+self.z/self.Lz,1,1,[]); end
if any(needed=="u" | needed=="w"), physicalU=sampled.u./gamma; end
if any(needed=="v" | needed=="w"), physicalV=sampled.v./gamma; end
for name = needed
    switch name
        case "u", value=physicalU;
        case "v", value=physicalV;
        case "w", value=sampled.w+alpha.*(physicalU.*self.diffX(totalSSH)+physicalV.*self.diffY(totalSSH));
        case "w_i", value=(sampled.w-alpha.*sampled.w(:,:,end))./gamma;
        case "z_physical", value=reshape(self.z,1,1,[])+alpha.*totalSSH;
        case {"u_hat","v_hat","w_hat"}, value=sampled.(extractBefore(name,"_hat"));
        case "eta_i", value=sampled.eta-alpha.*endpoint.ssh;
        case "ssu", value=endpoint.u./gamma;
        case "ssv", value=endpoint.v./gamma;
        case "ssh", value=endpoint.ssh;
        otherwise, value=sampled.(name);
    end
    fields.(name)=value;
    if ~any(name==["u_hat","v_hat","w_hat","eta","p","qgpv","ssh"]), remember(name,value,component); end
end

    function [found,value] = cached(name,selection)
        key = cacheKey(name,selection);
        found = key~="" && isKey(self.variableCache,key);
        value=[];
        if found, value=self.variableCache{key}; end
    end
    function remember(name,value,selection)
        key=cacheKey(name,selection);
        if key~="", self.addToVariableCache(key,value); end
    end
    function key = cacheKey(name,selection)
        key=name;
        if ~isempty(selection), key=key+"_"+string(selection.abbreviatedName); end
        if ~isKey(self.operationVariableNameMap,key), key=""; return; end
        annotation=self.operationVariableNameMap(key);
        op=annotation.modelOp;
        if ~isa(op,'WVInternal.FreeSurfaceFieldOperation') || ~isequal(op.component,selection), key=""; end
    end
end

function name = sampleName(name)
if any(name==["u","v","w"]), name=name+"_hat"; end
end
