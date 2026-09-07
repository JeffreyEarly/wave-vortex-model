function derivative = mdaDisplacementDerivative(self)
% Reconstruct the native-grid derivative of each stored MDA displacement mode.
% Share the modal identity between full QGPV and physical inventory metrics.
% An inactive surface has G(0)=0 and uses the stored sampled derivative rule,
% avoiding an undefined infinite endpoint parameter times a zero trace.
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
end
arguments (Output)
    derivative (:,:) double
end
if isfinite(self.g0)
    derivative = (self.mdaF+(self.g0/self.g)*self.mdaG(end,:))./self.mdaEquivalentDepth(:).';
else
    derivative = self.verticalDerivativeMatrix*self.mdaG;
end
end
