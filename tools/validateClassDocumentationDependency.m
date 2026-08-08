function dependency = validateClassDocumentationDependency()
requiredVersion = "1.3.0";
classPath = string(which("ClassDocumentation"));
if classPath == ""
    error("WaveVortexModel:MissingClassDocumentation","Documentation generation requires ClassDocumentation %s. Install it with mpminstall('ClassDocumentation@%s').",requiredVersion,requiredVersion);
end

packageRoot = string(fileparts(classPath));
manifestPath = fullfile(packageRoot,"resources","mpackage.json");
if ~isfile(manifestPath)
    error("WaveVortexModel:InvalidClassDocumentationPackage","ClassDocumentation resolved from %s, which has no package manifest.",packageRoot);
end
manifest = jsondecode(fileread(manifestPath));
actualVersion = string(manifest.version);
if actualVersion ~= requiredVersion
    error("WaveVortexModel:ClassDocumentationVersionMismatch","Documentation generation requires ClassDocumentation %s, but %s resolved from %s.",requiredVersion,actualVersion,packageRoot);
end

rebuildHelper = string(which("rebuildWebsiteDocumentationFromSource"));
if rebuildHelper == "" || ~startsWith(rebuildHelper,packageRoot + filesep)
    error("WaveVortexModel:InconsistentClassDocumentationPath","ClassDocumentation and its website rebuild helper must resolve from the same package root.");
end

dependency = struct("Name","ClassDocumentation","Version",actualVersion,"Root",packageRoot);
fprintf("Documentation dependency: %s %s (%s)\n",dependency.Name,dependency.Version,dependency.Root);
end
