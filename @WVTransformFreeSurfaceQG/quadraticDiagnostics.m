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
%
% ```matlab
% inventory = wvt.quadraticDiagnostics();
% budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
% ```
%
% - Topic: Evaluate physical fields
% - Parameter options.state: optional Ag_q, Ag_0, Amda structure; default is the current state
% - Parameter options.tendency: optional family-keyed coefficient tendency
% - Returns diagnostics: energy components, totalEnergy, potentialEnstrophy, and optional matching Tendency fields
% - Returns byWavenumber: contributions in klNonzero order, excluding the horizontal mean
arguments
    self (1,1) WVTransformFreeSurfaceQG
    options.state (1,1) struct = struct()
    options.tendency (1,1) struct = struct()
end
state = options.state;
if isempty(fieldnames(state))
    state = struct(Ag_q=self.Ag_q,Ag_0=self.Ag_0,Amda=self.Amda);
end
validateState(self,state);
hasTendency = ~isempty(fieldnames(options.tendency));
if hasTendency
    validateState(self,options.tendency);
    derivative = [options.tendency.Ag_q;options.tendency.Ag_0];
end
operators = self.physicalMetricOperators();
balanced = [state.Ag_q;state.Ag_0];
names = ["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "potentialEnstrophy"];
for name = names
    byWavenumber.(name) = zeros(1,length(self.klNonzero));
    if hasTendency, byWavenumber.(name+"Tendency") = zeros(1,length(self.klNonzero)); end
end
for p = 1:length(self.khUnique)
    columns = self.klNonzeroKhUniqueIndex==p;
    a = balanced(:,columns);
    for name = names(1:3)
        dual = operators.pages{p}.(name)*a;
        byWavenumber.(name)(columns) = real(sum(conj(a).*dual,1));
        if hasTendency
            byWavenumber.(name+"Tendency")(columns) = 2*real(sum(conj(dual).*derivative(:,columns),1));
        end
    end
end
dual = operators.apvPotentialEnstrophy*state.Ag_q;
byWavenumber.potentialEnstrophy = real(sum(conj(state.Ag_q).*dual,1));
if hasTendency
    byWavenumber.potentialEnstrophyTendency = 2*real(sum(conj(dual).*options.tendency.Ag_q,1));
end
for name = names
    diagnostics.(name) = sum(byWavenumber.(name));
    if hasTendency, diagnostics.(name+"Tendency") = sum(byWavenumber.(name+"Tendency")); end
end
for name = ["interiorPotentialEnergy" "potentialEnstrophy"]
    dual = operators.mda.(name)*state.Amda;
    diagnostics.(name) = diagnostics.(name)+real(state.Amda'*dual)/2;
    if hasTendency
        diagnostics.(name+"Tendency") = diagnostics.(name+"Tendency")+real(dual'*options.tendency.Amda);
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
