function tolerances = coefficientAbsoluteTolerances(self,absTolerance)
% Scale local coefficient errors by positive unit-coefficient physical energy.
%
% Each radial bin receives a flat error-energy density independently for
% each retained mode and family. Horizontal means receive the clipped zero
% bin width. Inactive wave padding is assigned a finite unused tolerance.
% Mixed balanced energy cross terms remain a separate validation diagnostic.
%
% - Topic: Project physical sources
% - Declaration: tolerances = coefficientAbsoluteTolerances(absTolerance)
% - Parameter absTolerance: positive square-root spectral energy-density scale in m2 s-1
% - Returns tolerances: positive arrays following coefficientStateAnnotations
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
    absTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
end
arguments (Output)
    tolerances (1,1) struct
end
empty=self.coefficientState();
names=string(fieldnames(empty)).';
for name=names, empty.(name)=zeros(size(empty.(name))); end
kh=reshape(self.khNonzero,1,[]);
radial=self.kRadial;
if isempty(radial), radial=0; end
if numel(radial)>1, dk=radial(2)-radial(1); else, dk=min(2*pi./[self.Lx,self.Ly]); end
width=radial+dk/2-max(radial-dk/2,0);
meanColumn=self.k==0 & self.l==0;
for name=names
    shape=size(empty.(name));
    alpha=absTolerance*ones(shape);
    isMean=ismember(name,["Aio","Amda"]);
    active=true(shape);
    if ismember(name,["Aw_p","Aw_m"]), active=self.activeWaveModes; end
    for mode=1:shape(1)
        state=empty; state.(name)(mode,:)=active(mode,:);
        fields=self.reconstructSpectralState(state=state);
        energy=sum(self.verticalQuadratureWeights.*(abs(fields.u).^2+abs(fields.v).^2+abs(fields.w).^2+self.N2.*abs(fields.eta).^2),1)+self.g*abs(fields.ssh(end,:)).^2;
        if isMean
            factor=energy(meanColumn)/2;
            share=width(1);
        else
            factor=energy(self.klNonzero);
            share=zeros(size(factor));
            for b=1:numel(radial)
                inBin=active(mode,:) & kh>radial(b)-dk/2 & kh<=radial(b)+dk/2;
                if any(inBin), share(inBin)=width(b)/nnz(inBin); end
            end
        end
        selected=active(mode,:);
        if any(~isfinite(factor(selected)) | factor(selected)<=0 | share(selected)<=0)
            error('WVTransformFreeSurfaceBoussinesq:InvalidToleranceMetric','Every retained coefficient requires positive finite physical energy and radial allocation.');
        end
        alpha(mode,selected)=absTolerance*sqrt(share(selected)./factor(selected));
    end
    tolerances.(name)=alpha;
end
end
