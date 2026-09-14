function geometry=endpointGeometry(self)
if isempty(self.endpointGeometry_)
    self.endpointGeometry_=WVGeometryDoublyPeriodic([self.Lx self.Ly],[self.Nx self.Ny],Nz=2,shouldAntialias=self.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
end
geometry=self.endpointGeometry_;
end
