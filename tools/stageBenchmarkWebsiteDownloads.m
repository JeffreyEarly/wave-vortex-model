function stageBenchmarkWebsiteDownloads(repositoryRoot,stagingFolder)
% Materialize catalog downloads in a temporary website tree using Python 3.
arguments
    repositoryRoot (1,1) string
    stagingFolder (1,1) string
end

script = fullfile(fileparts(mfilename("fullpath")),"website_downloads.py");
manifest = fullfile(stagingFolder,"benchmarks","downloads.json");
commandArguments = ["python3",script,"--root",repositoryRoot,"--manifest",manifest,"--destination",stagingFolder];
command = javaArray('java.lang.String',numel(commandArguments));
for iArgument = 1:numel(commandArguments)
    command(iArgument) = java.lang.String(commandArguments(iArgument));
end
builder = java.lang.ProcessBuilder(command);
builder.redirectErrorStream(true);
try
    process = builder.start();
catch exception
    error("WaveVortexModel:WebsitePythonUnavailable","Website download validation requires Python 3 on PATH: %s",exception.message);
end
reader = java.util.Scanner(process.getInputStream(),'UTF-8');
reader.useDelimiter('\A');
output = "";
if reader.hasNext(), output = string(reader.next()); end
status = process.waitFor();
reader.close();
if status ~= 0
    error("WaveVortexModel:WebsiteDownloadStagingFailed","Benchmark downloads could not be staged: %s",output);
end
fprintf("%s",output);
end
