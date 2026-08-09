function du = diffY(self,u,options)
% Differentiate a spatial variable in the y direction using MATLAB FFTs.
%
% - Topic: Apply spatial derivatives
% - Declaration: du = diffY(u,n)
% - Parameter u: real spatial array `[Nx,Ny,Nz]`
% - Parameter n: derivative order, default 1
% - Returns du: differentiated spatial array `[Nx,Ny,Nz]`
% - Developer: true
arguments
    self WVFastTransformDoublyPeriodicFFTW
    u (:,:,:) double
    options.n (1,1) double = 1
end
implementation = WVSpatialDerivativeDispatch.implementation("fftw","diffY",[self.wvg.Nx self.wvg.Ny self.Nz],options.n,false);
if implementation == "fftw-1d" && ~self.yDerivativeUnavailable
    try
        if isempty(self.yDerivativeTransform) || ~isvalid(self.yDerivativeTransform)
            self.yDerivativeTransform = RealToComplexTransform([self.wvg.Nx self.wvg.Ny self.Nz],dims=2,planner="measure",alignmentMode="unaligned",plannerTimeLimitSeconds=10);
        end
        spectrum = self.yDerivativeTransform.transformForward(u);
        modes = 0:floor(self.wvg.Ny/2);
        if mod(self.wvg.Ny,2) == 0 && mod(options.n,2) == 1
            modes(end) = 0;
        end
        spectrum = (1i*2*pi*modes/self.wvg.Ly).^options.n .* spectrum;
        du = zeros(self.yDerivativeTransform.realSize);
        [~,du] = self.yDerivativeTransform.transformBackIntoArrayDestructive(spectrum,du);
        du = self.yDerivativeTransform.scaleFactor*du;
        return
    catch exception
        self.yDerivativeUnavailable = true;
        if ~isempty(self.yDerivativeTransform) && isvalid(self.yDerivativeTransform)
            delete(self.yDerivativeTransform);
        end
        self.yDerivativeTransform = [];
        if ~self.hasWarnedOfDerivativeFailure
            warning("WaveVortexModel:FFTWDerivativeUnavailable","The selected FFTW y-derivative failed and this adapter will use MATLAB instead: %s",exception.message);
            self.hasWarnedOfDerivativeFailure = true;
        end
    end
end
du = ifft((sqrt(-1)*shiftdim(self.wvg.l_dft,-1)).^options.n.*fft(u,self.wvg.Ny,2),self.wvg.Ny,2,"symmetric");
end
