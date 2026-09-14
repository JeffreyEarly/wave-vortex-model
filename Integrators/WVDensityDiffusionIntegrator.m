classdef WVDensityDiffusionIntegrator < handle
    % Integrate canonical free-surface QG with exact linear density diffusion.
    %
    % APV coefficients Ag_q and Ag_0, thermal coefficients Ath, and the shared horizontal-mean family Amda remain canonical and directly mutable. Diffusion eigencoordinates are square changes of basis local to each integration. Reattach explicitly after canonical snapshot restoration. Positive computed rates are reported, never clipped.
    %
    % APV transforms obtain diffusivity from WVVerticalDiffusivity; thermal transforms use their stored kappa_z.
    %
    % For an APV transform with both endpoints active:
    %
    % ```matlab
    % wvt.addForcing(WVVerticalDiffusivity(wvt,kappa_z=1e-5));
    % model = WVModel(wvt);
    % model.setupIntegrator(integratorType="exponential");
    % ```
    %
    % - Topic: Density diffusion integration
    % - Developer: true
    properties (SetAccess = private)
        % Canonical transform; both endpoints must be active.
        % - Topic: Density diffusion integration
        wvt
        % Galerkin operators, reconstruction arrays, and numerical diagnostics.
        % - Topic: Density diffusion integration
        operators
        % Packed homogeneous rates, including every MDA direction.
        % - Topic: Density diffusion integration
        rates
    end
    properties (Access = private)
        evolution_
        seasonalForcing_ = {}
        seasonalSource_ = {}
        seasonalSourceIndices_ = {}
        distinctRates_
        rateIndices_
    end
    methods
        function self = WVDensityDiffusionIntegrator(wvt,options)
            % Obtain exact eigencoordinates from the registered diffusion forcing.
            % - Topic: Density diffusion integration
            arguments
                wvt (1,1) WVTransform
                options.thermalLinearDynamics (1,1) logical = true
            end
            self.wvt=wvt;
            self.evolution_=WVInternal.qgEvolutionAdapter(wvt,options.thermalLinearDynamics);
            self.operators=self.evolution_.operators;
            self.rates=self.evolution_.rates;
            [self.distinctRates_,~,self.rateIndices_]=unique(self.rates);
            self.updateSeasonalSources();
        end

        function statistics = integrateToTime(self,model,finalTime,o)
            % Advance canonical coefficients with ETDRK4 and physical error control.
            % - Topic: Density diffusion integration
            arguments
                self WVDensityDiffusionIntegrator
                model WVModel
                finalTime (1,1) double {mustBeFinite}
                o (1,1) struct
            end
            if model.wvt~=self.wvt
                error('WV:DensityDiffusionTransformMismatch','The integrator and model must share a transform.');
            end
            if finalTime<=model.t || model.t<0
                error('WVModel:ExponentialTimeRange','Exponential integration requires forward evolution at nonnegative times.');
            end
            w=self.wvt;
            evolution=self;
            evolution.validateConfiguration();
            t=model.t;
            acceptedState=w.coefficientState();
            acceptedTotal=evolution.modalState();
            try
                times=model.outputTimesForIntegrationPeriod(t,finalTime);
                model.finalIntegrationTime=finalTime;
                model.showIntegrationStartDiagnostics(finalTime);
                model.writeTimeStepToNetCDFFile(t);
                nextOutput=2; state=acceptedTotal-evolution.seasonalCoefficients(t);
                h=min(o.initialStep,o.maximumStep);
                accepted=0; rejected=0; evaluations=0; outputEvaluations=0;
                stageDampingRate=0;
                steps=[]; maxCFL=0; maxDampingNumber=0; timer=tic;
                gridSize=min(w.Lx/w.Nx,w.Ly/w.Ny);
                while t<finalTime
                    h=min([h,finalTime-t,o.maximumStep]);
                    stageDampingRate=0;
                    [N0,speed]=rhs(state,t);
                    h=min(h,.5*gridSize/max(speed,realmin));
                    h=min(h,1/max(stageDampingRate,realmin));
                    c=evolution.exponentialCoefficients(h);
                    [whole,stageSpeed]=WVInternal.exponentialRK4Step(state,t,h,c,@rhs,N0,speed);
                    errorValue=0; trial=whole;
                    if o.exponentialAdaptive
                        halfC=evolution.exponentialCoefficients(h/2);
                        [half,s1]=WVInternal.exponentialRK4Step(state,t,h/2,halfC,@rhs,N0,speed);
                        [trial,s2]=WVInternal.exponentialRK4Step(half,t+h/2,h/2,halfC,@rhs);
                        stageSpeed=max([stageSpeed s1 s2]);
                        difference=evolution.physicalErrorNorms(trial-whole)/15;
                        normStart=state; normEnd=trial;
                        if self.evolution_.errorScaleUsesTotal
                            normStart=acceptedTotal;
                            normEnd=trial+evolution.seasonalCoefficients(t+h);
                        end
                        scale=o.physicalAbsTolerance+o.relTolerance*max(evolution.physicalErrorNorms(normStart),evolution.physicalErrorNorms(normEnd));
                        errorValue=max(difference./scale);
                    end
                    cfl=h*stageSpeed/gridSize;
                    dampingNumber=h*stageDampingRate;
                    finite=all(isfinite(trial),'all') && isfinite(errorValue);
                    accept=finite && errorValue<=1 && cfl<=.6 && dampingNumber<=1.2;
                    if accept
                        oldTime=t; oldState=state;
                        newTotal=trial+evolution.seasonalCoefficients(t+h);
                        newState=evolution.fromModes(newTotal);
                        t=t+h; state=trial; acceptedTotal=newTotal; acceptedState=newState;
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
                                    sampleC=evolution.exponentialCoefficients(sampleH/2);
                                    halfway=WVInternal.exponentialRK4Step(oldState,oldTime,sampleH/2,sampleC,@outputRHS);
                                    sample=WVInternal.exponentialRK4Step(halfway,oldTime+sampleH/2,sampleH/2,sampleC,@outputRHS);
                                else
                                    sampleC=evolution.exponentialCoefficients(sampleH);
                                    sample=WVInternal.exponentialRK4Step(oldState,oldTime,sampleH,sampleC,@outputRHS);
                                end
                            end
                            setState(sampleTime,sample+evolution.seasonalCoefficients(sampleTime));
                            model.writeTimeStepToNetCDFFile(sampleTime);
                            nextOutput=nextOutput+1;
                        end
                        restoreAccepted();
                        model.showIntegrationTimeDiagnostics(finalTime);
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
                statistics=struct(acceptedSteps=accepted,rejectedSteps=rejected,rhsEvaluations=evaluations,outputRhsEvaluations=outputEvaluations,acceptedStepSeconds=steps,maximumCFL=maxCFL,maximumDampingNumber=maxDampingNumber,wallSeconds=toc(timer));
                model.showIntegrationFinishDiagnostics();
                model.finalIntegrationTime=[];
            catch exception
                restoreAccepted();
                model.finalIntegrationTime=[];
                rethrow(exception)
            end

            function [value,s] = rhs(c,stageTime)
                setState(stageTime,c+evolution.seasonalCoefficients(stageTime));
                [tendency,s]=model.explicitFlux();
                value=tendency;
                stageDampingRate=max(stageDampingRate,evolution.maximumExplicitDampingRate(s));
                evaluations=evaluations+1;
            end
            function [value,s] = outputRHS(c,stageTime)
                setState(stageTime,c+evolution.seasonalCoefficients(stageTime));
                [tendency,s]=evolution.explicitCoefficientTendency(true);
                value=tendency;
                outputEvaluations=outputEvaluations+1;
            end
            function restoreAccepted()
                w.t=t;
                for name=reshape(string(fieldnames(acceptedState)),1,[]), w.(name)=acceptedState.(name); end
            end
            function setState(time,total)
                w.t=time;
                evolution.setModalState(total);
            end
        end

        function amplitudes = modalState(self)
            % Read current canonical properties in complete diffusion coordinates.
            % - Topic: Density diffusion integration
            amplitudes=self.toModes(self.wvt.coefficientState());
        end

        function setModalState(self,amplitudes)
            % Restore the canonical properties from integrator-local coordinates.
            % - Topic: Density diffusion integration
            state=self.fromModes(amplitudes);
            for name=reshape(string(fieldnames(state)),1,[]), self.wvt.(name)=state.(name); end
        end

        function amplitudes = toModes(self,state)
            % Transform a family-keyed state or tendency without losing rows.
            % - Topic: Density diffusion integration
            amplitudes=self.evolution_.toModes(state);
        end

        function state = fromModes(self,amplitudes)
            % Invert the complete modal coordinate change.
            % - Topic: Density diffusion integration
            state=self.evolution_.fromModes(amplitudes);
        end

        function amplitudes = seasonalCoefficients(self,t)
            % Exact zero-at-time-zero response to strict seasonal endpoint forcing.
            % - Topic: Density diffusion integration
            self.updateSeasonalSources();
            amplitudes=complex(zeros(size(self.rates)));
            for k=1:length(self.seasonalForcing_)
                force=self.seasonalForcing_{k}; omega=2*pi/force.period;
                indices=self.seasonalSourceIndices_{k};
                plus=harmonicIntegral(self.rates(indices),omega,t);
                minus=harmonicIntegral(self.rates(indices),-omega,t);
                response=(exp(1i*force.phase)*plus-exp(-1i*force.phase)*minus)/(2i);
                amplitudes(indices)=amplitudes(indices)+self.seasonalSource_{k}.*response;
            end
        end

        function [amplitudes,speed] = explicitCoefficientTendency(self,excludeSeasonal)
            % Evaluate registered forcings except those integrated analytically.
            % - Topic: Density diffusion integration
            self.updateSeasonalSources();
            excluded=strings(1,0);
            if excludeSeasonal
                for k=1:length(self.seasonalForcing_)
                    excluded(end+1)=string(self.seasonalForcing_{k}.name); %#ok<AGROW>
                end
            end
            [tendency,speed]=self.evolution_.explicitRHS(excluded);
            amplitudes=self.toModes(tendency);
        end

        function validateConfiguration(self)
            % Require setup again after replacing or changing the diffusion forcing.
            % - Topic: Density diffusion integration
            self.evolution_.validateConfiguration();
        end

        function norms = physicalErrorNorms(self,amplitudes)
            % Evaluate the owning transform's positive physical RMS norms.
            % - Topic: Density diffusion integration
            norms=self.evolution_.physicalErrorNorms(amplitudes);
        end

        function rate = maximumExplicitDampingRate(self,speed)
            % Sum forcing-owned explicit bounds at the current physical stage.
            % - Topic: Density diffusion integration
            rate=0;
            for name=reshape(self.wvt.forcingNames(),1,[])
                force=self.wvt.forcingWithName(name);
                contribution=force.maximumExplicitDampingRate(struct(uvMax=speed));
                if ~isscalar(contribution) || ~isreal(contribution) || ~isfinite(contribution) || contribution<0
                    error('WV:ExplicitDampingBound','Forcing %s must supply a finite nonnegative stability bound.',force.name);
                end
                rate=rate+contribution;
            end
        end
    end
    methods (Access = private)
        function c = exponentialCoefficients(self,h)
            % Evaluate repeated rates once, then restore packed state order.
            c=WVInternal.exponentialRK4Coefficients(self.distinctRates_,h);
            for name=string(fieldnames(c)).'
                c.(name)=c.(name)(self.rateIndices_);
            end
        end

        function updateSeasonalSources(self)
            self.validateConfiguration();
            forces={};
            for name=reshape(self.wvt.forcingNames(),1,[])
                force=self.wvt.forcingWithName(name);
                if isa(force,'WVSeasonalSurfaceAnomalyForcing')
                    forces{end+1}=force; %#ok<AGROW>
                end
            end
            if isequal(forces,self.seasonalForcing_), return; end
            sources=cell(size(forces)); indices=cell(size(forces)); w=self.wvt;
            for k=1:length(forces)
                Fb=zeros(w.Nx,w.Ny,numel(w.activeEndpoint));
                Fb(:,:,1)=forces{k}.amplitude*forces{k}.pattern;
                source=self.evolution_.projectSource(zeros(w.spatialMatrixSize),Fb);
                amplitudes=self.toModes(source);
                % Keep every nonzero entry, including Fourier roundoff tails.
                indices{k}=find(amplitudes~=0);
                sources{k}=amplitudes(indices{k});
            end
            self.seasonalForcing_=forces; self.seasonalSource_=sources;
            self.seasonalSourceIndices_=indices;
        end
    end
end

function value = harmonicIntegral(lambda,omega,t)
z=(lambda-1i*omega)*t;
ratio=ones(size(z)); nonzero=z~=0;
ratio(nonzero)=expm1(z(nonzero))./z(nonzero);
value=t*exp(1i*omega*t).*ratio;
end
