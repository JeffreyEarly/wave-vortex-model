function [diagnosis,reconstruction] = apvDecomposition(self,apv,options)
% Diagnose a complete thermal state with an independent APV and zero-APV basis.
%
% Project physical QGPV through the diagnostic F-channel Galerkin operator,
% then subtract its endpoint response before finding zero-APV coefficients.
% Physical accounting retains APV, zero-APV, the original thermal horizontal
% mean, and the unresolved field. Neither transform's state or clock changes.
% The diagnostic band is independent of any registered damping closure.
%
% For physical quadrature weights W and sampled APV F modes, the projection
% is $$a_q=(F^*WF)^{-1}F^*Wq$$, evaluated by weighted QR. The two endpoint
% coefficients are $$a_0=-(g/f)k_h^2(\theta-E_k a_q)$$, where theta is the
% interior-displacement anomaly and E_k is the APV endpoint response.
% Both coefficient families have units $$s^{-1}$$. Their row counts are the
% diagnostic APV count and two endpoints; columns follow the diagnostic
% transform's nonzero Fourier order recorded in metadata.kNonzero/lNonzero.
%
% Inventories use horizontally averaged depth integrals, with all physical
% cross terms. Modal power is twice the squared coefficient magnitude in
% s^-2; it is not a diagonal physical-energy spectrum. Radial spectra are bin
% sums of nonzero Fourier contributions; mean inventories remain separate.
% Residuals include absolute RMS, reference RMS and their ratio. A zero
% reference gives NaN for the ratio. energyNorm uses sqrt(physical energy).
%
% Each inventory has total, apv, zeroAPV, residual and mean self terms, and
% apvZeroAPV, apvResidual and zeroAPVResidual cross terms. Their sum, excluding
% total itself, recovers total. Energies have units $$m^{3}/s^{2}$$, potential
% enstrophy $$m/s^{2}$$, and endpoint half second moments $$m^{2}$$. Physical
% spectra use source Fourier order (metadata.accountingKNonzero and
% accountingLNonzero); radialSpectrum contains bin sums and kRadial.
%
% A row of canonical tendencies gives instantaneous coefficient and inventory
% rates. It does not supply time-integrated process budgets. The caller owns
% the process ordering and evaluates any forcing at the appropriate clock.
% directional.residualRateNorms contains positive norms of the rate fields;
% directional.inventories contains signed instantaneous work or variance rates.
%
% With one output no physical volumes are allocated. The optional second
% output reconstructs only fieldNames: volumes on the common physical Gauss
% grid, SSH as Nx-by-Ny, and endpoints as Nx-by-Ny-by-2, surface then bottom.
% Coordinates are reconstruction.x/y/z. Supported fields are psi, u, v, eta,
% eta_i, buoyancy, qgpv, ssh and endpointAnomalies; the last two are defaults.
% Cached quadrature and maps depend on immutable scientific arrays and the
% diagnostic object, not on coefficients, time, forcing or damping rates.
% Changing solved-basis physics requires new scientific transforms. A warmed
% cache rejects changed gravity or rotation parameters. The diagnostic band,
% signed endpoint weights and stored sampling may differ from the source.
% Requested counts are not retained by existing transforms: metadata reports
% their absence explicitly. Retain the constructor settings and saved arrays
% with the analysis to preserve complete construction provenance.
%
% ```matlab
% d = thermal.apvDecomposition(apv,quadratureCount=513);
% [d,fields] = thermal.apvDecomposition(apv,fieldNames=["ssh","endpointAnomalies"]);
% ```
%
% - Topic: Evaluate physical fields
% - Parameter apv: compatible WVTransformFreeSurfaceQG diagnostic transform
% - Parameter options.state: Ath/Amda structure; defaults to the current state
% - Parameter options.tendency: optional row of Ath/Amda directional tendencies
% - Parameter options.time: physical time recorded with the result, in seconds
% - Parameter options.quadratureCount: physical Gauss count, at least both stored grids and thermal count
% - Parameter options.fieldNames: requested physical fields for the second output
% - Returns diagnosis: coefficients, physical inventories, spectra, residuals and directional rates
% - Returns reconstruction: selected total, APV, zero-APV, mean and residual physical fields
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    apv (1,1) WVTransformFreeSurfaceQG
    options.state (1,1) struct = struct()
    options.tendency (1,:) struct = struct()
    options.time (1,1) double {mustBeReal,mustBeFinite} = self.t
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = max(129,2*max(self.Nz,apv.Nz)+1)
    options.fieldNames (1,:) string = ["ssh","endpointAnomalies"]
end
arguments (Output)
    diagnosis (1,1) struct
    reconstruction (1,1) struct
end
state=options.state;
if isempty(fieldnames(state)), state=self.coefficientState(); end
tendencies=options.tendency;
if isempty(tendencies) || isempty(fieldnames(tendencies)), tendencies=struct.empty(1,0); end
states=[{state},num2cell(tendencies)];
for j=1:numel(states)
    if ~isequal(sort(string(fieldnames(states{j}))),["Amda";"Ath"])
        error('WV:APVDiagnosticState','Supply exactly the canonical Ath and Amda families.');
    end
    self.validateCoefficientValue(states{j}.Ath,"Ath");
    self.validateCoefficientValue(states{j}.Amda,"Amda");
end
names=["psi","u","v","eta","eta_i","buoyancy","qgpv","ssh","endpointAnomalies"];
if any(~ismember(options.fieldNames,names)) || numel(unique(options.fieldNames))~=numel(options.fieldNames)
    error('WV:APVDiagnosticField','Request distinct supported physical field names.');
end
data=self.apvDecompositionData_;
for name=["Lx","Ly","Lz","g","f","rho0"]
    if ~isequal(self.(name),apv.(name))
        error('WV:APVDiagnosticGeometry','Source and diagnostic %s must agree. Construct a new scientific basis to change physics.',name);
    end
end
sourcePhysics=[self.g,self.f,self.rho0,self.latitude,self.rotationRate];
targetPhysics=[apv.g,apv.f,apv.rho0,apv.latitude,apv.rotationRate];
if ~isempty(data) && (~isequal(sourcePhysics,data.sourcePhysics) || (data.apv==apv && ~isequal(targetPhysics,data.targetPhysics)))
    error('WV:APVDiagnosticGeometry','Physics changed after diagnostic preparation. Construct new scientific transforms instead of changing solved-basis parameters.');
end
if isempty(data) || data.apv~=apv || data.quadratureCount~=options.quadratureCount
    data=WVInternal.thermalAPVDecompositionData(self,apv,options.quadratureCount);
    self.apvDecompositionData_=data;
end
fields=string.empty(1,0);
if nargout>1, fields=options.fieldNames; end
[diagnosis,reconstruction]=WVInternal.thermalAPVDecomposition(data,state,tendencies,options.time,fields);
end
