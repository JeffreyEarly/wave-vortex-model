function measureDerivativeMemory(backend)
% Run under /usr/bin/time -l for process peak RSS, including MATLAB startup.
arguments
    backend (1,1) string {mustBeMember(backend,["baseline","dense","fft"])}
end
Z = 513; x = -cos(pi*(0:Z-1)'/(Z-1));
weights = (-1).^(0:Z-1)'; weights([1 end])=weights([1 end])/2;
distance = x-x'; distance(1:Z+1:end)=1;
D = (weights'./weights)./distance; D(1:Z+1:end)=0; D(1:Z+1:end)=-sum(D,2);
metric = (1+0.2*x)/500; D=metric.*D;
u = repmat(reshape(exp(x),1,1,[]),64,64,1);
for repeat = 1:10
    switch backend
        case "dense", value=denseWKBDerivative(u,D);
        case "fft", value=fftWKBDerivative(u,metric);
        case "baseline", value=u;
    end
end
fprintf('%s checksum %.15g\n',backend,sum(value,'all'));
end
