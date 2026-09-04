classdef WVDensityDiffusionIntegrator < handle
    % Integrate canonical free-surface QG with exact linear density diffusion.
    %
    % Accepted and trial coordinates are local to each integration. The transform's
    % Ag_q, Ag_0, and Amda remain directly mutable and persist unchanged.
    % Diffusion coordinates are square changes of basis, packed only for the
    % integrator. Reattach explicitly after canonical snapshot restoration.
    % Positive computed rates are reported, never clipped.
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
        diffusionForcing_
        columnGroups_
        balancedShape_
        balancedCount_
        seasonalForcing_ = {}
        seasonalSource_ = {}
    end
    methods
        function self = WVDensityDiffusionIntegrator(wvt)
            % Obtain exact eigencoordinates from the registered diffusion forcing.
            % - Topic: Density diffusion integration
            arguments
                wvt (1,1) WVTransformFreeSurfaceQG
            end
            self.wvt=wvt;
            if ~any(wvt.forcingNames()=="vertical diffusivity")
                error('WV:DensityDiffusionForcingRequired','Register WVVerticalDiffusivity before selecting exponential integration.');
            end
            self.diffusionForcing_=wvt.forcingWithName('vertical diffusivity');
            if ~isa(self.diffusionForcing_,'WVVerticalDiffusivity')
                error('WV:DensityDiffusionForcingRequired','Exponential integration requires WVVerticalDiffusivity.');
            end
            self.operators=self.diffusionForcing_.densityDiffusionModes();
            self.balancedShape_=[wvt.apvModeCount+wvt.activeEndpointCount,length(wvt.klNonzero)];
            self.balancedCount_=prod(self.balancedShape_);
            lambda=zeros(self.balancedShape_);
            self.columnGroups_=cell(length(wvt.khUnique),1);
            for p=1:length(wvt.khUnique)
                columns=find(wvt.klNonzeroKhUniqueIndex==p);
                self.columnGroups_{p}=columns;
                lambda(:,columns)=repmat(self.operators.pages{p}.rates,1,length(columns));
            end
            self.rates=[lambda(:);self.operators.mda.rates];
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
            acceptedTotal=evolution.modalState();
            try
                times=model.outputTimesForIntegrationPeriod(t,finalTime);
                model.finalIntegrationTime=finalTime;
                model.showIntegrationStartDiagnostics(finalTime);
                model.writeTimeStepToNetCDFFile(t);
                nextOutput=2; state=acceptedTotal-evolution.seasonalCoefficients(t);
                % Evaluate time functions once per kh, then expand weights.
                lambda=evolution.rates; columnIndices=1;
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
                evaluations=evaluations+1;
            end
            function [value,s] = outputRHS(c,stageTime)
                setState(stageTime,c+evolution.seasonalCoefficients(stageTime));
                [tendency,s]=evolution.explicitCoefficientTendency(true);
                value=tendency;
                outputEvaluations=outputEvaluations+1;
            end
            function restoreAccepted()
                setState(t,acceptedTotal);
            end
            function setState(time,total)
                w.t=time;
                evolution.setModalState(total);
            end
        end

        function amplitudes = modalState(self)
            % Read current canonical properties in complete diffusion coordinates.
            % - Topic: Density diffusion integration
            w=self.wvt;
            amplitudes=self.toModes(struct(Ag_q=w.Ag_q,Ag_0=w.Ag_0,Amda=w.Amda));
        end

        function setModalState(self,amplitudes)
            % Restore the canonical properties from integrator-local coordinates.
            % - Topic: Density diffusion integration
            state=self.fromModes(amplitudes);
            self.wvt.Ag_q=state.Ag_q; self.wvt.Ag_0=state.Ag_0; self.wvt.Amda=state.Amda;
        end

        function amplitudes = toModes(self,state)
            % Transform a family-keyed state or tendency without losing rows.
            % - Topic: Density diffusion integration
            balanced=[state.Ag_q;state.Ag_0];
            transformed=complex(zeros(self.balancedShape_));
            for p=1:length(self.columnGroups_)
                columns=self.columnGroups_{p};
                transformed(:,columns)=self.operators.pages{p}.toModes*balanced(:,columns);
            end
            amplitudes=[transformed(:);self.operators.mda.toModes*state.Amda];
        end

        function state = fromModes(self,amplitudes)
            % Invert the complete modal coordinate change.
            % - Topic: Density diffusion integration
            if ~iscolumn(amplitudes) || length(amplitudes)~=length(self.rates) || any(~isfinite(amplitudes))
                error('WV:DensityDiffusionState','Supply one finite packed diffusion-coordinate column.');
            end
            transformed=reshape(amplitudes(1:self.balancedCount_),self.balancedShape_);
            balanced=complex(zeros(self.balancedShape_));
            for p=1:length(self.columnGroups_)
                columns=self.columnGroups_{p};
                balanced(:,columns)=self.operators.pages{p}.fromModes*transformed(:,columns);
            end
            meanState=self.operators.mda.fromModes*amplitudes(self.balancedCount_+1:end);
            if norm(imag(meanState))>1e-12*max(norm(meanState),realmin)
                error('WV:DensityDiffusionMeanReality','MDA coordinates must reconstruct a real horizontal mean.');
            end
            n=self.wvt.apvModeCount;
            state=struct(Ag_q=balanced(1:n,:),Ag_0=balanced(n+1:end,:),Amda=real(meanState));
        end

        function amplitudes = seasonalCoefficients(self,t)
            % Exact zero-at-time-zero response to strict seasonal endpoint forcing.
            % - Topic: Density diffusion integration
            self.updateSeasonalSources();
            amplitudes=complex(zeros(size(self.rates)));
            for k=1:length(self.seasonalForcing_)
                force=self.seasonalForcing_{k}; omega=2*pi/force.period;
                plus=harmonicIntegral(self.rates,omega,t);
                minus=harmonicIntegral(self.rates,-omega,t);
                response=(exp(1i*force.phase)*plus-exp(-1i*force.phase)*minus)/(2i);
                amplitudes=amplitudes+self.seasonalSource_{k}.*response;
            end
        end

        function [amplitudes,speed] = explicitCoefficientTendency(self,excludeSeasonal)
            % Evaluate registered forcings except those integrated analytically.
            % - Topic: Density diffusion integration
            self.updateSeasonalSources();
            excluded=string(self.diffusionForcing_.name);
            if excludeSeasonal
                for k=1:length(self.seasonalForcing_)
                    excluded(end+1)=string(self.seasonalForcing_{k}.name); %#ok<AGROW>
                end
            end
            [tendency,speed]=self.wvt.coefficientTendency(excludingForcing=excluded);
            amplitudes=self.toModes(tendency);
        end

        function validateConfiguration(self)
            % Require setup again after replacing or changing the diffusion forcing.
            % - Topic: Density diffusion integration
            names=self.wvt.forcingNames();
            force=self.diffusionForcing_;
            if ~any(names==string(force.name)) || self.wvt.forcingWithName(force.name)~=force || ...
                    force.kappa_z~=self.operators.kappa_z || ...
                    force.shouldForceMeanDensityAnomaly~=self.operators.shouldForceMeanDensityAnomaly
                error('WV:DensityDiffusionConfigurationChanged','Density diffusion changed; call model.setupIntegrator(integratorType="exponential") again.');
            end
        end

        function norms = physicalErrorNorms(self,amplitudes)
            % RMS full QGPV, buoyancy, speed, and active-endpoint displacement.
            % Includes MDA means; compact nonzero Fourier entries count twice.
            % - Topic: Density diffusion integration
            state=self.fromModes(amplitudes); balanced=[state.Ag_q;state.Ag_0];
            weights=self.operators.weights/self.wvt.Lz;
            variance=zeros(1,4);
            for p=1:length(self.columnGroups_)
                a=balanced(:,self.columnGroups_{p}); r=self.operators.reconstruction{p};
                variance=variance+2*[sum(weights.*abs(r.q*a).^2,'all'), ...
                    sum(weights.*abs(r.buoyancy*a).^2,'all'), ...
                    self.wvt.khUnique(p)^2*sum(weights.*abs(r.phi*a).^2,'all'),sum(abs(r.endpoint*a).^2,'all')];
            end
            r=self.operators.mda.reconstruction; a=state.Amda;
            variance=variance+[sum(weights.*abs(r.q*a).^2),sum(weights.*abs(r.buoyancy*a).^2),0,sum(abs(r.endpoint*a).^2)];
            norms=sqrt(variance);
        end

        function rate = maximumExplicitDampingRate(self,speed)
            % Bound existing parent-transform damping without changing its strength.
            % - Topic: Density diffusion integration
            rate=0;
            for name=reshape(self.wvt.forcingNames(),1,[])
                force=self.wvt.forcingWithName(name);
                if isa(force,'WVAdaptiveDamping')
                    rate=rate+speed*max(abs([force.dampAg_q(:);force.dampAg_0(:)]));
                end
            end
        end
    end
    methods (Access = private)
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
            sources=cell(size(forces)); w=self.wvt;
            for k=1:length(forces)
                Fb=zeros(w.Nx,w.Ny,w.activeEndpointCount);
                Fb(:,:,1)=forces{k}.amplitude*forces{k}.pattern;
                source=w.projectQuasigeostrophicSpatialTendency(zeros(w.spatialMatrixSize),Fb);
                sources{k}=self.toModes(source);
            end
            self.seasonalForcing_=forces; self.seasonalSource_=sources;
        end
    end
end

function value = harmonicIntegral(lambda,omega,t)
z=(lambda-1i*omega)*t;
ratio=ones(size(z)); nonzero=z~=0;
ratio(nonzero)=expm1(z(nonzero))./z(nonzero);
value=t*exp(1i*omega*t).*ratio;
end
