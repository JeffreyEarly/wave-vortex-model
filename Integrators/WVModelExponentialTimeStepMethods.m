classdef WVModelExponentialTimeStepMethods < handle
    % Opt-in forward exponential stepping for balanced diffusion modes.
    %
    % Public transform coefficients always contain the total state.
    % Departures from the exact seasonal response are integrator-local.
    % Physical absolute tolerances are RMS q [s^-1], buoyancy [m s^-2],
    % horizontal speed [m s^-1], and endpoint displacement [m], in order.
    % Passive output observers are supported; other integrated observers
    % require a future coupled exponential/ordinary stepping interface.
    % Adaptive damping limits trial h*gammaMax to 1, with a 1.2 stage margin.
    % The independent advective CFL and physical-error checks are unchanged.
    %
    % - Topic: Exponential integration
    properties (Abstract, GetAccess = public, SetAccess = protected)
        wvt
        isDynamicsLinear
        fluxedObservingSystems
    end
    properties (Abstract)
        t
        finalIntegrationTime
    end
    methods (Abstract)
        times = outputTimesForIntegrationPeriod(self,initialTime,finalTime)
        showIntegrationStartDiagnostics(self,finalTime)
        showIntegrationTimeDiagnostics(self,finalTime)
        showIntegrationFinishDiagnostics(self)
        writeTimeStepToNetCDFFile(self,t)
        [F,speed] = explicitFlux(self)
    end
    properties (SetAccess = private)
        % Settings for the opt-in exponential integrator.
        % - Topic: Exponential integration
        exponentialOptions
        % Counts and accepted steps from the most recent integration.
        % - Topic: Exponential integration
        exponentialStatistics
        % Runtime density-diffusion integrator; canonical snapshots do not persist it.
        % - Topic: Exponential integration
        % - Developer: true
        densityDiffusionIntegrator = []
    end
    methods
        function setupExponentialTimeStepIntegrator(self,options)
            % Configure adaptive physical-norm ETDRK4 stepping.
            % - Topic: Exponential integration
            arguments
                self WVModel
                options.relTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-4
                options.physicalAbsTolerance (1,4) double {mustBePositive,mustBeFinite} = [1e-13 1e-11 1e-8 1e-8]
                options.initialStep (1,1) double {mustBePositive,mustBeFinite} = 3600
                options.maximumStep (1,1) double {mustBePositive,mustBeFinite} = 86400
                options.exponentialAdaptive (1,1) logical = true
            end
            self.assertExponentialConfiguration();
            self.densityDiffusionIntegrator=WVDensityDiffusionIntegrator(self.wvt);
            self.exponentialOptions=options;
        end

        function integrateToTimeWithExponentialTimeStep(self,finalTime)
            % Advance through the configured density-diffusion integrator.
            % - Topic: Exponential integration
            self.assertExponentialConfiguration();
            self.exponentialStatistics=self.densityDiffusionIntegrator.integrateToTime(self,finalTime,self.exponentialOptions);
        end
    end
    methods (Access = protected)
        function clearDensityDiffusionIntegrator(self)
            self.densityDiffusionIntegrator=[];
        end
    end
    methods (Access = private)
        function assertExponentialConfiguration(self)
            if ~isa(self.wvt,'WVTransformFreeSurfaceQG') || self.isDynamicsLinear
                error('WVModel:ExponentialTransformRequired','Use a canonical free-surface QG model with WVVerticalDiffusivity; remove nonlinear forcing for a diffusion-only run.');
            end
            if length(self.fluxedObservingSystems)~=1 || ~isa(self.fluxedObservingSystems(1),'WVCoefficients')
                error('WVModel:ExponentialObserverUnsupported','The exponential MVP integrates coefficients only; passive output observers are supported.');
            end
        end
    end
end
