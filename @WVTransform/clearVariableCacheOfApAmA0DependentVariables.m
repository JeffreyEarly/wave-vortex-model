function clearVariableCacheOfApAmA0DependentVariables(self)
% clear the internal cache
%
% - Topic: Internal
self.variableCache(intersect(self.variableCache.keys,self.wvCoefficientDependentVariablesNameMap.keys)) = [];
if isa(self,'WVStratification')
    self.resetRhoNoMotion();
end
end