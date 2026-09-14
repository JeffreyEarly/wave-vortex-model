function force=thermalReadinessDamping(wvt,canonical,options)
% Construct a readiness candidate from one frozen online APV configuration.
%
% The horizontal candidate changes only apvVerticalRates to zero. Both
% candidates retain the same physical horizontal cutoff and resolution,
% independently of the target grid. Use forcingWithResolutionOfTransform
% for subsequent transfers and ordinary annotated transform persistence.
% The caller records the variant and canonical arrays in its case manifest;
% both candidates deliberately use the existing runtime class and name.
% A case with no optional damping simply omits this forcing.
%
% - Topic: Developer utilities
% - Parameter wvt: owning thermal transform
% - Parameter canonical: exact WVThermalAPVDamping required-property struct frozen once on the candidate grid
% - Parameter options.variant: horizontal (zero vertical rates) or apv (unchanged frozen rates)
% - Returns force: unregistered existing runtime closure; its APV-map construction and evaluation costs remain present
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceThermalQG
    canonical (1,1) struct
    options.variant (1,1) string {mustBeMember(options.variant,["horizontal","apv"])} = "horizontal"
end
arguments (Output)
    force (1,1) WVThermalAPVDamping
end
names=string(WVThermalAPVDamping.classRequiredPropertyNames()).';
if ~isequal(sort(string(fieldnames(canonical))),sort(names))
    error('ThermalReadiness:ClosureConfiguration','Supply exactly the frozen WVThermalAPVDamping required properties.');
end
rates=canonical.apvVerticalRates;
if ~isa(rates,'double') || ~isreal(rates) || any(~isfinite(rates) | rates>0,'all')
    error('ThermalReadiness:ClosureConfiguration','Frozen APV vertical rates must be finite real nonpositive doubles.');
end
if options.variant=="horizontal", canonical.apvVerticalRates=zeros(size(rates)); end
args=namedargs2cell(canonical);
force=WVThermalAPVDamping(wvt,args{:});
end
