function tolerances = coefficientAbsoluteTolerances(~,~)
% Require the qualified fixed-step path until physical adaptive tolerances exist.
%
% Independent coefficient families have different units and energy weights.
% A common scalar coefficient tolerance is not a physical error contract.
%
% - Topic: Project physical sources
% - Declaration: tolerances = coefficientAbsoluteTolerances(absTolerance)
% - Returns tolerances: unavailable until adaptive stepping is qualified
tolerances = struct();
WVTransformFreeSurfaceBoussinesq.throwUnavailable('WVTransformFreeSurfaceBoussinesq:AdaptiveIntegrationUnavailable','Use setupIntegrator(integratorType="fixed",deltaT=...) for the qualified forced linear path. Adaptive family tolerances are not yet implemented.')
end
