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
            if ~isa(wvt,'WVTransformFreeSurfaceQG') && ~isa(wvt,'WVTransformFreeSurfaceThermalQG')
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
        end
        function [Fq,Fb] = addQuasigeostrophicSpatialForcing(self,wvt,Fq,Fb,~)
            % Add only the prescribed surface endpoint tendency.
            % - Topic: Implement forcing evaluation
            i=find(wvt.activeEndpoint==1,1);
            Fb(:,:,i)=Fb(:,:,i)+self.amplitude*sin(2*pi*wvt.t/self.period+self.phase)*self.pattern;
        end
        function [force,relativeError] = forcingWithResolutionOfTransform(self,wvt)
            % Transfer the Fourier pattern while preserving its absolute clock.
            % Content outside either retained Fourier space is measured by a
            % sampled round trip; relative RMS loss above 1e-8 rejects conversion.
            % - Topic: Create the forcing
            % - Parameter wvt: compatible target with identical horizontal domain
            % - Returns force: target-owned seasonal forcing with unchanged clock
            % - Returns relativeError: sampled relative RMS round-trip pattern loss
            arguments (Input)
                self WVSeasonalSurfaceAnomalyForcing
                wvt (1,1) WVTransform
            end
            if ~isequal([self.wvt.Lx self.wvt.Ly],[wvt.Lx wvt.Ly])
                error('WV:TransferIncompatible','Seasonal forcing conversion requires identical horizontal domains.');
            end
            source=WVGeometryDoublyPeriodic([self.wvt.Lx self.wvt.Ly],[self.wvt.Nx self.wvt.Ny],Nz=1,shouldAntialias=self.wvt.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            target=WVGeometryDoublyPeriodic([wvt.Lx wvt.Ly],[wvt.Nx wvt.Ny],Nz=1,shouldAntialias=wvt.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            S=source.transformFromSpatialDomainWithFourier(self.pattern);
            [common,index]=ismember([target.kMode_wv,target.lMode_wv],[source.kMode_wv,source.lMode_wv],'rows');
            T=complex(zeros(1,target.Nkl)); T(:,common)=S(:,index(common));
            recovered=complex(zeros(size(S))); recovered(:,index(common))=T(:,common);
            back=source.transformToSpatialDomainWithFourier(recovered);
            relativeError=norm(back-self.pattern,'fro')/max(norm(self.pattern,'fro'),realmin);
            if relativeError>1e-8
                error('WVSeasonalSurfaceAnomalyForcing:UnresolvedTransfer','Target cannot preserve the pattern: relative RMS round-trip loss %.3g exceeds 1e-8.',relativeError);
            end
            if isequal([source.Nx source.Ny],[target.Nx target.Ny])
                pattern=self.pattern;
            else
                pattern=target.transformToSpatialDomainWithFourier(T);
            end
            force=WVSeasonalSurfaceAnomalyForcing(wvt,pattern=pattern,amplitude=self.amplitude,period=self.period,phase=self.phase);
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
