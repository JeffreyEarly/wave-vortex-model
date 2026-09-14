function results=qualifyThermalForcing(outputDirectory)
% Qualify short nonlinear source/drag controls under time refinement.
% Run with the pinned OceanKit path configured; this is authoring-only code.
arguments
    outputDirectory (1,1) string = "Documentation/Validation/Issue436"
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'UnitTests','Fixtures'));
steps=[2000 1000 500]; rows=struct('inverseScale',{},'mechanism',{},'coarseError',{},'fineError',{},'energy',{});
controls=struct('inverseScale',{},'omitted',{},'qEffect',{},'buoyancyEffect',{},'speedEffect',{},'surfaceEffect',{},'bottomEffect',{});
for a=[0 1/1300]
    w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[16 16 65],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4,kappa_z=1e-5,shouldCheckQuadraticAliasing=true);
    thermalManufacturedState(w,[2 3 4],10000); seed=w.coefficientState(); finals=cell(4,3); energies=zeros(4,3);
    for mechanism=0:3
        for i=1:3
            r=WVTransformFreeSurfaceThermalQG(scientificState=w.scientificState,coefficientState=seed);
            r.addForcing(WVNonlinearAdvection(r));
            if bitand(mechanism,1)
                r.addForcing(WVSeasonalSurfaceAnomalyForcing(r,pattern=repmat(sin(2*pi*r.y'/r.Ly),r.Nx,1),amplitude=1e-5,period=1e5,phase=.7));
            end
            if bitand(mechanism,2), r.addForcing(WVBottomFrictionQuadratic(r,Cd=1e-3)); end
            model=WVModel(r); model.setupIntegrator(integratorType="exponential",initialStep=steps(i),maximumStep=steps(i),exponentialAdaptive=false);
            model.integrateToTime(20000,shouldShowIntegrationDiagnostics=false);
            finals{mechanism+1,i}=r.coefficientState(); energies(mechanism+1,i)=r.totalEnergy;
        end
    end
    evolution=w.linearEvolutionData(); normScale=evolution.physicalErrorNorms(evolution.toModes(seed));
    for mechanism=0:3
        reference=finals{mechanism+1,3}; delta=reference; errors=zeros(2,5);
        for i=1:2
            delta.Ath=finals{mechanism+1,i}.Ath-reference.Ath; delta.Amda=finals{mechanism+1,i}.Amda-reference.Amda;
            errors(i,:)=evolution.physicalErrorNorms(evolution.toModes(delta))./max(normScale,1e-15);
        end
        assert(max(errors(2,:))<1e-5,'T5 fine trajectory error exceeds 1e-5 physical relative budget.');
        assert(max(errors(2,:))<max(2e-11,max(errors(1,:))/4),'T5 refinement failed to decrease by four.');
        rows(end+1)=struct(inverseScale=a,mechanism=mechanism,coarseError=max(errors(1,:)),fineError=max(errors(2,:)),energy=energies(mechanism+1,3)); %#ok<AGROW>
    end
    combined=finals{4,3};
    for omitted=1:2
        other=finals{4-omitted,3}; delta=struct(Ath=combined.Ath-other.Ath,Amda=combined.Amda-other.Amda);
        effect=evolution.physicalErrorNorms(evolution.toModes(delta))./max(normScale,1e-15);
        assert(max(effect)>1e-6,'T5 omission did not change a relevant observable.');
        controls(end+1)=struct(inverseScale=a,omitted=omitted,qEffect=effect(1),buoyancyEffect=effect(2),speedEffect=effect(3),surfaceEffect=effect(4),bottomEffect=effect(5)); %#ok<AGROW>
    end
end
results=struct(trajectories=struct2table(rows),omissions=struct2table(controls));
writetable(results.trajectories,fullfile(outputDirectory,'time-refinement.csv'));
writetable(results.omissions,fullfile(outputDirectory,'mechanism-omissions.csv'));
disp(results.trajectories); disp(results.omissions);
end
