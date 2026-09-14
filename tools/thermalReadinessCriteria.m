function criteria = thermalReadinessCriteria()
% Return the fixed T10 dimensional field allowances for authoring reports.
% - Topic: Developer utilities
% - Returns criteria: observable names, units, relative allowances and absolute floors
arguments (Output)
    criteria (1,1) struct
end
criteria=struct(observable=["qgpv","buoyancy","velocity","ssh","surfaceAnomaly","bottomAnomaly","energyNorm","upperBuoyancyGradient","surfaceBuoyancyGradient"],units=["s^-1","m s^-2","m s^-1","m","m","m","m^(3/2) s^-1","s^-2","s^-2"],relativeAllowance=[.01 .01 .01 .01 .01 .01 .01 .05 .05],absoluteFloor=[1e-12 1e-10 1e-7 1e-4 1e-4 1e-5 1e-6 1e-11 1e-11]);
end
