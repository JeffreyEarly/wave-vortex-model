function annotations = coefficientStateAnnotations(self)
% Return canonical coefficient-family annotations in integrator order.
%
% Legacy transforms expose the applicable `Ap`, `Am`, and `A0` families.
% New transforms override this method when their coefficient vocabulary or
% logical dimensions differ.
%
% - Topic: Wave-vortex coefficients
% - Declaration: annotations = coefficientStateAnnotations(self)
% - Returns annotations: ordered WVCoefficientAnnotation array
arguments
    self (1,1) WVTransform
end

annotations = WVCoefficientAnnotation.empty(0,0);
if self.hasWaveComponent
    annotations(end+1) = legacyAnnotation(self,'Ap',"positive-frequency wave basis");
    annotations(end+1) = legacyAnnotation(self,'Am',"negative-frequency wave basis");
end
if self.hasPVComponent
    annotations(end+1) = legacyAnnotation(self,'A0',"legacy zero-frequency geostrophic and mean-density-anomaly basis");
end
end

function annotation = legacyAnnotation(wvt,name,canonicalBasis)
source = wvt.propertyAnnotationWithName(name);
annotation = WVCoefficientAnnotation(name,source.dimensions,source.units,source.description,canonicalBasis=canonicalBasis,isComplex=source.isComplex);
end
