classdef WVWeakThermalEvolution < handle
    % Opt-in weak diffusion coordinates for a canonical free-surface state.
    %
    % This developmental adapter owns no coefficient state. The transform's
    % Ag_q, Ag_0, and Amda remain directly mutable and persist unchanged.
    % Thermal coordinates are square changes of basis, packed only for the
    % integrator. Reattach explicitly after canonical snapshot restoration.
    % Positive computed rates are reported, never clipped.
    %
    % - Topic: Developmental thermal evolution
    % - Developer: true
    properties (SetAccess = private)
        % Canonical transform; both endpoints must be active.
        % - Topic: Developmental thermal evolution
        wvt
        % Weak operators, reconstruction arrays, and numerical diagnostics.
        % - Topic: Developmental thermal evolution
        operators
        % Packed homogeneous rates, including every MDA direction.
        % - Topic: Developmental thermal evolution
        rates
    end
    properties (Access = private)
        columnGroups_
        balancedShape_
        balancedCount_
        seasonalForcing_ = {}
        seasonalSource_ = {}
    end
    methods
        function self = WVWeakThermalEvolution(wvt,kappaT,options)
            % Build solely from the transform's sampled, persisted arrays.
            % - Topic: Developmental thermal evolution
            arguments
                wvt (1,1) WVTransformFreeSurfaceQG
                kappaT (1,1) double {mustBeNonnegative,mustBeFinite}
                options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = max(129,2*wvt.Nz+1)
            end
            self.wvt=wvt;
            self.operators=WVInternal.weakThermalOperators(wvt,kappaT,quadratureCount=options.quadratureCount);
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

        function amplitudes = modalState(self)
            % Read current canonical properties in complete thermal coordinates.
            % - Topic: Developmental thermal evolution
            w=self.wvt;
            amplitudes=self.toModes(struct(Ag_q=w.Ag_q,Ag_0=w.Ag_0,Amda=w.Amda));
        end

        function setModalState(self,amplitudes)
            % Restore the canonical properties from integrator-local coordinates.
            % - Topic: Developmental thermal evolution
            state=self.fromModes(amplitudes);
            self.wvt.Ag_q=state.Ag_q; self.wvt.Ag_0=state.Ag_0; self.wvt.Amda=state.Amda;
        end

        function amplitudes = toModes(self,state)
            % Transform a family-keyed state or tendency without losing rows.
            % - Topic: Developmental thermal evolution
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
            % - Topic: Developmental thermal evolution
            if ~iscolumn(amplitudes) || length(amplitudes)~=length(self.rates) || any(~isfinite(amplitudes))
                error('WV:WeakThermalState','Supply one finite packed thermal-coordinate column.');
            end
            transformed=reshape(amplitudes(1:self.balancedCount_),self.balancedShape_);
            balanced=complex(zeros(self.balancedShape_));
            for p=1:length(self.columnGroups_)
                columns=self.columnGroups_{p};
                balanced(:,columns)=self.operators.pages{p}.fromModes*transformed(:,columns);
            end
            meanState=self.operators.mda.fromModes*amplitudes(self.balancedCount_+1:end);
            if norm(imag(meanState))>1e-12*max(norm(meanState),realmin)
                error('WV:WeakThermalMeanReality','MDA coordinates must reconstruct a real horizontal mean.');
            end
            n=self.wvt.apvModeCount;
            state=struct(Ag_q=balanced(1:n,:),Ag_0=balanced(n+1:end,:),Amda=real(meanState));
        end

        function amplitudes = seasonalCoefficients(self,t)
            % Exact zero-at-time-zero response to strict seasonal endpoint forcing.
            % - Topic: Developmental thermal evolution
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

        function [amplitudes,speed] = nonthermalCoefficientTendency(self,excludeSeasonal)
            % Use existing WVForcing projection, optionally removing exact sources.
            % - Topic: Developmental thermal evolution
            self.updateSeasonalSources();
            amplitudes=self.toModes(self.wvt.coefficientTendency());
            if excludeSeasonal
                for k=1:length(self.seasonalForcing_)
                    force=self.seasonalForcing_{k};
                    amplitudes=amplitudes-self.seasonalSource_{k}*sin(2*pi*self.wvt.t/force.period+force.phase);
                end
            end
            speed=self.wvt.uvMax;
        end

        function norms = physicalErrorNorms(self,amplitudes)
            % RMS full QGPV, buoyancy, speed, and active-endpoint displacement.
            % Includes MDA means; compact nonzero Fourier entries count twice.
            % - Topic: Developmental thermal evolution
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
            % - Topic: Developmental thermal evolution
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
            forces={};
            for name=reshape(self.wvt.forcingNames(),1,[])
                force=self.wvt.forcingWithName(name);
                if isa(force,'WVVerticalDiffusivity')
                    error('WV:WeakThermalDoubleDiffusion','Remove WVVerticalDiffusivity before using weak thermal evolution.');
                elseif isa(force,'WVSeasonalSurfaceAnomalyForcing')
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
