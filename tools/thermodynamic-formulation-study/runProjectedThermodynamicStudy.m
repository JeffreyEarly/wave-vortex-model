function runProjectedThermodynamicStudy
% Fixed-state amplitude and resolution study; no trajectories or timing.
folder=fileparts(mfilename('fullpath'));
rows=struct([]); families=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    % First refine the evaluation grid at fixed modes, then retained modes.
    for configuration=[8 16 16;33 65 65;3 3 6;4 4 8;2 2 4]
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[configuration(1) configuration(1) configuration(2)],N2Function=N2,apvModeCount=configuration(3),waveModeCount=configuration(4),mdaModeCount=configuration(5),inertialModeCount=3,shouldAntialias=false);
        study=manuscriptEvolutionOperators(w,profile,padding=1);
        for amplitude=[.1 .01]
            state=study.seed("mixed",amplitude);
            result=evaluateProjectedThermodynamics(w,profile,state,327);
            row=rmfield(result,{'families','reference','pulled'});
            row.profile=profile; row.amplitude=amplitude;
            row.Nx=w.Nx; row.Nz=w.Nz; row.apvModes=configuration(3); row.waveModes=configuration(4); row.mdaModes=configuration(5);
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            for entry=result.families
                entry.profile=profile; entry.amplitude=amplitude;
                entry.Nx=w.Nx; entry.Nz=w.Nz; entry.apvModes=configuration(3); entry.waveModes=configuration(4); entry.mdaModes=configuration(5);
                if isempty(families), families=entry; else, families(end+1)=entry; end %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','projected-states.csv'));
writetable(struct2table(families),fullfile(folder,'results','projected-families.csv'));
end
