function [field,columnScale,R,energyMetric] = densityDiffusionEnergyCoordinates(phi,eta,phiSurface,weights,N2,kh,f,g)
% Factor the positive physical energy of the canonical balanced columns.
field = [sqrt(weights)*kh.*phi; sqrt(weights.*N2).*eta; (f/sqrt(g))*phiSurface];
columnScale = vecnorm(field);
scaledField = field./columnScale;
[~,R] = qr(scaledField,0);
energyField = scaledField/R;
energyMetric = energyField'*energyField;
end
