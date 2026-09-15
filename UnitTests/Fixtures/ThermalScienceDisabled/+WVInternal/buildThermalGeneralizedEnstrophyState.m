function state = buildThermalGeneralizedEnstrophyState(varargin) %#ok<STOUT> This fixture always throws.
% Test-only shadow: canonical restart must not invoke scientific assembly.
error('TestNativeThermalAdaptiveDamping:ScientificConstructionDisabled','The restored canonical damping state attempted scientific construction.');
end
