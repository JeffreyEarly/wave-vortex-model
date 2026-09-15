function [comparison,observables] = compareThermalReadinessDiagnostics(candidate,reference,options)
% Compare fixed-state diagnostic sampling, retaining source-norm uncertainty.
%
% Coefficients must already use the same physical mode labels, normalization,
% phase and compact Fourier order. A stored-grid comparison should align them
% with coefficientStateForTransform before calling this function. Residuals
% need not be small; their sampling changes and source norms must be stable.
%
% - Topic: Developer utilities
% - Parameter candidate: public apvDecomposition result at candidate sampling
% - Parameter reference: result for the same state at finer sampling
% - Parameter options.samplingTolerance: relative reporting allowance; default 1%
% - Returns comparison: coefficient, residual and source-norm changes and admission
% - Returns observables: all residual components with explicit denominator floors
arguments (Input)
    candidate (1,1) struct
    reference (1,1) struct
    options.samplingTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-2
end
arguments (Output)
    comparison (1,1) struct
    observables table
end
comparison=struct(coefficientChange=0,residualChangeOverSource=0,sourceNormChange=0,samplingTolerance=options.samplingTolerance,accepted=false);
for name=["Ag_q","Ag_0"]
    labels="apvModeNumber";
    if name=="Ag_0",labels="activeEndpoint";end
    if ~isequal(candidate.metadata.(labels),reference.metadata.(labels)) || ~isequal(size(candidate.coefficients.(name)),size(reference.coefficients.(name)))
        error('WV:ReadinessDiagnosticLabels','Align physical labels and compact Fourier order before comparing coefficients.');
    end
    a=candidate.coefficients.(name); b=reference.coefficients.(name);
    difference=norm(a-b,'fro'); scale=norm(b,'fro');
    value=0;
    if ~isfinite(difference) || ~isfinite(scale),value=Inf;elseif scale>0,value=difference/scale;elseif difference>0,value=Inf;end
    comparison.coefficientChange=max(comparison.coefficientChange,value);
end
observables=table();
for name=string(fieldnames(reference.residuals)).'
    a=candidate.residuals.(name); b=reference.residuals.(name);
    floor=1e-10;
    if name=="qgpv",floor=1e-13;elseif ismember(name,["velocity","buoyancy"]),floor=1e-12;end
    units="m";
    if name=="qgpv",units="s^-1";elseif name=="buoyancy",units="m s^-2";elseif name=="velocity",units="m s^-1";elseif name=="energyNorm",units="m^(3/2) s^-1";end
    for component=1:numel(b.absolute)
        scale=max(b.reference(component),floor);
        residualChange=abs(a.absolute(component)-b.absolute(component))/scale;
        sourceChange=abs(a.reference(component)-b.reference(component))/scale;
        comparison.residualChangeOverSource=max(comparison.residualChangeOverSource,residualChange);
        comparison.sourceNormChange=max(comparison.sourceNormChange,sourceChange);
        row=struct(observable=name,component=component,units=units,candidateResidual=a.absolute(component),referenceResidual=b.absolute(component), ...
            candidateSourceNorm=a.reference(component),referenceSourceNorm=b.reference(component),sourceNormFloor=floor, ...
            candidateRelativeResidual=a.relative(component),referenceRelativeResidual=b.relative(component), ...
            residualChangeOverSource=residualChange,sourceNormChange=sourceChange, ...
            accepted=isfinite(residualChange) && isfinite(sourceChange) && max(residualChange,sourceChange)<=options.samplingTolerance);
        observables=[observables;struct2table(row)]; %#ok<AGROW>
    end
end
values=[comparison.coefficientChange,comparison.residualChangeOverSource,comparison.sourceNormChange];
comparison.accepted=all(isfinite(values)) && all(values<=options.samplingTolerance) && all(observables.accepted);
end
