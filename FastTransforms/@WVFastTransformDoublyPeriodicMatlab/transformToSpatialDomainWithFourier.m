function u = transformToSpatialDomainWithFourier(self,u_bar)
layout = self.fourierSpectrumLayout;
self.complexBufferRows(layout.directStorageRows,:) = u_bar(:,layout.directWVColumns).';
if ~isempty(layout.completionStorageRows)
    self.complexBufferRows(layout.completionStorageRows,:) = conj(u_bar(:,layout.completionWVColumns).');
end
if ~isempty(layout.selfConjugateStorageRows)
    self.complexBufferRows(layout.selfConjugateStorageRows,:) = real(self.complexBufferRows(layout.selfConjugateStorageRows,:));
end
complexBuffer = layout.spectrumFromRows(self.complexBufferRows);
if self.wvg.conjugateDimension == 1
    u = ifft(ifft(complexBuffer,self.wvg.Ny,2),self.wvg.Nx,1,'symmetric')*(self.wvg.Nx*self.wvg.Ny);
else
    u = ifft(ifft(complexBuffer,self.wvg.Nx,1),self.wvg.Ny,2,'symmetric')*(self.wvg.Nx*self.wvg.Ny);
end
end
