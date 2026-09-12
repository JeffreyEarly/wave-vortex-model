function [variation,energyAverage] = chebyshevIntervalAverages(integralCoefficients,energyCoefficients,label,interval,D)
% Evaluate I[a,a,b] and J[a,a,b] without subtracting nearby values.
% I'=N2 and J''=N2 in physical coordinates. For normalized Chebyshev
% coordinates, Q_n=T_n[a,a,b] obeys Q_(n+1)=2*b*Q_n+2*T'_n(a)-Q_(n-1).
% Return average(N2)-N2(label) and integral_0^1 (1-s)*N2(label+s*interval) ds.
scale = 2/D;
a = 1+scale*label;
b = a+scale*interval;
previousT = ones(size(label)); currentT = a;
previousDerivative = zeros(size(label)); currentDerivative = ones(size(label));
previousQ = zeros(size(label)); currentQ = previousQ;
variation = zeros(size(label)); energyAverage = variation;
for degree = 2:length(energyCoefficients)-1
    nextQ = 2*b.*currentQ+2*currentDerivative-previousQ;
    variation = variation+integralCoefficients(degree+1)*nextQ;
    energyAverage = energyAverage+energyCoefficients(degree+1)*nextQ;
    nextDerivative = 2*currentT+2*a.*currentDerivative-previousDerivative;
    nextT = 2*a.*currentT-previousT;
    previousQ=currentQ; currentQ=nextQ;
    previousDerivative=currentDerivative; currentDerivative=nextDerivative;
    previousT=currentT; currentT=nextT;
end
variation = interval.*(scale^2*variation);
energyAverage = scale^2*energyAverage;
end
