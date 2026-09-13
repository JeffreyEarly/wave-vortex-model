function tolerances = familyCoefficientTolerances(wvt,energy,energyScale,scales)
% Convert an energy floor to independently calibrated diagonal family floors.
% Boundary metrics are half the horizontal displacement variance. Multiplying
% displacement by the reference endpoint N2 gives the equivalent buoyancy
% convention, provided its dimensional scale is multiplied by the same N2.
% The compact Fourier pair cancels the half in each quadratic invariant.
arguments (Input)
    wvt
    energy (1,1) struct
    energyScale (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    scales (1,1) struct
end
arguments (Output)
    tolerances (1,1) struct
end
if ~isa(wvt,'WVTransformFreeSurfaceQG') && ~isa(wvt,'WVTransformFreeSurfaceBoussinesq')
    error('WVCoefficients:UnsupportedTolerancePolicy','Family tolerances require a v5 free-surface QG or Boussinesq transform.');
end
for field=string(fieldnames(scales)).'
    value=scales.(field);
    if ~isempty(value) && ~isscalar(value)
        error('WVCoefficients:InvalidToleranceScale','Each invariant scale must be empty or a positive finite scalar.');
    end
end
tolerances=energy;
if isempty(wvt.khNonzero), return; end
[~,referenceColumn]=min(wvt.khNonzero);
isQG=isa(wvt,'WVTransformFreeSurfaceQG');
if isQG
    metrics=wvt.physicalMetricOperators();
    pages=wvt.klNonzeroKhUniqueIndex;
else
    empty=wvt.coefficientState();
    for name=string(fieldnames(empty)).', empty.(name)=zeros(size(empty.(name))); end
end
for name=["Ag_q","Ag_0"]
    ratios=zeros(size(energy.(name)));
    for mode=1:size(ratios,1)
        if isQG
            for column=1:size(ratios,2)
                page=metrics.pages{pages(column)};
                weights=real(diag(page.kineticEnergy+page.interiorPotentialEnergy+page.surfacePotentialEnergy));
                if name=="Ag_q"
                    E=weights(mode); C=metrics.apvPotentialEnstrophy(mode,mode);
                else
                    E=weights(wvt.apvModeCount+mode);
                    C=(wvt.f/(wvt.g*wvt.khNonzero(column)^2))^2;
                end
                ratios(mode,column)=E/C;
            end
        else
            state=empty; state.(name)(mode,:)=1;
            fields=wvt.reconstructSpectralState(state=state);
            E=sum(wvt.verticalQuadratureWeights.*(abs(fields.u).^2+abs(fields.v).^2+abs(fields.w).^2+wvt.N2.*abs(fields.eta).^2),1)+wvt.g*abs(fields.ssh(end,:)).^2;
            if name=="Ag_q"
                C=sum(wvt.verticalQuadratureWeights.*abs(fields.qgpv).^2,1);
            elseif wvt.activeEndpoint(mode)==1
                C=abs(fields.eta(end,:)-fields.ssh(end,:)).^2;
            else
                C=abs(fields.eta(1,:)).^2;
            end
            ratios(mode,:)=E(wvt.klNonzero)./C(wvt.klNonzero);
        end
    end
    if any(~isfinite(ratios) | ratios<=0,'all')
        error('WVCoefficients:InvalidToleranceMetric','Retained family coefficients require positive finite unit invariants and energy.');
    end
    for mode=1:size(ratios,1)
        if name=="Ag_q"
            scale=scales.pvAbsTolerance;
            referenceMode=1;
        else
            if wvt.activeEndpoint(mode)==1, scale=scales.surfaceAbsTolerance; else, scale=scales.bottomAbsTolerance; end
            referenceMode=mode;
        end
        if isempty(scale), scale=energyScale/sqrt(ratios(referenceMode,referenceColumn)); end
        tolerances.(name)(mode,:)=energy.(name)(mode,:).*(scale/energyScale).*sqrt(ratios(mode,:));
    end
end
end
