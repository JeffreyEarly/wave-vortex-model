function [diagnostics,byWavenumber] = quadraticDiagnostics(self,options)
% Evaluate positive physical energy, full potential enstrophy, and their rates.
%
% The energy is the horizontal average of
% $$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2.$$
% Potential enstrophy is $$Z=\frac12\int_{-D}^{0}q^2\,dz$$, including
% the horizontal-mean QGPV from MDA. These are physical inventories; signed
% generalized energy is a separate diagnostic. Units are m3 s-2 and m s-2.
% Supply any coefficient tendency to evaluate its instantaneous contribution
% using the same metrics, without modifying the transform.
% A row array of tendencies shares the inventory and state-dependent products.
% Tendency fields then have one row per supplied tendency; by-wavenumber
% tendency fields have shape numberOfTendencies by NklNonzero.
%
% ```matlab
% inventory = wvt.quadraticDiagnostics();
% budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
% ```
%
% - Topic: Evaluate physical fields
% - Parameter options.state: optional Ag_q, Ag_0, Amda structure; default is the current state
% - Parameter options.tendency: optional row array of family-keyed coefficient tendencies
% - Returns diagnostics: energy components, totalEnergy, potentialEnstrophy, and optional matching Tendency fields
% - Returns byWavenumber: contributions in klNonzero order, excluding the horizontal mean
arguments
    self (1,1) WVTransformFreeSurfaceQG
    options.state (1,1) struct = struct()
    options.tendency (1,:) struct = struct()
end
state = options.state;
if isempty(fieldnames(state))
    state = struct(Ag_q=self.Ag_q,Ag_0=self.Ag_0,Amda=self.Amda);
end
validateState(self,state);
hasTendency = ~isempty(options.tendency) && ~isempty(fieldnames(options.tendency));
if hasTendency
    for k = 1:length(options.tendency), validateState(self,options.tendency(k)); end
    derivative = [cat(3,options.tendency.Ag_q);cat(3,options.tendency.Ag_0)];
    nTendency = length(options.tendency);
end
operators = self.physicalMetricOperators();
balanced = [state.Ag_q;state.Ag_0];
names = ["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "potentialEnstrophy"];
for name = names
    byWavenumber.(name) = zeros(1,length(self.klNonzero));
    if hasTendency, byWavenumber.(name+"Tendency") = zeros(nTendency,length(self.klNonzero)); end
end
for p = 1:length(self.khUnique)
    columns = self.klNonzeroKhUniqueIndex==p;
    a = balanced(:,columns);
    for name = names(1:3)
        dual = operators.pages{p}.(name)*a;
        byWavenumber.(name)(columns) = real(sum(conj(a).*dual,1));
        if hasTendency
            power = 2*real(sum(conj(dual).*derivative(:,columns,:),1));
            byWavenumber.(name+"Tendency")(:,columns) = reshape(power,nnz(columns),nTendency).';
        end
    end
end
dual = operators.apvPotentialEnstrophy*state.Ag_q;
byWavenumber.potentialEnstrophy = real(sum(conj(state.Ag_q).*dual,1));
if hasTendency
    power = 2*real(sum(conj(dual).*derivative(1:self.apvModeCount,:,:),1));
    byWavenumber.potentialEnstrophyTendency = reshape(power,length(self.klNonzero),nTendency).';
end
for name = names
    diagnostics.(name) = sum(byWavenumber.(name));
    if hasTendency, diagnostics.(name+"Tendency") = sum(byWavenumber.(name+"Tendency"),2); end
end
for name = ["interiorPotentialEnergy" "potentialEnstrophy"]
    dual = operators.mda.(name)*state.Amda;
    diagnostics.(name) = diagnostics.(name)+real(state.Amda'*dual)/2;
    if hasTendency
        diagnostics.(name+"Tendency") = diagnostics.(name+"Tendency")+real(dual'*horzcat(options.tendency.Amda)).';
    end
end
diagnostics.totalEnergy = diagnostics.kineticEnergy+diagnostics.interiorPotentialEnergy+diagnostics.surfacePotentialEnergy;
byWavenumber.totalEnergy = byWavenumber.kineticEnergy+byWavenumber.interiorPotentialEnergy+byWavenumber.surfacePotentialEnergy;
if hasTendency
    diagnostics.totalEnergyTendency = diagnostics.kineticEnergyTendency+diagnostics.interiorPotentialEnergyTendency+diagnostics.surfacePotentialEnergyTendency;
    byWavenumber.totalEnergyTendency = byWavenumber.kineticEnergyTendency+byWavenumber.interiorPotentialEnergyTendency+byWavenumber.surfacePotentialEnergyTendency;
end
end

function validateState(wvt,state)
if ~all(isfield(state,{'Ag_q','Ag_0','Amda'}))
    error('WV:DiagnosticState','Supply all canonical families: Ag_q, Ag_0, and Amda.');
end
wvt.validateAgq(state.Ag_q);
wvt.validateAg0(state.Ag_0);
wvt.validateAmda(state.Amda);
end
