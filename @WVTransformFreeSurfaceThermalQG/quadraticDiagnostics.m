function [diagnostics,byWavenumber,horizontalMean] = quadraticDiagnostics(self,options)
% Evaluate physical inventories and individual or batched directional rates.
%
% Energy is the horizontal average of
% $$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2$$
% in m3 s-2. Potential enstrophy is the full reconstructed
% $$Z=\frac12\int_{-D}^{0}q^2\,dz$$ in m s-2. Both endpoint anomaly
% variances are half second moments in m2, including their horizontal means.
% All nonorthogonal cross terms are retained. No signed generalized inventory
% is implied by the thermal eigenvector normalization.
%
% A row of tendencies shares the same reconstructed state. Rate fields have
% suffix Tendency and one row per input tendency; spectra have one column per
% klNonzero. Conjugate partners are included once. Summing a spectrum and its
% horizontalMean term recovers the total. Rate units are inventory units/s.
%
% - Topic: Evaluate physical fields
% - Parameter options.state: Ath/Amda structure; defaults to current state
% - Parameter options.tendency: optional row of Ath/Amda directional tendencies
% - Returns diagnostics: energy components, total energy, potential enstrophy and endpoint second moments
% - Returns byWavenumber: compact nonzero contributions including conjugate partners
% - Returns horizontalMean: independent MDA inventories and rates
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    options.state (1,1) struct = struct()
    options.tendency (1,:) struct = struct()
end
arguments (Output)
    diagnostics (1,1) struct
    byWavenumber (1,1) struct
    horizontalMean (1,1) struct
end
state=options.state;
if isempty(fieldnames(state)), state=self.coefficientState(); end
validateState(self,state);
hasTendency=~isempty(options.tendency) && ~isempty(fieldnames(options.tendency));
derivative=[]; meanDerivative=[]; nTendency=0;
if hasTendency
    for j=1:numel(options.tendency), validateState(self,options.tendency(j)); end
    derivative=cat(3,options.tendency.Ath); meanDerivative=horzcat(options.tendency.Amda);
    nTendency=numel(options.tendency);
end
operators=self.physicalMetricOperators();
names=string(fieldnames(operators.pages{1}.factors)).';
diagnostics=struct(); byWavenumber=struct(); horizontalMean=struct();
for name=names
    byWavenumber.(name)=zeros(1,numel(self.klNonzero));
    if hasTendency, byWavenumber.(name+"Tendency")=zeros(nTendency,numel(self.klNonzero)); end
    for p=1:numel(self.khUnique)
        columns=self.klNonzeroKhUniqueIndex==p;
        factor=operators.pages{p}.factors.(name); a=factor*state.Ath(:,columns);
        byWavenumber.(name)(columns)=sum(abs(a).^2,1);
        if hasTendency
            da=pagemtimes(factor,derivative(:,columns,:));
            power=2*real(sum(conj(a).*da,1));
            byWavenumber.(name+"Tendency")(:,columns)=reshape(power,nnz(columns),nTendency).';
        end
    end
    factor=operators.mda.factors.(name); a=factor*state.Amda;
    horizontalMean.(name)=sum(abs(a).^2)/2;
    diagnostics.(name)=sum(byWavenumber.(name))+horizontalMean.(name);
    if hasTendency
        horizontalMean.(name+"Tendency")=real(a'*(factor*meanDerivative)).';
        diagnostics.(name+"Tendency")=sum(byWavenumber.(name+"Tendency"),2)+horizontalMean.(name+"Tendency");
    end
end
diagnostics=completeEnergy(diagnostics,hasTendency);
byWavenumber=completeEnergy(byWavenumber,hasTendency);
horizontalMean=completeEnergy(horizontalMean,hasTendency);
end

function value=completeEnergy(value,hasTendency)
suffixes=""; if hasTendency, suffixes=["","Tendency"]; end
for suffix=suffixes
    value.("totalEnergy"+suffix)=value.("kineticEnergy"+suffix)+value.("interiorPotentialEnergy"+suffix)+value.("surfacePotentialEnergy"+suffix);
end
end

function validateState(w,state)
if ~isequal(sort(string(fieldnames(state))),["Amda";"Ath"])
    error('WV:DiagnosticState','Supply exactly the canonical families Ath and Amda.');
end
if ~isnumeric(state.Ath) || ~isequal(size(state.Ath),size(w.Ath)) || any(~isfinite(state.Ath),'all')
    error('WV:ThermalCoefficientShape','Ath must match the finite canonical thermal shape.');
end
if ~isnumeric(state.Amda) || ~isreal(state.Amda) || ~isequal(size(state.Amda),size(w.Amda)) || any(~isfinite(state.Amda),'all')
    error('WV:ThermalMeanShape','Amda must match the finite real canonical mean shape.');
end
end
