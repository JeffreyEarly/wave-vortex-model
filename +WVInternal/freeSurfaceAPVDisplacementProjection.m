function projection = freeSurfaceAPVDisplacementProjection(F,G,weights,N2,g,normalization)
% Assemble the PV displacement functional by integration by parts.
% F_z = -(N2/g)*G. The F traces also apply at the limiting boundary laws.
projection = G'.*(weights.*N2/g).';
projection(:,1) = projection(:,1)-F(1,:)';
projection(:,end) = projection(:,end)+F(end,:)';
projection = normalization*projection;
end
