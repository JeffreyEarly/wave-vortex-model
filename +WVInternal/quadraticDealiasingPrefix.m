function report = quadraticDealiasingPrefix(F,G,gridDegree,options)
% Apply the shared quadratic-dealiasing policy to one linear mode prefix.
arguments
    F double
    G double
    gridDegree (1,1) double {mustBeInteger,mustBeNonnegative}
    options (1,1) struct
end
if isempty(F)
    linearCount=size(G,2);
else
    linearCount=size(F,2);
end
if ~isempty(F) && ~isempty(G) && size(F,2)~=size(G,2)
    error('WV:QuadraticDealiasingShape','F and G must contain the same mode columns.')
end
report=assessQuadraticDealiasing(F,G,gridDegree, ...
    quadraticDealiasing=options.quadraticDealiasing, ...
    retainedFraction=options.retainedFraction, ...
    energyFraction=options.energyFraction, ...
    bandwidthFraction=options.bandwidthFraction, ...
    representation="values");
report.coordinateKind="wkb-chebyshev-lobatto";
report.linearCount=linearCount;
report.filteringCount=sum(cumprod(report.accepted));
report.selectedCount=report.filteringCount;
end
