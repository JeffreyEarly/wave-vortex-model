function data=linearEvolutionData(self)
% Build transient eigencoordinates and physical norms from authoritative arrays.
% - Topic: Density diffusion integration
% - Returns data: family packing, homogeneous rates, source and norm adapters
if ~isempty(self.linearEvolutionData_), data=self.linearEvolutionData_; return; end
shape=size(self.Ath); count=numel(self.Ath); m=self.mdaModeCount;
A=self.mdaGeneratorPerDiffusivity;
[V,D]=eig(A,'nobalance'); lambda=diag(D); inverse=V\eye(m);
if norm(A*V-V*D,'fro')/max(norm(A,'fro')*norm(V,'fro'),realmin)>1e-10 || norm(inverse*V-eye(m),'fro')>1e-8
    error('WV:ThermalMeanEvolution','Stored MDA generator has no qualified invertible eigenbasis.');
end
rates=self.kappa_z*self.thermalRatesPerDiffusivity(:,self.klNonzeroKhUniqueIndex);
factors=cell(numel(self.khUnique)+1,5);
[z,weights]=legpts(self.assemblyQuadratureCount); z=self.Lz*(z-1)/2; weights=weights(:)/2;
r=WVInternal.thermalPolynomialFields(z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
e=WVInternal.thermalPolynomialFields([0;-self.Lz],self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
for p=1:numel(self.khUnique)
    C=self.thermalToPolynomial(:,:,p); kh=self.khUnique(p);
    maps={sqrt(weights).*((r.qgpv-kh^2*r.psi)*C),sqrt(weights).*(r.buoyancy*C),sqrt(weights)*kh.*(r.psi*C),e.eta_i(1,:)*C,e.eta_i(2,:)*C};
    for k=1:5, [~,factors{p,k}]=qr(maps{k},0); end
end
% Mean maps use the authoritative native sampling, without an InternalModes solve.
w=sqrt(self.verticalQuadratureWeights/self.Lz);
maps={w.*(-self.f*self.mdaGZ),w.*(-self.N2.*self.mdaG),zeros(1,m),self.mdaG(end,:),self.mdaG(1,:)};
for k=1:5, [~,factors{end,k}]=qr(maps{k},0); end
data=struct(familyNames=["Ath","Amda"],familyShapes={{shape,size(self.Amda)}},rates=[rates(:);self.kappa_z*lambda], ...
    toModes=@toModes,fromModes=@fromModes,physicalNormFactors={factors},physicalErrorNorms=@physicalNorms, ...
    projectSource=@(q,b)self.projectQuasigeostrophicSpatialTendency(q,b));
self.linearEvolutionData_=data;
    function c=toModes(state)
        c=[state.Ath(:);inverse*state.Amda];
    end
    function state=fromModes(c)
        if ~iscolumn(c) || numel(c)~=count+m || any(~isfinite(c)), error('WV:DensityDiffusionState','Supply a finite packed thermal state.'); end
        meanState=V*c(count+1:end);
        if norm(imag(meanState))>1e-12*max(norm(meanState),realmin), error('WV:DensityDiffusionMeanReality','MDA must reconstruct a real mean.'); end
        state=struct(Ath=reshape(c(1:count),shape),Amda=real(meanState));
    end
    function values=physicalNorms(c)
        state=fromModes(c); variance=zeros(1,5);
        for page=1:numel(self.khUnique)
            columns=self.klNonzeroKhUniqueIndex==page;
            for field=1:5, variance(field)=variance(field)+2*sum(abs(factors{page,field}*state.Ath(:,columns)).^2,'all'); end
        end
        for field=1:5, variance(field)=variance(field)+sum(abs(factors{end,field}*state.Amda).^2); end
        values=sqrt(variance);
    end
end
