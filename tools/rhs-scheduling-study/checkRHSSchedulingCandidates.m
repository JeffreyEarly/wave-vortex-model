function checkRHSSchedulingCandidates(folder)
% Verify preserved authoring candidates and ordinary pressure/cache behavior.
for profile=["constant","exponential"]
    data=load(fullfile(folder,profile+"-1.mat"));
    reference=RHSSchedulingReference(data.scientificState);
    for name=string(fieldnames(data.initial)).', reference.(name)=data.initial.(name); end
    reference.t=327;
    [expected.u,expected.v,expected.w,expected.eta]=reference.nonlinearAdvectionSources();
    pressure=reference.reconstructFields("p");
    for strategy=["baseline","setup","source","spectral","combined","state","stateSource"]
        w=RHSSchedulingCandidate(data.scientificState,strategy);
        for name=string(fieldnames(data.initial)).', w.(name)=data.initial.(name); end
        w.t=327;
        for pass=1:3
            [actual.u,actual.v,actual.w,actual.eta]=w.nonlinearAdvectionSources();
            for name=["u","v","w","eta"]
                assert(max(abs(actual.(name)-expected.(name)),[],'all')<=3e-10*max(abs(expected.(name)),[],'all')+1e-17);
            end
            if pass==1
                if any(strategy==["spectral","combined"]), assert(~isKey(w.variableCache,'p')); end
                assert(isequal(w.reconstructFields("p"),pressure));
            end
        end
    end
end
fprintf('All preserved candidates passed cold, pressure-overlap, and warm source checks.\n');
end
