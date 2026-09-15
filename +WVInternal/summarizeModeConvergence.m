function summary = summarizeModeConvergence(report,n,tolerance)
% Reduce a provider report to count-policy evidence without changing it.
if n==0
    summary=struct(passed=false(0,1),complete=true,acceptedCount=0,prefixError=nan(0,1));
    return
end
labels=report.identity.columnLabels(1:n).';
measurements=report.measurements;
required=ismember(measurements.quantity,["equivalentDepth","h1"]);
[uniqueLabels,~,candidateGroup]=unique(labels);
[found,measurementGroup]=ismember(measurements.columnLabel(required),uniqueLabels);
measurementRows=find(required);
measurementRows=measurementRows(found);
measurementGroup=measurementGroup(found);
nGroups=numel(uniqueLabels);
hasUnmeasured=accumarray(measurementGroup,measurements.status(measurementRows)~="measured",[nGroups 1],@any,false);
withinTolerance=accumarray(measurementGroup,measurements.value(measurementRows)<=tolerance,[nGroups 1],@all,true);
values=measurements.value(measurementRows);
groupHasValue=accumarray(measurementGroup,~isnan(values),[nGroups 1],@any,false);
values(isnan(values))=-Inf;
groupError=accumarray(measurementGroup,values,[nGroups 1],@max,-Inf);
groupError(~groupHasValue)=NaN;
passed=~hasUnmeasured(candidateGroup) & withinTolerance(candidateGroup);
prefixError=cummax(groupError(candidateGroup),"omitnan");
summary=struct(passed=passed,complete=~any(hasUnmeasured(candidateGroup)),acceptedCount=sum(cumprod(passed)),prefixError=prefixError);
end
