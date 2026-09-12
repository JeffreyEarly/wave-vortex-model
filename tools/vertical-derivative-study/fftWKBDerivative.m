function du = fftWKBDerivative(u,metric,n)
% Candidate sampled differentiation on increasing Chebyshev-Lobatto nodes.
% metric is dx/dz for x in [-1,1], one value per vertical level.
% Reapply the metric after each derivative, including variable metrics.
arguments
    u double
    metric (:,1) double
    n (1,1) double {mustBeMember(n,1:4)} = 1
end
shape = size(u);
Z = size(u,3); degree = Z-1;
v = reshape(permute(u,[3 1 2]),Z,[]);
for order = 1:n
    % The even extension is in decreasing-node order. Its FFT is a DCT-I.
    spectrum = fft([flipud(v);v(2:end-1,:)],[],1)/degree;
    coefficients = spectrum(1:Z,:);
    coefficients([1 end],:) = coefficients([1 end],:)/2;
    if isreal(u), coefficients=real(coefficients); end
    derivative = zeros(size(coefficients),'like',coefficients);
    weighted = 2*(1:degree)'.*coefficients(2:end,:);
    for parity = 1:2
        rows = parity:2:degree;
        derivative(rows,:) = flipud(cumsum(flipud(weighted(rows,:)),1));
    end
    derivative(1,:) = derivative(1,:)/2;
    derivative(2:end-1,:) = derivative(2:end-1,:)/2;
    values = fft([derivative;derivative(end-1:-1:2,:)],[],1);
    v = metric.*flipud(values(1:Z,:));
    if isreal(u), v=real(v); end
end
du = reshape(permute(reshape(v,Z,shape(1),shape(2)),[2 3 1]),shape);
end
