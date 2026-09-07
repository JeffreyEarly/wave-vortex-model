function [diagnostics,byWavenumber,horizontalMean] = quadraticDiagnostics(self,options)
% Evaluate physical and generalized invariants and their directional rates.
%
% The energy is the horizontal average of
% $$E=\frac12\int_{-D}^{0}(u^2+v^2+N^2\eta^2)\,dz+\frac12 g\eta_s^2.$$
% Potential enstrophy is $$Z=\frac12\int_{-D}^{0}q^2\,dz$$, including
% the horizontal-mean QGPV from MDA. Units are m3 s-2 and m s-2.
% Endpoint anomaly variances are $$B_b=\frac12\langle b_b^2\rangle$$,
% in m2, including the squared horizontal mean (not mean-subtracted variance).
% `surfaceAnomalyVariance` and `bottomAnomalyVariance` are zero for inactive
% endpoints. Signed generalized energy is
% $$H_g=E+g_0 B_0+g_d B_d,$$
% in m3 s-2, with inactive terms omitted before multiplying by their weights.
% `generalizedEnergy` retains all cross terms in the boundary-normalized
% coordinates; it can be negative and must not serve as a positive error norm.
% Supply any coefficient tendency to evaluate its instantaneous contribution
% using the same metrics, without modifying the transform.
% A row array of tendencies shares the inventory and state-dependent products.
% Tendency fields then have one row per supplied tendency; by-wavenumber
% tendency fields have shape numberOfTendencies by NklNonzero.
% The optional `horizontalMean` output contains the MDA contribution to
% every inventory and rate. Summing a by-wavenumber field across columns
% and adding its horizontal-mean field recovers the corresponding total.
% The nonzero columns include the conjugate contribution; do not double
% them again. Time derivatives have the inventory units divided by seconds.
%
% ```matlab
% [inventory,spectrum,meanPart] = wvt.quadraticDiagnostics();
% inventory.generalizedEnergy
% sum(spectrum.generalizedEnergy)+meanPart.generalizedEnergy
% budget = wvt.quadraticDiagnostics(tendency=wvt.coefficientTendency());
% ```
%
% - Topic: Evaluate physical fields
% - Declaration: [diagnostics,byWavenumber,horizontalMean] = quadraticDiagnostics(self,options)
% - Parameter options.state: optional Ag_q, Ag_0, Amda structure; default is the current state
% - Parameter options.tendency: optional row array of family-keyed coefficient tendencies
% - Returns diagnostics: physical energy components, totalEnergy, potentialEnstrophy, surfaceAnomalyVariance, bottomAnomalyVariance, generalizedEnergy, and optional matching Tendency fields
% - Returns byWavenumber: contributions in klNonzero order, excluding the horizontal mean
% - Returns horizontalMean: corresponding horizontal-mean contributions, including MDA
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    options.state (1,1) struct = struct()
    options.tendency (1,:) struct = struct()
end
arguments (Output)
    diagnostics (1,1) struct
    byWavenumber (1,1) struct
    horizontalMean (1,1) struct
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
matrixNames = ["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "surfaceAnomalyVariance" "bottomAnomalyVariance"];
names = [matrixNames,"potentialEnstrophy"];
for name = names
    byWavenumber.(name) = zeros(1,length(self.klNonzero));
    horizontalMean.(name) = 0;
    if hasTendency
        byWavenumber.(name+"Tendency") = zeros(nTendency,length(self.klNonzero));
        horizontalMean.(name+"Tendency") = zeros(nTendency,1);
    end
end
for p = 1:length(self.khUnique)
    columns = self.klNonzeroKhUniqueIndex==p;
    a = balanced(:,columns);
    for name = matrixNames
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
for name = ["interiorPotentialEnergy" "potentialEnstrophy" "surfaceAnomalyVariance" "bottomAnomalyVariance"]
    dual = operators.mda.(name)*state.Amda;
    horizontalMean.(name) = real(state.Amda'*dual)/2;
    if hasTendency
        horizontalMean.(name+"Tendency") = real(dual'*horzcat(options.tendency.Amda)).';
    end
end
for name = names
    diagnostics.(name) = sum(byWavenumber.(name))+horizontalMean.(name);
    if hasTendency
        diagnostics.(name+"Tendency") = sum(byWavenumber.(name+"Tendency"),2)+horizontalMean.(name+"Tendency");
    end
end
diagnostics = completeEnergy(diagnostics,self.g0,self.gd,hasTendency);
byWavenumber = completeEnergy(byWavenumber,self.g0,self.gd,hasTendency);
horizontalMean = completeEnergy(horizontalMean,self.g0,self.gd,hasTendency);
end

function validateState(wvt,state)
if ~all(isfield(state,{'Ag_q','Ag_0','Amda'}))
    error('WV:DiagnosticState','Supply all canonical families: Ag_q, Ag_0, and Amda.');
end
wvt.validateAgq(state.Ag_q);
wvt.validateAg0(state.Ag_0);
wvt.validateAmda(state.Amda);
end

function d = completeEnergy(d,g0,gd,hasTendency)
suffixes = "";
if hasTendency, suffixes = ["","Tendency"]; end
for suffix = suffixes
    d.("totalEnergy"+suffix) = d.("kineticEnergy"+suffix)+d.("interiorPotentialEnergy"+suffix)+d.("surfacePotentialEnergy"+suffix);
    d.("generalizedEnergy"+suffix) = d.("totalEnergy"+suffix);
    if isfinite(g0)
        d.("generalizedEnergy"+suffix) = d.("generalizedEnergy"+suffix)+g0*d.("surfaceAnomalyVariance"+suffix);
    end
    if isfinite(gd)
        d.("generalizedEnergy"+suffix) = d.("generalizedEnergy"+suffix)+gd*d.("bottomAnomalyVariance"+suffix);
    end
end
end
