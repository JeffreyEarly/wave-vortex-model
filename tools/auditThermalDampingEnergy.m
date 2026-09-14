function records = auditThermalDampingEnergy(w,force)
% Independently audit signed work and bounds of a frozen APV-mapped closure.
%
% With physical energy factor R and vertical generator A per unit speed,
% the largest eigenvalue of (R*A/R + (R*A/R)')/2 bounds half the fractional
% energy rate. A positive value is a physical growth direction even though
% the diagnosed APV coordinates have negative diagonal damping rates.
%
% - Topic: Developer utilities
% - Parameter w: owning thermal transform
% - Parameter force: its frozen APV-mapped closure
% - Returns records: signed work extrema and independent norm-to-bound ratios per radius
arguments (Input)
    w (1,1) WVTransformFreeSurfaceThermalQG
    force (1,1) WVThermalAPVDamping
end
arguments (Output)
    records table
end
data=force.coefficientDampingData(); metrics=w.physicalMetricOperators(); records=table();
for p=1:numel(w.khUnique)
    factors=metrics.pages{p}.factors;
    [~,R]=qr([factors.kineticEnergy;factors.interiorPotentialEnergy;factors.surfacePotentialEnergy],0);
    page=data.pages{p}; A=page.lift*(data.verticalRates.*page.projection); B=(R*A)/R;
    [V,D]=eig((B+B')/2); growth=real(diag(D));
    [largest,i]=max(growth); state=R\V(:,i);
    direct=2*real((R*state)'*(R*A*state))/norm(R*state)^2;
    if page.physicalVerticalNorm==0, boundRatio=norm(B,2); else, boundRatio=norm(B,2)/page.physicalVerticalNorm; end
    records=[records;table(w.inverseScale,w.khUnique(p),largest,direct,min(growth),boundRatio,VariableNames={'inverseScale','kh','maximumHalfEnergyRatePerSpeed','directMaximumEnergyRatePerSpeed','minimumHalfEnergyRatePerSpeed','boundRatio'})]; %#ok<AGROW>
end
assert(all(records.boundRatio<1+1e-8),'Frozen closure norm bound does not cover the independent physical-energy operator.');
end
