function recordToleranceAttempt(t,h,normalizedError,accepted,relativeToAbsolute)
% Record the maximum normalized local error in each coefficient family.
global toleranceTrace %#ok<GVMIS> Temporary solver probe shared with the unmodified solver interface.
values=zeros(1,numel(toleranceTrace.last));
for k=1:numel(values)
    values(k)=max(normalizedError(toleranceTrace.first(k):toleranceTrace.last(k)),[],'all');
end
toleranceTrace.rows(end+1,:)=[t,h,accepted,values];
[~,index]=max(normalizedError);
if ~isfield(toleranceTrace,'branches'), toleranceTrace.branches=zeros(0,3); end
% Ratio > 1 selects the relative branch; record the global winner and all-state maximum.
toleranceTrace.branches(end+1,:)=[index,relativeToAbsolute(index),max(relativeToAbsolute)];
if mod(size(toleranceTrace.rows,1),200)==0
    writematrix([t,h,size(toleranceTrace.rows,1)],fullfile(tempdir,sprintf('v5-tolerance-progress-%d.txt',matlabProcessID)));
end
end
