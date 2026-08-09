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
du = ifft((sqrt(-1)*self.wvg.k_dft).^options.n.*fft(u,self.wvg.Nx,1),self.wvg.Nx,1,"symmetric");
end
