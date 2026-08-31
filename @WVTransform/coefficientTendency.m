function tendency = coefficientTendency(self)
% Return nonlinear coefficient tendencies in a family-keyed structure.
%
% - Topic: Wave-vortex coefficients
% - Declaration: tendency = coefficientTendency(self)
% - Returns tendency: scalar structure whose fields follow coefficientStateAnnotations order
arguments
    self (1,1) WVTransform
end

annotations = self.coefficientStateAnnotations();
values = cell(1,length(annotations));
[values{:}] = self.nonlinearFlux();
tendency = struct();
for iFamily = 1:length(annotations)
    tendency.(annotations(iFamily).name) = values{iFamily};
end
end
