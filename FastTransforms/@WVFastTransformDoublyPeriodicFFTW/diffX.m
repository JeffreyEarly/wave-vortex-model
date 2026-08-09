function du = diffX(self,u,options)
% Differentiate a spatial variable in the x direction using MATLAB FFTs.
%
% - Topic: Apply spatial derivatives
% - Declaration: du = diffX(u,n)
% - Parameter u: real spatial array `[Nx,Ny,Nz]`
% - Parameter n: derivative order, default 1
% - Returns du: differentiated spatial array `[Nx,Ny,Nz]`
% - Developer: true
arguments
    self WVFastTransformDoublyPeriodicFFTW
    u (:,:,:) double
    options.n (1,1) double = 1
end
implementation = WVSpatialDerivativeDispatch.implementation("fftw","diffX",[self.wvg.Nx self.wvg.Ny self.Nz],options.n,false);
if implementation == "fftw-1d" && ~self.xDerivativeUnavailable
    try
        if isempty(self.xDerivativeTransform) || ~isvalid(self.xDerivativeTransform)
            self.xDerivativeTransform = RealToComplexTransform([self.wvg.Nx self.wvg.Ny self.Nz],dims=1,planner="measure",alignmentMode="unaligned",plannerTimeLimitSeconds=10);
        end
        spectrum = self.xDerivativeTransform.transformForward(u);
        modes = (0:floor(self.wvg.Nx/2))';
        if mod(self.wvg.Nx,2) == 0 && mod(options.n,2) == 1
            modes(end) = 0;
        end
        spectrum = (1i*2*pi*modes/self.wvg.Lx).^options.n .* spectrum;
        du = zeros(self.xDerivativeTransform.realSize);
        [~,du] = self.xDerivativeTransform.transformBackIntoArrayDestructive(spectrum,du);
        du = self.xDerivativeTransform.scaleFactor*du;
        return
    catch exception
        self.xDerivativeUnavailable = true;
        if ~isempty(self.xDerivativeTransform) && isvalid(self.xDerivativeTransform)
            delete(self.xDerivativeTransform);
        end
        self.xDerivativeTransform = [];
        if ~self.hasWarnedOfDerivativeFailure
            warning("WaveVortexModel:FFTWDerivativeUnavailable","The selected FFTW x-derivative failed and this adapter will use MATLAB instead: %s",exception.message);
            self.hasWarnedOfDerivativeFailure = true;
        end
    end
end
du = ifft((sqrt(-1)*self.wvg.k_dft).^options.n.*fft(u,self.wvg.Nx,1),self.wvg.Nx,1,"symmetric");
end
