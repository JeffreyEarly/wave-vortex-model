function flux = fluxForForcing(self)
% Partition the reference-time coefficient tendency by registered forcing.
%
% Values use the six canonical family names and their independent shapes.
% In nonlinear dynamics every prescribed source is projected through the
% same frozen weak metric and endpoint constraints as the full stage.
% Nonlinear advection receives the autonomous full-equation response after
% removing analytical linear phases. Summing all entries recovers
% coefficientTendency. These rates are not energy/work partitions.
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
if any(arrayfun(@(forcing)isa(forcing,'WVNonlinearAdvection'),self.spatialFluxForcing))
    context=self.nonlinearContext();
    [~,~,~,flux]=context.evaluate(self.coefficientState(),includeForcing=true);
else
    flux=configureDictionary("string","cell");
    zero=zeros(self.Nx,self.Ny,self.Nz);
    for forcing=self.spatialFluxForcing
        [source.u,source.v,source.w,source.eta]=forcing.addNonhydrostaticSpatialForcing(self,zero,zero,zero,zero);
        flux{string(forcing.name)}=self.projectSources(source);
    end
end
end
