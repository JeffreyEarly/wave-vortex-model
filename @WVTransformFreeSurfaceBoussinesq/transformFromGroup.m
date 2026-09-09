function wvt = transformFromGroup(group)
% Restore the scientific representation without invoking a mode solver.
%
% Coefficient stream/time selection and forcing restoration belong to the
% file reader; this constructor adapter restores immutable scientific state.
%
% - Topic: Save transform state
% - Declaration: wvt = transformFromGroup(group)
% - Parameter group: group holding complete annotated scientific operators
% - Returns wvt: zero-state transform using the saved operators
arguments (Input)
    group (1,1) NetCDFGroup
end
arguments (Output)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
[Lxyz,Nxyz,args] = WVGeometryDoublyPeriodicStratified.requiredPropertiesForGeometryFromGroup(group);
state = struct(args{:});
state.Lxyz = Lxyz; state.Nxyz = Nxyz;
optional = [WVTransformFreeSurfaceBoussinesq.optionalEndpointPropertyNames(),WVTransformFreeSurfaceBoussinesq.optionalWavePropertyNames(),{'waveModeCountByKh'}];
names = setdiff(WVTransformFreeSurfaceBoussinesq.scientificPropertyNames(),optional);
values = CAAnnotatedClass.propertyValuesFromGroup(group,[names,{'activeEndpointCount','rhoFunction'}]);
for name = string(fieldnames(values)).', state.(name) = values.(name); end
if group.hasVariableWithName('waveModeCountByKh')
    values = CAAnnotatedClass.propertyValuesFromGroup(group,{'waveModeCountByKh'});
    state.waveModeCountByKh = values.waveModeCountByKh;
else
    % Uniform-count files predate the explicit count map.
    values = CAAnnotatedClass.propertyValuesFromGroup(group,{'waveMode'});
    state.waveModeCountByKh = repmat(length(values.waveMode),length(state.khUnique),1);
end
if any(state.waveModeCountByKh>0)
    values = CAAnnotatedClass.propertyValuesFromGroup(group,setdiff(WVTransformFreeSurfaceBoussinesq.optionalWavePropertyNames(),{'Aw_p','Aw_m'}));
    for name = string(fieldnames(values)).', state.(name) = values.(name); end
else
    nz=Nxyz(3); np=length(state.khUnique);
    state.waveMode=zeros(0,1); state.waveModeNumber=zeros(0,1);
    state.waveF=zeros(nz,0,np); state.waveG=zeros(nz,0,np);
    state.waveGForward=zeros(0,nz,np);
    state.waveEquivalentDepth=zeros(0,np); state.waveFrequency=zeros(0,np);
end
if state.activeEndpointCount>0
    values = CAAnnotatedClass.propertyValuesFromGroup(group,setdiff(WVTransformFreeSurfaceBoussinesq.optionalEndpointPropertyNames(),{'Ag_0'}));
    for name = string(fieldnames(values)).', state.(name) = values.(name); end
else
    nz=Nxyz(3); np=length(state.khUnique); nq=length(state.apvMode);
    state.activeEndpoint=zeros(0,1); state.apvEndpointResponse=zeros(0,nq,np);
    state.zeroAPVF=zeros(nz,0,np); state.zeroAPVG=zeros(nz,0,np);
    state.zeroAPVFPairing=zeros(0,nz,np); state.zeroAPVGPairing=zeros(0,nz,np);
    state.zeroAPVSourceSolve=zeros(0,0,np);
end
wvt = WVTransformFreeSurfaceBoussinesq(state);
end
