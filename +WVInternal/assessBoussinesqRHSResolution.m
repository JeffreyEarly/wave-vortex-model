function report = assessBoussinesqRHSResolution(candidate,reference,controls,options)
% Assess a fixed-state assembled RHS, with independent reference-grid checks.
% Acceptance applies only to these coefficients, phase, basis, and tolerances.
% It does not grant or modify the construction-time quadratic activation flag.
arguments
    candidate (1,1) struct
    reference (1,1) struct
    controls (1,:) cell
    options.relativeTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-3
    options.absoluteTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-18
    options.referenceFraction (1,1) double {mustBePositive,mustBeLessThan(options.referenceFraction,1)} = .01
end
if candidate.snapshot~=reference.snapshot
    error('WV:AssessmentInventoryMismatch','Evaluate candidate and references from the same immutable snapshot.')
end
horizontal=false; vertical=false;
for j=1:numel(controls)
    if controls{j}.snapshot~=reference.snapshot
        error('WV:AssessmentInventoryMismatch','Reference controls must use the same immutable snapshot.')
    end
    grid=controls{j}.grid;
    horizontal=horizontal || (all(grid(1:2)>reference.grid(1:2)) && grid(3)==reference.grid(3));
    vertical=vertical || (all(grid(1:2)==reference.grid(1:2)) && grid(3)>reference.grid(3));
end
rows=struct([]);
for family=string(fieldnames(reference.tendency)).'
    a=candidate.tendency.(family); b=reference.tendency.(family);
    if ~isequal(size(a),size(b)), error('WV:AssessmentInventoryMismatch','Keep every retained family and horizontal index fixed.'); end
    scale=norm(b,'fro'); errorValue=norm(a-b,'fro'); delta=0;
    for j=1:numel(controls)
        value=controls{j}.tendency.(family);
        if ~isequal(size(value),size(b)), error('WV:AssessmentInventoryMismatch','Reference family shapes must agree.'); end
        if any(~isfinite(value),'all'), delta=Inf; else, delta=max(delta,norm(value-b,'fro')); end
    end
    budget=options.relativeTolerance*scale+options.absoluteTolerance;
    row=struct(family=family,absoluteError=errorValue,referenceNorm=scale,relativeError=errorValue/max(scale,options.absoluteTolerance),referenceChange=delta,allowanceFraction=(errorValue+delta)/budget,referenceFraction=delta/(options.referenceFraction*budget));
    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
end
rows=struct2table(rows);
finite=all(isfinite(rows{:,2:end}),'all');
referencesStable=finite && horizontal && vertical && all(rows.referenceFraction<=1);
accepted=referencesStable && all(rows.allowanceFraction<=1);
status="rejected";
if ~referencesStable, status="reference-inconclusive"; elseif accepted, status="assessed"; end
report=struct(status=status,accepted=accepted,referencesStable=referencesStable,horizontalReferenceChecked=horizontal,verticalReferenceChecked=vertical,relativeTolerance=options.relativeTolerance,absoluteTolerance=options.absoluteTolerance,referenceAllowance=options.referenceFraction,rows=rows,coverage="one fixed modal state; all four sources and six retained coefficient families; no universal nonlinear qualification");
end
