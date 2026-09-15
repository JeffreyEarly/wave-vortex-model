function failure = buildThermalGeneralizedEnstrophyState(varargin)
% Test-only shadow: canonical restart must not invoke scientific assembly.
failure = MException('TestNativeThermalAdaptiveDamping:ScientificConstructionDisabled','The restored canonical damping state attempted scientific construction.');
throw(failure);
end
