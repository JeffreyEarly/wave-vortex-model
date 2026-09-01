classdef WVSeasonalSurfaceBuoyancyFlux < WVForcing
    % Apply a sinusoidal surface buoyancy flux to free-surface QG.
    %
    % The prescribed inward surface flux is
    %
    % $$
    % \mathcal Q_{\mathfrak b,0}(x,y,t)
    % =Q_*P(x,y)\sin\left(\frac{2\pi t}{T}+\phi\right).
    % $$
    %
    % `pattern` is stored and used exactly as supplied: it is not
    % normalized and its horizontal mean is not removed. Consequently, a
    % nonzero pattern mean forces the `Amda` family. The default pattern is
    % $$P=\sin(2\pi y/L_y)$$. The surface endpoint must be active.
    %
    % ```matlab
    % wvt = WVTransformFreeSurfaceQG([100e3 100e3 1000],[8 8 33],N2Function=@(z)1e-4*ones(size(z)),g0=0.02);
    % wvt.addForcing(WVSeasonalSurfaceBuoyancyFlux(wvt,amplitude=1e-8));
    % ```
    %
    % - Topic: Create the forcing
    % - Topic: Inspect forcing configuration
    % - Topic: Implement forcing evaluation
    % - Topic: Forcing persistence
    % - Declaration: WVSeasonalSurfaceBuoyancyFlux < [WVForcing](/classes/forcing/wvforcing/)

    properties (SetAccess = private)
        % Exact horizontal surface-flux pattern.
        %
        % This finite real array has shape `Nx × Ny`. No normalization or
        % mean removal is applied.
        %
        % - Topic: Inspect forcing configuration
        pattern

        % Peak buoyancy-flux amplitude in $$\mathrm{m^{2}\,s^{-3}}$$.
        %
        % - Topic: Inspect forcing configuration
        amplitude

        % Seasonal period in seconds.
        %
        % The default is 365.25 days.
        %
        % - Topic: Inspect forcing configuration
        period

        % Phase offset $$\phi$$ in radians.
        %
        % - Topic: Inspect forcing configuration
        phase
    end

    properties (Access = private)
        unitTendency
    end

    methods
        function self = WVSeasonalSurfaceBuoyancyFlux(wvt,options)
            % Create seasonal surface buoyancy-flux forcing.
            %
            % - Topic: Create the forcing
            % - Declaration: self = WVSeasonalSurfaceBuoyancyFlux(wvt,options)
            % - Parameter wvt: free-surface QG transform with an active surface endpoint
            % - Parameter options.pattern: exact finite real `Nx × Ny` pattern; default `sin(2*pi*y/Ly)`
            % - Parameter options.amplitude: required peak buoyancy-flux amplitude in square meters per cubic second
            % - Parameter options.period: positive period in seconds; default 365.25 days
            % - Parameter options.phase: finite phase in radians; default zero
            % - Returns self: seasonal surface buoyancy-flux forcing owned by `wvt`
            arguments
                wvt (1,1) WVTransformFreeSurfaceQG
                options.pattern double = []
                options.amplitude (1,1) double {mustBeReal,mustBeFinite}
                options.period (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 365.25*86400
                options.phase (1,1) double {mustBeReal,mustBeFinite} = 0
            end
            if ~any(wvt.activeEndpoint == 1)
                error('WVSeasonalSurfaceBuoyancyFlux:InactiveSurface','Seasonal surface buoyancy flux requires an active surface endpoint.');
            end
            if isempty(options.pattern)
                [~,Y] = ndgrid(wvt.x,wvt.y);
                pattern = sin(2*pi*Y/wvt.Ly);
            else
                pattern = options.pattern;
            end
            if ~isreal(pattern) || any(~isfinite(pattern),"all") || ~isequal(size(pattern),[wvt.Nx wvt.Ny])
                error('WVSeasonalSurfaceBuoyancyFlux:InvalidPattern','pattern must be a finite real double array with shape Nx x Ny.');
            end

            self@WVForcing(wvt,"seasonal surface buoyancy flux",WVForcingType("QGSpectral"));
            self.pattern = pattern;
            self.amplitude = options.amplitude;
            self.period = options.period;
            self.phase = options.phase;
            self.unitTendency = wvt.thermalCoefficientTendency(0,surfaceBuoyancyFlux=self.pattern);
        end

        function tendency = addQuasigeostrophicSpectralForcing(self,wvt,tendency,~)
            % Add the instantaneous seasonal coefficient tendency.
            %
            % - Topic: Implement forcing evaluation
            % - Declaration: tendency = addQuasigeostrophicSpectralForcing(wvt,tendency,physicalState)
            % - Parameter wvt: free-surface QG transform evaluating the forcing
            % - Parameter tendency: accumulated family-keyed coefficient tendency
            % - Returns tendency: coefficient tendency including the seasonal surface flux
            % - Developer: true
            scale = self.amplitude*sin(2*pi*wvt.t/self.period+self.phase);
            tendency.Ag_q = tendency.Ag_q+scale*self.unitTendency.Ag_q;
            tendency.Ag_0 = tendency.Ag_0+scale*self.unitTendency.Ag_0;
            tendency.Amda = tendency.Amda+scale*self.unitTendency.Amda;
        end

        function writeToGroup(self,group,propertyAnnotations,attributes)
            % Write forcing configuration using the transform-owned x-y dimensions.
            %
            % - Topic: Forcing persistence
            % - Declaration: writeToGroup(group,propertyAnnotations,attributes)
            % - Parameter group: transform-owned NetCDF forcing group
            % - Parameter propertyAnnotations: forcing properties to persist
            % - Parameter attributes: additional NetCDF attributes
            % - Developer: true
            arguments
                self WVSeasonalSurfaceBuoyancyFlux
                group NetCDFGroup
                propertyAnnotations CAPropertyAnnotation = CAPropertyAnnotation.empty(0,0)
                attributes = configureDictionary("string","string")
            end
            isPattern = string({propertyAnnotations.name}) == "pattern";
            writeToGroup@CAAnnotatedClass(self,group,propertyAnnotations(~isPattern),attributes);
            if any(isPattern)
                annotation = propertyAnnotations(find(isPattern,1));
                variableAttributes = annotation.attributes;
                variableAttributes('units') = annotation.units;
                variableAttributes('long_name') = annotation.description;
                group.addVariable(annotation.name,annotation.dimensions,self.pattern,isComplex=false,attributes=variableAttributes);
            end
        end
    end

    methods (Static)
        function vars = classRequiredPropertyNames()
            % Return persisted constructor property names.
            %
            % - Topic: Forcing persistence
            % - Declaration: vars = classRequiredPropertyNames()
            % - Returns vars: required persisted property names
            % - Developer: true
            vars = {'pattern','amplitude','period','phase'};
        end

        function propertyAnnotations = classDefinedPropertyAnnotations()
            % Return annotated persistence metadata.
            %
            % - Topic: Forcing persistence
            % - Declaration: propertyAnnotations = classDefinedPropertyAnnotations()
            % - Returns propertyAnnotations: forcing property annotations
            % - Developer: true
            propertyAnnotations = CAPropertyAnnotation.empty(0,0);
            propertyAnnotations(end+1) = CANumericProperty('pattern',{'x','y'},'1','exact horizontal surface buoyancy-flux pattern');
            propertyAnnotations(end+1) = CANumericProperty('amplitude',{},'m2 s-3','peak inward surface buoyancy-flux amplitude');
            propertyAnnotations(end+1) = CANumericProperty('period',{},'s','seasonal forcing period');
            propertyAnnotations(end+1) = CANumericProperty('phase',{},'rad','seasonal forcing phase');
        end
    end
end
