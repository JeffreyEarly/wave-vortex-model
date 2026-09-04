classdef WVSeasonalSurfaceAnomalyForcing < WVForcing
    % Force surface displacement without a direct interior QGPV source.
    %
    % The imposed tendency is b0_t = amplitude*pattern*sin(omega*t+phase).
    % b0 is an endpoint displacement in meters, not physical buoyancy.
    % The corresponding buoyancy tendency is -N2(0)*b0_t. This is not a
    % weak buoyancy-flux load and has no surface quadrature-weight factor.
    %
    % ```matlab
    % force = WVSeasonalSurfaceAnomalyForcing(wvt,pattern=sin(10*pi*wvt.Y(:,:,1)/wvt.Ly),amplitude=1e-7);
    % wvt.addForcing(force);
    % ```
    %
    % - Topic: Create the forcing
    % - Topic: Inspect forcing configuration
    % - Topic: Implement forcing evaluation
    % - Topic: Forcing persistence
    properties (SetAccess = private)
        % Dimensionless horizontal pattern; required, zero mean for diffusion MVP.
        % - Topic: Inspect forcing configuration
        pattern
        % Endpoint displacement tendency amplitude in meters per second.
        % - Topic: Inspect forcing configuration
        amplitude
        % Seasonal period in seconds.
        % - Topic: Inspect forcing configuration
        period
        % Phase at time zero in radians.
        % - Topic: Inspect forcing configuration
        phase
    end
    properties (Access = private, Transient)
        modalSource_
    end
    methods
        function self = WVSeasonalSurfaceAnomalyForcing(wvt,options)
            % Create strict seasonal endpoint forcing.
            % - Topic: Create the forcing
            arguments
                wvt (1,1) WVTransform
                options.pattern double {mustBeReal,mustBeFinite}
                options.amplitude (1,1) double {mustBeReal,mustBeFinite}
                options.period (1,1) double {mustBePositive,mustBeFinite} = 365.25*86400
                options.phase (1,1) double {mustBeReal,mustBeFinite} = 0
            end
            if ~isa(wvt,'WVTransformFreeSurfaceQGDiffusion') && ~isa(wvt,'WVTransformFreeSurfaceQG')
                error('WVSeasonalSurfaceAnomalyForcing:UnsupportedTransform','Use a free-surface QG transform.');
            end
            if ~isequal(size(options.pattern),[wvt.Nx wvt.Ny]) || ~any(wvt.activeEndpoint==1)
                error('WVSeasonalSurfaceAnomalyForcing:InvalidPattern','Supply an Nx-by-Ny pattern and an active surface.');
            end
            if abs(mean(options.pattern,'all')) > 1e-12*max(max(abs(options.pattern),[],'all'),realmin)
                error('WVSeasonalSurfaceAnomalyForcing:MeanUnsupported','A nonzero pattern mean requires an MDA source implementation.');
            end
            self@WVForcing(wvt,'seasonal surface anomaly',WVForcingType('QGSpatial'));
            self.pattern=options.pattern; self.amplitude=options.amplitude;
            self.period=options.period; self.phase=options.phase;
            if isa(wvt,'WVTransformFreeSurfaceQGDiffusion')
                b=zeros(wvt.activeEndpointCount,length(wvt.klNonzero));
                b(1,:)=wvt.spectralField(self.amplitude*self.pattern);
                self.modalSource_=wvt.transformStateForward(zeros(wvt.Nz-2,length(wvt.klNonzero)),b);
            end
        end
        function [Fq,Fb] = addQuasigeostrophicSpatialForcing(self,wvt,Fq,Fb,~)
            % Add only the prescribed surface endpoint tendency.
            % - Topic: Implement forcing evaluation
            i=find(wvt.activeEndpoint==1,1);
            Fb(:,:,i)=Fb(:,:,i)+self.amplitude*sin(2*pi*wvt.t/self.period+self.phase)*self.pattern;
        end
        function amplitudes = exactThermalResponse(self,wvt,t)
            % Evaluate the zero-at-time-zero sinusoidal thermal response.
            % The full complex Fourier source is multiplied by a real-time
            % harmonic integral, never by a real-part operation on itself.
            % - Topic: Implement forcing evaluation

            % Time dependence is shared by every Fourier entry at this kh.
            % Expand only after evaluation; modalSource_ keeps its complete
            % complex Fourier pattern, including roundoff-sized entries.
            lambda=-wvt.thermalDecayRate; omega=2*pi/self.period;
            plus=harmonicIntegral(lambda,omega,t);
            minus=harmonicIntegral(lambda,-omega,t);
            response=exp(1i*self.phase)*plus-exp(-1i*self.phase)*minus;
            amplitudes=self.modalSource_.*response(:,wvt.klNonzeroKhUniqueIndex)/(2i);
        end
        function force = forcingWithResolutionOfTransform(self,wvt)
            % Require an explicitly resampled horizontal forcing pattern.
            % - Topic: Create the forcing
            if ~isequal(size(self.pattern),[wvt.Nx wvt.Ny])
                error('WVSeasonalSurfaceAnomalyForcing:ResolutionUnsupported','Supply a pattern on the new horizontal grid.');
            end
            force=WVSeasonalSurfaceAnomalyForcing(wvt,pattern=self.pattern,amplitude=self.amplitude,period=self.period,phase=self.phase);
        end
        function writeToGroup(self,group,propertyAnnotations,attributes)
            % Persist the pattern on the parent transform's x-y axes.
            % - Topic: Forcing persistence
            arguments
                self WVSeasonalSurfaceAnomalyForcing
                group NetCDFGroup
                propertyAnnotations CAPropertyAnnotation = CAPropertyAnnotation.empty(0,0)
                attributes = configureDictionary("string","string")
            end
            isPattern=string({propertyAnnotations.name})=="pattern";
            writeToGroup@CAAnnotatedClass(self,group,propertyAnnotations(~isPattern),attributes);
            if any(isPattern)
                annotation=propertyAnnotations(find(isPattern,1));
                variableAttributes=annotation.attributes;
                variableAttributes('units')=annotation.units;
                variableAttributes('long_name')=annotation.description;
                group.addVariable(annotation.name,annotation.dimensions,self.pattern,isComplex=false,attributes=variableAttributes);
            end
        end
    end
    methods (Static)
        function names = classRequiredPropertyNames(), names={'pattern','amplitude','period','phase'}; end
        function a = classDefinedPropertyAnnotations()
            a=CAPropertyAnnotation.empty(0,0);
            a(end+1)=CANumericProperty('pattern',{'x','y'},'1','strict endpoint forcing pattern');
            a(end+1)=CANumericProperty('amplitude',{},'m s-1','surface displacement tendency amplitude');
            a(end+1)=CANumericProperty('period',{},'s','seasonal period');
            a(end+1)=CANumericProperty('phase',{},'rad','phase at time zero');
        end
    end
end

function value = harmonicIntegral(lambda,omega,t)
% (exp(i*omega*t)-exp(lambda*t))/(i*omega-lambda), without inverse decay.
z=(lambda-1i*omega)*t;
ratio=ones(size(z)); nonzero=z~=0;
ratio(nonzero)=expm1(z(nonzero))./z(nonzero);
value=t*exp(1i*omega*t).*ratio;
end
