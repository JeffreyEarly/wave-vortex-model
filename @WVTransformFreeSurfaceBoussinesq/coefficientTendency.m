function [tendency,speed,diagnostics] = coefficientTendency(self)
% Sum registered equation sources and project once into coefficient rates.
%
% WVNonlinearAdvection evaluates the manuscript -N-P using modal pressure.
% Reconstruction already carries the analytical phases, so the complete
% linear operator contributes zero to these reference-time rates.
% Physical prescribed sources are mapped once into hatted accelerations.
% Nonlinear activation requires the stored inventory's quadratic qualification.
%
% Optional diagnostics distinguish the actual directional derivative of
% nonlinearEnergy from prescribedWork, the unprojected physical source work.
% Finite spatial/modal residuals and the quadratic-order pressure approximation
% can make those rates differ. Neither rate is imposed on the evolved state.
%
% - Topic: Project physical sources
% - Declaration: [tendency,speed,diagnostics] = coefficientTendency()
% - Returns tendency: structure following coefficientStateAnnotations
% - Returns speed: maximum physical horizontal speed, when requested
% - Returns diagnostics: nonlinear energy, energyTendency, prescribedWork and parcel-label diagnostics; empty for linear source projection
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    tendency (1,1) struct
    speed (1,1) double
    diagnostics (1,1) struct
end
zero = zeros(self.Nx,self.Ny,self.Nz);
source = struct(u=zero,v=zero,w=zero,eta=zero);
prescribed = source;
hasAdvection = false;
for forcing = self.spatialFluxForcing
    [increment.u,increment.v,increment.w,increment.eta] = self.spatialFluxForForcingWithName(string(forcing.name));
    isAdvection = isa(forcing,'WVNonlinearAdvection');
    hasAdvection = hasAdvection || isAdvection;
    for name = ["u","v","w","eta"]
        source.(name) = source.(name)+increment.(name);
        if nargout>2 && ~isAdvection, prescribed.(name) = prescribed.(name)+increment.(name); end
    end
end
tendency = self.projectSources(source);
diagnostics = struct();
if nargout>1
    fields = self.reconstructFields(["u","v"]);
    speed = max(hypot(fields.u,fields.v),[],'all');
end
if nargout>2 && hasAdvection
    diagnostics = energyDiagnostics(self,tendency,prescribed,self.thermodynamicContext());
end
end

function diagnostics = energyDiagnostics(wvt,rate,prescribed,thermodynamics)
% Differentiate the physical inventory along the actual reconstructed rate,
% including its SSH tendency. This is diagnostic algebra, not a RHS repair.
fields = wvt.reconstructFields(["u","v","w","eta","ssh","z_physical"]);
thermal = thermodynamics.evaluate(fields.z_physical,fields.eta,fields.ssh);
totalRate = rate;
omega = wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
totalRate.Aw_p = rate.Aw_p+1i*omega.*wvt.Aw_p;
totalRate.Aw_m = rate.Aw_m-1i*omega.*wvt.Aw_m;
totalRate.Aio = rate.Aio+1i*wvt.f*wvt.Aio;
spectral = wvt.reconstructSpectralState(state=totalRate);
for name = ["u","v","w","eta","ssh"]
    sampled.(name) = wvt.transformToSpatialDomainWithFourier(spectral.(name));
end
sshRate = sampled.ssh(:,:,end);
alpha = reshape(1+wvt.z/wvt.Lz,1,1,[]);
gamma = 1+fields.ssh/wvt.Lz;
gammaRate = sshRate/wvt.Lz;
sshX = wvt.diffX(fields.ssh); sshY = wvt.diffY(fields.ssh);
uRate = (sampled.u-fields.u.*gammaRate)./gamma;
vRate = (sampled.v-fields.v.*gammaRate)./gamma;
wRate = sampled.w+alpha.*(uRate.*sshX+vRate.*sshY+fields.u.*wvt.diffX(sshRate)+fields.v.*wvt.diffY(sshRate));
kinetic = .5*(fields.u.^2+fields.v.^2+fields.w.^2);
weights = reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
kineticEnergy = sum(weights.*gamma.*kinetic,'all');
availablePotentialEnergy = sum(weights.*gamma.*thermal.ape,'all');
surfaceEnergy = mean(thermal.energySurface,'all');
energyTendency = sum(weights.*(gammaRate.*(kinetic+thermal.ape)+gamma.*(fields.u.*uRate+fields.v.*vRate+fields.w.*wRate+thermal.apeEta.*sampled.eta+thermal.apeZ.*alpha.*sshRate)),'all')+wvt.g*mean(fields.ssh.*sshRate,'all');
physicalSourceW = prescribed.w+alpha.*(sshX.*prescribed.u+sshY.*prescribed.v)./gamma;
prescribedWork = sum(weights.*(fields.u.*prescribed.u+fields.v.*prescribed.v+gamma.*(fields.w.*physicalSourceW+thermal.apeEta.*prescribed.eta)),'all');
diagnostics = struct(kineticEnergy=kineticEnergy,availablePotentialEnergy=availablePotentialEnergy,surfaceEnergy=surfaceEnergy,totalEnergy=kineticEnergy+availablePotentialEnergy+surfaceEnergy,energyTendency=energyTendency,prescribedWork=prescribedWork,minimumLabel=min(thermal.label,[],'all'),maximumLabel=max(thermal.label,[],'all'),maximumLabelRoundoffAdjustment=thermal.maximumLabelRoundoffAdjustment,adjustedLabelCount=thermal.adjustedLabelCount,labelRoundoffTolerance=thermal.labelRoundoffTolerance,referenceConvention=thermodynamics.referenceConvention);
end
