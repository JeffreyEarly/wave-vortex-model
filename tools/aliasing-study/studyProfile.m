function profile = studyProfile(name,D)
% Define study profiles and their analytic logarithmic gradients.
arguments
    name (1,1) string
    D (1,1) double {mustBePositive}
end
switch name
    case "constant"
        N2=@(z)1e-4*ones(size(z)); dLog=@(z)zeros(size(z));
    case "exponential"
        N2=@(z)1e-4*exp(2*z/D); dLog=@(z)(2/D)*ones(size(z));
    case "exponential-withheld"
        N2=@(z)8e-5*exp(1.3*z/D); dLog=@(z)(1.3/D)*ones(size(z));
    case "pycnocline"
        center=-.35*D; width=.08*D;
        N2=@(z)1e-5+9e-5*exp(-((z-center)/width).^2);
        dLog=@(z)(-2*(z-center)/width^2).*9e-5.*exp(-((z-center)/width).^2)./N2(z);
    otherwise
        error('WVStudy:UnknownProfile','Unknown declared study profile: %s',name)
end
profile=struct(name=name,N2=N2,dLogN2=dLog);
end
