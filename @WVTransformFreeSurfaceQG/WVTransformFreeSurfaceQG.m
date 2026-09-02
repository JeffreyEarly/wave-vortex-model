classdef WVTransformFreeSurfaceQG < WVGeometryDoublyPeriodicStratified & WVTransform
    % Represent free-surface quasigeostrophic flow in canonical families.
    %
    % The nonzero-horizontal-wavenumber state is split into generalized-
    % energy APV coefficients `Ag_q` and boundary-normalized zero-APV
    % coefficients `Ag_0`. The horizontal mean is represented independently
    % by real mean-density-anomaly coefficients `Amda`.
    % APV and MDA select independent mode counts on the same
    % physical vertical grid. The inherited `Nj` value equals
    % `apvModeCount`; `mdaModeCount` may differ.
    % Omitted endpoints use $$g_0=-\int_{-D}^{0}N^2\,dz$$ and
    % $$g_d=\mathop{\rm Inf}$$. The resulting APV family normally includes
    % a negative mode. InternalModes retains that mode and uses its signed
    % Pontryagin pairing for projection; coupled quadratic errors are
    % positive magnitudes in the induced Hilbert majorant.
    %
    % Scientific construction solves the InternalModesEVP problems once and
    % stores every sampled mode and projection operator. Persisted-state
    % construction supplies those annotated arrays directly and never calls
    % an InternalModes solver.
    %
    % ```matlab
    % N2 = @(z) (5.2e-3)^2*exp(2*z/1300);
    % wvt = WVTransformFreeSurfaceQG([100e3 100e3 4000],[32 32 33],N2Function=N2,latitude=30);
    % ```
    %
    % - Topic: Create and restore a transform
    % - Topic: Initialize the flow
    % - Topic: Inspect coefficient families
    % - Topic: Inspect modes and operators
    % - Topic: Transform coefficient state
    % - Topic: Evaluate physical fields
    % - Topic: Save transform state
    % - Declaration: classdef WVTransformFreeSurfaceQG < WVTransform

    properties (GetAccess = public, SetAccess = public)
        % Generalized-energy APV coefficients in inverse seconds.
        % - Topic: Inspect coefficient families
        Ag_q

        % Boundary-normalized zero-APV coefficients in inverse seconds.
        % - Topic: Inspect coefficient families
        Ag_0

        % Real mean-density-anomaly displacement coefficients in meters.
        % - Topic: Inspect coefficient families
        Amda
    end

    properties (GetAccess = public, SetAccess = private)
        % Effective surface acceleration; omitted default is `-integral(N2,-Lz,0)`.
        % - Topic: Inspect modes and operators
        g0
        % Effective bottom acceleration; omitted default is `Inf`.
        % - Topic: Inspect modes and operators
        gd
        % Number of finite endpoint accelerations.
        % - Topic: Inspect modes and operators
        activeEndpointCount
        % Numeric endpoint codes, surface `1` then bottom `2`.
        % - Topic: Inspect modes and operators
        activeEndpoint
        % Matching source-endpoint coordinate codes.
        % - Topic: Inspect modes and operators
        sourceEndpoint

        % Ordinal APV family coordinate.
        % - Topic: Inspect modes and operators
        apvMode
        % Physical APV mode labels.
        % - Topic: Inspect modes and operators
        apvModeNumber
        % Ordinal MDA family coordinate.
        % - Topic: Inspect modes and operators
        mdaMode
        % Physical MDA mode labels.
        % - Topic: Inspect modes and operators
        mdaModeNumber

        % Original full-`kl` indices retained at positive horizontal wavenumber.
        % - Topic: Inspect modes and operators
        klNonzero
        % X wavenumber associated with `klNonzero`.
        % - Topic: Inspect modes and operators
        kNonzero
        % Y wavenumber associated with `klNonzero`.
        % - Topic: Inspect modes and operators
        lNonzero
        % Horizontal-wavenumber magnitude associated with `klNonzero`.
        % - Topic: Inspect modes and operators
        khNonzero
        % Distinct positive horizontal-wavenumber pages.
        % - Topic: Inspect modes and operators
        khUnique
        % One-based map from `klNonzero` to `khUnique`.
        % - Topic: Inspect modes and operators
        klNonzeroKhUniqueIndex

        % Sampled APV F modes.
        % - Topic: Inspect modes and operators
        apvF
        % Sampled APV G modes.
        % - Topic: Inspect modes and operators
        apvG
        % APV F projection matrix.
        % - Topic: Inspect modes and operators
        apvFForward
        % APV G projection matrix.
        % - Topic: Inspect modes and operators
        apvGForward
        % APV equivalent depths.
        % - Topic: Inspect modes and operators
        apvEquivalentDepth
        % APV inversion eigenvalues for each horizontal page.
        % - Topic: Inspect modes and operators
        apvMu
        % APV endpoint responses for each active endpoint and page.
        % - Topic: Inspect modes and operators
        apvEndpointResponse
        % APV F source-pairing operator.
        % - Topic: Inspect modes and operators
        apvFSourcePairing
        % APV G source-pairing operator.
        % - Topic: Inspect modes and operators
        apvGSourcePairing

        % Sampled MDA F modes.
        % - Topic: Inspect modes and operators
        mdaF
        % Sampled MDA G modes.
        % - Topic: Inspect modes and operators
        mdaG
        % MDA G projection matrix.
        % - Topic: Inspect modes and operators
        mdaGForward
        % MDA equivalent depths.
        % - Topic: Inspect modes and operators
        mdaEquivalentDepth
        % Shared positive physical quadrature weights.
        % - Topic: Inspect modes and operators
        verticalQuadratureWeights
        % Physical first-derivative matrix on the shared increasing-z grid.
        % - Topic: Inspect modes and operators
        verticalDerivativeMatrix

        % Shared vertical-grid design kind, `chebyshevLobatto`.
        % - Topic: Inspect modes and operators
        verticalGridKind
        % Coordinate in which the vertical-grid rule is native.
        % - Topic: Inspect modes and operators
        verticalGridCoordinate

        % Sampled boundary-normalized zero-APV F pages.
        % - Topic: Inspect modes and operators
        zeroAPVF
        % Sampled boundary-normalized zero-APV G pages.
        % - Topic: Inspect modes and operators
        zeroAPVG
        % Zero-APV F source-pairing matrices.
        % - Topic: Inspect modes and operators
        zeroAPVFPairing
        % Zero-APV G source-pairing matrices.
        % - Topic: Inspect modes and operators
        zeroAPVGPairing
        % Pagewise zero-APV source-solve matrices.
        % - Topic: Inspect modes and operators
        zeroAPVSourceSolve

        % Worst retained APV Gram error.
        % - Topic: Inspect modes and operators
        apvGramError
        % Worst retained APV sampled round-trip error.
        % - Topic: Inspect modes and operators
        apvRoundTripError
        % Retained MDA Gram error.
        % - Topic: Inspect modes and operators
        mdaGramError
        % Retained MDA sampled round-trip error.
        % - Topic: Inspect modes and operators
        mdaRoundTripError
        % Normalized Gram tolerance used for APV selection.
        % - Topic: Inspect modes and operators
        apvGramTolerance
        % Normalized Gram tolerance used for MDA selection.
        % - Topic: Inspect modes and operators
        mdaGramTolerance
        % Coupled quadratic-aliasing tolerance used for APV selection.
        %
        % Continuous and sampled projections use the signed Pontryagin
        % pairing. Their difference and the source-product magnitude are
        % measured with the induced positive Hilbert majorant.
        % - Topic: Inspect modes and operators
        quadraticAliasingTolerance
        % Coupled quadratic-aliasing error at the selected APV count.
        %
        % This is a positive relative error in the induced Hilbert
        % majorant, not a signed generalized-energy self-pairing.
        % - Topic: Inspect modes and operators
        quadraticAliasingError
        % Product channel limiting the selected APV prefix.
        % - Topic: Inspect modes and operators
        quadraticAliasingLimitingChannel
        % First physical mode label in the limiting product.
        % - Topic: Inspect modes and operators
        quadraticAliasingLimitingModeNumberI
        % Second physical mode label in the limiting product.
        % - Topic: Inspect modes and operators
        quadraticAliasingLimitingModeNumberJ
        % Minimum relative APV inversion-eigenvalue separation.
        % - Topic: Inspect modes and operators
        minimumRelativeMuSeparation
        % Relative singularity tolerance used for APV inversion.
        % - Topic: Inspect modes and operators
        muTolerance
        % Pagewise zero-APV generalized-energy reciprocal condition.
        % - Topic: Inspect modes and operators
        zeroAPVGramReciprocalCondition
        % Pagewise zero-APV generalized-energy relative separation.
        % - Topic: Inspect modes and operators
        zeroAPVGramRelativeSeparation
        % APV/zero-APV quadratic-product error at maximum horizontal wavenumber.
        % - Topic: Inspect modes and operators
        apvZeroAPVQuadraticError
        % Active endpoint limiting the APV/zero-APV product error.
        % - Topic: Inspect modes and operators
        apvZeroAPVLimitingEndpoint
        % APV physical mode label limiting the APV/zero-APV product error.
        % - Topic: Inspect modes and operators
        apvZeroAPVLimitingModeNumber
        % Persisted mode-selection method identifier.
        % - Topic: Inspect modes and operators
        modeSelectionMethod
    end

    properties (Access = private, Transient)
        % Rebuildable unit-diffusivity operators derived from the fixed
        % vertical modes, quadrature rule, and endpoint configuration.
        hasThermalCoefficientOperators_ (1,1) logical = false
        thermalDiffusionOperatorByKh_ = []
        thermalDiffusionOperatorByKl_ = []
        thermalMDADiffusionOperator_ = []
        thermalSurfaceFluxOperatorByKh_ = []
        thermalBottomFluxOperatorByKh_ = []
        thermalSurfaceMDAFluxOperator_ = []
        thermalBottomMDAFluxOperator_ = []
    end

    properties (Dependent)
        % Spatially integrated quasigeostrophic energy.
        % - Topic: Evaluate physical fields
        totalEnergySpatiallyIntegrated
        % Spectral-state energy evaluated through the physical reconstruction.
        % - Topic: Evaluate physical fields
        totalEnergy
        % Whether this transform uses hydrostatic balance.
        % - Topic: Inspect modes and operators
        isHydrostatic
    end

    properties (Dependent, SetAccess = private)
        % Number of retained APV modes.
        %
        % This is `length(apvMode)` and equals the inherited `Nj` value.
        % - Topic: Inspect modes and operators
        apvModeCount
        % Number of retained MDA modes.
        %
        % This is `length(mdaMode)` and is independent of `apvModeCount`.
        % - Topic: Inspect modes and operators
        mdaModeCount
        % Reconstructed geostrophic streamfunction.
        % - Topic: Evaluate physical fields
        psi
        % Reconstructed x velocity.
        % - Topic: Evaluate physical fields
        u
        % Reconstructed y velocity.
        % - Topic: Evaluate physical fields
        v
        % Maximum reconstructed horizontal speed.
        % - Topic: Evaluate physical fields
        uvMax
        % Reconstructed isopycnal displacement including MDA.
        % - Topic: Evaluate physical fields
        eta
        % Reconstructed APV field.
        % - Topic: Evaluate physical fields
        qgpv
    end

    methods
        function self = WVTransformFreeSurfaceQG(Lxyz,Nxyz,options)
            % Create a free-surface QG transform scientifically or directly.
            %
            % Omitted `g0` uses $$-\int_{-D}^{0}N^2\,dz$$ and omitted `gd`
            % is `Inf`. A finite endpoint, including zero, activates one
            % boundary-normalized zero-APV family row. Supplying every
            % persisted mode/operator option selects the direct construction
            % path and performs no InternalModes solve.
            %
            % - Topic: Create and restore a transform
            % - Declaration: wvt = WVTransformFreeSurfaceQG(Lxyz,Nxyz,options)
            % - Parameter Lxyz: domain lengths `[Lx Ly Lz]` in meters
            % - Parameter Nxyz: grid counts `[Nx Ny Nz]`
            % - Parameter options.N2Function: squared buoyancy-frequency function
            % - Parameter options.rhoFunction: no-motion density function
            % - Parameter options.g0: surface acceleration; default stratification integral
            % - Parameter options.gd: bottom acceleration; default `Inf`
            % - Parameter options.apvGramTolerance: APV normalized-Gram tolerance
            % - Parameter options.mdaGramTolerance: MDA normalized-Gram tolerance
            % - Parameter options.quadraticAliasingTolerance: APV quadratic-product tolerance in the induced Hilbert majorant
            % - Parameter options.muTolerance: APV inversion singularity tolerance
            % - Returns wvt: new `WVTransformFreeSurfaceQG` instance
            arguments
                Lxyz (1,3) double {mustBePositive}
                Nxyz (1,3) double {mustBeInteger,mustBePositive}
                options.shouldAntialias (1,1) logical = true
                options.N2Function function_handle = @isempty
                options.rhoFunction function_handle = @isempty
                options.rho0 (1,1) double {mustBePositive} = 1025
                options.planetaryRadius (1,1) double {mustBePositive} = 6.371e6
                options.rotationRate (1,1) double {mustBePositive} = 7.2921e-5
                options.latitude (1,1) double {mustBeSupportedLatitude} = 33
                options.g (1,1) double {mustBePositive} = 9.81
                options.g0 (1,1) double = NaN
                options.gd (1,1) double = Inf
                options.z (:,1) double = zeros(0,1)
                options.j (:,1) double
                options.apvGramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-2
                options.mdaGramTolerance (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 1e-2
                options.quadraticAliasingTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 0.1
                options.muTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = sqrt(eps)

                options.dLnN2 (:,1) double
                options.PF0inv double
                options.QG0inv double
                options.PF0 double
                options.QG0 double
                options.P0 (:,1) double
                options.Q0 (:,1) double
                options.h_0 (:,1) double
                options.z_int (:,1) double

                options.Ag_q double
                options.Ag_0 double
                options.Amda double {mustBeReal}
                options.activeEndpointCount (1,1) double {mustBeInteger,mustBeNonnegative}
                options.activeEndpoint (:,1) double
                options.sourceEndpoint (:,1) double
                options.apvMode (:,1) double
                options.apvModeNumber (:,1) double
                options.mdaMode (:,1) double
                options.mdaModeNumber (:,1) double
                options.klNonzero (:,1) double
                options.kNonzero (:,1) double
                options.lNonzero (:,1) double
                options.khNonzero (:,1) double
                options.khUnique (:,1) double
                options.klNonzeroKhUniqueIndex (:,1) double
                options.apvF double
                options.apvG double
                options.apvFForward double
                options.apvGForward double
                options.apvEquivalentDepth (:,1) double
                options.apvMu double
                options.apvEndpointResponse double
                options.apvFSourcePairing double
                options.apvGSourcePairing double
                options.mdaF double
                options.mdaG double
                options.mdaGForward double
                options.mdaEquivalentDepth (:,1) double
                options.verticalQuadratureWeights (:,1) double
                options.verticalDerivativeMatrix double
                options.verticalGridKind (1,1) string
                options.verticalGridCoordinate (1,1) string
                options.zeroAPVF double
                options.zeroAPVG double
                options.zeroAPVFPairing double
                options.zeroAPVGPairing double
                options.zeroAPVSourceSolve double
                options.apvGramError (1,1) double
                options.apvRoundTripError (1,1) double
                options.mdaGramError (1,1) double
                options.mdaRoundTripError (1,1) double
                options.quadraticAliasingError (1,1) double
                options.quadraticAliasingLimitingChannel (1,1) string
                options.quadraticAliasingLimitingModeNumberI (1,1) double
                options.quadraticAliasingLimitingModeNumberJ (1,1) double
                options.minimumRelativeMuSeparation (1,1) double
                options.zeroAPVGramReciprocalCondition double
                options.zeroAPVGramRelativeSeparation double
                options.apvZeroAPVQuadraticError (1,1) double
                options.apvZeroAPVLimitingEndpoint (1,1) string
                options.apvZeroAPVLimitingModeNumber (1,1) double
                options.modeSelectionMethod (1,1) string
            end

            directNames = WVTransformFreeSurfaceQG.directConstructionPropertyNames();
            isDirect = all(isfield(options,directNames));
            if isDirect
                state = options;
                if state.activeEndpointCount > 0
                    requiredZeroNames = setdiff(WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames(),{'Ag_0'});
                    if ~all(isfield(state,requiredZeroNames))
                        missing = requiredZeroNames(~isfield(state,requiredZeroNames));
                        error('WVTransformFreeSurfaceQG:IncompletePersistedState','Direct construction is missing zero-APV properties: %s.',strjoin(missing,', '));
                    end
                    if ~isfield(state,'Ag_0')
                        state.Ag_0 = complex(zeros(state.activeEndpointCount,length(state.klNonzero)));
                    end
                else
                    state.activeEndpoint = zeros(0,1);
                    state.sourceEndpoint = zeros(0,1);
                    state.Ag_0 = complex(zeros(0,length(state.klNonzero)));
                    state.apvEndpointResponse = zeros(0,length(state.apvMode),length(state.khUnique));
                    state.zeroAPVF = zeros(length(state.z),0,length(state.khUnique));
                    state.zeroAPVG = zeros(length(state.z),0,length(state.khUnique));
                    state.zeroAPVFPairing = zeros(0,length(state.z),length(state.khUnique));
                    state.zeroAPVGPairing = zeros(0,length(state.z),length(state.khUnique));
                    state.zeroAPVSourceSolve = zeros(0,0,length(state.khUnique));
                    state.zeroAPVGramReciprocalCondition = zeros(0,1);
                    state.zeroAPVGramRelativeSeparation = zeros(0,1);
                    state.apvZeroAPVQuadraticError = NaN;
                    state.apvZeroAPVLimitingEndpoint = "";
                    state.apvZeroAPVLimitingModeNumber = NaN;
                end
            else
                state = WVTransformFreeSurfaceQG.buildScientificState(Lxyz,Nxyz,options);
            end

            geometryOptions = struct(shouldAntialias=options.shouldAntialias,z=state.z,j=state.apvModeNumber,Nj=length(state.apvMode),N2Function=state.N2Function,rhoFunction=state.rhoFunction,rho0=options.rho0,planetaryRadius=options.planetaryRadius,rotationRate=options.rotationRate,latitude=options.latitude,g=options.g,dLnN2=state.dLnN2,PF0inv=state.PF0inv,QG0inv=state.QG0inv,PF0=state.PF0,QG0=state.QG0,P0=state.P0,Q0=state.Q0,h_0=state.h_0,z_int=state.z_int);
            geometryArguments = namedargs2cell(geometryOptions);
            self@WVGeometryDoublyPeriodicStratified(Lxyz,Nxyz,geometryArguments{:});
            self@WVTransform(WVForcingType(["QGSpatial" "QGSpectral"]));

            stateNames = WVTransformFreeSurfaceQG.persistedScientificPropertyNames();
            for iProperty = 1:length(stateNames)
                self.(stateNames{iProperty}) = state.(stateNames{iProperty});
            end
            self.hasWaveComponent = false;
            self.hasPVComponent = true;
            self.Ag_q = state.Ag_q;
            self.Ag_0 = state.Ag_0;
            self.Amda = state.Amda;
            self.addForcing(WVNonlinearAdvection(self));
        end

        function set.Ag_q(self,value)
            self.validateAgq(value);
            self.Ag_q = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end

        function set.Ag_0(self,value)
            self.validateAg0(value);
            self.Ag_0 = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end

        function set.Amda(self,value)
            self.validateAmda(value);
            self.Amda = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end

        function annotations = coefficientStateAnnotations(~)
            % Return the canonical free-surface coefficient-family order.
            % - Topic: Inspect coefficient families
            annotations = WVCoefficientAnnotation.empty(0,0);
            annotations(end+1) = WVCoefficientAnnotation('Ag_q',{'apvMode','klNonzero'},'s-1','generalized-energy APV coefficients',auxiliaryCoordinates=["apvModeNumber" "kNonzero" "lNonzero" "khNonzero"],canonicalBasis="generalized-energy APV modes",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Ag_0',{'activeEndpoint','klNonzero'},'s-1','boundary-normalized zero-APV coefficients',auxiliaryCoordinates=["kNonzero" "lNonzero" "khNonzero"],canonicalBasis="boundary-normalized zero-APV responses",emptyFamilyPolicy="omit",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Amda',{'mdaMode'},'m','mean-density-anomaly displacement coefficients',auxiliaryCoordinates="mdaModeNumber",canonicalBasis="signed-normalized mean-density-anomaly modes",isComplex=false);
        end

        function tolerances = coefficientAbsoluteTolerances(self,absTolerance)
            % Return uniform family-local tolerances for the prototype.
            % - Topic: Inspect coefficient families
            annotations = self.coefficientStateAnnotations();
            tolerances = struct();
            for iFamily = 1:length(annotations)
                name = annotations(iFamily).name;
                tolerances.(name) = absTolerance*ones(size(self.(name)));
            end
        end

        function tendency = coefficientTendency(self)
            % Evaluate the family-keyed free-surface QG tendency.
            %
            % Every registered `QGSpatial` object contributes an interior
            % QGPV tendency and active-endpoint anomaly tendencies. Their
            % accumulated physical state is projected APV first and residual
            % zero APV second. Registered `QGSpectral` objects then modify
            % the family-keyed coefficient tendency directly. One local
            % reconstruction is shared by all forcing objects during this
            % evaluation; it is not retained as transform cache state.
            %
            % - Topic: Transform coefficient state
            % - Declaration: tendency = coefficientTendency(self)
            % - Returns tendency: scalar structure with `Ag_q`, `Ag_0`, and `Amda` tendencies
            Fq = zeros(self.spatialMatrixSize);
            Fb = zeros(self.Nx,self.Ny,self.activeEndpointCount);
            physicalState = struct();
            if ~isempty(self.spatialFluxForcing) || ~isempty(self.spectralFluxForcing)
                [q,uPhysical,vPhysical,b,ub,vb] = self.quasigeostrophicSpatialState();
                physicalState = struct('q',q,'u',uPhysical,'v',vPhysical,'b',b,'ub',ub,'vb',vb,'uvMax',max(hypot(uPhysical,vPhysical),[],"all"));
            end
            for iForcing = 1:length(self.spatialFluxForcing)
                [Fq,Fb] = self.spatialFluxForcing(iForcing).addQuasigeostrophicSpatialForcing(self,Fq,Fb,physicalState);
            end
            tendency = self.projectQuasigeostrophicSpatialTendency(Fq,Fb);
            for iForcing = 1:length(self.spectralFluxForcing)
                tendency = self.spectralFluxForcing(iForcing).addQuasigeostrophicSpectralForcing(self,tendency,physicalState);
            end
        end

        function [Fq,Fzero,Fmda] = nonlinearFlux(self)
            % Adapt the abstract legacy signature to the family-keyed RHS.
            % - Topic: Transform coefficient state
            tendency = self.coefficientTendency();
            Fq = tendency.Ag_q;
            Fzero = tendency.Ag_0;
            Fmda = tendency.Amda;
        end

        function value = get.psi(self)
            [psiHat,~,~] = self.reconstructSpectralState();
            value = self.transformToSpatialDomainWithFourier(psiHat);
        end

        function value = get.apvModeCount(self)
            value = length(self.apvMode);
        end

        function value = get.mdaModeCount(self)
            value = length(self.mdaMode);
        end

        function value = get.u(self)
            [psiHat,~,~] = self.reconstructSpectralState();
            value = self.transformToSpatialDomainWithFourier(-sqrt(-1)*reshape(self.l,1,[]).*psiHat);
        end

        function value = get.v(self)
            [psiHat,~,~] = self.reconstructSpectralState();
            value = self.transformToSpatialDomainWithFourier(sqrt(-1)*reshape(self.k,1,[]).*psiHat);
        end

        function value = get.uvMax(self)
            [psiHat,~,~] = self.reconstructSpectralState();
            u_ = self.transformToSpatialDomainWithFourier(-sqrt(-1)*reshape(self.l,1,[]).*psiHat);
            v_ = self.transformToSpatialDomainWithFourier(sqrt(-1)*reshape(self.k,1,[]).*psiHat);
            value = max(hypot(u_,v_),[],"all");
        end

        function value = get.eta(self)
            [~,etaHat,~] = self.reconstructSpectralState();
            value = self.transformToSpatialDomainWithFourier(etaHat);
        end

        function value = get.qgpv(self)
            [~,~,qHat] = self.reconstructSpectralState();
            value = self.transformToSpatialDomainWithFourier(qHat);
        end

        function energy = get.totalEnergySpatiallyIntegrated(self)
            u_ = self.u;
            v_ = self.v;
            eta_ = self.eta;
            energy = sum(self.z_int.*squeeze(mean(mean(u_.^2+v_.^2+reshape(self.N2,1,1,[]).*eta_.^2,1),2)))/2;
        end

        function energy = get.totalEnergy(self)
            energy = self.totalEnergySpatiallyIntegrated;
        end

        function value = get.isHydrostatic(~)
            value = true;
        end

        function wvtX2 = waveVortexTransformWithResolution(~,~)
            % Defer free-surface resolution transfer to milestone issue #352.
            wvtX2 = WVTransformFreeSurfaceQG.empty(0,0);
            WVTransformFreeSurfaceQG.throwUnavailable('WVTransformFreeSurfaceQG:ResolutionTransferUnavailable','Resolution transfer is not yet implemented for WVTransformFreeSurfaceQG.');
        end

        function values = transformFromSpatialDomainWithFg(self,values)
            values = self.apvFForward*values;
        end

        function values = transformFromSpatialDomainWithGg(self,values)
            values = self.apvGForward*values;
        end

        function values = transformToSpatialDomainWithF(~,~)
            values = [];
            WVTransformFreeSurfaceQG.throwUnavailable('WVTransformFreeSurfaceQG:UseCanonicalFamilies','Use reconstructSpectralState or the `psi`, `u`, and `v` properties with canonical free-surface coefficient families.');
        end

        function values = transformToSpatialDomainWithG(~,~)
            values = [];
            WVTransformFreeSurfaceQG.throwUnavailable('WVTransformFreeSurfaceQG:UseCanonicalFamilies','Use reconstructSpectralState or the `eta` property with canonical free-surface coefficient families.');
        end
    end

    methods (Access = private)
        function ensureThermalCoefficientOperators(self)
            if self.hasThermalCoefficientOperators_
                return
            end

            N2 = reshape(self.N2,[],1);
            weights = self.verticalQuadratureWeights;
            Dz = self.verticalDerivativeMatrix;
            verticalOperator = -(Dz.'*(weights.*(Dz.*N2.')))./(weights.*N2);
            if ~any(self.activeEndpoint == 1)
                verticalOperator(end,:) = 0;
            end
            if ~any(self.activeEndpoint == 2)
                verticalOperator(1,:) = 0;
            end

            nAPV = self.apvModeCount;
            nEndpoint = self.activeEndpointCount;
            nState = nAPV+nEndpoint;
            nPage = length(self.khUnique);
            stateOperator = zeros(nState,nState,nPage);
            surfaceOperator = zeros(nState,nPage);
            bottomOperator = zeros(nState,nPage);
            surfaceEtaTendency = zeros(self.Nz,1);
            bottomEtaTendency = zeros(self.Nz,1);
            if any(self.activeEndpoint == 1)
                surfaceEtaTendency(end) = -1/(weights(end)*N2(end));
            end
            if any(self.activeEndpoint == 2)
                bottomEtaTendency(1) = -1/(weights(1)*N2(1));
            end

            surfaceTaper = 1+self.z/self.Lz;
            for iPage = 1:nPage
                inverseMu = -1./self.apvMu(:,iPage).';
                apvInteriorDisplacement = (self.f/self.g)*(self.apvG-surfaceTaper*self.apvF(end,:)).*inverseMu;
                if nEndpoint > 0
                    inverseKhSquared = -1/(self.khUnique(iPage)^2);
                    zeroInteriorDisplacement = (self.f/self.g)*(self.zeroAPVG(:,:,iPage)-surfaceTaper*self.zeroAPVF(end,:,iPage))*inverseKhSquared;
                else
                    zeroInteriorDisplacement = zeros(self.Nz,0);
                end
                etaTendency = verticalOperator*[apvInteriorDisplacement zeroInteriorDisplacement];
                stateOperator(:,:,iPage) = self.projectThermalEtaTendencyOnPage(etaTendency,iPage);
                surfaceOperator(:,iPage) = self.projectThermalEtaTendencyOnPage(surfaceEtaTendency,iPage);
                bottomOperator(:,iPage) = self.projectThermalEtaTendencyOnPage(bottomEtaTendency,iPage);
            end

            self.thermalDiffusionOperatorByKh_ = stateOperator;
            self.thermalDiffusionOperatorByKl_ = stateOperator(:,:,self.klNonzeroKhUniqueIndex);
            self.thermalMDADiffusionOperator_ = real(self.mdaGForward*(verticalOperator*self.mdaG));
            self.thermalSurfaceFluxOperatorByKh_ = surfaceOperator;
            self.thermalBottomFluxOperatorByKh_ = bottomOperator;
            self.thermalSurfaceMDAFluxOperator_ = real(self.mdaGForward*surfaceEtaTendency);
            self.thermalBottomMDAFluxOperator_ = real(self.mdaGForward*bottomEtaTendency);
            self.hasThermalCoefficientOperators_ = true;
        end

        function stateTendency = projectThermalEtaTendencyOnPage(self,etaTendency,pageIndex)
            qTendency = -self.f*(self.verticalDerivativeMatrix*etaTendency);
            AgqTendency = self.apvFForward*qTendency;
            if self.activeEndpointCount > 0
                endpointRows = self.Nz-(self.activeEndpoint-1)*(self.Nz-1);
                endpointTendency = etaTendency(endpointRows,:);
                Ag0Tendency = -(self.g/self.f)*self.khUnique(pageIndex)^2*(endpointTendency-self.apvEndpointResponse(:,:,pageIndex)*AgqTendency);
            else
                Ag0Tendency = zeros(0,size(etaTendency,2));
            end
            stateTendency = [AgqTendency;Ag0Tendency];
        end

        function validateAgq(self,value)
            self.validateCoefficient(value,[length(self.apvMode),length(self.klNonzero)],false,'Ag_q');
        end

        function validateAg0(self,value)
            self.validateCoefficient(value,[self.activeEndpointCount,length(self.klNonzero)],false,'Ag_0');
        end

        function validateAmda(self,value)
            self.validateCoefficient(value,[length(self.mdaMode),1],true,'Amda');
        end
    end

    methods (Static)
        assessment = assessVerticalResolution(Lz,Nz,options)

        function propertyAnnotations = classDefinedPropertyAnnotations()
            propertyAnnotations = WVTransformFreeSurfaceQG.propertyAnnotationsForTransform();
        end

        function names = classRequiredPropertyNames()
            names = WVTransformFreeSurfaceQG.namesOfRequiredPropertiesForTransform();
        end

        function names = namesOfRequiredPropertiesForTransform()
            names = WVGeometryDoublyPeriodicStratified.namesOfRequiredPropertiesForGeometry();
            names = union(names,WVTransformFreeSurfaceQG.newRequiredPropertyNames());
        end

        function names = newRequiredPropertyNames()
            names = [WVTransformFreeSurfaceQG.persistedScientificPropertyNames(),{'Ag_q','Amda','rhoFunction','t0','t','forcing'}];
            names = setdiff(names,WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames());
        end

        function propertyAnnotations = propertyAnnotationsForTransform()
            propertyAnnotations = WVGeometryDoublyPeriodicStratified.propertyAnnotationsForGeometry();
            propertyAnnotations = cat(2,propertyAnnotations,WVTransform.propertyAnnotationsForTransform());
            fieldAnnotations = WVTransform.propertyAnnotationForKnownVariable('u','v','eta','psi','qgpv', ...
                spatialDimensionNames={'x','y','z'});
            propertyAnnotations = cat(2,propertyAnnotations,fieldAnnotations);

            propertyAnnotations(end+1) = CADimensionProperty('apvMode','1','ordinal APV-mode coordinate');
            propertyAnnotations(end+1) = CADimensionProperty('mdaMode','1','ordinal MDA-mode coordinate');
            propertyAnnotations(end+1) = CADimensionProperty('klNonzero','1','original full-kl indices at positive horizontal wavenumber');
            propertyAnnotations(end+1) = CADimensionProperty('khUnique','rad m-1','distinct positive horizontal-wavenumber magnitudes');
            propertyAnnotations(end+1) = CADimensionProperty('activeEndpoint','1','active endpoint code, surface 1 then bottom 2');
            propertyAnnotations(end+1) = CADimensionProperty('sourceEndpoint','1','source endpoint code, surface 1 then bottom 2');

            coefficientAnnotations = WVTransformFreeSurfaceQG.prototypeCoefficientAnnotations();
            propertyAnnotations = cat(2,propertyAnnotations,coefficientAnnotations);
            propertyAnnotations(end+1) = CANumericProperty('g0',{},'m s-2','resolved surface acceleration');
            propertyAnnotations(end+1) = CANumericProperty('gd',{},'m s-2','resolved bottom acceleration');
            propertyAnnotations(end+1) = CANumericProperty('activeEndpointCount',{},'1','number of active endpoints');
            propertyAnnotations(end+1) = CANumericProperty('apvModeNumber',{'apvMode'},'1','physical APV mode labels');
            propertyAnnotations(end+1) = CANumericProperty('mdaModeNumber',{'mdaMode'},'1','physical MDA mode labels');
            propertyAnnotations(end+1) = CANumericProperty('kNonzero',{'klNonzero'},'rad m-1','x wavenumber for each nonzero kl entry');
            propertyAnnotations(end+1) = CANumericProperty('lNonzero',{'klNonzero'},'rad m-1','y wavenumber for each nonzero kl entry');
            propertyAnnotations(end+1) = CANumericProperty('khNonzero',{'klNonzero'},'rad m-1','horizontal-wavenumber magnitude for each nonzero kl entry');
            propertyAnnotations(end+1) = CANumericProperty('klNonzeroKhUniqueIndex',{'klNonzero'},'1','one-based map from klNonzero to khUnique');

            propertyAnnotations(end+1) = CANumericProperty('apvF',{'z','apvMode'},'1','sampled APV F modes');
            propertyAnnotations(end+1) = CANumericProperty('apvG',{'z','apvMode'},'1','sampled APV G modes');
            propertyAnnotations(end+1) = CANumericProperty('apvFForward',{'apvMode','z'},'m-1','APV F forward matrix');
            propertyAnnotations(end+1) = CANumericProperty('apvGForward',{'apvMode','z'},'1','APV G forward matrix');
            propertyAnnotations(end+1) = CANumericProperty('apvEquivalentDepth',{'apvMode'},'m','APV equivalent depths');
            propertyAnnotations(end+1) = CANumericProperty('apvMu',{'apvMode','khUnique'},'m-2','APV inversion eigenvalues');
            propertyAnnotations(end+1) = CANumericProperty('apvEndpointResponse',{'activeEndpoint','apvMode','khUnique'},'m','APV endpoint-displacement response');
            propertyAnnotations(end+1) = CANumericProperty('apvFSourcePairing',{'apvMode','z'},'1','APV F source-pairing operator');
            propertyAnnotations(end+1) = CANumericProperty('apvGSourcePairing',{'apvMode','z'},'1','APV G source-pairing operator');

            propertyAnnotations(end+1) = CANumericProperty('mdaF',{'z','mdaMode'},'1','sampled MDA F modes');
            propertyAnnotations(end+1) = CANumericProperty('mdaG',{'z','mdaMode'},'1','sampled MDA G modes');
            propertyAnnotations(end+1) = CANumericProperty('mdaGForward',{'mdaMode','z'},'m-1','MDA G forward matrix');
            propertyAnnotations(end+1) = CANumericProperty('mdaEquivalentDepth',{'mdaMode'},'m','MDA equivalent depths');
            propertyAnnotations(end+1) = CANumericProperty('verticalQuadratureWeights',{'z'},'m','shared positive physical quadrature weights');
            propertyAnnotations(end+1) = CANumericProperty('verticalDerivativeMatrix',{'z','z'},'m-1','physical first-derivative matrix on the shared increasing-z grid');

            propertyAnnotations(end+1) = CAPropertyAnnotation('verticalGridKind','shared vertical-grid design kind');
            propertyAnnotations(end+1) = CAPropertyAnnotation('verticalGridCoordinate','native coordinate of the shared vertical grid');

            propertyAnnotations(end+1) = CANumericProperty('zeroAPVF',{'z','activeEndpoint','khUnique'},'1','sampled boundary-normalized zero-APV F pages');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVG',{'z','activeEndpoint','khUnique'},'1','sampled boundary-normalized zero-APV G pages');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVFPairing',{'activeEndpoint','z','khUnique'},'1','zero-APV F source-pairing matrices');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVGPairing',{'activeEndpoint','z','khUnique'},'1','zero-APV G source-pairing matrices');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVSourceSolve',{'activeEndpoint','sourceEndpoint','khUnique'},'1','zero-APV source-solve matrices');

            scalarNames = {'apvGramError','apvRoundTripError','mdaGramError','mdaRoundTripError','apvGramTolerance','mdaGramTolerance','quadraticAliasingTolerance','quadraticAliasingError','quadraticAliasingLimitingModeNumberI','quadraticAliasingLimitingModeNumberJ','minimumRelativeMuSeparation','muTolerance'};
            scalarDescriptions = {'worst APV Gram error','worst APV round-trip error','MDA Gram error','MDA round-trip error','APV normalized-Gram tolerance','MDA normalized-Gram tolerance','coupled quadratic-aliasing tolerance in the induced Hilbert majorant','coupled quadratic-aliasing error in the induced Hilbert majorant at selected APV count','first limiting quadratic-product mode number','second limiting quadratic-product mode number','minimum relative mu separation','APV inversion relative singularity tolerance'};
            for iProperty = 1:length(scalarNames)
                propertyAnnotations(end+1) = CANumericProperty(scalarNames{iProperty},{},'1',scalarDescriptions{iProperty}); %#ok<AGROW>
            end
            propertyAnnotations(end+1) = CAPropertyAnnotation('quadraticAliasingLimitingChannel','limiting coupled quadratic-product channel');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVGramReciprocalCondition',{'khUnique'},'1','zero-APV Gram reciprocal condition by page');
            propertyAnnotations(end+1) = CANumericProperty('zeroAPVGramRelativeSeparation',{'khUnique'},'1','zero-APV Gram relative separation by page');
            propertyAnnotations(end+1) = CANumericProperty('apvZeroAPVQuadraticError',{},'1','APV/zero-APV quadratic-product error at maximum horizontal wavenumber');
            propertyAnnotations(end+1) = CAPropertyAnnotation('apvZeroAPVLimitingEndpoint','active endpoint limiting the APV/zero-APV quadratic-product error');
            propertyAnnotations(end+1) = CANumericProperty('apvZeroAPVLimitingModeNumber',{},'1','APV physical mode label limiting the APV/zero-APV quadratic-product error');
            propertyAnnotations(end+1) = CAPropertyAnnotation('modeSelectionMethod','mode-selection method identifier');
        end

        function [wvt,ncfile] = waveVortexTransformFromFile(path,options)
            % Restore a free-surface QG transform from persisted arrays.
            % - Topic: Create and restore a transform
            arguments
                path char {mustBeFile}
                options.iTime (1,1) double {mustBePositive} = 1
                options.shouldReadOnly logical = true
            end
            ncfile = NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
            try
                wvt = WVTransformFreeSurfaceQG.transformFromGroup(ncfile);
                wvt.initFromNetCDFFile(ncfile,iTime=options.iTime,shouldDisplayInit=true);
                wvt.initForcingFromNetCDFFile(ncfile);
            catch exception
                if ~isempty(ncfile.id)
                    ncfile.close();
                end
                rethrow(exception)
            end
            if nargout < 2
                ncfile.close();
            end
        end

        function wvt = transformFromGroup(group)
            % Construct directly from the complete annotated representation.
            % - Topic: Create and restore a transform
            arguments
                group (1,1) NetCDFGroup
            end
            [Lxyz,Nxyz,geometryArguments] = WVGeometryDoublyPeriodicStratified.requiredPropertiesForGeometryFromGroup(group);
            names = WVTransformFreeSurfaceQG.newRequiredPropertyNames();
            names = setdiff(names,{'Ag_q','Amda','t0','t','forcing'});
            values = CAAnnotatedClass.propertyValuesFromGroup(group,names);
            if all(WVTransformFreeSurfaceQG.hasLocalVariables(group,{'Ag_q','Amda'}))
                [values.Ag_q,values.Amda] = group.readVariables('Ag_q','Amda');
            else
                values.Ag_q = complex(zeros(length(values.apvMode),length(values.klNonzero)));
                values.Amda = zeros(length(values.mdaMode),1);
            end
            if values.activeEndpointCount > 0
                optionalNames = setdiff(WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames(),{'Ag_0'});
                optional = CAAnnotatedClass.propertyValuesFromGroup(group,optionalNames);
                if WVTransformFreeSurfaceQG.hasLocalVariables(group,{'Ag_0'})
                    optional.Ag_0 = group.readVariables('Ag_0');
                else
                    optional.Ag_0 = complex(zeros(values.activeEndpointCount,length(values.klNonzero)));
                end
                optionalArguments = namedargs2cell(optional);
            else
                optionalArguments = {};
            end
            valueArguments = namedargs2cell(values);
            wvt = WVTransformFreeSurfaceQG(Lxyz,Nxyz,geometryArguments{:},valueArguments{:},optionalArguments{:});
        end
    end

    methods (Static, Access = private)
        state = buildScientificState(Lxyz,Nxyz,options)
        inputs = resolveScientificInputs(Lz,options)
        vertical = buildVerticalModes(Lz,Nz,N2Function,options)
        result = measureAPVZeroAPVQuadraticError(apvBasis,apvTransform,zeroModes,pageIndex,referenceOrder)
        assessment = supportedHorizontalWavenumber(apvBasis,apvTransform,N2Function,f0,g,endpoints,nEVP,tolerance,options)

        function names = directConstructionPropertyNames()
            names = [WVTransformFreeSurfaceQG.persistedScientificPropertyNames(),{'Ag_q','Amda','rhoFunction','N2Function','z','dLnN2','PF0inv','QG0inv','PF0','QG0','P0','Q0','h_0','z_int'}];
            names = setdiff(names,WVTransformFreeSurfaceQG.optionalZeroAPVPropertyNames());
        end

        function names = persistedScientificPropertyNames()
            names = {'g0','gd','activeEndpointCount','activeEndpoint','sourceEndpoint','apvMode','apvModeNumber','mdaMode','mdaModeNumber','klNonzero','kNonzero','lNonzero','khNonzero','khUnique','klNonzeroKhUniqueIndex','apvF','apvG','apvFForward','apvGForward','apvEquivalentDepth','apvMu','apvEndpointResponse','apvFSourcePairing','apvGSourcePairing','mdaF','mdaG','mdaGForward','mdaEquivalentDepth','verticalQuadratureWeights','verticalDerivativeMatrix','verticalGridKind','verticalGridCoordinate','zeroAPVF','zeroAPVG','zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve','apvGramError','apvRoundTripError','mdaGramError','mdaRoundTripError','apvGramTolerance','mdaGramTolerance','quadraticAliasingTolerance','quadraticAliasingError','quadraticAliasingLimitingChannel','quadraticAliasingLimitingModeNumberI','quadraticAliasingLimitingModeNumberJ','minimumRelativeMuSeparation','muTolerance','zeroAPVGramReciprocalCondition','zeroAPVGramRelativeSeparation','apvZeroAPVQuadraticError','apvZeroAPVLimitingEndpoint','apvZeroAPVLimitingModeNumber','modeSelectionMethod'};
        end

        function names = optionalZeroAPVPropertyNames()
            names = {'activeEndpoint','sourceEndpoint','Ag_0','apvEndpointResponse','zeroAPVF','zeroAPVG','zeroAPVFPairing','zeroAPVGPairing','zeroAPVSourceSolve','zeroAPVGramReciprocalCondition','zeroAPVGramRelativeSeparation','apvZeroAPVQuadraticError','apvZeroAPVLimitingEndpoint','apvZeroAPVLimitingModeNumber'};
        end

        function annotations = prototypeCoefficientAnnotations()
            annotations = WVCoefficientAnnotation.empty(0,0);
            annotations(end+1) = WVCoefficientAnnotation('Ag_q',{'apvMode','klNonzero'},'s-1','generalized-energy APV coefficients',auxiliaryCoordinates=["apvModeNumber" "kNonzero" "lNonzero" "khNonzero"],canonicalBasis="generalized-energy APV modes",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Ag_0',{'activeEndpoint','klNonzero'},'s-1','boundary-normalized zero-APV coefficients',auxiliaryCoordinates=["kNonzero" "lNonzero" "khNonzero"],canonicalBasis="boundary-normalized zero-APV responses",emptyFamilyPolicy="omit",isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Amda',{'mdaMode'},'m','mean-density-anomaly displacement coefficients',auxiliaryCoordinates="mdaModeNumber",canonicalBasis="signed-normalized mean-density-anomaly modes");
        end

        function tf = hasLocalVariables(group,names)
            tf = false(size(names));
            for iName = 1:length(names)
                if strlength(group.groupPath) == 0
                    localPath = string(names{iName});
                else
                    localPath = group.groupPath + "/" + string(names{iName});
                end
                tf(iName) = any(group.variablePathsWithName(names{iName}) == localPath);
            end
        end

        function validateCoefficient(value,expectedSize,mustBeRealValue,name)
            if ~isa(value,'double') || any(~isfinite(value(:)))
                error('WVTransformFreeSurfaceQG:InvalidCoefficient','%s must contain finite double values.',name);
            end
            if mustBeRealValue && ~isreal(value)
                error('WVTransformFreeSurfaceQG:InvalidCoefficient','%s must be real.',name);
            end
            if expectedSize(1) == 0
                isExpectedShape = isempty(value) && size(value,1) == 0 && size(value,2) == expectedSize(2);
            else
                isExpectedShape = isequal(size(value),expectedSize);
            end
            if ~isExpectedShape
                error('WVTransformFreeSurfaceQG:InvalidCoefficientShape','%s must have shape %s.',name,mat2str(expectedSize));
            end
        end

        function throwUnavailable(identifier,message)
            error(identifier,'%s',message);
        end
    end
end
