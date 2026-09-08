function results=runShortSeasonalQGLinearPreflight(folder)
% Assess the forced vertical page with explicit progressively finer modes.
% The 100 km mode-1 proxy has the same kh as mode 5 in the 500 km case.
% This rest-state linear preflight excludes the seed and other processes;
% it estimates vertical accuracy, not nonlinear production-run accuracy.
arguments (Input)
    folder (1,1) string
end
arguments (Output)
    results table
end
if ~isfolder(folder), mkdir(folder); end
results=table();
for series=1:2
    if series==1, counts=[65 129 257]; modes=[14 54 108]; else, counts=[513 769 1025]; modes=[217 325 433]; end
    transforms=cell(1,3);
    for j=1:3
        N2=@(z)(5.2e-3)^2*exp(2*z/1300);
        weight=(5.2e-3)^2*1300*(1-exp(-8000/1300))/2;
        transforms{j}=WVTransformFreeSurfaceQG([100e3 100e3 4000],[4 4 counts(j)],apvModeCount=modes(j),N2Function=N2,latitude=24,g0=-weight,gd=weight,mdaModeCount=2,shouldAntialias=false);
        fprintf('Linear preflight Nz=%g APV=%g\n',counts(j),transforms{j}.apvModeCount);
    end
    w=transforms{1}; period=365.25*86400;
    forcing=WVSeasonalSurfaceAnomalyForcing(w,pattern=sin(2*pi*w.Y(:,:,1)/w.Ly),amplitude=10*pi/period,period=period,phase=0);
    diffusion=WVVerticalDiffusivity(w,kappa_z=1e-5);
    r=diffusion.assessSeasonalResponse(forcing,[64*86400 period/4],referenceTransforms=transforms(2:3));
    comparisons={r.representation,r.evolution,r.total,r.reference.convergence};
    labels=["representation","evolution","total","referenceConvergence"];
    for j=1:4
        c=comparisons{j};
        for name=string(c.absolute.Properties.VariableNames(2:end))
            rows=table(repmat(labels(j),2,1),repmat(name,2,1),c.absolute.time/86400,c.absolute.(name),c.relative.(name),c.referenceMagnitude.(name),repmat(counts(1),2,1),repmat(w.apvModeCount,2,1),repmat(transforms{2}.Nz,2,1),repmat(transforms{2}.apvModeCount,2,1),repmat(transforms{3}.Nz,2,1),repmat(transforms{3}.apvModeCount,2,1),VariableNames=["comparison","observable","day","absolute","relative","referenceMagnitude","Nz","apvModeCount","referenceNz","referenceAPV","finestNz","finestAPV"]);
            results=[results;rows]; %#ok<AGROW>
        end
    end
    writetable(results,fullfile(folder,'issue-353-spatial-linear.csv'));
end
end
