function [varargout] = variableAtPositionWithName(self,x,y,z,variableNames,options)
% Evaluate fields at periodic horizontal positions and physical heights.
%
% Volume fields are sampled on the reference grid. Interpolate total SSH
% at each horizontal query, then invert the moving-column map using
% xi=(z-ssh)/(1+ssh/Lz). Surface fields depend only on x and y, so z may
% be empty when every requested field is two-dimensional. Volume values
% outside the physical column are zero, matching the base interpolation API.
%
% - Topic: State variables
% - Declaration: [varargout] = variableAtPositionWithName(x,y,z,variableNames,options)
% - Parameter x: row of horizontal x positions, wrapped periodically
% - Parameter y: row of horizontal y positions, wrapped periodically
% - Parameter z: physical query heights, or empty for surface fields
% - Parameter variableNames: requested field names
% - Parameter options.interpolationMethod: periodic "linear" (default) or "spline" interpolation
% - Returns varargout: interpolated fields in the requested order and query shape
arguments (Input)
    self WVTransformFreeSurfaceBoussinesq {mustBeNonempty}
    x (1,:) double
    y (1,:) double
    z (1,:) double
end
arguments (Input,Repeating)
    variableNames char
end
arguments (Input)
    options.interpolationMethod char {mustBeMember(options.interpolationMethod,["linear","spline"])} = "linear"
end
varargout = cell(size(variableNames));
[varargout{:}] = self.variableWithName(variableNames{:});
isVolume = ~cellfun(@ismatrix,varargout);
xi = z;
if any(isVolume)
    ssh = self.interpolatedFieldAtPosition(x,y,[],options.interpolationMethod,self.ssh);
    gamma = 1+ssh/self.Lz;
    if any(gamma<=0,'all')
        error('WV:InvalidFreeSurfaceGeometry','Interpolated surface height must exceed minus the reference depth.')
    end
    xi = (z-ssh)./gamma;
    outside = z < -self.Lz | z > ssh;
    % Preserve exact physical endpoints despite roundoff in the inverse map.
    inside = z >= -self.Lz & z <= ssh;
    xi(inside) = min(0,max(-self.Lz,xi(inside)));
end
[varargout{:}] = self.interpolatedFieldAtPosition(x,y,xi,options.interpolationMethod,varargout{:});
for index = find(isVolume)
    varargout{index}(outside) = 0;
end
end
