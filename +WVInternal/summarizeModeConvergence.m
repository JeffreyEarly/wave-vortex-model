function summary = summarizeModeConvergence(report,n,tolerance)
% Reduce a provider report to count-policy evidence without changing it.
if n==0
    summary=struct(passed=false(0,1),measured=false(0,1),complete=true,acceptedCount=0,modeError=nan(0,1),prefixError=nan(0,1));
    return
end
labels=report.identity.columnLabels(1:n).';
measurements=report.measurements;
keys=["equivalentDepth:";"h1:"+report.coverage.variables(:)];
[required,metricGroup]=ismember(measurements.quantity+":"+measurements.variable,keys);
[uniqueLabels,~,candidateGroup]=unique(labels);
[found,measurementGroup]=ismember(measurements.columnLabel(required),uniqueLabels);
measurementRows=find(required);
measurementRows=measurementRows(found);
measurementGroup=measurementGroup(found);
nGroups=numel(uniqueLabels);
metricGroup=metricGroup(measurementRows);
rowCount=accumarray([measurementGroup,metricGroup],1,[nGroups numel(keys)],@sum,0);
unmeasured=measurements.status(measurementRows)~="measured" | isnan(measurements.value(measurementRows));
hasUnmeasured=accumarray(measurementGroup,unmeasured,[nGroups 1],@any,false);
measured=all(rowCount(candidateGroup,:)==1,2) & ~hasUnmeasured(candidateGroup);
withinTolerance=accumarray(measurementGroup,measurements.value(measurementRows)<=tolerance,[nGroups 1],@all,true);
values=measurements.value(measurementRows);
groupHasValue=accumarray(measurementGroup,~isnan(values),[nGroups 1],@any,false);
values(isnan(values))=-Inf;
groupError=accumarray(measurementGroup,values,[nGroups 1],@max,-Inf);
groupError(~groupHasValue)=NaN;
passed=measured & withinTolerance(candidateGroup);
modeError=groupError(candidateGroup);
prefixError=cummax(modeError,"omitnan");
summary=struct(passed=passed,measured=measured,complete=all(measured),acceptedCount=sum(cumprod(passed)), ...
    modeError=modeError,prefixError=prefixError);
end
