function [plus,minus] = projectFreeSurfaceWaves(wvt,page,columns,spectral,F,G,weights,N2)
% Apply the wave energy projection for one positive wavenumber page.
% A state supplies its Fourier SSH. A hatted equation source supplies the
% four independent volume components.
indices = wvt.klNonzero(columns);
U = F'*(weights.*spectral.u(:,indices));
V = F'*(weights.*spectral.v(:,indices));
W = G'*(weights.*spectral.w(:,indices));
E = G'*((weights.*N2).*spectral.eta(:,indices));
if isfield(spectral,"ssh")
    % At the surface the wave total displacement equals its SSH.
    E = E+wvt.g*G(end,:)'*spectral.ssh(indices);
end

k = wvt.kNonzero(columns).';
l = wvt.lNonzero(columns).';
kh = wvt.khUnique(page);
D = wvt.Lz;
omega = wvt.waveFrequency(1:size(F,2),page);
common = (k.*U+l.*V)/kh+1i*kh*D.*W;
signed = (1i*wvt.f./(omega*kh)).*(l.*U-k.*V)-(kh*D./omega).*E;
phase = exp(1i*omega*(wvt.t-wvt.t0));
plus = ((common+signed)/(2*D))./phase;
minus = ((common-signed)/(2*D)).*phase;
end
