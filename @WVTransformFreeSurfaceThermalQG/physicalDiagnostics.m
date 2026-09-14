function [diagnostics,radialSpectrum] = physicalDiagnostics(self,options)
% Measure physical RMS, native-grid peaks, radial spectra and horizontal tails.
%
% RMS uses physical-depth quadrature and includes horizontal means. Spectra
% are bin sums on the ordinary kRadial axis, not densities per wavenumber;
% their sum is the squared RMS. Tails report the fraction of squared RMS at
% physical horizontal radii above tailFraction times the largest retained
% radius. This diagnoses occupied horizontal bandwidth, not unresolved error
% or an APV vertical-mode spectrum. Peaks are sampled on the native grid.
%
% - Topic: Evaluate physical fields
% - Parameter options.flowComponent: optional family/component selection
% - Parameter options.tailFraction: fraction of maximum retained horizontal radius; default 0.8
% - Returns diagnostics: rms, peakAbsolute, horizontalTailFraction and tailWavenumber
% - Returns radialSpectrum: kRadial and squared-RMS bin sums for each physical field
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
    options.tailFraction (1,1) double {mustBeReal,mustBeFinite,mustBeGreaterThanOrEqual(options.tailFraction,0),mustBeLessThanOrEqual(options.tailFraction,1)} = .8
end
arguments (Output)
    diagnostics (1,1) struct
    radialSpectrum (1,1) struct
end
state=self.coefficientState(flowComponent=options.flowComponent);
operators=self.physicalMetricOperators();
names=["qgpv","buoyancy","speed","eta","eta_i","ssh","surfaceAnomaly","bottomAnomaly"];
mapNames=["q","buoyancy","psi","eta","eta_i","ssh","endpoint","endpoint"];
variances=zeros(numel(names),self.Nkl);
meanIndex=find(hypot(self.k,self.l)==0,1);
for j=1:numel(names)
    endpointRow=0; if j>=7, endpointRow=j-6; end
    for p=1:numel(self.khUnique)
        columns=self.klNonzeroKhUniqueIndex==p;
        map=operators.reconstruction{p}.(mapNames(j));
        if endpointRow>0, map=map(endpointRow,:); end
        value=map*state.Ath(:,columns);
        if j<=5
            weight=operators.weights/self.Lz;
            if j==3, weight=weight*self.khUnique(p)^2; end
            variance=2*sum(weight.*abs(value).^2,1);
        else
            variance=2*sum(abs(value).^2,1);
        end
        variances(j,self.klNonzero(columns))=variance;
    end
    if ~ismember(j,[3 6])
        map=operators.mda.reconstruction.(mapNames(j));
        if endpointRow>0, map=map(endpointRow,:); end
        value=map*state.Amda;
        if j<=5, variance=sum(operators.weights.*abs(value).^2)/self.Lz; else, variance=sum(abs(value).^2); end
        variances(j,meanIndex)=variance;
    end
end
binned=self.transformToRadialWavenumber(variances);
threshold=options.tailFraction*max(self.khUnique);
tail=hypot(self.k,self.l)>=threshold & hypot(self.k,self.l)>0;
fields=self.reconstructFields(["qgpv","buoyancy","u","v","eta","eta_i","ssh","endpointAnomalies"],flowComponent=options.flowComponent);
fields.speed=hypot(fields.u,fields.v); fields.surfaceAnomaly=fields.endpointAnomalies(:,:,1); fields.bottomAnomaly=fields.endpointAnomalies(:,:,2);
diagnostics=struct(rms=struct(),peakAbsolute=struct(),horizontalTailFraction=struct(),tailWavenumber=threshold);
radialSpectrum=struct(kRadial=self.kRadial);
for j=1:numel(names)
    total=sum(variances(j,:));
    diagnostics.rms.(names(j))=sqrt(total);
    diagnostics.peakAbsolute.(names(j))=max(abs(fields.(names(j))),[],'all');
    if total==0, fraction=0; else, fraction=sum(variances(j,tail))/total; end
    diagnostics.horizontalTailFraction.(names(j))=fraction;
    radialSpectrum.(names(j))=binned(j,:);
end
end
