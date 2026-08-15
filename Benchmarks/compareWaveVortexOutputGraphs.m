function comparison = compareWaveVortexOutputGraphs(referencePath,candidatePath,options)
% Compare the complete saved WaveVortexModel NetCDF output graph.
arguments
    referencePath (1,1) string {mustBeFile}
    candidatePath (1,1) string {mustBeFile}
    options.relativeTolerance (1,1) double {mustBeNonnegative} = 1e-12
    options.absoluteTolerance (1,1) double {mustBeNonnegative} = 1e-13
    options.maximumChunkBytes (1,1) double {mustBeInteger,mustBePositive} = 16*2^20
end
reference = ncinfo(referencePath);
candidate = ncinfo(candidatePath);
comparison = struct("passed",true,"maximumRelativeError",0,"maximumAbsoluteError",0,"variableCount",0,"recordCount",0,"categories",emptyCategories,"differences",strings(0,1));
comparison = compareGroup(reference,candidate,"",referencePath,candidatePath,options,comparison);
comparison.passed = isempty(comparison.differences);
end

function comparison = compareGroup(reference,candidate,parentPath,referencePath,candidatePath,options,comparison)
groupPath = joinedPath(parentPath,string(reference.Name));
comparison = requireEqual(string(reference.Name),string(candidate.Name),groupPath+" group name",comparison);
comparison = compareDimensions(reference.Dimensions,candidate.Dimensions,groupPath,comparison);
comparison = compareAttributes(reference.Attributes,candidate.Attributes,groupPath,comparison);
comparison = requireEqual(structStrings(reference.Variables,"Name"),structStrings(candidate.Variables,"Name"),groupPath+" variable order",comparison);
if numel(reference.Variables) == numel(candidate.Variables)
    for iVariable = 1:numel(reference.Variables)
        comparison = compareVariable(reference.Variables(iVariable),candidate.Variables(iVariable),groupPath,referencePath,candidatePath,options,comparison);
    end
end
comparison = requireEqual(structStrings(reference.Groups,"Name"),structStrings(candidate.Groups,"Name"),groupPath+" group order",comparison);
if numel(reference.Groups) == numel(candidate.Groups)
    for iGroup = 1:numel(reference.Groups)
        comparison = compareGroup(reference.Groups(iGroup),candidate.Groups(iGroup),groupPath,referencePath,candidatePath,options,comparison);
    end
end
end

function comparison = compareDimensions(reference,candidate,path,comparison)
comparison = requireEqual(structStrings(reference,"Name"),structStrings(candidate,"Name"),path+" dimension names",comparison);
comparison = requireEqual(structNumbers(reference,"Length"),structNumbers(candidate,"Length"),path+" dimension lengths",comparison);
comparison = requireEqual(logical(structNumbers(reference,"Unlimited")),logical(structNumbers(candidate,"Unlimited")),path+" unlimited dimensions",comparison);
end

function comparison = compareAttributes(reference,candidate,path,comparison)
comparison = requireEqual(structStrings(reference,"Name"),structStrings(candidate,"Name"),path+" attribute names",comparison);
if numel(reference) ~= numel(candidate), return, end
for iAttribute = 1:numel(reference)
    name = string(reference(iAttribute).Name);
    if name == "history"
        if strlength(string(reference(iAttribute).Value))==0 || strlength(string(candidate(iAttribute).Value))==0
            comparison.differences(end+1,1) = path+"/@history is empty";
        end
    else
        comparison = requireEqual(reference(iAttribute).Value,candidate(iAttribute).Value,path+"/@"+name,comparison);
    end
end
end

function comparison = compareVariable(reference,candidate,groupPath,referencePath,candidatePath,options,comparison)
variablePath = joinedPath(groupPath,string(reference.Name));
comparison = requireEqual(string(reference.Name),string(candidate.Name),variablePath+" name",comparison);
comparison = requireEqual(string(reference.Datatype),string(candidate.Datatype),variablePath+" type",comparison);
comparison = requireEqual(structStrings(reference.Dimensions,"Name"),structStrings(candidate.Dimensions,"Name"),variablePath+" dimension names",comparison);
comparison = requireEqual(double(reference.Size),double(candidate.Size),variablePath+" shape",comparison);
comparison = compareAttributes(reference.Attributes,candidate.Attributes,variablePath,comparison);
if string(reference.Datatype) ~= string(candidate.Datatype) || ~isequal(double(reference.Size),double(candidate.Size))
    return
end
comparison.variableCount = comparison.variableCount+1;
dimensionNames = structStrings(reference.Dimensions,"Name");
timeDimension = find(dimensionNames=="t",1);
if ~isempty(timeDimension)
    comparison.recordCount = comparison.recordCount+double(reference.Size(timeDimension));
end
[maximumAbsolute,maximumRelative,passed] = compareVariableValues(referencePath,candidatePath,variablePath,reference,options);
comparison.maximumAbsoluteError = max(comparison.maximumAbsoluteError,maximumAbsolute);
comparison.maximumRelativeError = max(comparison.maximumRelativeError,maximumRelative);
category = variableCategory(reference);
comparison.categories = updateCategory(comparison.categories,category,maximumAbsolute,maximumRelative,passed);
if ~passed
    comparison.differences(end+1,1) = variablePath+" payload differs";
