function runThermodynamicTangentStudy
% Directional derivatives, amplitude scaling, and retained-mode assessment.
folder=fileparts(mfilename('fullpath'));
finiteRows=struct([]); comparisonRows=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    for configuration=[8 16 16;33 65 65;3 3 6;4 4 8;2 2 4]
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[configuration(1) configuration(1) configuration(2)],N2Function=N2,apvModeCount=configuration(3),waveModeCount=configuration(4),mdaModeCount=configuration(5),inertialModeCount=3,shouldAntialias=false);
        study=manuscriptEvolutionOperators(w,profile,padding=1);
        for amplitude=[.1 .01]
            r=evaluateThermodynamicCoefficientTangent(w,profile,study.seed("mixed",amplitude),327);
            metadata=struct(profile=profile,amplitude=amplitude,Nx=w.Nx,Nz=w.Nz,apvModes=configuration(3),waveModes=configuration(4),mdaModes=configuration(5));
            for row=r.finiteDifferences
                for name=string(fieldnames(metadata)).', row.(name)=metadata.(name); end
                if isempty(finiteRows), finiteRows=row; else, finiteRows(end+1)=row; end %#ok<AGROW>
            end
            for row=r.comparison
                for name=string(fieldnames(metadata)).', row.(name)=metadata.(name); end
                row.surfacePressureMismatch=r.surfacePressureMismatch;
                if isempty(comparisonRows), comparisonRows=row; else, comparisonRows(end+1)=row; end %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table(finiteRows),fullfile(folder,'results','coefficient-tangent-convergence.csv'));
writetable(struct2table(comparisonRows),fullfile(folder,'results','coefficient-tangent-comparison.csv'));
end
