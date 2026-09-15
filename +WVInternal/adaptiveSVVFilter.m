function [filter,cutoff,significant] = adaptiveSVVFilter(coordinate,maximum,spacing,cutoffFraction)
% Evaluate the adaptive spectral-vanishing-viscosity filter and cutoff.
% A NaN cutoff fraction selects the standard n^(3/4) rule in the supplied
% coordinate units. Finite fractions multiply the supplied maximum.
% - Topic: Developer utilities
arguments (Input)
    coordinate double {mustBeReal,mustBeFinite}
    maximum (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    spacing (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
    cutoffFraction (1,1) double = NaN
end
if ~isnan(cutoffFraction) && (~isreal(cutoffFraction) || ~isfinite(cutoffFraction) || cutoffFraction<0 || cutoffFraction>=1)
    error('WV:AdaptiveSVVCutoff','Use a cutoff fraction in [0,1), or NaN for the standard cutoff.');
end
if isnan(cutoffFraction)
    cutoff=spacing*(maximum/spacing)^(3/4);
else
    cutoff=cutoffFraction*maximum;
end
b=sqrt(-log(0.1));
significant=(maximum+b*cutoff)/(1+b);
filter=zeros(size(coordinate));
active=coordinate>cutoff;
filter(active)=exp(-((coordinate(active)-maximum)./(coordinate(active)-cutoff)).^2);
filter(coordinate>maximum & active)=1;
end
