function bytes = measureReconstructionMemory(stateFile,implementation)
% Run in separate /usr/bin/time -l workers to compare full-call process peaks.
arguments
    stateFile (1,1) string
    implementation (1,1) string {mustBeMember(implementation,["reference","selected"])}
end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path; cleanup=onCleanup(@()path(originalPath));
addpath(fullfile(root,'UnitTests','ReferenceImplementations'));
data=load(stateFile,'scientific','coefficients');
w=WVTransformFreeSurfaceBoussinesq(data.scientific);
for name=string(fieldnames(data.coefficients)).', w.(name)=data.coefficients.(name); end
if implementation=="reference"
    w.addOperation(fullBoussinesqReferenceOperation(w),shouldOverwriteExisting=true,shouldSuppressWarning=true);
end
for repeat=1:10
    w.t=repeat;
    ssh=w.variableWithName('ssh');
end
bytes=0;
for key=w.variableCache.keys.'
    value=w.variableCache{key}; entry=whos('value'); bytes=bytes+entry.bytes;
end
fprintf('%s: cached array bytes %d; SSH checksum %.15g\n',implementation,bytes,sum(ssh,'all'));
end
