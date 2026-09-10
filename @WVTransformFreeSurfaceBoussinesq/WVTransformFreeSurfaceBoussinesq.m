classdef WVTransformFreeSurfaceBoussinesq < WVGeometryDoublyPeriodicStratified & WVTransform
    % Represent resolved linear free-surface waves and balanced flow together.
    %
    % Create scientific operators with `fromStratification`. The primary
    % constructor accepts the complete structure returned by `scientificState`
    % and performs no scientific mode solve. Each coefficient family has its
    % own retained count on one WKB-Chebyshev physical grid. Nonzero Fourier
    % columns represent a Hermitian half plane; real fields include conjugates.
    % Waves use exp(+/-i*omega*(t-t0)); Aio uses exp(i*f*(t-t0)).
    %
    % This experimental transform supports observable and volume-source
    % projection, exact linear phases, fixed-step forced WVModel evolution,
    % and annotated restart using stored scientific operators. Use WVModel(wvt)
    % and an explicit fixed deltaT to integrate registered sources;
    % shouldUseLinearDynamics=true advances unforced analytical phases only.
    % Resolution transfer preserves matching physical modes with independent
    % retained counts and reports positive physical reconstruction errors.
    % u/v/w are physical velocities on the moving mesh; u_hat/v_hat/w_hat
    % expose the modal variables. p_linear and p_full distinguish linear
    % polarization from the full instantaneous pressure diagnostic. Existing
    % physicalEnergy/totalEnergy are quadratic; nonlinearEnergy uses full APE
    % and the matching C1-reference surface term.
    % Nonlinear runtime activation remains unqualified.
    % Legacy rigid-lid Ap/Am/A0 initialization is not supported here.
    %
    % ```matlab
    % wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*exp(2*z/700));
    % copy = WVTransformFreeSurfaceBoussinesq(wvt.scientificState());
    % ```
    %
    % - Topic: Create a transform
    % - Topic: Inspect coefficient families
    % - Topic: Inspect scientific operators
    % - Topic: Reconstruct and project fields
    % - Topic: Project physical sources
    % - Topic: Save transform state
    % - Topic: Transfer resolution
    % - Topic: Analyze physical energy
    % - Declaration: classdef WVTransformFreeSurfaceBoussinesq < WVTransform

    properties
        % Positive-frequency wave amplitudes at t0, in m s-1.
        % - Topic: Inspect coefficient families
        Aw_p
        % Negative-frequency wave amplitudes at t0, in m s-1.
        % - Topic: Inspect coefficient families
        Aw_m
        % APV amplitudes in s-1.
        % - Topic: Inspect coefficient families
        Ag_q
        % Boundary-normalized zero-APV amplitudes in s-1.
        % - Topic: Inspect coefficient families
        Ag_0
        % Complex inertial amplitudes at t0, in m s-1.
        % - Topic: Inspect coefficient families
        Aio
        % Real mean-density-anomaly amplitudes in meters.
        % - Topic: Inspect coefficient families
        Amda
    end

    properties (Constant)
        % Persisted interpretation of physical fields and full thermodynamics.
        % - Topic: Save transform state
        fieldConvention = "physical-velocity-full-c1"
    end

    properties (Transient, Access=private)
        % Factors depend only on the immutable scientific representation.
        thermodynamics_ = []
        pressureSolver_ = []
        nonlinearSolver_ = []
    end

    properties (Transient, SetAccess=private)
        % Evidence produced by scientific construction; empty after canonical restore.
        %
        % Selected counts, sampled operators and tolerances are persisted separately.
        % Inspect this report before saving when full construction provenance is needed.
        % - Topic: Inspect modes and operators
        constructionAssessment (1,1) struct = struct()
    end

    properties (SetAccess = private)
        % Effective surface acceleration for the balanced basis.
        % - Topic: Inspect scientific operators
        g0
        % Effective bottom acceleration for the balanced basis.
        % - Topic: Inspect scientific operators
        gd
        % Ordinal APV mode coordinate.
        % - Topic: Inspect scientific operators
        apvMode
        % Ordinal mean-density-anomaly mode coordinate.
        % - Topic: Inspect scientific operators
        mdaMode
        % Ordinal wave mode coordinate.
        % - Topic: Inspect scientific operators
        waveMode
        % Retained wave prefix on each distinct positive wavenumber page.
        % - Topic: Inspect scientific operators
        waveModeCountByKh
        % Ordinal inertial mode coordinate.
        % - Topic: Inspect scientific operators
        inertialMode
        % Physical APV mode labels.
        % - Topic: Inspect scientific operators
        apvModeNumber
        % Physical mean-density-anomaly mode labels.
        % - Topic: Inspect scientific operators
        mdaModeNumber
        % Physical wave mode labels.
        % - Topic: Inspect scientific operators
        waveModeNumber
        % Physical inertial mode labels.
        % - Topic: Inspect scientific operators
        inertialModeNumber
        % Active endpoint codes: surface 1 and bottom 2.
        % - Topic: Inspect scientific operators
        activeEndpoint
        % Compact nonzero Fourier indices.
        % - Topic: Inspect scientific operators
        klNonzero
        % Zonal wavenumbers for klNonzero.
        % - Topic: Inspect scientific operators
        kNonzero
        % Meridional wavenumbers for klNonzero.
        % - Topic: Inspect scientific operators
        lNonzero
        % Horizontal wavenumber magnitudes for klNonzero.
        % - Topic: Inspect scientific operators
        khNonzero
        % Distinct positive horizontal wavenumber pages.
        % - Topic: Inspect scientific operators
        khUnique
        % Map from nonzero Fourier columns to mode pages.
        % - Topic: Inspect scientific operators
        klNonzeroKhUniqueIndex
        % Stored APV velocity and pressure modes.
        % - Topic: Inspect scientific operators
        apvF
        % Stored APV displacement modes.
        % - Topic: Inspect scientific operators
        apvG
        % Resolved APV projection functional.
        % - Topic: Inspect scientific operators
        apvFForward
        % APV inversion eigenvalues.
        % - Topic: Inspect scientific operators
        apvMu
        % APV response at each active endpoint.
        % - Topic: Inspect scientific operators
        apvEndpointResponse
        % Stored boundary-normalized zero-APV velocity modes.
        % - Topic: Inspect scientific operators
        zeroAPVF
        % Stored boundary-normalized zero-APV displacement modes.
        % - Topic: Inspect scientific operators
        zeroAPVG
        % Stored resolved balanced source operator apvFSourcePairing.
        % - Topic: Inspect scientific operators
        apvFSourcePairing
        % Stored resolved balanced source operator apvGSourcePairing.
        % - Topic: Inspect scientific operators
        apvGSourcePairing
        % Stored resolved balanced source operator zeroAPVFPairing.
        % - Topic: Inspect scientific operators
        zeroAPVFPairing
        % Stored resolved balanced source operator zeroAPVGPairing.
        % - Topic: Inspect scientific operators
        zeroAPVGPairing
        % Stored resolved balanced source operator zeroAPVSourceSolve.
        % - Topic: Inspect scientific operators
        zeroAPVSourceSolve
        % Stored mean-density-anomaly displacement modes.
        % - Topic: Inspect scientific operators
        mdaG
        % Signed resolved mean-density-anomaly projection.
        % - Topic: Inspect scientific operators
        mdaGForward
        % Hydrostatic mean pressure per unit displacement coefficient, divided by rho0.
        % - Topic: Inspect scientific operators
        mdaPressureMode
        % Stored wave F modes, Nz by waveMode by khUnique.
        % - Topic: Inspect scientific operators
        waveF
        % Stored wave G modes, Nz by waveMode by khUnique.
        % - Topic: Inspect scientific operators
        waveG
        % Resolved wave projection using (N2-f^2)/g and the surface term.
        % - Topic: Inspect scientific operators
        waveGForward
        % Wave equivalent depths, waveMode by khUnique.
        % - Topic: Inspect scientific operators
        waveEquivalentDepth
        % Positive angular frequencies, waveMode by khUnique.
        % - Topic: Inspect scientific operators
        waveFrequency
        % Stored inertial velocity modes.
        % - Topic: Inspect scientific operators
        inertialF
        % Inertial projection using the continuous h normalization.
        % - Topic: Inspect scientific operators
        inertialFForward
        % Inertial equivalent depths.
        % - Topic: Inspect scientific operators
        inertialEquivalentDepth
        % Positive physical quadrature weights on the common grid.
        % - Topic: Inspect scientific operators
        verticalQuadratureWeights
        % Physical vertical differentiation on the common grid.
        % - Topic: Inspect scientific operators
        verticalDerivativeMatrix
        % Wave Gram error on each horizontal-wavenumber page.
        % - Topic: Inspect scientific operators
        waveGramError
        % Inertial Gram error on the common grid.
        % - Topic: Inspect scientific operators
        inertialGramError
        % APV Gram error on the common grid.
        % - Topic: Inspect scientific operators
        apvGramError
        % MDA Gram error on the common grid.
        % - Topic: Inspect scientific operators
        mdaGramError
        % Balanced eigenproblem coefficient count under the existing QG policy.
        % - Topic: Inspect scientific operators
        balancedNEVP
        % Wave and inertial eigenproblem coefficient count.
        % - Topic: Inspect scientific operators
        nEVP
        % Requested per-family quadrature qualification tolerance.
        % - Topic: Inspect scientific operators
        gramTolerance
        % Allowed bounded physical-product sampling error.
        % - Topic: Inspect scientific operators
        quadraticAliasingTolerance
        % Whether scientific construction checks quadratic products.
        % - Topic: Inspect scientific operators
        shouldCheckQuadraticAliasing
        % Physical H1 and equivalent-depth agreement between independent solves.
        % - Topic: Inspect scientific operators
        modeConvergenceTolerance
        % Fixed zero-APV derivative and energy accuracy.
        % - Topic: Inspect scientific operators
        boundaryResolutionTolerance
    end

    properties (Dependent)
        % Active entries in the rectangular wave coefficient arrays.
        % - Topic: Inspect coefficient families
        activeWaveModes
        % Positive quadratic reference-geometry energy per area and reference density.
        % - Topic: Analyze physical energy
        totalEnergy
        % Alias for totalEnergy, in m3 s-2.
        % - Topic: Analyze physical energy
        totalEnergySpatiallyIntegrated
        % Number of active balanced boundaries.
        % - Topic: Inspect scientific operators
        activeEndpointCount
        % False: waves satisfy the nonhydrostatic vertical momentum equation.
        % - Topic: Inspect scientific operators
        isHydrostatic
    end

    methods
        function self = WVTransformFreeSurfaceBoussinesq(state)
            % Construct from complete stored scientific operators without solving modes.
            %
            % `state` is returned by `scientificState`; it includes geometry,
            % stratification functions, and every resolved matrix. Coefficients
            % start at zero and are set separately through their named properties.
            %
            % - Topic: Create a transform
            % - Declaration: self = WVTransformFreeSurfaceBoussinesq(state)
            % - Parameter state: complete scalar scientific-state structure
            % - Returns self: transform with zero coefficient state
            arguments (Input)
                state (1,1) struct
            end
            % Historical uniform scientific states did not store a count map.
            if ~isfield(state,'waveModeCountByKh') && all(isfield(state,{'waveMode','khUnique'}))
                state.waveModeCountByKh = repmat(numel(state.waveMode),numel(state.khUnique),1);
            end
            required = [WVTransformFreeSurfaceBoussinesq.scientificPropertyNames(),WVTransformFreeSurfaceBoussinesq.geometryStateNames()];
            if ~all(isfield(state,required))
                error('WVTransformFreeSurfaceBoussinesq:IncompleteScientificState','Supply the complete structure returned by scientificState or use fromStratification.')
            end
            nz = state.Nxyz(3); nq = length(state.apvMode); nw = length(state.waveMode);
            if size(state.apvF,1) ~= nz || size(state.apvF,2) ~= nq || size(state.waveF,1) ~= nz || size(state.waveF,2) ~= nw || ~isequal(size(state.waveF),size(state.waveG)) || length(state.z) ~= nz || any(diff(state.z)<=0) || any(state.verticalQuadratureWeights<=0)
                error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','Stored mode shapes and positive increasing-grid quadrature must match the declared geometry.')
            end
            nc = length(state.klNonzero); np = length(state.khUnique); ne = length(state.activeEndpoint);
            nm = length(state.mdaMode); ni = length(state.inertialMode);
            shapeNames = ["apvF","apvG","apvFForward","apvMu","apvEndpointResponse","zeroAPVF","zeroAPVG","mdaG","mdaGForward","mdaPressureMode","waveF","waveG","waveGForward","waveEquivalentDepth","waveFrequency","inertialF","inertialFForward","inertialEquivalentDepth","verticalQuadratureWeights","verticalDerivativeMatrix","apvFSourcePairing","apvGSourcePairing","zeroAPVFPairing","zeroAPVGPairing","zeroAPVSourceSolve"];
            shapes = {[nz nq],[nz nq],[nq nz],[nq np],[ne nq np],[nz ne np],[nz ne np],[nz nm],[nm nz],[nz nm],[nz nw np],[nz nw np],[nw nz np],[nw np],[nw np],[nz ni],[ni nz],[ni 1],[nz 1],[nz nz],[nq nz],[nq nz],[ne nz np],[ne nz np],[ne ne np]};
            for iShape=1:length(shapeNames)
                value=state.(shapeNames(iShape)); expected=shapes{iShape}; actual=size(value,1:length(expected));
                if ~isa(value,'double') || ~isreal(value) || any(~isfinite(value),'all') || ~isequal(actual,expected) || ndims(value)>max(2,length(expected))
                    error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','%s must be a finite real array with shape %s.',shapeNames(iShape),mat2str(expected))
                end
            end
            if ~isa(state.waveModeCountByKh,'double') || ~isreal(state.waveModeCountByKh) || ~isequal(size(state.waveModeCountByKh),[np 1]) || any(~isfinite(state.waveModeCountByKh) | state.waveModeCountByKh<0 | state.waveModeCountByKh~=fix(state.waveModeCountByKh) | state.waveModeCountByKh>nw) || max([state.waveModeCountByKh;0])~=nw
                error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','waveModeCountByKh must contain one nonnegative integer prefix per page, with maximum matching waveMode.')
            end
            active = (1:nw).' <= state.waveModeCountByKh.';
            if any(state.waveEquivalentDepth(active)<=0) || any(state.waveFrequency(active)<=0) || any(state.waveEquivalentDepth(~active)~=0) || any(state.waveFrequency(~active)~=0)
                error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','Wave depths and frequencies must be positive on active modes and zero in padding.')
            end
            for p = 1:np
                inactive = state.waveModeCountByKh(p)+1:nw;
                if any(state.waveF(:,inactive,p)~=0,'all') || any(state.waveG(:,inactive,p)~=0,'all') || any(state.waveGForward(inactive,:,p)~=0,'all')
                    error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','Inactive wave operator entries must be zero.')
                end
            end
            if length(state.klNonzeroKhUniqueIndex)~=nc || any(state.klNonzeroKhUniqueIndex<1 | state.klNonzeroKhUniqueIndex>np) || any(state.inertialEquivalentDepth<=0)
                error('WVTransformFreeSurfaceBoussinesq:InvalidScientificState','Wave depths and horizontal page indices must be positive and match the stored families.')
            end
            geometry = struct(shouldAntialias=state.shouldAntialias,z=state.z,j=state.apvModeNumber,Nj=nq,N2Function=state.N2Function,rhoFunction=state.rhoFunction,rho0=state.rho0,planetaryRadius=state.planetaryRadius,rotationRate=state.rotationRate,latitude=state.latitude,g=state.g,dLnN2=state.dLnN2,PF0inv=state.PF0inv,QG0inv=state.QG0inv,PF0=state.PF0,QG0=state.QG0,P0=state.P0,Q0=state.Q0,h_0=state.h_0,z_int=state.z_int);
            geometryArguments = namedargs2cell(geometry);
            self@WVGeometryDoublyPeriodicStratified(state.Lxyz,state.Nxyz,geometryArguments{:});
            self@WVTransform(WVForcingType("NonhydrostaticSpatial"));
            for name = string(self.scientificPropertyNames()), self.(name) = state.(name); end
            self.hasWaveComponent = true; self.hasPVComponent = true;
            nc = length(self.klNonzero);
            self.Aw_p = complex(zeros(nw,nc)); self.Aw_m = complex(zeros(nw,nc));
            self.Ag_q = complex(zeros(nq,nc)); self.Ag_0 = complex(zeros(length(self.activeEndpoint),nc));
            self.Aio = complex(zeros(length(self.inertialMode),1)); self.Amda = zeros(length(self.mdaMode),1);
            names = setdiff(self.namesOfTransformVariables(),{'p_full'},'stable');
            self.addOperation(self.operationForKnownVariable(names{:}));
            self.addOperation(self.operationForKnownVariable('p_full'));
            addlistener(self,'forcingDidChange',@(~,~)self.removeFromVariableCache('p_full'));
            groups = {struct(Aw_p=true,Aw_m=true),struct(Ag_q=true),struct(Ag_0=true),struct(Ag_q=true,Ag_0=true,Amda=true),struct(Aio=true),struct(Amda=true)};
            labels = ["wave","apv","zeroapv","balanced","inertial","mda"];
            for i = 1:length(labels)
                component = WVFlowComponent(self,coefficientMasks=groups{i});
                component.name = char(labels(i)); component.shortName = char(labels(i)); component.abbreviatedName = char(labels(i));
                self.addFlowComponent(component);
            end
        end

        state = scientificState(self)
        fields = reconstructFields(self,variableNames,options)
        [varargout] = variableAtPositionWithName(self,x,y,z,variableNames,options)
        [pressure,diagnostics] = fullPressure(self)
        diagnostics = nonlinearEnergy(self)
        flux = fluxForForcing(self)
        fields = reconstructSpectralState(self,options)
        [state,assessment] = projectFields(self,fields)
        operation = operationForKnownVariable(self,variableName,options)
        diagnostics = physicalEnergy(self,options)

        function value = get.activeWaveModes(self), value = self.waveMode <= self.waveModeCountByKh(self.klNonzeroKhUniqueIndex).'; end
        function value = get.activeEndpointCount(self), value = length(self.activeEndpoint); end
        function value = get.isHydrostatic(~), value = false; end
        function value = get.totalEnergy(self), d = self.physicalEnergy(); value = d.totalEnergy; end
        function value = get.totalEnergySpatiallyIntegrated(self), value = self.totalEnergy; end

        function set.Aw_p(self,value)
            self.validateCoefficient(value,"Aw_p");
            self.Aw_p = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Aw_m(self,value)
            self.validateCoefficient(value,"Aw_m");
            self.Aw_m = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Ag_q(self,value)
            self.validateCoefficient(value,"Ag_q");
            self.Ag_q = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Ag_0(self,value)
            self.validateCoefficient(value,"Ag_0");
            self.Ag_0 = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Aio(self,value)
            self.validateCoefficient(value,"Aio");
            self.Aio = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Amda(self,value)
            self.validateCoefficient(value,"Amda");
            self.Amda = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end

        function annotations = coefficientStateAnnotations(~)
            % Discover independently shaped reference-time coefficient families.
            % - Topic: Inspect coefficient families
            annotations = WVTransformFreeSurfaceBoussinesq.coefficientAnnotations();
        end

        function removeAll(self)
            % Set every canonical family to zero.
            % - Topic: Inspect coefficient families
            for annotation = self.coefficientStateAnnotations(), self.(annotation.name) = zeros(size(self.(annotation.name))); end
        end

        function value = transformFromSpatialDomainWithFg(self,value), value = self.apvFForward*value; end
        function value = transformFromSpatialDomainWithGg(~,~)
            value = []; WVTransformFreeSurfaceBoussinesq.throwUnavailable('WVTransformFreeSurfaceBoussinesq:UseCanonicalFamilies','Use projectFields with velocity, total displacement, and SSH.')
        end
        function value = transformToSpatialDomainWithF(~,~)
            value = []; WVTransformFreeSurfaceBoussinesq.throwUnavailable('WVTransformFreeSurfaceBoussinesq:UseCanonicalFamilies','Use reconstructFields with canonical coefficient families.')
        end
        function value = transformToSpatialDomainWithG(~,~)
            value = []; WVTransformFreeSurfaceBoussinesq.throwUnavailable('WVTransformFreeSurfaceBoussinesq:UseCanonicalFamilies','Use reconstructFields with canonical coefficient families.')
        end
        function [Fp,Fm,F0] = nonlinearFlux(~)
            Fp=[]; Fm=[]; F0=[]; WVTransformFreeSurfaceBoussinesq.throwUnavailable('WVTransformFreeSurfaceBoussinesq:UseCanonicalFamilies','Use coefficientTendency to evaluate the six independently shaped coefficient families.')
        end

    end

    methods (Hidden)
        [u,v,w,eta] = nonlinearAdvectionSources(self,stage)
    end

    methods (Access = protected)
        validateForcingInventory(self,forcing)
    end

    methods (Access = private)
        function context = thermodynamicContext(self)
            if isempty(self.thermodynamics_)
                self.thermodynamics_ = WVInternal.freeSurfaceThermodynamics(self);
            end
            context = self.thermodynamics_;
        end
        function context = nonlinearContext(self)
            if isempty(self.nonlinearSolver_)
                self.nonlinearSolver_ = WVInternal.freeSurfaceNonlinearStage(self);
            end
            context = self.nonlinearSolver_;
        end
        function context = pressureContext(self)
            if isempty(self.pressureSolver_)
                self.pressureSolver_ = WVInternal.freeSurfacePressureSolver(self);
            end
            context = self.pressureSolver_;
        end
        function validateCoefficient(self,value,name)
            switch name
                case {"Aw_p","Aw_m"}, shape=[length(self.waveMode),length(self.klNonzero)];
                case "Ag_q", shape=[length(self.apvMode),length(self.klNonzero)];
                case "Ag_0", shape=[length(self.activeEndpoint),length(self.klNonzero)];
                case "Aio", shape=[length(self.inertialMode),1];
                case "Amda", shape=[length(self.mdaMode),1];
            end
            if ~isa(value,'double') || ~isequal(size(value),shape) || any(~isfinite(value),'all') || (name=="Amda" && ~isreal(value))
                error('WVTransformFreeSurfaceBoussinesq:InvalidCoefficient','%s must be a finite double array of shape %s; Amda must be real.',name,mat2str(shape))
            end
            if ismember(name,["Aw_p","Aw_m"]) && any(value(~self.activeWaveModes)~=0)
                error('WVTransformFreeSurfaceBoussinesq:InactiveWaveCoefficient','%s must be zero outside activeWaveModes.',name)
            end
        end
    end

    methods (Static)
        [self,assessment] = fromStratification(Lxyz,Nxyz,options)
        function names = namesOfTransformVariables()
            names = {'u','v','w','u_hat','v_hat','w_hat','eta','eta_i','p_linear','p_full','ssh','ssu','ssv','w_i','z_physical','qgpv'};
        end
        annotations = classDefinedPropertyAnnotations()
        [wvt,ncfile] = waveVortexTransformFromFile(path,options)
        wvt = transformFromGroup(group)
        function names = classRequiredPropertyNames()
            names = union(WVGeometryDoublyPeriodicStratified.namesOfRequiredPropertiesForGeometry(),WVTransformFreeSurfaceBoussinesq.scientificPropertyNames());
            names = union(names,{'activeEndpointCount','rhoFunction','Aw_p','Aw_m','Ag_q','Aio','Amda','t','t0','forcing','fieldConvention'});
            names = setdiff(names,[WVTransformFreeSurfaceBoussinesq.optionalEndpointPropertyNames(),WVTransformFreeSurfaceBoussinesq.optionalWavePropertyNames()]);
        end
    end

    methods (Static, Access = private)
        function throwUnavailable(identifier,message)
            error(identifier,'%s',message)
        end
    end

    methods (Static, Hidden)
        function annotations = coefficientAnnotations()
            annotations = WVCoefficientAnnotation.empty(0,0);
            annotations(end+1) = WVCoefficientAnnotation('Aw_p',{'waveMode','klNonzero'},'m s-1','positive-frequency waves',canonicalBasis="free-surface fixed-wavenumber waves",emptyFamilyPolicy="omit",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Aw_m',{'waveMode','klNonzero'},'m s-1','negative-frequency waves',canonicalBasis="free-surface fixed-wavenumber waves",emptyFamilyPolicy="omit",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Ag_q',{'apvMode','klNonzero'},'s-1','APV coefficients',canonicalBasis="generalized-energy APV modes",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Ag_0',{'activeEndpoint','klNonzero'},'s-1','zero-APV coefficients',canonicalBasis="boundary-normalized zero-APV responses",emptyFamilyPolicy="omit",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Aio',{'inertialMode'},'m s-1','inertial oscillations',canonicalBasis="free-surface zero-wavenumber F modes",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Amda',{'mdaMode'},'m','mean density anomaly',canonicalBasis="signed-normalized MDA modes",isComplex=false);
        end
        function names = optionalWavePropertyNames()
            names = {'waveMode','waveModeNumber','waveF','waveG','waveGForward','waveEquivalentDepth','waveFrequency','Aw_p','Aw_m'};
        end
        function names = optionalEndpointPropertyNames()
            names = {'activeEndpoint','Ag_0','apvEndpointResponse','zeroAPVF','zeroAPVG','zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve'};
        end
        function names = scientificPropertyNames()
            names = {'g0','gd','apvMode','mdaMode','waveMode','waveModeCountByKh','inertialMode','apvModeNumber','mdaModeNumber','waveModeNumber','inertialModeNumber','activeEndpoint','klNonzero','kNonzero','lNonzero','khNonzero','khUnique','klNonzeroKhUniqueIndex','apvF','apvG','apvFForward','apvMu','apvEndpointResponse','apvFSourcePairing','apvGSourcePairing','zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve','zeroAPVF','zeroAPVG','mdaG','mdaGForward','mdaPressureMode','waveF','waveG','waveGForward','waveEquivalentDepth','waveFrequency','inertialF','inertialFForward','inertialEquivalentDepth','verticalQuadratureWeights','verticalDerivativeMatrix','waveGramError','inertialGramError','apvGramError','mdaGramError','balancedNEVP','nEVP','gramTolerance','shouldCheckQuadraticAliasing','quadraticAliasingTolerance','modeConvergenceTolerance','boundaryResolutionTolerance'};
        end
        function names = geometryStateNames()
            names = {'Lxyz','Nxyz','shouldAntialias','z','N2Function','rhoFunction','rho0','planetaryRadius','rotationRate','latitude','g','dLnN2','PF0inv','QG0inv','PF0','QG0','P0','Q0','h_0','z_int'};
        end
    end
end
