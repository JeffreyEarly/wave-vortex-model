function assessment = freeSurfaceGridAssessment(rule,z,kh)
% Record the prescribed sampling and the largest retained Fourier radius.
if nargin<3
    maximumRetainedKh = NaN;
else
    maximumRetainedKh = max([kh(:);0]);
end
assessment = struct(rule=rule,Nz=numel(z),zEndpoints=[z(1) z(end)],maximumRetainedKh=maximumRetainedKh);
end
