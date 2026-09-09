function fields = evaluateResolvedModes(basis,z,N2,dLogN2)
% Evaluate the physical derivatives of the actual spectral basis.
F=basis.F(z); G=basis.G(z);
factors=basis.normalizationFactors(basis.normalization);
dFirst=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,1)./factors;
dSecond=basis.solver.evaluatePhysicalDerivative(basis.nativeModes,z,2)./factors;
if basis.evp.modeFamily=="meanDensityAnomaly"
    dG=dFirst; dF=-N2(z).*G/basis.evp.g;
elseif basis.evp.formulation=="G"
    dG=dFirst; dF=dSecond.*basis.h(:).';
else
    dF=dFirst; dG=-basis.evp.g*dSecond./N2(z)-dLogN2(z).*G;
end
fields=struct(F=F,G=G,dF=dF,dG=dG);
end
