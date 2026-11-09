function spline = densitySplineFromSnapshot(snapshot)
% Recover an independent spline from canonical density source data.
arguments (Input)
    snapshot (1,1) string
end
arguments (Output)
    spline BSpline
end

if strlength(snapshot)==0
    spline = BSpline.empty(0,1);
else
    args = namedargs2cell(jsondecode(snapshot));
    spline = BSpline(args{:});
end
end
