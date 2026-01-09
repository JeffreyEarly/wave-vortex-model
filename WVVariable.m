classdef WVVariable < handle
    % Describes a variable computed from the WVTransform
    % 
    % In addition to adding a name, description and detailed description of
    % a given variable, you also specify its dimensions, units, and whether
    % or note it has an imaginary part. These annotations are used for both
    % online documentation and for writing to NetCDF files.
    %
    % Setting the two properties `isVariableWithLinearTimeStep` and
    % `isVariableWithNonlinearTimeStep` are important for determining
    % how the variable is cached, and when it is saved to a NetCDF file.
    %
    % Note that as a subclass of WVAnnotation, this class looks for
    % a file (name).md in the directory where it is defined another other
    % subdirectories. This file is then read-in to the detailed description
    % that is used on the website.
    %
    % - Declaration: classdef WVVariableAnnotation < [WVAnnotation](/classes/wvannotation/)
    properties
        % WVOperation responsible for computing this variable
        %
        % This property will be automatically populated when the variable
        % annotation is passed to the WVOperation.
        % - Topic: Properties
        modelOp

        % boolean indicating whether the variable changes value with a linear time step
        %
        % This information is used when caching variables and when writing
        % to NetCDF file.
        % - Topic: Properties
        isVariableWithLinearTimeStep logical = true

        % boolean indicating whether the variable changes value with a non-linear time step
        %
        % This information is used when caching variables and when writing
        % to NetCDF file.
        % - Topic: Properties
        isVariableWithNonlinearTimeStep logical = true

        % boolean indicating whether the variable depends on Ap, Am, or A0
        %
        % This information is used when caching variables and when writing
        % to NetCDF file.
        % - Topic: Properties
        isDependentOnApAmA0 logical = true
    end
end