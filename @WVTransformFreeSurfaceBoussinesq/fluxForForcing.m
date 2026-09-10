function flux = fluxForForcing(self)
% Project each registered source into the reference-time coefficient families.
%
% Summing all entries recovers coefficientTendency. Every entry uses the
% same hatted source convention as spatialFluxForForcingWithName and the
% six independently shaped coefficient families. These are rates, not energy
% partitions; nonlinearEnergy includes cross terms and moving geometry.
%
% - Topic: Project physical sources
% - Declaration: flux = fluxForForcing()
% - Returns flux: string-to-cell dictionary, with one coefficient structure per forcing name
arguments (Input)
    self (1,1) WVTransformFreeSurfaceBoussinesq
end
arguments (Output)
    flux (1,1) dictionary
end
flux = configureDictionary("string","cell");
for forcing = self.spatialFluxForcing
    [source.u,source.v,source.w,source.eta] = self.spatialFluxForForcingWithName(string(forcing.name));
    flux{string(forcing.name)} = self.projectSources(source);
end
end
