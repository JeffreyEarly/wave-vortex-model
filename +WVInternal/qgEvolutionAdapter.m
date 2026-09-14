function data=qgEvolutionAdapter(w,linearDynamics)
% Select one owner-specific adapter without changing either physical model.
% - Topic: Developer utilities
arguments
    w (1,1) WVTransform
    linearDynamics (1,1) logical
end
if isa(w,'WVTransformFreeSurfaceThermalQG')
    data=w.linearEvolutionData(); data.operators=[];
    data.explicitRHS=@explicitRHS;
    data.validateConfiguration=@validateConfiguration;
    data.errorScaleUsesTotal=true;
elseif isa(w,'WVTransformFreeSurfaceQG')
    data=WVInternal.apvLinearEvolutionData(w);
else
    error('WV:DensityDiffusionTransform','Supply an adiabatic or thermal free-surface QG transform.');
end
    function [tendency,speed]=explicitRHS(excluded)
        [tendency,speed]=w.coefficientTendency(linearDynamics=linearDynamics,excludingHomogeneousEvolution=true,excludingForcing=excluded);
    end
    function validateConfiguration()
        hasAdvection=any(arrayfun(@(force)isa(force,'WVNonlinearAdvection'),w.forcing));
        if hasAdvection==linearDynamics
            error('WV:ThermalLinearConflict','Nonlinear registration changed; configure the thermal linear/nonlinear integrator selection again.');
        end
    end
end
