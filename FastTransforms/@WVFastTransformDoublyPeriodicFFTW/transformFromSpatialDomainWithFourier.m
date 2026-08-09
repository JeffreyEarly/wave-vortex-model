function uBar = transformFromSpatialDomainWithFourier(self,u)
% Transform a real spatial array to normalized canonical WV coefficients.
%
% - Topic: Apply horizontal transforms
% - Declaration: uBar = transformFromSpatialDomainWithFourier(u)
% - Parameter u: real spatial array `[Nx,Ny,Nz]`
% - Returns uBar: normalized canonical WV-grid coefficients `[Nz,Nkl]`
% - Developer: true
halfSpectrum = self.horizontalTransform.transformForward(u);
rows = self.fourierStorageLayout.reshapeFourierStorageToRows(halfSpectrum);
if self.forwardMappingMethod == "specialized-rows"
    layout = self.fourierStorageLayout;
    uBar = complex(zeros(self.Nz,layout.Nkl));
    uBar(:,layout.directWVIndices) = self.horizontalTransform.scaleFactor*rows(layout.fourierRowsForDirectWVIndices,:).';
    if ~isempty(layout.conjugatedWVIndices)
        uBar(:,layout.conjugatedWVIndices) = self.horizontalTransform.scaleFactor*conj(rows(layout.fourierRowsForConjugatedWVIndices,:).');
    end
else
    uBar = self.horizontalTransform.scaleFactor*self.fourierStorageLayout.transformFromFourierStorageToWVGrid(rows);
end
end
