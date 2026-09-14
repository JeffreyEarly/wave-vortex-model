function modes=thermalManufacturedState(w,degrees,amplitude,vectors)
% Independent monomial pressure amplitudes, including their signed conjugates.
if nargin<4, vectors=[1 0;0 2;1 1]; end
phases=[1,.7+.2i,-.4+.3i]; modes=struct('k',{},'l',{},'p',{});
for j=1:3
    k=2*pi*vectors(j,1)/w.Lx; l=2*pi*vectors(j,2)/w.Ly;
    column=find(abs(w.k(w.klNonzero)-k)<1e-14 & abs(w.l(w.klNonzero)-l)<1e-14);
    assert(isscalar(column),'The manufactured interaction must be retained.');
    p=zeros(1,max(2,degrees(j))+1); p(end-degrees(j))=1; p(end-1)=p(end-1)+.3; p(end)=p(end)+1;
    p=amplitude*phases(j)*p;
    [x,weights]=legpts(w.thermalModeCount+2);
    r=WVInternal.thermalPolynomialFields((x-1)*w.Lz/2,w.thermalModeCount,w.Lz,w.N20,0,0,w.f,w.g);
    % This r evaluates Legendre polynomials at x, independent of physical WKB.
    c=r.psi'*(weights(:).*polyval(p,x)); c=c.*((2*(0:w.thermalModeCount-1)'+1)/2);
    page=w.klNonzeroKhUniqueIndex(column);
    w.Ath(:,column)=w.polynomialToThermal(:,:,page)*c;
    modes(end+1)=struct(k=k,l=l,p=p); %#ok<AGROW>
    modes(end+1)=struct(k=-k,l=-l,p=conj(p)); %#ok<AGROW>
end
end
