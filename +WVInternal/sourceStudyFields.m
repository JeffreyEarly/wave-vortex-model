function fields = sourceStudyFields(data,familyName,vectorIndex)
% Evaluate physical polarizations, retaining both wave frequency signs.
arguments
    data (1,1) struct
    familyName (1,1) string {mustBeMember(familyName,["wave","apv","boundary"])}
    vectorIndex (1,1) double {mustBeInteger,mustBePositive}
end
kl=data.inventory.physicalVectors(vectorIndex,:); kh=hypot(kl(1),kl(2));
[~,page]=min(abs(data.inventory.magnitudes-kh));
switch familyName
    case "wave", B=data.wave{page};
    case "apv", B=data.apv;
    case "boundary", B=data.boundary{page};
end
fields=struct(labels=B.labels,positions=B.positions,signs=B.signs,tail=B.tail);
if familyName=="wave"
    fields.labels=repelem(B.labels,2); fields.positions=repelem(B.positions,2);
    fields.signs=repmat([1 -1],1,length(B.labels)); fields.tail=repelem(B.tail,2);
end
for setName=["S","R","Q","E","H","J"]
    values=B.(setName);
    if familyName=="wave" && isempty(B.labels)
        for name=["u","v","w","eta","du","dv","dw","deta"], fields.(setName).(name)=zeros(size(values.F,1),0); end
        continue
    end
    if familyName=="wave"
        h=B.basis.h(1:numel(B.labels)); h=h(:); if ismember(setName,["H","J"]), h=B.checkh; end
        pol=WVInternal.freeSurfaceWavePolarization(values.F,values.G,h,kl(1),kl(2),f=data.config.f,g=data.config.g);
        derivative=WVInternal.freeSurfaceWavePolarization(values.dF,values.dG,h,kl(1),kl(2),f=data.config.f,g=data.config.g);
        for name=["u","v","w","eta"]
            fields.(setName).(name)=reshape(permute(pol.(name),[1 3 2]),size(values.F,1),[]);
            fields.(setName).("d"+name)=reshape(permute(derivative.(name),[1 3 2]),size(values.F,1),[]);
        end
    else
        % Unit streamfunction amplitude; canonical APV/boundary coefficient
        % conversion is a nonzero scalar per mode and cancels in this metric.
        fields.(setName)=struct(u=-1i*kl(2)*values.F,v=1i*kl(1)*values.F,w=zeros(size(values.F)),eta=(data.config.f/data.config.g)*values.G,du=-1i*kl(2)*values.dF,dv=1i*kl(1)*values.dF,dw=zeros(size(values.F)),deta=(data.config.f/data.config.g)*values.dG);
    end
end
end
