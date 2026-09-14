function derivative=diffZ(self,field,order)
% Differentiate physical-grid samples once or twice using mapped FFT calculus.
% - Topic: Evaluate physical fields
% - Parameter field: real or complex Nx-by-Ny-by-Nz samples
% - Parameter order: derivative order, 1 or 2
% - Returns derivative: physical vertical derivative with the input shape
arguments
    self (1,1) WVTransformFreeSurfaceThermalQG
    field double {mustBeFinite}
    order (1,1) double {mustBeMember(order,[1 2])} = 1
end
if ~isequal(size(field),[self.Nx self.Ny self.Nz]), error('WV:ThermalFieldShape','Expected Nx-by-Ny-by-Nz samples.'); end
columns=reshape(permute(field,[3 1 2]),self.Nz,[]);
columns=WVInternal.thermalChebyshev(columns,"derivative",depth=self.Lz,inverseScale=self.inverseScale,order=order);
derivative=permute(reshape(columns,self.Nz,self.Nx,self.Ny),[2 3 1]);
end
