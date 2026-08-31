function ncfile = writeToFile(self,path,properties,options)
% Write the complete free-surface QG scientific representation.
%
% Inactive zero-APV dimensions and variables are physically omitted.
%
% - Topic: Save transform state
% - Declaration: ncfile = writeToFile(self,path,properties,options)
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    path char {mustBeNonempty}
end
arguments (Input,Repeating)
    properties char
end
arguments (Input)
    options.shouldOverwriteExisting logical = false
    options.shouldAddRequiredProperties logical = true
    options.attributes = configureDictionary("string","string")
end
arguments (Output)
    ncfile NetCDFFile
end

selected = properties;
if options.shouldAddRequiredProperties
    selected = union(selected,self.requiredProperties);
end
if self.activeEndpointCount > 0
    representationNames = setdiff(WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames(),{'Ag_0'});
    selected = union(selected,representationNames);
    coefficientNames = self.coefficientStateVariableNamesForPersistence();
    if any(ismember(coefficientNames,selected))
        selected = union(selected,{'Ag_0'});
    end
else
    selected = setdiff(selected,WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames());
end

optionArguments = namedargs2cell(options);
optionArguments = replaceOption(optionArguments,'shouldAddRequiredProperties',false);
ncfile = writeToFile@WVTransform(self,path,selected{:},optionArguments{:});
end

function options = replaceOption(options,name,value)
index = find(strcmp(options(1:2:end),name),1);
if isempty(index)
    options{end+1} = name;
    options{end+1} = value;
else
    options{2*index} = value;
end
end
