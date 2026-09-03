classdef WVTransformFreeSurfaceQGDiffusion < WVGeometryDoublyPeriodic & WVTransform
    % Evolve free-surface QG in complete balanced buoyancy-diffusion modes.
    %
    % The public Ag_T array is the total instantaneous modal state, in
    % meters. Unit Euclidean right eigenvectors act on scaled interior
    % QGPV and surface-displacement data. These modes are not energy
    % orthogonal. Fixed homogeneous buoyancy diffusion is part of the
    % transform; it must not also be supplied as a forcing.
    %
    % This MVP supports an active surface, inactive bottom, and zero
    % horizontal mean. Operations, flow components, MDA, and the portable
    % runtime are not supported. Use the exponential WVModel integrator.
    %
    % ```matlab
    % wvt = WVTransformFreeSurfaceQGDiffusion.fromN2([500e3 500e3 4000],[64 64 385],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),latitude=24,kappaT=1e-5);
    % ```
    %
    % - Topic: Create and restore a transform
    % - Topic: Transform coefficient state
    % - Topic: Inspect the representation
    % - Topic: Evaluate physical fields
    % - Topic: Evolution internals

    properties
        % Total instantaneous thermal coefficients in meters.
        % - Topic: Transform coefficient state
        Ag_T
    end

    properties (SetAccess = private)
        % Physical vertical nodes, bottom to surface, in meters.
        % - Topic: Inspect the representation
        z
        % Squared buoyancy frequency on z, in inverse seconds squared.
        % - Topic: Inspect the representation
        N2
        % Depth in meters.
        % - Topic: Inspect the representation
        Lz
        % Fixed buoyancy diffusivity in square meters per second.
        % - Topic: Inspect the representation
        kappaT
        % Latitude in degrees north.
        % - Topic: Inspect the representation
        latitude
        % Planetary rotation rate in radians per second.
        % - Topic: Inspect the representation
        rotationRate
        % Planetary radius in meters.
        % - Topic: Inspect the representation
        planetaryRadius
        % Gravity in meters per second squared.
        % - Topic: Inspect the representation
        g
        % Positive physical quadrature weights in meters.
        % - Topic: Inspect the representation
        verticalQuadratureWeights
        % Physical spectral first derivative in inverse meters.
        % - Topic: Inspect the representation
        verticalDerivativeMatrix
        % Distinct positive horizontal wavenumbers in radians per meter.
        % - Topic: Inspect the representation
        khUnique
        % Original one-based full-kl indices excluding the horizontal mean.
        % - Topic: Inspect the representation
        klNonzero
        % One-based wavenumber-page map for klNonzero.
        % - Topic: Inspect the representation
        klNonzeroKhUniqueIndex
        % Signed decay rates; the eigenvalues are their negatives.
        % - Topic: Inspect the representation
        thermalDecayRate
        % Dimensionless right modes in scaled independent-data coordinates.
        % - Topic: Inspect the representation
        scaledStateFromModes
        % Dimensionless inverse transformation, including left normalization.
        % - Topic: Inspect the representation
        modesFromScaledState
        % Streamfunction per meter of amplitude, in meters per second.
        % - Topic: Inspect the representation
        phiModes
        % Displacement per meter of amplitude, dimensionless.
        % - Topic: Inspect the representation
        etaModes
        % Full-grid diagnostic QGPV per amplitude, in inverse meters-seconds.
        % - Topic: Inspect the representation
        qModes
        % Relative eigendecomposition residual for each page.
        % - Topic: Inspect the representation
        eigenResidual
        % Right-eigenvector condition number for each page.
        % - Topic: Inspect the representation
        eigenvectorCondition
        % Persisted vertical polynomial operators; empty for legacy files.
        % - Topic: Inspect the representation
        verticalNumerics = WVQGVerticalOperators.empty(0,0)
        % Evaluate nonlinear QGPV advection by vertical over-integration.
        % - Topic: Inspect the representation
        shouldDealiasVertical = false
    end

    properties (Access = private, Transient)
        % Rebuildable page membership; depends only on the persisted map.
        pageIndices_
        pageValid_
        % Fourier work geometry for the extra quadrature planes.
        verticalFourierGeometry_
    end

    properties (Dependent)
        % Horizontally averaged depth-integrated physical energy per density.
        % - Topic: Evaluate physical fields
        totalEnergy
        % Same reconstructed physical-energy integral as totalEnergy.
        % - Topic: Evaluate physical fields
        totalEnergySpatiallyIntegrated
        % Hydrostatic diagnostic flag.
        % - Topic: Inspect the representation
        isHydrostatic
    end

    properties (Dependent, SetAccess = private)
        % Physical field shape Nx-by-Ny-by-Nz.
        % - Topic: Inspect the representation
        spatialMatrixSize
        % Thermal coefficient shape Nj-by-NklNonzero.
        % - Topic: Inspect the representation
        spectralMatrixSize
        % Physical x grid in meters.
        % - Topic: Inspect the representation
        X
        % Physical y grid in meters.
        % - Topic: Inspect the representation
        Y
        % Physical z grid in meters.
        % - Topic: Inspect the representation
        Z
        % Number of physical vertical nodes.
        % - Topic: Inspect the representation
        Nz
        % Number of complete thermal modes.
        % - Topic: Inspect the representation
        Nj
        % Ordinal thermal-mode coordinate (not an APV mode number).
        % - Topic: Inspect the representation
        thermalMode
        % Ordinal independent-data coordinate, interior QGPV then surface.
        % - Topic: Inspect the representation
        thermalState
        % Surface endpoint code, one.
        % - Topic: Inspect the representation
        activeEndpoint
        % Number of active endpoints, one.
        % - Topic: Inspect the representation
        activeEndpointCount
        % Coriolis frequency in inverse seconds.
        % - Topic: Inspect the representation
        f
        % Meridional Coriolis gradient in inverse meters-seconds.
        % - Topic: Inspect the representation
        beta
        % Inertial period in seconds.
        % - Topic: Inspect the representation
        inertialPeriod
        % X wavenumbers on klNonzero.
        % - Topic: Inspect the representation
        kNonzero
        % Y wavenumbers on klNonzero.
        % - Topic: Inspect the representation
        lNonzero
        % Wavenumber magnitudes on klNonzero.
        % - Topic: Inspect the representation
        khNonzero
        % Geostrophic streamfunction in square meters per second.
        % - Topic: Evaluate physical fields
        psi
        % Zonal velocity in meters per second.
        % - Topic: Evaluate physical fields
        u
        % Meridional velocity in meters per second.
        % - Topic: Evaluate physical fields
        v
        % Isopycnal displacement in meters.
        % - Topic: Evaluate physical fields
        eta
        % Physical buoyancy anomaly, including the free-surface correction.
        % - Topic: Evaluate physical fields
        buoyancy
        % Reconstructed QGPV, including diagnostic endpoint values.
        % - Topic: Evaluate physical fields
        qgpv
        % Surface endpoint displacement anomaly in meters.
        % - Topic: Evaluate physical fields
        surfaceAnomaly
        % Sea-surface height in meters.
        % - Topic: Evaluate physical fields
        ssh
        % Maximum horizontal speed in meters per second.
        % - Topic: Evaluate physical fields
        uvMax
        % Horizontally averaged depth-integrated ordinary potential enstrophy.
        % - Topic: Evaluate physical fields
        potentialEnstrophy
    end

    methods
        function self = WVTransformFreeSurfaceQGDiffusion(options)
            % Restore complete annotated arrays without any scientific solve.
            % - Topic: Create and restore a transform
            arguments
                options.Lx (1,1) double {mustBePositive,mustBeFinite}
                options.Ly (1,1) double {mustBePositive,mustBeFinite}
                options.x (:,1) double {mustBeFinite}
                options.y (:,1) double {mustBeFinite}
                options.z (:,1) double {mustBeFinite}
                options.N2 (:,1) double {mustBePositive,mustBeFinite}
                options.kappaT (1,1) double {mustBeNonnegative,mustBeFinite}
                options.latitude (1,1) double {mustBeSupportedLatitude}
                options.rotationRate (1,1) double {mustBePositive,mustBeFinite}
                options.planetaryRadius (1,1) double {mustBePositive,mustBeFinite}
                options.g (1,1) double {mustBePositive,mustBeFinite}
                options.shouldAntialias (1,1) logical = true
                options.verticalQuadratureWeights (:,1) double {mustBePositive,mustBeFinite}
                options.verticalDerivativeMatrix double {mustBeFinite}
                options.khUnique (:,1) double {mustBePositive,mustBeFinite}
                options.klNonzeroKhUniqueIndex (:,1) double {mustBeInteger,mustBePositive}
                options.thermalDecayRate double {mustBeFinite}
                options.scaledStateFromModes double {mustBeFinite}
                options.modesFromScaledState double {mustBeFinite}
                options.phiModes double {mustBeFinite}
                options.etaModes double {mustBeFinite}
                options.qModes double {mustBeFinite}
                options.eigenResidual (:,1) double {mustBeNonnegative,mustBeFinite}
                options.eigenvectorCondition (:,1) double {mustBePositive,mustBeFinite}
                options.Ag_T double = []
                options.verticalNumerics WVQGVerticalOperators = WVQGVerticalOperators.empty(0,0)
                options.shouldDealiasVertical (1,1) logical = false
            end
            required = WVTransformFreeSurfaceQGDiffusion.scientificPropertyNames();
            if ~all(isfield(options,required))
                error('WVTransformFreeSurfaceQGDiffusion:IncompleteState','Supply complete annotated arrays, or use fromN2 for scientific construction.');
            end
            nz = length(options.z);
            if nz < 5 || options.z(1) >= 0 || options.z(end) ~= 0 || any(diff(options.z)<=0) || length(options.N2)~=nz
                error('WVTransformFreeSurfaceQGDiffusion:InvalidGrid','Use at least five increasing nodes from -D to zero, with positive N2 at each node.');
            end
            self@WVGeometryDoublyPeriodic([options.Lx options.Ly],[length(options.x) length(options.y)],Nz=nz,shouldAntialias=options.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            self@WVTransform(WVForcingType(["QGSpatial" "QGSpectral"]));
            if ~isequal(options.x,self.x) || ~isequal(options.y,self.y)
                error('WVTransformFreeSurfaceQGDiffusion:InvalidGrid','Persisted x and y must match the periodic geometry.');
            end
            names = setdiff(required,{'Lx','Ly','x','y','shouldAntialias'});
            for name = string(names), self.(name) = options.(name); end
            self.Lz = -self.z(1);
            self.klNonzero = find(hypot(self.k,self.l)>0);
            n = nz-1; np = length(self.khUnique);
            for name = ["scaledStateFromModes" "modesFromScaledState"]
                self.checkSize(self.(name),[n n np],name);
            end
            for name = ["phiModes" "etaModes" "qModes"]
                self.checkSize(self.(name),[nz n np],name);
            end
            self.checkSize(self.thermalDecayRate,[n np],'thermalDecayRate');
            self.checkSize(self.verticalDerivativeMatrix,[nz nz],'verticalDerivativeMatrix');
            if length(self.verticalQuadratureWeights)~=nz || length(self.klNonzeroKhUniqueIndex)~=length(self.klNonzero) || any(self.klNonzeroKhUniqueIndex>np) || length(self.eigenResidual)~=np || length(self.eigenvectorCondition)~=np
                error('WVTransformFreeSurfaceQGDiffusion:InvalidState','Quadrature or page-coordinate lengths do not match the representation.');
            end
            if max(abs(self.khUnique(self.klNonzeroKhUniqueIndex)-self.khNonzero)) > 1000*eps*max(self.khNonzero)
                error('WVTransformFreeSurfaceQGDiffusion:InvalidPageMap','The saved page map does not match the horizontal geometry.');
            end
            counts = accumarray(self.klNonzeroKhUniqueIndex,1,[np 1]);
            self.pageIndices_ = ones(max(counts),np);
            self.pageValid_ = false(size(self.pageIndices_));
            for ip = 1:np
                self.pageIndices_(1:counts(ip),ip) = find(self.klNonzeroKhUniqueIndex==ip);
                self.pageValid_(1:counts(ip),ip) = true;
            end
            self.initializeVerticalNumerics();
            self.hasWaveComponent = false; self.hasPVComponent = true;
            if isempty(options.Ag_T), options.Ag_T = complex(zeros(n,length(self.klNonzero))); end
            self.Ag_T = options.Ag_T;
            self.addForcing(WVNonlinearAdvection(self));
        end

        function set.Ag_T(self,value)
            self.validateCoefficientShape(value);
            if ~isa(value,'double') || any(~isfinite(value),'all')
                error('WVTransformFreeSurfaceQGDiffusion:InvalidCoefficients','Ag_T must contain finite doubles.');
            end
            self.Ag_T = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end

        function annotations = coefficientStateAnnotations(~)
            % Declare the single canonical total-state coefficient family.
            % - Topic: Transform coefficient state
            annotations = WVTransformFreeSurfaceQGDiffusion.thermalCoefficientAnnotation();
        end

        configureVerticalNumerics(self,options)
        [Fq,Fb,speed] = dealiasedAdvection(self,physical)
        [FqHat,FbHat,speed] = dealiasedAdvectionFourierTendency(self,physical)
        diagnostics = verticalClosureDiagnostics(self)

        function rate=maximumExplicitDampingRate(self,speed)
            % Bound the sum of horizontal and vertical adaptive damping rates.
            % - Topic: Evolution internals
            rate=0;
            for force=self.spectralFluxForcing
                if isa(force,'WVAdaptiveDamping')
                    rate=rate+speed*(max(abs(force.damp),[],'all')+force.verticalDampingStrength/self.effectiveHorizontalGridResolution);
                end
            end
        end

        function rates = coefficientLinearRates(self)
            % Return diagonal homogeneous rates, excluding all forcing.
            % - Topic: Evolution internals
            rates = -self.thermalDecayRate(:,self.klNonzeroKhUniqueIndex);
        end

        function [q,b] = transformStateBack(self,amplitudes)
            % Reconstruct independent interior QGPV and surface anomaly.
            % - Topic: Transform coefficient state
            self.checkSize(amplitudes,size(self.Ag_T),'amplitudes');
            state = self.applyModalMatrices(self.scaledStateFromModes,amplitudes);
            state = state./self.stateScale();
            q = state(1:end-1,:); b = state(end,:);
        end

        function amplitudes = transformStateForward(self,q,b)
            % Project independent interior QGPV and surface displacement.
            % - Topic: Transform coefficient state
            self.checkSize(q,[self.Nz-2 length(self.klNonzero)],'q');
            self.checkSize(b,[1 length(self.klNonzero)],'b');
            state = self.stateScale().*[q;b];
            amplitudes = self.applyModalMatrices(self.modesFromScaledState,state);
        end

        function [phi,eta,q,b] = reconstructSpectralState(self,amplitudes)
            % Reconstruct full-grid compact fields from total coefficients.
            % - Topic: Transform coefficient state
            if nargin<2, amplitudes = self.Ag_T; end
            phi = self.applyModalMatrices(self.phiModes,amplitudes);
            if nargout>1, eta = self.applyModalMatrices(self.etaModes,amplitudes); end
            if nargout>2, q = self.applyModalMatrices(self.qModes,amplitudes); end
            if nargout>3, b = self.applyModalMatrices(self.scaledStateFromModes(end,:,:),amplitudes); end
        end

        function [q,u,v,b,ub,vb,qInteriorHat,phi] = quasigeostrophicSpatialState(self)
            % Share one physical reconstruction between QG forcing objects.
            % Interior QGPV comes directly from the independent state.
            % Optional outputs share compact interior QGPV and streamfunction
            % with damping and dealiasing; endpoint QGPV still uses qModes.
            % - Topic: Evolution internals
            phi = self.reconstructSpectralState();
            [qInteriorHat,bHat] = self.transformStateBack(self.Ag_T);
            qHat = complex(zeros(self.Nz,length(self.klNonzero)));
            qHat(2:end-1,:) = qInteriorHat;
            qHat([1 end],:) = self.applyModalMatrices(self.qModes([1 end],:,:),self.Ag_T);
            q = self.spatialField(qHat);
            u = self.spatialField(-1i*self.lNonzero.'.*phi);
            v = self.spatialField(1i*self.kNonzero.'.*phi);
            b = self.spatialField(bHat);
            ub = u(:,:,end); vb = v(:,:,end);
        end

        function tendency = projectQuasigeostrophicSpatialTendency(self,Fq,Fb)
            % Project zero-mean QGPV and endpoint tendencies into Ag_T.
            % - Topic: Evolution internals
            self.checkSize(Fq,[self.Nx self.Ny self.Nz],'Fq');
            self.checkSize(Fb,[self.Nx self.Ny],'Fb');
            q = self.spectralField(Fq); b = self.spectralField(Fb);
            tendency = struct(Ag_T=self.transformStateForward(q(2:end-1,:),b));
        end

        function [tendency,speed] = nonthermalCoefficientTendency(self,excludeSeasonal)
            % Evaluate spatial and spectral forcing on the total stage state.
            % - Topic: Evolution internals
            if nargin<2, excludeSeasonal = false; end
            [q,u,v,b,ub,vb,qInteriorHat,phiHat] = self.quasigeostrophicSpatialState();
            speed = max(hypot(u,v),[],'all');
            physical = struct(q=q,u=u,v=v,b=b,ub=ub,vb=vb,uvMax=speed,qInteriorHat=qInteriorHat,phiHat=phiHat);
            Fq = zeros(self.spatialMatrixSize); Fb = zeros(self.Nx,self.Ny);
            qTendency = complex(zeros(size(qInteriorHat)));
            bTendency = complex(zeros(1,length(self.klNonzero)));
            % Early projection is safe only for known additive callbacks.
            % Custom forcing must still see the full accumulated grid field,
            % including horizontal product modes outside the stored subset.
            additiveClasses = ["WVNonlinearAdvection" "WVSeasonalSurfaceAnomalyForcing" "WVBetaPlanePVAdvection"];
            forceClasses = string(arrayfun(@class,self.spatialFluxForcing,UniformOutput=false));
            shouldProjectAdvectionEarly = self.shouldDealiasVertical && all(ismember(forceClasses,additiveClasses));
            for force = self.spatialFluxForcing
                if excludeSeasonal && isa(force,'WVSeasonalSurfaceAnomalyForcing'), continue; end
                if self.shouldDealiasVertical && isa(force,'WVNonlinearAdvection')
                    if shouldProjectAdvectionEarly
                        [advectionQ,advectionB,fineSpeed]=self.dealiasedAdvectionFourierTendency(physical);
                        qTendency=qTendency+advectionQ; bTendency=bTendency+advectionB;
                    else
                        [advectionQ,advectionB,fineSpeed]=self.dealiasedAdvection(physical);
                        Fq=Fq+advectionQ; Fb=Fb+advectionB;
                    end
                    speed=max(speed,fineSpeed); physical.uvMax=speed;
                else
                    [Fq,Fb] = force.addQuasigeostrophicSpatialForcing(self,Fq,Fb,physical);
                end
            end
            if any(Fq,'all')
                spatialQTendency = self.spectralField(Fq);
                qTendency = qTendency+spatialQTendency(2:end-1,:);
            end
            if any(Fb,'all'), bTendency = bTendency+self.spectralField(Fb); end
            tendency = struct(Ag_T=complex(zeros(size(self.Ag_T))));
            isProjected = false;
            for force = self.spectralFluxForcing
                % Combine additive damping with advection before the first
                % modal projection. Custom forces (including subclasses)
                % see the usual fully projected tendency in original order.
                if ~isProjected && metaclass(force)==?WVAdaptiveDamping
                    [horizontal,vertical] = force.thermalDampingTendency(self,physical);
                    tendency.Ag_T = tendency.Ag_T+horizontal;
                    if ~isempty(vertical), qTendency = qTendency+vertical; end
                else
                    if ~isProjected
                        tendency.Ag_T = tendency.Ag_T+self.transformStateForward(qTendency,bTendency);
                        isProjected = true;
                    end
                    tendency = force.addQuasigeostrophicSpectralForcing(self,tendency,physical);
                end
            end
            if ~isProjected
                tendency.Ag_T = tendency.Ag_T+self.transformStateForward(qTendency,bTendency);
            end
        end

        function tendency = coefficientTendency(self)
            % Return the full physical-time coefficient tendency.
            % - Topic: Transform coefficient state
            tendency = self.nonthermalCoefficientTendency();
            tendency.Ag_T = tendency.Ag_T+self.coefficientLinearRates().*self.Ag_T;
        end

        function amplitudes = seasonalCoefficients(self,t)
            % Evaluate all registered strict seasonal responses from rest.
            % - Topic: Evolution internals
            amplitudes = complex(zeros(size(self.Ag_T)));
            for force = self.spatialFluxForcing
                if isa(force,'WVSeasonalSurfaceAnomalyForcing')
                    amplitudes = amplitudes+force.exactThermalResponse(self,t);
                end
            end
        end

        function norms = physicalErrorNorms(self,amplitudes)
            % Return RMS QGPV, buoyancy, speed, and endpoint displacement.
            % - Topic: Evolution internals
            [phi,eta,q,b] = self.reconstructSpectralState(amplitudes);
            B = -self.N2.*(eta-(self.f/self.g)*(1+self.z/self.Lz).*phi(end,:));
            w = self.verticalQuadratureWeights/self.Lz;
            norms = sqrt(2*[sum(w.*abs(q).^2,'all'),sum(w.*abs(B).^2,'all'),sum(w.*self.khNonzero.'.^2.*abs(phi).^2,'all'),sum(abs(b).^2)]);
        end

        function state = coefficientAbsoluteTolerances(~,~)
            % Reject coefficient tolerances for this nonorthogonal basis.
            % - Topic: Evolution internals
            error('WVTransformFreeSurfaceQGDiffusion:ExponentialIntegratorRequired','Use integratorType="exponential" with physical absolute tolerances.');
        end

        function values = spectralField(self,field)
            % Transform a zero-mean full-grid or endpoint field horizontally.
            % - Topic: Transform coefficient state
            count = size(field,3);
            padded = zeros(self.Nx,self.Ny,self.Nz); padded(:,:,1:count) = field;
            values = self.transformFromSpatialDomainWithFourier(padded);
            meanValue = values(1:count,setdiff(1:self.Nkl,self.klNonzero));
            if any(abs(meanValue)>1e-10*max(max(abs(values),[],'all'),realmin),'all')
                error('WVTransformFreeSurfaceQGDiffusion:MeanUnsupported','Nonzero horizontal-mean state or forcing requires an MDA implementation.');
            end
            values = values(1:count,self.klNonzero);
        end

        function field = spatialField(self,values)
            % Reconstruct full-grid or endpoint compact Fourier values.
            % - Topic: Transform coefficient state
            count = size(values,1);
            padded = complex(zeros(self.Nz,self.Nkl)); padded(1:count,self.klNonzero) = values;
            field = self.transformToSpatialDomainWithFourier(padded);
            field = field(:,:,1:count);
        end

        function summarizeEnergyContent(self)
            % Report reconstructed physical energy without flow components.
            % - Topic: Evaluate physical fields
            fprintf('Physical energy: %.6g m^3 s^-2.\n',self.totalEnergy);
        end

        function [a,b,c] = nonlinearFlux(~)
            % Reject the legacy three-family interface.
            % - Topic: Evolution internals
            error('WVTransformFreeSurfaceQGDiffusion:UseThermalState','Use coefficientTendency and Ag_T.');
        end
        function value = transformFromSpatialDomainWithFg(~,~), value=WVTransformFreeSurfaceQGDiffusion.unsupported(); end
        function value = transformFromSpatialDomainWithGg(~,~), value=WVTransformFreeSurfaceQGDiffusion.unsupported(); end
        function value = transformToSpatialDomainWithF(~,~), value=WVTransformFreeSurfaceQGDiffusion.unsupported(); end
        function value = transformToSpatialDomainWithG(~,~), value=WVTransformFreeSurfaceQGDiffusion.unsupported(); end
        function value = waveVortexTransformWithResolution(~,~), value=WVTransformFreeSurfaceQGDiffusion.unsupported(); end
        function value = get.Nz(self), value=length(self.z); end
        function value = get.spatialMatrixSize(self), value=[self.Nx self.Ny self.Nz]; end
        function value = get.spectralMatrixSize(self), value=[self.Nj length(self.klNonzero)]; end
        function value = get.X(self), [value,~,~]=ndgrid(self.x,self.y,self.z); end
        function value = get.Y(self), [~,value,~]=ndgrid(self.x,self.y,self.z); end
        function value = get.Z(self), [~,~,value]=ndgrid(self.x,self.y,self.z); end
        function value = get.Nj(self), value=self.Nz-1; end
        function value = get.thermalMode(self), value=(1:self.Nj).'; end
        function value = get.thermalState(self), value=(1:self.Nj).'; end
        function value = get.activeEndpoint(~), value=1; end
        function value = get.activeEndpointCount(~), value=1; end
        function value = get.f(self), value=2*self.rotationRate*sind(self.latitude); end
        function value = get.beta(self), value=2*self.rotationRate*cosd(self.latitude)/self.planetaryRadius; end
        function value = get.inertialPeriod(self), value=2*pi/abs(self.f); end
        function value = get.kNonzero(self), value=self.k(self.klNonzero); end
        function value = get.lNonzero(self), value=self.l(self.klNonzero); end
        function value = get.khNonzero(self), value=hypot(self.kNonzero,self.lNonzero); end
        function value = get.psi(self), phi=self.reconstructSpectralState(); value=self.spatialField(phi); end
        function value = get.u(self), phi=self.reconstructSpectralState(); value=self.spatialField(-1i*self.lNonzero.'.*phi); end
        function value = get.v(self), phi=self.reconstructSpectralState(); value=self.spatialField(1i*self.kNonzero.'.*phi); end
        function value = get.eta(self), [~,eta]=self.reconstructSpectralState(); value=self.spatialField(eta); end
        function value = get.qgpv(self), [~,~,q]=self.reconstructSpectralState(); value=self.spatialField(q); end
        function value = get.surfaceAnomaly(self), [~,b]=self.transformStateBack(self.Ag_T); value=self.spatialField(b); end
        function value = get.ssh(self), phi=self.reconstructSpectralState(); value=self.spatialField((self.f/self.g)*phi(end,:)); end
        function value = get.buoyancy(self)
            [phi,eta]=self.reconstructSpectralState();
            value=self.spatialField(-self.N2.*(eta-(self.f/self.g)*(1+self.z/self.Lz).*phi(end,:)));
        end
        function value = get.uvMax(self)
            [~,u,v]=self.quasigeostrophicSpatialState(); value=max(hypot(u,v),[],'all');
        end
        function value = get.totalEnergy(self)
            [phi,eta]=self.reconstructSpectralState();
            value=sum(self.verticalQuadratureWeights.*(self.khNonzero.'.^2.*abs(phi).^2+self.N2.*abs(eta).^2),'all');
        end
        function value = get.totalEnergySpatiallyIntegrated(self), value=self.totalEnergy; end
        function value = get.potentialEnstrophy(self)
            [~,~,q]=self.reconstructSpectralState(); value=sum(self.verticalQuadratureWeights.*abs(q).^2,'all');
        end
        function value = get.isHydrostatic(~), value=true; end
    end

    methods (Access = private)
        [advection,Fb,speed] = advectionOnQuadrature(self,physical,shouldUseFourier)
        function values = applyModalMatrices(self,matrices,amplitudes)
            % Batch kh pages; padding is temporary, never scientific state.
            % Only small coefficient/result buffers are gathered. The large
            % persisted operators are used directly, without repacking.
            indices = self.pageIndices_; valid = self.pageValid_;
            pages = reshape(amplitudes(:,indices(:)),size(amplitudes,1),size(indices,1),size(indices,2));
            pages = pagemtimes(matrices,pages);
            pages = reshape(pages,size(matrices,1),[]);
            values = complex(zeros(size(matrices,1),size(amplitudes,2)));
            values(:,indices(valid)) = pages(:,valid);
        end

        function initializeVerticalNumerics(self)
            self.verticalFourierGeometry_=[];
            if ~isempty(self.verticalNumerics) && (~isscalar(self.verticalNumerics) || ~isequal(self.verticalNumerics.nativeZ,self.z))
                error('WVTransformFreeSurfaceQGDiffusion:VerticalGridMismatch','Vertical operators must match the native z grid.');
            end
            if self.shouldDealiasVertical
                if isempty(self.verticalNumerics)
                    error('WVTransformFreeSurfaceQGDiffusion:MissingVerticalOperators','Vertical dealiasing requires persisted operators or configureVerticalNumerics().');
                end
                self.verticalFourierGeometry_=WVGeometryDoublyPeriodic([self.Lx self.Ly],[self.Nx self.Ny],Nz=length(self.verticalNumerics.zQuadrature),shouldAntialias=self.shouldAntialias,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
            end
        end
        function validateCoefficientShape(self,value)
            self.checkSize(value,[self.Nj length(self.klNonzero)],'Ag_T');
        end
        function scale = stateScale(self)
            scale=[(self.Lz/abs(self.f))*sqrt(self.verticalQuadratureWeights(2:end-1)/self.Lz);1];
        end
    end

    methods (Static)
        self = fromN2(Lxyz,Nxyz,options)
        annotations = classDefinedPropertyAnnotations()
        [wvt,ncfile] = waveVortexTransformFromFile(path,options)
        function names = spatialDimensionNames(), names={'x','y','z'}; end
        function names = spectralDimensionNames(), names={'thermalMode','klNonzero'}; end
        function names = classRequiredPropertyNames()
            names=[WVTransformFreeSurfaceQGDiffusion.scientificPropertyNames(),{'Ag_T','kNonzero','lNonzero','khNonzero','activeEndpoint','t','t0','forcing'}];
        end
        function names = scientificPropertyNames()
            % List the complete direct-construction vocabulary.
            % - Topic: Create and restore a transform
            names={'Lx','Ly','x','y','z','N2','kappaT','latitude','rotationRate','planetaryRadius','g','shouldAntialias','verticalQuadratureWeights','verticalDerivativeMatrix','khUnique','klNonzeroKhUniqueIndex','thermalDecayRate','scaledStateFromModes','modesFromScaledState','phiModes','etaModes','qModes','eigenResidual','eigenvectorCondition','verticalNumerics','shouldDealiasVertical'};
        end
        function annotation = thermalCoefficientAnnotation()
            annotation=WVCoefficientAnnotation('Ag_T',{'thermalMode','klNonzero'},'m','total instantaneous balanced diffusion-mode amplitudes',canonicalBasis="complete scaled balanced buoyancy-diffusion eigenmodes",auxiliaryCoordinates=["kNonzero" "lNonzero" "khNonzero"],isComplex=true);
        end
    end

    methods (Static, Access = private)
        function checkSize(value,expected,name)
            actual=size(value); n=max(length(expected),length(actual));
            actual(end+1:n)=1; expected(end+1:n)=1;
            if ~isequal(actual,expected)
                error('WVTransformFreeSurfaceQGDiffusion:InvalidShape','%s must have size %s.',name,mat2str(expected));
            end
        end
        function value = unsupported()
            error('WVTransformFreeSurfaceQGDiffusion:UnsupportedMVP','Use the thermal coefficient and physical-field interfaces; legacy modal APIs are unsupported.');
        end
    end
end
