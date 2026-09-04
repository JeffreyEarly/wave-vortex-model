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
        [F,speed] = nonthermalFlux(self)
    end
    properties (SetAccess = private)
        % Settings for the opt-in exponential integrator.
        % - Topic: Exponential integration
        exponentialOptions
        % Counts and accepted steps from the most recent integration.
        % - Topic: Exponential integration
        exponentialStatistics
        % Explicit developmental adapter; canonical snapshots do not persist it.
        % - Topic: Exponential integration
        % - Developer: true
        weakThermalEvolution = []
    end
    methods
        function setupWeakThermalIntegrator(self,kappaT,options)
            % Opt into weak diffusion on the unchanged APV/zero-APV/MDA state.
            % Reapply this choice explicitly after restoring a canonical snapshot.
            % - Topic: Exponential integration
            % - Developer: true
            arguments
                self WVModel
                kappaT (1,1) double {mustBeNonnegative,mustBeFinite}
                options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = max(129,2*self.wvt.Nz+1)
                options.relTolerance (1,1) double {mustBePositive,mustBeFinite} = 1e-4
                options.physicalAbsTolerance (1,4) double {mustBePositive,mustBeFinite} = [1e-13 1e-11 1e-8 1e-8]
                options.initialStep (1,1) double {mustBePositive,mustBeFinite} = 3600
                options.maximumStep (1,1) double {mustBePositive,mustBeFinite} = 86400
                options.exponentialAdaptive (1,1) logical = true
            end
            self.assertExponentialConfiguration(true);
            evolution=WVWeakThermalEvolution(self.wvt,kappaT,quadratureCount=options.quadratureCount);
            previous=self.weakThermalEvolution;
            self.weakThermalEvolution=evolution;
            try
                args=namedargs2cell(rmfield(options,'quadratureCount'));
                self.setupIntegrator(args{:},integratorType="exponential");
            catch exception
                self.weakThermalEvolution=previous;
                rethrow(exception)
            end
        end

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
            self.exponentialOptions=options;
        end

        function integrateToTimeWithExponentialTimeStep(self,finalTime)
            % Evolve departures, sampling outputs without changing the trajectory.
            % - Topic: Exponential integration
            arguments
                self WVModel
                finalTime (1,1) double {mustBeFinite}
            end
            self.assertExponentialConfiguration();
            if finalTime<=self.t || self.t<0
                error('WVModel:ExponentialTimeRange','Exponential integration requires forward evolution at nonnegative times.');
            end
            w=self.wvt; o=self.exponentialOptions;
            evolution=w; isWeak=~isempty(self.weakThermalEvolution);
            if isWeak, evolution=self.weakThermalEvolution; end
            t=self.t;
            if isWeak, acceptedTotal=evolution.modalState(); else, acceptedTotal=w.Ag_T; end
            try
                times=self.outputTimesForIntegrationPeriod(t,finalTime);
                self.finalIntegrationTime=finalTime;
                self.showIntegrationStartDiagnostics(finalTime);
                if self.shouldShowIntegrationDiagnostics && ~isWeak
                    if ~isempty(w.verticalNumerics), quadratureCount=length(w.verticalNumerics.zQuadrature); else, quadratureCount=0; end
                    dampingNames=w.forcingNames(); hasDamping=any(dampingNames=="adaptive damping"); verticalStrength=0;
                    if hasDamping, damping=w.forcingWithName('adaptive damping'); verticalStrength=damping.verticalDampingStrength; end
                    fprintf('QG numerics: horizontal dealiasing %d; vertical dealiasing %d (%d quadrature nodes); adaptive horizontal damping %d; vertical strength %.3g.\n',w.shouldAntialias,w.shouldDealiasVertical,quadratureCount,hasDamping,verticalStrength);
                end
                self.writeTimeStepToNetCDFFile(t);
                nextOutput=2; state=acceptedTotal-evolution.seasonalCoefficients(t);
                % Evaluate time functions once per kh, then expand weights.
                if isWeak
                    lambda=evolution.rates; columnIndices=1;
                else
                    lambda=-w.thermalDecayRate; columnIndices=w.klNonzeroKhUniqueIndex;
                end
                h=min(o.initialStep,o.maximumStep);
                accepted=0; rejected=0; evaluations=0; outputEvaluations=0;
                steps=[]; maxCFL=0; maxDampingNumber=0; timer=tic;
                gridSize=min(w.Lx/w.Nx,w.Ly/w.Ny);
                while t<finalTime
                    h=min([h,finalTime-t,o.maximumStep]);
                    [N0,speed]=rhs(state,t);
                    h=min(h,.5*gridSize/max(speed,realmin));
                    h=min(h,1/max(evolution.maximumExplicitDampingRate(speed),realmin));
                    c=WVInternal.exponentialRK4Coefficients(lambda,h,columnIndices);
                    [whole,stageSpeed]=WVInternal.exponentialRK4Step(state,t,h,c,@rhs,N0,speed);
                    errorValue=0; trial=whole;
                    if o.exponentialAdaptive
                        halfC=WVInternal.exponentialRK4Coefficients(lambda,h/2,columnIndices);
                        [half,s1]=WVInternal.exponentialRK4Step(state,t,h/2,halfC,@rhs,N0,speed);
                        [trial,s2]=WVInternal.exponentialRK4Step(half,t+h/2,h/2,halfC,@rhs);
                        stageSpeed=max([stageSpeed s1 s2]);
                        difference=evolution.physicalErrorNorms(trial-whole)/15;
                        scale=o.physicalAbsTolerance+o.relTolerance*max(evolution.physicalErrorNorms(state),evolution.physicalErrorNorms(trial));
                        errorValue=max(difference./scale);
                    end
                    cfl=h*stageSpeed/gridSize;
                    dampingNumber=h*evolution.maximumExplicitDampingRate(stageSpeed);
                    finite=all(isfinite(trial),'all') && isfinite(errorValue);
                    accept=finite && errorValue<=1 && cfl<=.6 && dampingNumber<=1.2;
                    if accept
                        oldTime=t; oldState=state;
                        t=t+h; state=trial; acceptedTotal=state+evolution.seasonalCoefficients(t);
                        accepted=accepted+1; steps(end+1)=h; %#ok<AGROW>
                        maxCFL=max(maxCFL,cfl);
                        maxDampingNumber=max(maxDampingNumber,dampingNumber);
                        while nextOutput<=length(times) && times(nextOutput)<=t
                            sampleTime=times(nextOutput);
                            if sampleTime==t
                                sample=state;
                            else
                                sampleH=sampleTime-oldTime;
                                if o.exponentialAdaptive
                                    sampleC=WVInternal.exponentialRK4Coefficients(lambda,sampleH/2,columnIndices);
                                    halfway=WVInternal.exponentialRK4Step(oldState,oldTime,sampleH/2,sampleC,@outputRHS);
                                    sample=WVInternal.exponentialRK4Step(halfway,oldTime+sampleH/2,sampleH/2,sampleC,@outputRHS);
                                else
                                    sampleC=WVInternal.exponentialRK4Coefficients(lambda,sampleH,columnIndices);
                                    sample=WVInternal.exponentialRK4Step(oldState,oldTime,sampleH,sampleC,@outputRHS);
                                end
                            end
                            setState(sampleTime,sample+evolution.seasonalCoefficients(sampleTime));
                            self.writeTimeStepToNetCDFFile(sampleTime);
                            nextOutput=nextOutput+1;
                        end
                        restoreAccepted();
                        self.showIntegrationTimeDiagnostics(finalTime);
                    else
                        rejected=rejected+1;
                        restoreAccepted();
                    end
                    if o.exponentialAdaptive
                        factor=min(2,max(.2,.9*max(errorValue,1e-12)^(-1/5)));
                        if cfl>.6, factor=min(factor,.5/cfl); end
                        if dampingNumber>1.2, factor=min(factor,1/dampingNumber); end
                        if ~accept, factor=min(.8,factor); end
                        h=h*factor;
                    elseif accept
                        h=min(o.initialStep,o.maximumStep);
                    else
                        h=h/2;
                    end
                    if h<1e-6 || rejected>2000 || accepted>1000000
                        error('WVModel:ExponentialStepLimit','Exponential integration cannot progress safely; inspect the state and physical tolerances.');
                    end
                end
                restoreAccepted();
                self.exponentialStatistics=struct(acceptedSteps=accepted,rejectedSteps=rejected,rhsEvaluations=evaluations,outputRhsEvaluations=outputEvaluations,acceptedStepSeconds=steps,maximumCFL=maxCFL,maximumDampingNumber=maxDampingNumber,wallSeconds=toc(timer));
                self.showIntegrationFinishDiagnostics();
                self.finalIntegrationTime=[];
            catch exception
                restoreAccepted();
                self.finalIntegrationTime=[];
                rethrow(exception)
            end

            function [value,s] = rhs(c,stageTime)
                setState(stageTime,c+evolution.seasonalCoefficients(stageTime));
                [tendency,s]=self.nonthermalFlux();
                if isWeak, value=tendency; else, value=tendency.Ag_T; end
                evaluations=evaluations+1;
            end
            function [value,s] = outputRHS(c,stageTime)
                setState(stageTime,c+evolution.seasonalCoefficients(stageTime));
                [tendency,s]=evolution.nonthermalCoefficientTendency(true);
                if isWeak, value=tendency; else, value=tendency.Ag_T; end
                outputEvaluations=outputEvaluations+1;
            end
            function restoreAccepted()
                setState(t,acceptedTotal);
            end
            function setState(time,total)
                w.t=time;
                if isWeak, evolution.setModalState(total); else, w.Ag_T=total; end
            end
        end
    end
    methods (Access = private)
        function assertExponentialConfiguration(self,allowWeakSetup)
            arguments
                self WVModel
                allowWeakSetup (1,1) logical = false
            end
            isWeak=~isempty(self.weakThermalEvolution) && self.weakThermalEvolution.wvt==self.wvt;
            isWeak=isWeak || (allowWeakSetup && isa(self.wvt,'WVTransformFreeSurfaceQG'));
            if (~isa(self.wvt,'WVTransformFreeSurfaceQGDiffusion') && ~isWeak) || self.isDynamicsLinear
                error('WVModel:ExponentialTransformRequired','Use the diffusion transform in a normal WVModel; remove nonlinear forcing for a purely thermal run.');
            end
            if length(self.fluxedObservingSystems)~=1 || ~isa(self.fluxedObservingSystems(1),'WVCoefficients')
                error('WVModel:ExponentialObserverUnsupported','The exponential MVP integrates coefficients only; passive output observers are supported.');
            end
        end
    end
end
