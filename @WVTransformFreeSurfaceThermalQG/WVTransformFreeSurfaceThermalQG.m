classdef WVTransformFreeSurfaceThermalQG < WVGeometryDoublyPeriodicStratified & WVTransform
    % Reconstruct complete balanced thermal states with two active boundaries.
    %
    % Ath has velocity units and Amda retains the independent real MDA state.
    % The scientific factory retains every requested polynomial direction.
    % Supports linear and qualified nonlinear evolution through the exponential integrator.
    % Register WVNonlinearAdvection with qualified product quadrature, or select
    % thermalLinearDynamics=true explicitly for a linear configuration.
    %
    % ```matlab
    % w = WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4*ones(size(z)),thermalModeCount=17,mdaModeCount=4);
    % fields = w.reconstructFields(["qgpv","endpointAnomalies"]);
    % ```
    %
    % - Topic: Create and restore a transform
    % - Topic: Inspect coefficient families
    % - Topic: Evaluate physical fields
    % - Topic: Project physical states and sources
    % - Topic: Inspect scientific operators
    % - Topic: Inspect supported operations
    % - Declaration: classdef WVTransformFreeSurfaceThermalQG < WVTransform
    properties
        % Complex complete thermal amplitudes in m/s.
        % - Topic: Inspect coefficient families
        Ath
        % Real independent MDA displacement amplitudes in m.
        % - Topic: Inspect coefficient families
        Amda
    end
    properties (SetAccess=private)
        % Nonlinear quadrature policy and construction evidence.
        % - Topic: Inspect supported operations
        shouldCheckQuadraticAliasing
        % Nonlinear quadrature policy and construction evidence.
        % - Topic: Inspect supported operations
        nonlinearQuadratureCount
        % Nonlinear quadrature policy and construction evidence.
        % - Topic: Inspect supported operations
        nonlinearQuadratureTolerance
        % Nonlinear quadrature policy and construction evidence.
        % - Topic: Inspect supported operations
        nonlinearQuadratureResidual
        % Nonlinear quadrature policy and construction evidence.
        % - Topic: Inspect supported operations
        nonlinearReferenceResidual
        % Domain coordinate indices (1).
        % - Topic: Inspect scientific operators
        domainAxis
        % Domain lengths (m).
        % - Topic: Inspect scientific operators
        domainSize
        % Physical grid counts (1).
        % - Topic: Inspect scientific operators
        gridSize
        % Surface squared buoyancy frequency (s-2).
        % - Topic: Inspect scientific operators
        N20
        % Half logarithmic stratification gradient (m-1).
        % - Topic: Inspect scientific operators
        inverseScale
        % Immutable buoyancy diffusivity (m2 s-1).
        % - Topic: Inspect scientific operators
        kappa_z
        % Thermal scientific state schema (1).
        % - Topic: Inspect scientific operators
        schemaVersion
        % Ordinal complete thermal directions (1).
        % - Topic: Inspect scientific operators
        thermalDirection
        % Complete Legendre polynomial degrees (1).
        % - Topic: Inspect scientific operators
        polynomialDegree
        % Independent MDA directions (1).
        % - Topic: Inspect scientific operators
        mdaMode
        % Surface then bottom endpoint codes (1).
        % - Topic: Inspect scientific operators
        activeEndpoint
        % Compact nonzero Fourier indices (1).
        % - Topic: Inspect scientific operators
        klNonzero
        % Distinct horizontal radii (m-1).
        % - Topic: Inspect scientific operators
        khUnique
        % Radius page for each column (1).
        % - Topic: Inspect scientific operators
        klNonzeroKhUniqueIndex
        % Physical-depth sampling weights (m).
        % - Topic: Inspect scientific operators
        verticalQuadratureWeights
        % Streamfunction polynomial map for unit velocity amplitudes (m).
        % - Topic: Inspect scientific operators
        thermalToPolynomial
        % Inverse polynomial map (m-1).
        % - Topic: Inspect scientific operators
        polynomialToThermal
        % Weak source dual in polynomial trial coordinates (1).
        % - Topic: Inspect scientific operators
        sourceDual
        % Strict displacement-source projection (s-1).
        % - Topic: Inspect scientific operators
        sourceEndpoint
        % Unit-diffusivity eigenvalues, including null directions (m-2).
        % - Topic: Inspect scientific operators
        thermalRatesPerDiffusivity
        % Conjugate eigenvector permutation (1).
        % - Topic: Inspect scientific operators
        conjugateDirection
        % Positive physical energy metric including cross terms (1).
        % - Topic: Inspect scientific operators
        thermalEnergyGram
        % Physical-depth assembly quadrature count (1).
        % - Topic: Inspect scientific operators
        assemblyQuadratureCount
        % MDA sampling Gram allowance (1).
        % - Topic: Inspect scientific operators
        gramTolerance
        % MDA mode convergence allowance (1).
        % - Topic: Inspect scientific operators
        modeConvergenceTolerance
        % Boundary sampling allowance (1).
        % - Topic: Inspect scientific operators
        boundaryResolutionTolerance
        % MDA basis surface weight (m s-2).
        % - Topic: Inspect scientific operators
        mdaSurfaceWeight
        % MDA basis bottom weight (m s-2).
        % - Topic: Inspect scientific operators
        mdaBottomWeight
        % MDA displacement reconstruction (1).
        % - Topic: Inspect scientific operators
        mdaG
        % MDA displacement projector (1).
        % - Topic: Inspect scientific operators
        mdaGForward
        % MDA displacement derivative (m-1).
        % - Topic: Inspect scientific operators
        mdaGZ
        % Conservative mean diffusivity operator (m-2).
        % - Topic: Inspect scientific operators
        mdaGeneratorPerDiffusivity
        % Mean physical energy metric (s-2).
        % - Topic: Inspect scientific operators
        mdaEnergyGram
    end
    properties (Transient, SetAccess=private)
        % Construction evidence; empty after restoration.
        % - Topic: Create and restore a transform
        constructionAssessment = struct()
    end
    properties (Dependent)
        % Validated canonical arrays for cheap construction.
        % - Topic: Create and restore a transform
        scientificState
        % Number of complete thermal directions.
        % - Topic: Inspect coefficient families
        thermalModeCount
        % Number of independent mean directions.
        % - Topic: Inspect coefficient families
        mdaModeCount
        % Horizontally averaged, depth-integrated physical energy in m3 s-2.
        % - Topic: Evaluate physical fields
        totalEnergy
        % Horizontally averaged, depth-integrated physical energy in m3 s-2.
        % - Topic: Evaluate physical fields
        totalEnergySpatiallyIntegrated
        % Horizontally averaged, depth-integrated full QGPV enstrophy in m s-2.
        % - Topic: Evaluate physical fields
        totalPotentialEnstrophy
        % True for the balanced hydrostatic reconstruction.
        % - Topic: Inspect supported operations
        isHydrostatic
    end
    properties (Access=private)
        polynomialFields_ = []
        sourcePairing_ = []
        nonlinearMaps_ = []
        linearEvolutionData_ = []
        endpointGeometry_ = []
        physicalMetricOperators_ = []
        apvDecompositionData_ = []
    end
    methods
        function self = WVTransformFreeSurfaceThermalQG(options)
            % Construct from canonical scientific arrays without solving modes.
            % - Topic: Create and restore a transform
            % - Parameter options.scientificState: complete flat-array scientific contract
            % - Parameter options.coefficientState: optional Ath/Amda structure
            % - Parameter options.t: physical time in seconds
            arguments
                options.scientificState (1,1) struct
                options.coefficientState (1,1) struct = struct()
                options.t (1,1) double {mustBeReal,mustBeFinite} = 0
            end
            s=WVInternal.upgradeThermalState(options.scientificState);
            WVInternal.validateThermalState(s);
            nz=s.gridSize(3); n=numel(s.thermalDirection);
            N20=s.N20; a=s.inverseScale; g=s.g; rho0=s.rho0;
            N2Function=@(z)N20*exp(2*a*z);
            if a==0, rhoFunction=@(z)rho0*(1-N20*z/g); else, rhoFunction=@(z)rho0*(1-N20*expm1(2*a*z)/(2*a*g)); end
            % Empty legacy F/G matrices disable rigid-lid modal bootstrap.
            % Thermal reconstruction never consumes them.
            self@WVGeometryDoublyPeriodicStratified(s.domainSize.',s.gridSize.',z=s.z,j=(0:n-1)',Nj=n,N2Function=N2Function,rhoFunction=rhoFunction,rho0=rho0,latitude=s.latitude,g=g,shouldAntialias=logical(s.shouldAntialias),dLnN2=2*a*ones(nz,1),PF0inv=[],QG0inv=[],PF0=[],QG0=[],P0=[],Q0=[],h_0=[],z_int=s.verticalQuadratureWeights);
            self@WVTransform([WVForcingType.QGSpatial WVForcingType.QGSpectral]);
            schema=WVInternal.thermalStateSchema();
            inherited=["z","latitude","g","rho0","shouldAntialias"];
            for k=1:size(schema,1)
                name=string(schema{k,1});
                if ~ismember(name,inherited)
                    if schema{k,6}, self.(name)=complex(s.(name)); else, self.(name)=s.(name); end
                end
            end
            kh=hypot(self.k,self.l);
            if ~isequal(find(kh>0),s.klNonzero) || any(abs(kh(s.klNonzero)-s.khUnique(s.klNonzeroKhUniqueIndex))>1e-11*max(kh))
                error('WV:ThermalStoredGeometry','Stored horizontal layout is inconsistent with the geometry.');
            end
            self.hasWaveComponent=false; self.hasPVComponent=true;
            state=options.coefficientState;
            if isempty(fieldnames(state)), state=struct(Ath=complex(zeros(n,numel(s.klNonzero))),Amda=zeros(numel(s.mdaMode),1)); end
            if ~isequal(sort(string(fieldnames(state))),sort(["Ath";"Amda"]))
                error('WV:ThermalCoefficientState','Supply exactly the Ath and Amda families.');
            end
            self.Ath=state.Ath; self.Amda=state.Amda; self.t=options.t;
            names=self.namesOfTransformVariables(); endpoints={'ssh','ssu','ssv','endpointAnomalies'};
            interior=names(~ismember(names,endpoints));
            self.addOperation(self.operationForKnownVariable(interior{:}));
            self.addOperation(self.operationForKnownVariable(endpoints{:}));
            for family=["Ath","Amda"]
                component=WVFlowComponent(self,coefficientMasks=struct(family,true));
                component.name=family; component.shortName=lower(family); component.abbreviatedName=lower(family);
                self.addFlowComponent(component);
            end
        end
        function set.Ath(self,value)
            self.validateCoefficientValue(value,"Ath");
            self.Ath=complex(double(value)); self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function set.Amda(self,value)
            self.validateCoefficientValue(value,"Amda");
            self.Amda=double(value); self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function s=get.scientificState(self)
            schema=WVInternal.thermalStateSchema(); s=struct();
            for k=1:size(schema,1), s.(schema{k,1})=self.(schema{k,1}); end
        end
        function n=get.thermalModeCount(self), n=numel(self.thermalDirection); end
        function n=get.mdaModeCount(self), n=numel(self.mdaMode); end
        function value=get.isHydrostatic(~), value=true; end
        function value=get.totalEnergy(self)
            diagnostics=self.quadraticDiagnostics();
            value=diagnostics.totalEnergy;
        end
        function value=get.totalEnergySpatiallyIntegrated(self), value=self.totalEnergy; end
        function value=get.totalPotentialEnstrophy(self)
            diagnostics=self.quadraticDiagnostics();
            value=diagnostics.potentialEnstrophy;
        end
        [diagnostics,byWavenumber,horizontalMean]=quadraticDiagnostics(self,options)
        operators=physicalMetricOperators(self)
        energy=totalEnergyOfFlowComponent(self,flowComponent)
        [diagnostics,radialSpectrum]=physicalDiagnostics(self,options)
        [diagnosis,reconstruction]=apvDecomposition(self,apv,options)
        function other=withDiffusivity(self,kappa_z)
            % Copy the physical state and fixed basis with new scalar diffusivity.
            % - Topic: Create and restore a transform
            arguments
                self
                kappa_z (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
            end
            s=self.scientificState; s.kappa_z=kappa_z;
            other=WVTransformFreeSurfaceThermalQG(scientificState=s,coefficientState=self.coefficientState(),t=self.t);
        end
        function annotations=coefficientStateAnnotations(~)
            % Discover the two independent canonical families.
            % - Topic: Inspect coefficient families
            annotations=WVCoefficientAnnotation('Ath',{'thermalDirection','klNonzero'},'m s-1','Complete thermal amplitudes',canonicalBasis="complete balanced thermal modes",isComplex=true);
            annotations(end+1)=WVCoefficientAnnotation('Amda',{'mdaMode'},'m','Mean displacement amplitudes',canonicalBasis="signed-normalized MDA modes");
        end
        function out=coefficientAbsoluteTolerances(~,~) %#ok<STOUT>
            % Ordinary adaptive coefficient tolerances are not a thermal physical norm.
            % - Topic: Inspect supported operations
            error('WV:ThermalEvolutionUnavailable','Use exponential integration with thermalLinearDynamics=true and physical RMS tolerances.');
        end
        [tendency,speed,processes]=coefficientTendency(self,options)
        data=linearEvolutionData(self)
        [other,assessment]=waveVortexTransformWithResolution(self,Nxyz,options)
        [state,assessment]=coefficientStateForTransform(self,other,options)
        psiHat=boundaryStreamfunction(self,endpoint)
        tendency=boundaryMomentumTendency(self,tauXHat,tauYHat,endpoint)
        function varargout=nonlinearFlux(~,varargin) %#ok<STOUT>
            % Reject the legacy three-family flux signature.
            % - Topic: Inspect supported operations
            error('WV:ThermalEvolutionUnavailable','Use the family-keyed coefficientTendency with registered nonlinear advection.');
        end
        function out=transformFromSpatialDomainWithFg(~,varargin) %#ok<STOUT>
            % Reject legacy rigid-lid modal operations.
            % - Topic: Inspect supported operations
            error('WV:ThermalLegacyOperation','Use reconstructFields or projectState for the thermal peer.');
        end
        function out=transformFromSpatialDomainWithGg(~,varargin) %#ok<STOUT>
            % Reject legacy rigid-lid modal operations.
            % - Topic: Inspect supported operations
            error('WV:ThermalLegacyOperation','Use reconstructFields or projectState for the thermal peer.');
        end
        function out=transformToSpatialDomainWithF(~,varargin) %#ok<STOUT>
            % Reject legacy rigid-lid modal operations.
            % - Topic: Inspect supported operations
            error('WV:ThermalLegacyOperation','Use reconstructFields or projectState for the thermal peer.');
        end
        function out=transformToSpatialDomainWithG(~,varargin) %#ok<STOUT>
            % Reject legacy rigid-lid modal operations.
            % - Topic: Inspect supported operations
            error('WV:ThermalLegacyOperation','Use reconstructFields or projectState for the thermal peer.');
        end
        [tendency,speed,diagnostics]=nonlinearCoefficientTendency(self)
        fields=reconstructFields(self,variableNames,options)
        operation=operationForKnownVariable(self,variableName,options)
        [state,residual]=projectState(self,qgpv,endpointAnomalies,options)
        tendency=projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
        [q,u,v,b,ub,vb,phiHat]=quasigeostrophicSpatialState(self)
        derivative=diffZ(self,field,order)
    end
    methods (Access=protected)
        function validateForcingInventory(self,forces)
            for force=forces
                if isa(force,'WVVerticalDiffusivity')
                    error('WV:ThermalDiffusionOwnership','Thermal diffusivity belongs to the transform; use withDiffusivity.');
                end
                if isa(force,'WVThermalAPVDamping') || isa(force,'WVAdaptiveDamping'), continue; end
                if isa(force,'WVNonlinearAdvection')
                    if ~self.shouldCheckQuadraticAliasing || ~self.shouldAntialias
                        error('WV:ThermalNonlinearQualification','Nonlinear advection requires qualified product quadrature and horizontal antialiasing.');
                    end
                    continue
                end
                if ~isa(force,'WVSeasonalSurfaceAnomalyForcing') && (~any(force.forcingType==WVForcingType("QGSpectral")) || force.isClosure)
                    error('WV:ThermalForcingUnavailable','T3 supports seasonal and coefficient-source adapters; physical nonlinear forcings require T4-T6.');
                end
            end
        end
    end
    methods (Access=private)
        function validateCoefficientValue(self,value,name)
            if name=="Ath"
                valid=isnumeric(value) && isequal(size(value),[self.thermalModeCount,numel(self.klNonzero)]) && all(isfinite(value),'all');
                if ~valid, error('WV:ThermalCoefficientShape','Ath must be a finite thermalModeCount-by-nonzeroFourierCount array.'); end
            else
                valid=isnumeric(value) && isreal(value) && isequal(size(value),[self.mdaModeCount,1]) && all(isfinite(value));
                if ~valid, error('WV:ThermalMeanShape','Amda must be a finite real mdaModeCount-by-1 array.'); end
            end
        end
        [r,C]=polynomialState(self,state)
        geometry=endpointGeometry(self)
    end
    methods (Static)
        w=fromStratification(domainSize,gridSize,options)
        [w,file]=waveVortexTransformFromFile(path,options)
        w=annotatedClassFromGroup(group)
        function names=spatialDimensionNames()
            % Return native physical coordinate names.
            % - Topic: Inspect supported operations
            names={'x','y','z'};
        end
        function names=spectralDimensionNames()
            % Return thermal coefficient coordinate names.
            % - Topic: Inspect supported operations
            names={'thermalDirection','klNonzero'};
        end
        function names=namesOfTransformVariables()
            % List the supported physical reconstructions.
            % - Topic: Inspect scientific operators
            names={'psi','u','v','eta','eta_i','buoyancy','qgpv','ssh','ssu','ssv','uvMax','endpointAnomalies'};
        end
        function names=classRequiredPropertyNames()
            % List canonical flat arrays required for restoration.
            % - Topic: Inspect scientific operators
            schema=WVInternal.thermalStateSchema(); names=[schema(:,1).',{'Ath','Amda','t','t0','forcing','x','y'}];
        end
        function annotations=classDefinedPropertyAnnotations()
            % Describe scientific arrays and coefficients for NetCDF.
            % - Topic: Inspect scientific operators
            annotations=WVGeometryDoublyPeriodicStratified.propertyAnnotationsForGeometry();
            schema=WVInternal.thermalStateSchema();
            for k=1:size(schema,1)
                if schema{k,5}
                    annotation=CADimensionProperty(schema{k,1},schema{k,3},schema{k,4});
                else
                    annotation=CANumericProperty(schema{k,1},schema{k,2},schema{k,3},schema{k,4},isComplex=schema{k,6});
                end
                annotations(end+1)=annotation; %#ok<AGROW> Bounded annotation metadata.
            end
            annotations(end+1)=WVCoefficientAnnotation('Ath',{'thermalDirection','klNonzero'},'m s-1','Complete thermal amplitudes',canonicalBasis="complete balanced thermal modes",isComplex=true);
            annotations(end+1)=CANumericProperty('t0',{},'s','Reference time');
            annotations(end+1)=CAObjectProperty('forcing','Registered forcing configuration');
            annotations(end+1)=WVCoefficientAnnotation('Amda',{'mdaMode'},'m','Mean displacement amplitudes',canonicalBasis="signed-normalized MDA modes");
            annotations(end+1)=CANumericProperty('t',{},'s','Physical time');
        end
    end
end