end
end

function [maximumAbsolute,maximumRelative,passed] = compareVariableValues(referencePath,candidatePath,variablePath,variable,options)
if isempty(variable.Dimensions)
    expected = ncread(referencePath,variablePath);
    actual = ncread(candidatePath,variablePath);
    [maximumAbsolute,maximumRelative,passed] = compareValues(expected,actual,options);
    return
end
shape = double(variable.Size);
if isempty(shape), shape = 1; end
elementBytes = 8;
if contains(lower(string(variable.Datatype)),["char" "byte" "int" "short"]), elementBytes = 4; end
count = shape;
count(1) = max(1,min(shape(1),floor(options.maximumChunkBytes/(elementBytes*max(1,prod(shape(2:end)))))));
maximumAbsolute = 0;
maximumReference = 0;
passed = true;
for first = 1:count(1):shape(1)
    chunk = count;
    chunk(1) = min(count(1),shape(1)-first+1);
    start = ones(size(shape));
    start(1) = first;
    expected = ncread(referencePath,variablePath,start,chunk);
    actual = ncread(candidatePath,variablePath,start,chunk);
    [chunkAbsolute,~,chunkPassed,chunkReference] = compareValues(expected,actual,options);
    maximumAbsolute = max(maximumAbsolute,chunkAbsolute);
    maximumReference = max(maximumReference,chunkReference);
    passed = passed && chunkPassed;
end
maximumRelative = maximumAbsolute/max(maximumReference,realmin("double"));
end

function [maximumAbsolute,maximumRelative,passed,maximumReference] = compareValues(expected,actual,options)
maximumReference = 0;
if isfloat(expected)
    expected = double(expected);
    actual = double(actual);
    matchingNonfinite = (isnan(expected)&isnan(actual)) | (isinf(expected)&isinf(actual)&sign(expected)==sign(actual));
    finite = isfinite(expected)&isfinite(actual);
    difference = inf(size(expected));
    difference(matchingNonfinite) = 0;
    difference(finite) = abs(actual(finite)-expected(finite));
    maximumAbsolute = max(difference,[],"all");
    finiteReference = abs(expected(isfinite(expected)));
    if ~isempty(finiteReference), maximumReference = max(finiteReference,[],"all"); end
    passed = all(matchingNonfinite|finite,"all") && all(difference<=options.absoluteTolerance+options.relativeTolerance*abs(expected)|matchingNonfinite,"all");
else
    passed = isequal(actual,expected);
    maximumAbsolute = conditional(passed,0,Inf);
end
maximumRelative = maximumAbsolute/max(maximumReference,realmin("double"));
end

function category = variableCategory(variable)
name = string(variable.Name);
attributeNames = structStrings(variable.Attributes,"Name");
if name == "t"
    category = "times";
elseif any(attributeNames=="isParticle")
    category = "particles";
elseif any(attributeNames=="isTracer")
    category = "tracers";
elseif any(attributeNames=="mooringName")
    category = "moorings";
elseif ismember(name,["Ap" "Am" "A0" "Ap_real" "Ap_imag" "Am_real" "Am_imag" "A0_real" "A0_imag"])
    category = "coefficients";
elseif any(structStrings(variable.Dimensions,"Name")=="t")
    category = "eulerianFields";
else
    category = "metadata";
end
end

function categories = updateCategory(categories,name,maximumAbsolute,maximumRelative,passed)
index = find(string({categories.name})==name,1);
if isempty(index)
    categories(end+1) = struct("name",name,"variableCount",1,"maximumAbsoluteError",maximumAbsolute,"maximumRelativeError",maximumRelative,"passed",passed);
else
    categories(index).variableCount = categories(index).variableCount+1;
    categories(index).maximumAbsoluteError = max(categories(index).maximumAbsoluteError,maximumAbsolute);
    categories(index).maximumRelativeError = max(categories(index).maximumRelativeError,maximumRelative);
    categories(index).passed = categories(index).passed && passed;
end
end

function comparison = requireEqual(reference,candidate,label,comparison)
if ~isequaln(reference,candidate)
    comparison.differences(end+1,1) = label+" differs";
end
end

function value = joinedPath(parent,child)
child = strip(child,"left","/");
if parent == "" || parent == "/", value = "/"+child; else, value = parent+"/"+child; end
if value == "", value = "/"; end
end

function value = emptyCategories
value = repmat(struct("name","","variableCount",0,"maximumAbsoluteError",0,"maximumRelativeError",0,"passed",true),0,1);
end

function value = conditional(condition,trueValue,falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function values = structStrings(value,field)
if isempty(value)
    values = strings(1,0);
else
    values = string({value.(field)});
end
end

function values = structNumbers(value,field)
if isempty(value)
    values = zeros(1,0);
else
    values = double([value.(field)]);
end
end
