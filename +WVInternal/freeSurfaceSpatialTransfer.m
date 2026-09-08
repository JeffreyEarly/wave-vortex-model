function [values,relativeError] = freeSurfaceSpatialTransfer(source,target,values)
% Regrid a real volume field using compact Fourier identities and stored maps.
if ~isequal([source.Lx source.Ly source.Lz],[target.Lx target.Ly target.Lz])
    error('WV:TransferIncompatible','Spatial source transfer requires identical physical domains.')
end
P=WVInternal.qgVerticalInterpolation(source.z,target.z);
back=WVInternal.qgVerticalInterpolation(target.z,source.z);
S=source.transformFromSpatialDomainWithFourier(values);
[common,index]=ismember([target.kMode_wv,target.lMode_wv],[source.kMode_wv,source.lMode_wv],'rows');
T=complex(zeros(target.Nz,target.Nkl)); T(:,common)=P*S(:,index(common));
restored=complex(zeros(size(S))); restored(:,index(common))=back*T(:,common);
% Compare the original sampled pattern, including content the source's own
% compact Fourier representation cannot retain (such as Nyquist samples).
roundtrip=source.transformToSpatialDomainWithFourier(restored);
metric=reshape(source.verticalQuadratureWeights,1,1,[]);
relativeError=sqrt(sum(metric.*abs(values-roundtrip).^2,'all')/max(sum(metric.*abs(values).^2,'all'),realmin));
values=target.transformToSpatialDomainWithFourier(T);
end
