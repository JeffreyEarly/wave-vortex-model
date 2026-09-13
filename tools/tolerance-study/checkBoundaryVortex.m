function results = checkBoundaryVortex(outputFolder)
% Verify the reference vortex without mixing time and spatial errors.
arguments (Input)
    outputFolder (1,1) string
end
folder=fileparts(mfilename('fullpath'));
addpath(fullfile(folder,'..','..','Documentation','Examples'));
base=runBoundaryVortex(fullfile(outputFolder,'base'));
time=runBoundaryVortex(fullfile(outputFolder,'time'),absTolerance=1e-10,relTolerance=1e-10);
horizontal=runBoundaryVortex(fullfile(outputFolder,'horizontal'),gridSize=[256 256 129]);
vertical=runBoundaryVortex(fullfile(outputFolder,'vertical'),gridSize=[128 128 129]);
timeError=relative(base.boundary,time.boundary);
horizontalError=relative(base.boundary,horizontal.boundary(1:2:end,1:2:end,:));
verticalError=relative(base.boundary,vertical.boundary);
[wvt,scale]=makeBoundaryVortex(stationaryControl=true);
F=wvt.coefficientTendency();
stationaryError=norm(F.Ag_0)*scale.time/norm(wvt.Ag_0);
varianceDrift=max(abs(base.variance/base.variance(1)-1));
maximumPV=max(base.maximumPV);
results=table(timeError,horizontalError,verticalError,stationaryError,varianceDrift,maximumPV);
writetable(results,fullfile(outputFolder,'boundary-verification.csv'));
assert(max([timeError,horizontalError,verticalError])<.01,'BoundaryVortex:Unresolved','The displayed boundary field is not converged to one percent.');
assert(stationaryError<1e-12 && maximumPV<1e-12,'BoundaryVortex:PVControl','Stationary or zero-PV control failed.');
end
function e=relative(a,b)
e=0;
for i=1:size(a,3)
    e=max(e,norm(a(:,:,i)-b(:,:,i),'fro')/norm(b(:,:,i),'fro'));
end
end
