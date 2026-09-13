classdef (Hidden, Sealed) WVCompiledSourceIdentity < handle
    % Opaque runtime identity for one transform's compiled scientific source.
    %
    % Identity follows MATLAB handle equality and survives clear functions.
    % Transforms retain this token in transient storage; it has no state or
    % reference to the transform and is not part of scientific persistence.
    %
    % - Developer: true
    % - Topic: Compiled transform internals
    % - Declaration: classdef (Hidden, Sealed) WVCompiledSourceIdentity < handle
end
