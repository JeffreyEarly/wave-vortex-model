function P = qgVerticalInterpolation(zNative,zQuery)
% Interpolate stored WKB-Chebyshev samples at physical depths.
% Invert the stored polynomial coordinate map by bracketed bisection;
% no stratification function or interpolated physical-depth spline is needed.
% - Topic: Developer utilities
arguments (Input)
    zNative (:,1) double {mustBeFinite}
    zQuery (:,1) double {mustBeFinite}
end
arguments (Output)
    P (:,:) double
end
n = length(zNative);
s = -cos(pi*(0:n-1)'/(n-1));
V = cos(acos(s)*(0:n-1));
a = V\zNative;
if any(zQuery<zNative(1)) || any(zQuery>zNative(end)) || any(diff(zNative)<=0)
    error('WV:ResponseInterpolation','Queries must lie within an increasing stored vertical grid.');
end
lo = -ones(size(zQuery));
hi = ones(size(zQuery));
for iteration = 1:55
    mid = (lo+hi)/2;
    mapped = cos(acos(mid)*(0:n-1))*a;
    below = mapped<zQuery;
    lo(below) = mid(below);
    hi(~below) = mid(~below);
end
P = cos(acos((lo+hi)/2)*(0:n-1))/V;
if max(abs(P*zNative-zQuery))>1e-10*max(1,zNative(end)-zNative(1))
    error('WV:ResponseInterpolation','The stored vertical coordinate map could not be inverted.');
end
end
