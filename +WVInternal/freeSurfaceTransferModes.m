function [M,labels] = freeSurfaceTransferModes(w,family,column,P,time)
% Return resolved modal polarizations on a common quadrature, including SSH.
% Rows stack u,v,w,eta and one SSH endpoint. Mean IO is represented by a
% complex polarization plus its conjugate; mean MDA is real and occurs once.
n=size(P,1); p=1; k=0; l=0;
if column>0
    p=w.klNonzeroKhUniqueIndex(column); k=w.kNonzero(column); l=w.lNonzero(column);
end
switch family
    case "Ag_q"
        labels=w.apvModeNumber; F=(P*w.apvF)./(-w.apvMu(:,p).'); G=(P*w.apvG)./(-w.apvMu(:,p).');
        surface=w.apvF(end,:)./(-w.apvMu(:,p).');
        M=[-1i*l*F;1i*k*F;zeros(size(F));(w.f/w.g)*G;(w.f/w.g)*surface];
    case "Ag_0"
        labels=w.activeEndpoint; F=-(P*w.zeroAPVF(:,:,p))/(k^2+l^2); G=-(P*w.zeroAPVG(:,:,p))/(k^2+l^2);
        surface=-w.zeroAPVF(end,:,p)/(k^2+l^2);
        M=[-1i*l*F;1i*k*F;zeros(size(F));(w.f/w.g)*G;(w.f/w.g)*surface];
    case {"Aw_p","Aw_m"}
        labels=w.waveModeNumber; sign=1; page=1;
        if family=="Aw_m", sign=-1; page=2; end
        % Append the true surface so the shared polarization computes SSH
        % there, rather than at the last interior quadrature point.
        F=[P*w.waveF(:,:,p);w.waveF(end,:,p)];
        G=[P*w.waveG(:,:,p);w.waveG(end,:,p)];
        fields=WVInternal.freeSurfaceWavePolarization(F,G,w.waveEquivalentDepth(:,p),k,l,f=w.f,g=w.g,rho0=w.rho0);
        phase=exp(sign*1i*w.waveFrequency(:,p).'*(time-w.t0));
        M=[fields.u(1:n,:,page);fields.v(1:n,:,page);fields.w(1:n,:,page);fields.eta(1:n,:,page);fields.ssh(:,:,page)].*phase;
    case "Aio"
        labels=w.inertialModeNumber; F=(P*w.inertialF)*exp(1i*w.f*(time-w.t0));
        M=[F;1i*F;zeros(2*n+1,length(labels))];
    case "Amda"
        labels=w.mdaModeNumber; M=[zeros(3*n,length(labels));P*w.mdaG;zeros(1,length(labels))];
    otherwise
        error('WV:TransferFamily','Unsupported free-surface coefficient family %s.',family)
end
labels=labels(:);
if length(unique(labels))~=length(labels)
    error('WV:TransferIdentity','Physical mode labels must be unique within each family.')
end
end
