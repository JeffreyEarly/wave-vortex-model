function prepareToleranceTrace(outputFolder)
% Instrument a temporary copy of the installed ode78; never edit or redistribute it.
arguments (Input)
    outputFolder (1,1) string
end
source=which('ode78');
text=fileread(source);
text=replace(text,'function varargout = ode78(', 'function varargout = tracedOde78(');
text=replace(text,'function varargout=ode78(', 'function varargout=tracedOde78(');
marker='        % Accept the solution only if the weighted error is no more than the';
assert(contains(text,marker),'ToleranceStudy:SolverVersion','Installed ode78 has an unfamiliar error-estimator layout.');
insertion=join(["        if nofailed"; "            traceAmplitude=max(abs(y),abs(ynew));"; "        else"; "            traceAmplitude=abs(y);"; "        end"; "        traceWeight=max(traceAmplitude,threshold);"; "        recordToleranceAttempt(t,absh,absh*abs(fE)./traceWeight/rtol,err<=rtol,traceAmplitude./threshold);"; ""],newline);
text=replace(text,marker,insertion+marker);
if ~isfolder(outputFolder), mkdir(outputFolder); end
if ~isfolder(fullfile(outputFolder,'private'))
    copyfile(fullfile(fileparts(source),'private'),fullfile(outputFolder,'private'));
end
fid=fopen(fullfile(outputFolder,'tracedOde78.m'),'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s',text);
addpath(outputFolder);
end
