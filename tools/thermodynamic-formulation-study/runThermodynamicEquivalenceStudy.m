function runThermodynamicEquivalenceStudy
% Reproduce the grid-level gate for issue #487; no modal pressure solve.
studyDirectory=fileparts(mfilename('fullpath'));
rows=struct([]);
for profile=["constant","exponential"]
    for amplitude=[1e-6,.01,1]
        for forced=[false,true]
            a=thermodynamicFormulationFixture(profile,amplitude,32,65);
            row=evaluateThermodynamicEquivalence(a,forced=forced);
            row.profile=profile; row.amplitude=amplitude; row.forced=forced;
            if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
        end
    end
end
writetable(struct2table(rows),fullfile(studyDirectory,'results','analytic.csv'));
rows=struct([]);
for grid=[4 8 16 32 64 128 128 128 128 128 128;129 129 129 129 129 5 9 17 33 65 129]
    a=thermodynamicFormulationFixture("exponential",1,grid(1),grid(2));
    row=evaluateThermodynamicEquivalence(a,numericalDerivatives=true);
    row.Nx=grid(1); row.Nz=grid(2);
    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
end
writetable(struct2table(rows),fullfile(studyDirectory,'results','refinement.csv'));
end
