function tolerances = coefficientAbsoluteTolerances(self,absTolerance)
% Return one adaptive-integrator tolerance array per coefficient family.
%
% - Topic: Wave-vortex coefficients
% - Declaration: tolerances = coefficientAbsoluteTolerances(self,absTolerance)
% - Parameter absTolerance: scalar coefficient-error scale
% - Returns tolerances: family-keyed scalar structure
arguments
    self (1,1) WVTransform
    absTolerance (1,1) double {mustBePositive}
end

[alpha0,alphapm] = WVCoefficients.errorTolerances(self,absTolerance);
annotations = self.coefficientStateAnnotations();
tolerances = struct();
for iFamily = 1:length(annotations)
    name = annotations(iFamily).name;
    switch name
        case {'Ap','Am'}
            tolerances.(name) = alphapm;
        case 'A0'
            tolerances.(name) = alpha0;
        otherwise
            tolerances.(name) = absTolerance*ones(size(self.(name)));
    end
end
end
