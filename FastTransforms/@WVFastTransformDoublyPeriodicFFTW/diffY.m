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
du = ifft((sqrt(-1)*shiftdim(self.wvg.l_dft,-1)).^options.n.*fft(u,self.wvg.Ny,2),self.wvg.Ny,2,"symmetric");
end
