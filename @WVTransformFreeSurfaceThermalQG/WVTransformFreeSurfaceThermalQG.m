classdef WVTransformFreeSurfaceThermalQG < WVGeometryDoublyPeriodicStratified & WVTransform
    % Reconstruct complete balanced thermal states with two active boundaries.
    %
    % Ath has velocity units and Amda retains the independent real MDA state.
    % The scientific factory retains every requested polynomial direction.
    % This increment supports construction, fields, projections and snapshots;
    % model evolution and registered forcing are deliberately unavailable.
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
        % Positive depth-averaged physical energy per unit mass.
        % - Topic: Evaluate physical fields
        totalEnergy
        % Volume-integrated physical energy per unit reference density.
        % - Topic: Evaluate physical fields
        totalEnergySpatiallyIntegrated
        % True for the balanced hydrostatic reconstruction.
        % - Topic: Inspect supported operations
        isHydrostatic
    end
    properties (Access=private)
        polynomialFields_ = []
        sourcePairing_ = []
        endpointGeometry_ = []
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
            s=options.scientificState;
            WVInternal.validateThermalState(s);
            nz=s.gridSize(3); n=numel(s.thermalDirection);
            N20=s.N20; a=s.inverseScale; g=s.g; rho0=s.rho0;
            N2Function=@(z)N20*exp(2*a*z);
            if a==0, rhoFunction=@(z)rho0*(1-N20*z/g); else, rhoFunction=@(z)rho0*(1-N20*expm1(2*a*z)/(2*a*g)); end
            % Empty legacy F/G matrices disable rigid-lid modal bootstrap.
            % Thermal reconstruction never consumes them.
            self@WVGeometryDoublyPeriodicStratified(s.domainSize.',s.gridSize.',z=s.z,j=(0:n-1)',Nj=n,N2Function=N2Function,rhoFunction=rhoFunction,rho0=rho0,latitude=s.latitude,g=g,shouldAntialias=logical(s.shouldAntialias),dLnN2=2*a*ones(nz,1),PF0inv=[],QG0inv=[],PF0=[],QG0=[],P0=[],Q0=[],h_0=[],z_int=s.verticalQuadratureWeights);
            self@WVTransform(WVForcingType.QGSpectral);
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
            value=0;
            for p=1:numel(self.khUnique)
                c=self.Ath(:,self.klNonzeroKhUniqueIndex==p);
                value=value+real(sum(conj(c).*(self.thermalEnergyGram(:,:,p)*c),'all'));
            end
            value=value+real(self.Amda'*self.mdaEnergyGram*self.Amda)/2;
        end
        function value=get.totalEnergySpatiallyIntegrated(self), value=self.Lx*self.Ly*self.Lz*self.totalEnergy; end
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
            % Reject adaptive integration until T3 supplies physical error control.
            % - Topic: Inspect supported operations
            error('WV:ThermalEvolutionUnavailable','Thermal integration and error control require T3.');
        end
        function out=coefficientTendency(~,varargin) %#ok<STOUT>
            % Reject an incomplete ordinary RHS rather than omit diffusion.
            % - Topic: Inspect supported operations
            error('WV:ThermalEvolutionUnavailable','Use construction and projection only; thermal evolution requires T3.');
        end
        function addForcing(~,varargin)
            % Reject forcing until thermal physical adapters are qualified.
            % - Topic: Inspect supported operations
            error('WV:ThermalForcingUnavailable','Thermal forcing requires T3/T5; do not register a second diffusivity.');
        end
        function out=waveVortexTransformWithResolution(~,varargin) %#ok<STOUT>
            % Reject unqualified resolution transfer.
            % - Topic: Inspect supported operations
            error('WV:ThermalTransferUnavailable','Construct a target explicitly; qualified transfer belongs to T8.');
        end
        function varargout=nonlinearFlux(~,varargin) %#ok<STOUT>
            % Reject unqualified nonlinear evolution.
            % - Topic: Inspect supported operations
            error('WV:ThermalEvolutionUnavailable','Thermal nonlinear evolution requires T4.');
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
        fields=reconstructFields(self,variableNames,options)
        operation=operationForKnownVariable(self,variableName,options)
        [state,residual]=projectState(self,qgpv,endpointAnomalies,options)
        tendency=projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
        [q,u,v,b,ub,vb,phiHat]=quasigeostrophicSpatialState(self)
        derivative=diffZ(self,field,order)
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
            schema=WVInternal.thermalStateSchema(); names=[schema(:,1).',{'Ath','Amda','t'}];
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
            annotations(end+1)=WVCoefficientAnnotation('Amda',{'mdaMode'},'m','Mean displacement amplitudes',canonicalBasis="signed-normalized MDA modes");
            annotations(end+1)=CANumericProperty('t',{},'s','Physical time');
        end
    end
end
