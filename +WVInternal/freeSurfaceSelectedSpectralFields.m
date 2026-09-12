function fields = freeSurfaceSelectedSpectralFields(self,state,names,rows)
% Synthesize only requested hatted fields on selected reference rows.
% State validation belongs to the public caller. SSH uses the top pressure
% row; callers request p here and convert it to SSH after synthesis.
Z = numel(rows);
selected = any(names.'==["u","v","w","eta","p","qgpv"],1);
waveNames = names(names~="qgpv");
fields = struct();
for name = names, fields.(name)=complex(zeros(Z,self.Nkl)); end
for p = 1:length(self.khUnique)
    columns = find(self.klNonzeroKhUniqueIndex==p);
    indices = self.klNonzero(columns);
    if any(selected([1 2 4 5]))
        aq = -state.Ag_q(:,columns)./self.apvMu(:,p);
        a0 = -state.Ag_0(:,columns)/self.khUnique(p)^2;
        if any(selected([1 2 5]))
            psi = self.apvF(rows,:)*aq+self.zeroAPVF(rows,:,p)*a0;
            if selected(1), fields.u(:,indices)=-1i*self.lNonzero(columns).'.*psi; end
            if selected(2), fields.v(:,indices)=1i*self.kNonzero(columns).'.*psi; end
            if selected(5), fields.p(:,indices)=self.rho0*self.f*psi; end
        end
        if selected(4), fields.eta(:,indices)=(self.f/self.g)*(self.apvG(rows,:)*aq+self.zeroAPVG(rows,:,p)*a0); end
    end
    if selected(6), fields.qgpv(:,indices)=self.apvF(rows,:)*state.Ag_q(:,columns); end
    count = self.waveModeCountByKh(p);
    if count==0 || isempty(waveNames), continue; end
    modes = 1:count;
    phase = exp(1i*self.waveFrequency(modes,p)*(self.t-self.t0));
    for c = 1:length(columns)
        j = columns(c); index = indices(c);
        polarizations = WVInternal.freeSurfaceWavePolarization(self.waveF(rows,modes,p),self.waveG(rows,modes,p),self.waveEquivalentDepth(modes,p),self.kNonzero(j),self.lNonzero(j),f=self.f,g=self.g,rho0=self.rho0,variables=waveNames);
        a = [state.Aw_p(modes,j).*phase;state.Aw_m(modes,j).*conj(phase)];
        for name = waveNames
            fields.(name)(:,index) = fields.(name)(:,index)+reshape(polarizations.(name),Z,[])*a;
        end
    end
end
meanIndex = find(self.k==0 & self.l==0,1);
if any(selected([1 2]))
    io = self.inertialF(rows,:)*(state.Aio*exp(1i*self.f*(self.t-self.t0)));
    if selected(1), fields.u(:,meanIndex)=2*real(io); end
    if selected(2), fields.v(:,meanIndex)=2*real(1i*io); end
end
if selected(4), fields.eta(:,meanIndex)=self.mdaG(rows,:)*state.Amda; end
if selected(5), fields.p(:,meanIndex)=self.rho0*self.mdaPressureMode(rows,:)*state.Amda; end
if selected(6), fields.qgpv(:,meanIndex)=-self.f*self.verticalDerivativeMatrix(rows,:)*(self.mdaG*state.Amda); end
end
