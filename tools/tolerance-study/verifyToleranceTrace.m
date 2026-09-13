function verifyToleranceTrace()
% Verify that the temporary probe preserves accepted and rejected ode78 steps.
global toleranceTrace %#ok<GVMIS> The temporary probe shares the solver's unchanged interface.
toleranceTrace=struct(first=[1 2],last=[1 2],rows=zeros(0,5));
options=odeset('AbsTol',[1e-7;1e-8],'RelTol',1e-6,'Refine',1,'InitialStep',20);
rhs=@(~,y)[1i*y(1);-2*y(2)];
[t,a]=ode78(rhs,[0 20],[1;1],options);
[s,b]=tracedOde78(rhs,[0 20],[1;1],options);
assert(isequal(t,s)&&isequal(a,b),'ToleranceStudy:TraceParity','The probe changed the solver trajectory.');
assert(any(toleranceTrace.rows(:,3)==0),'ToleranceStudy:TraceRejection','The control must include a rejected step.');
assert(sum(toleranceTrace.rows(:,3))==numel(t)-1,'ToleranceStudy:TraceCount','Accepted trace rows do not match solver output.');
assert(all(max(toleranceTrace.rows(:,4:end),[],2)<=1 | toleranceTrace.rows(:,3)==0),'ToleranceStudy:TraceAcceptance','The trace disagrees with the local acceptance criterion.');
end
