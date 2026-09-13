classdef WVAdaptiveDamping < WVForcing
    % Adapt small-scale spectral damping to the current flow speed.
    %
    % This closure rebuilds its spectral shape when the transform's effective
    % resolution changes and scales its coefficient tendency by the current
    % maximum horizontal speed. It is useful when the flow amplitude evolves
    % substantially, such as during spin-up.
    % 
    % This closure has a number of noteworthy features:
    %
    % - It does not mix geostrophic and wave modes, which requires setting
    % the diffusivity equal to the viscosity.
    % - The properties `k_no_damp` and `j_no_damp` indicate the wavenumber and
    % mode below which there is zero damping, due to the spectral vanishing
    % viscosity filter.
    % - The properties `k_damp` and `j_damp` are *estimates* of the
    % wavenumber and mode above which significant damping will occur.
    %
    % The damping operator acts in the spectral domain, directly damping
    % the wave-vortex coefficients. For free-surface QG, the same closure
    % acts directly on the canonical coefficient families: `Ag_q` receives
    % horizontal and APV-mode damping, `Ag_0` receives horizontal damping,
    % and the horizontally uniform `Amda` family is unchanged.
    %
    % Free-surface Boussinesq damps small horizontal scales with one rate
    % shared by every active mode at a given horizontal wavenumber:
    % $$\partial_t A_j^{k\ell} = -r(\kappa) A_j^{k\ell},\qquad r(\kappa)=U\Delta\kappa^2 Q(\kappa)/\pi^2.$$
    % Here U is the maximum physical horizontal speed, Delta is the effective
    % horizontal grid spacing, and Q is the spectral-vanishing filter.
    % This preserves cancellation between APV and zero-APV contributions to
    % boundary anomalies. External surface waves use the same rate as internal
    % waves. Horizontally uniform inertial and MDA coefficients are unchanged.
    %
    % For each positive quadratic block I_k, the damping contribution is
    % $$\dot I_k=-2r(\kappa)I_k.$$
    % This includes quadratic APV enstrophy, boundary-displacement variance
    % and wave energy, with their actual normalization and cross terms.
    % It does not assert monotone full nonlinear energy or exact nonlinear
    % conservation of unweighted boundary variance. No vertical damping is
    % supplied for Boussinesq; vertical underresolution needs separate control.
    % The following horizontal-plus-vertical formulas describe legacy models.
    %
    % $$
    % \begin{align}
    %     \partial_t A_\pm^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_\pm^{k\ell j} - \nu_z \lambda_j^{-2} A_\pm^{k\ell j} \\
    %     \partial_t A_0^{k\ell j} =& - \nu (k^2 + \ell^2 ) A_0^{k\ell j} - \nu_z \lambda_j^{-2} A_0^{k\ell j}
    % \end{align}
    % $$
    %
    % where
    %
    % $$
    % \nu_z = \nu \lambda^2_\textrm{min} k^2_\textrm{max} = \nu \lambda^2_\textrm{min} \left( \frac{\pi}{\Delta} \right)^2
    % $$
    %
    % is chosen to make the damping isotropic. The notation here is that
    % $$\Delta$$ is the horizontal grid resolution and
    % $$\lambda^2_\textrm{min}$$ is the smallest resolved radius of
    % deformation. The value of $$\nu$$ is set as
    %
    % $$
    % \nu = \frac{U \Delta}{\pi^2}
    % $$
    %
    % where $$U$$ is the maximum fluid velocity.
    %
    % ### Example
    %
    % ```matlab
    % wvt = WVTransformConstantStratification([40e3,30e3,2e3],[8,6,5],N0=5.2e-3,latitude=45,isHydrostatic=true);
    % wvt.addForcing(WVAdaptiveDamping(wvt));
    % ```
    %
    % ### Notes
    %
    % The legacy implementation damps the non-hydrostatic wavemodes the same as the
    % hydrostatic geostrophic modes. The non-hydrostatic modes would have a
    % smaller deformation radius, and thus would be damped more strongly.
    % So arguably they're under-damped in a non-hydrostatic simulation.
    %
    % - Topic: Create the forcing
    % - Topic: Inspect forcing configuration
    % - Topic: Inspect forcing or damping scales
    % - Topic: Implement forcing evaluation
    % - Topic: Convert forcing resolution
    % - Topic: Forcing persistence
    % - Topic: Forcing internals
    %
    % - Declaration: WVAdaptiveDamping < [WVForcing](/classes/forcing/wvforcing/)
    properties
        % Fraction of the largest APV mode below which vertical damping is zero.
        %
        % Applies only to free-surface QG. A finite value lies in [0,1).
        % The default NaN retains the standard spectral-vanishing cutoff.
        % Changing this setting rebuilds the operator and persists on restart.
        % - Topic: Inspect forcing configuration
        apvCutoffFraction (1,1) double = NaN
        % Unit-speed spectral damping operator in inverse meters.
        %
        % This array has `wvt.spectralMatrixSize`. The actual coefficient
        % damping rate is `wvt.uvMax*damp` in inverse seconds. Free-surface
        % QG applies its `klNonzero` subset through `dampAg_q` and uses the
        % separate `dampAg_0` operator for active endpoints. Boussinesq embeds its
        % APV rates here; coefficientDampingOperator returns all six families.
        %
        % - Topic: Properties
        damp

        % Unit-speed damping operator for free-surface APV coefficients.
        %
        % This array has the shape of `wvt.Ag_q` for a
        % free-surface QG or Boussinesq transform and is empty otherwise. It
        % combines horizontal and APV-mode damping for QG; Boussinesq uses
        % horizontal damping only.
        %
        % - Topic: Properties
        dampAg_q = []

        % Unit-speed damping operator for free-surface zero-APV coefficients.
        %
        % This array has the shape of `wvt.Ag_0` for a
        % free-surface QG or Boussinesq transform and is empty otherwise. The
        % endpoint family is damped horizontally because its rows identify
        % active boundaries rather than an ordered vertical-mode family.
        %
        % - Topic: Properties
        dampAg_0 = []

        % Estimated horizontal wavenumber for significant damping.
        %
        % Units are radians per meter. The filter is already nonzero below
        % this estimate; use `k_no_damp` for the exact zero-damping cutoff.
        %
        % - Topic: Properties
        k_damp

        % Horizontal wavenumber below which damping is exactly zero.
        %
        % Units are radians per meter.
        %
        % - Topic: Properties
        k_no_damp
        
        % Estimated vertical mode number for significant damping.
        %
        % This value is dimensionless. Free-surface QG uses the ordinal APV
        % family coordinate because its physical labels include a negative
        % surface mode. The filter is already nonzero below this estimate;
        % use `j_no_damp` for the exact zero-damping cutoff. Boussinesq uses Inf.
        %
        % - Topic: Properties
        j_damp

        % Vertical mode number below which damping is exactly zero.
        %
        % Boussinesq uses Inf because it has no vertical filter.
        %
        % This value is dimensionless. Free-surface QG uses the ordinal APV
        % family coordinate.
        %
        % - Topic: Properties
        j_no_damp

        % Effective horizontal resolution used to construct `damp`, in meters.
        %
        % - Topic: Properties
        assumedEffectiveHorizontalGridResolution = Inf;
    end

    properties (Access = private, Hidden)
        forcingListener
    end

    properties (Access = private, Transient)
        horizontalDamping_ = []
        boussinesqDamping_ = struct()
    end

    methods (Access = private, Hidden)
        function buildBoussinesqDampingOperator(self)
            w = self.wvt;
            delta = self.assumedEffectiveHorizontalGridResolution;
            kmax = pi/delta;
            dk = min(w.dk,w.dl);
            self.k_no_damp = dk*(kmax/dk)^(3/4);
            b = sqrt(-log(.1));
            self.k_damp = (kmax+b*self.k_no_damp)/(1+b);
            horizontal = -delta/pi^2*w.khNonzero.'.^2.*WVAdaptiveDamping.vanishingFilter(w.khNonzero.',kmax,self.k_no_damp);
            operator = struct();
            self.j_no_damp = Inf;
            self.j_damp = Inf;
            operator.Ag_q = repmat(horizontal,size(w.Ag_q,1),1);
            operator.Ag_0 = repmat(horizontal,size(w.Ag_0,1),1);
            operator.Aw_p = repmat(horizontal,size(w.Aw_p,1),1);
            operator.Aw_p(~w.activeWaveModes) = 0;
            operator.Aw_m = operator.Aw_p;
            operator.Aio = zeros(size(w.Aio));
            operator.Amda = zeros(size(w.Amda));
            self.boussinesqDamping_ = operator;
            self.dampAg_q = operator.Ag_q;
            self.dampAg_0 = operator.Ag_0;
            self.horizontalDamping_ = horizontal;
            self.damp = zeros(w.Nj,w.Nkl);
            self.damp(:,w.klNonzero) = operator.Ag_q;
        end

        function apvCutoffFractionDidChange(self)
            % During construction the first operator is built explicitly.
            if ~isempty(self.damp)
                self.buildDampingOperator();
            end
        end

        function forcingDidChangeNotification(self,~,~)
            if self.wvt.effectiveHorizontalGridResolution ~= self.assumedEffectiveHorizontalGridResolution
                self.buildDampingOperator();
            end
        end
    end

    methods
        function contract = portableImplementationContract(self)
            % Return the paired portable implementation contract.
            %
            % - Topic: Forcing internals
            % - Declaration: contract = portableImplementationContract(self)
            % - Returns contract: versioned data-only forcing contract
            % - Developer: true
            if isa(self.wvt,"WVTransformFreeSurfaceBoussinesq")
                contract = portableImplementationContract@WVForcing(self);
                return
            end
            payload = struct("name",string(self.name),"forcingTypes",string(self.forcingType),"priority",self.priority,"assumedEffectiveHorizontalGridResolution",double(self.assumedEffectiveHorizontalGridResolution),"kNoDamp",double(self.k_no_damp),"jNoDamp",double(self.j_no_damp));
            contract = self.supportedPortableImplementationContract("WVAdaptiveDamping",payload);
        end

        function self = WVAdaptiveDamping(wvt,options)
            % Create adaptive spectral damping for a transform.
            %
            % - Topic: Initialization
            % - Declaration: self = WVAdaptiveDamping(wvt,options)
            % - Parameter wvt: transform that owns and evaluates the closure
            % - Parameter options.apvCutoffFraction: optional free-surface QG APV cutoff fraction; NaN uses the standard cutoff
            % - Returns self: adaptive-damping closure owned by `wvt`
            arguments
                wvt WVTransform {mustBeNonempty}
                options.apvCutoffFraction (1,1) double = NaN
            end
            self@WVForcing(wvt,"adaptive damping",WVAdaptiveDamping.forcingTypesForTransform(wvt));
            self.wvt = wvt;
            self.isClosure = true;
            self.apvCutoffFraction = options.apvCutoffFraction;
            self.buildDampingOperator();
            self.forcingListener = addlistener(self.wvt,'forcingDidChange',@self.forcingDidChangeNotification);
        end

        function set.apvCutoffFraction(self,value)
            if ~isreal(value) || ~(isnan(value) || (isfinite(value) && value>=0 && value<1))
                error('WVAdaptiveDamping:APVCutoff','Use an APV cutoff fraction in [0,1), or NaN for the standard cutoff.');
            end
            if ~isnan(value) && ~isa(self.wvt,'WVTransformFreeSurfaceQG')
                error('WVAdaptiveDamping:APVCutoff','The APV cutoff fraction applies only to free-surface QG transforms.');
            end
            self.apvCutoffFraction = value;
            self.apvCutoffFractionDidChange();
        end

        function didGetRemovedFromTransform(self, wvt)
            delete(self.forcingListener);
            self.forcingListener = [];
        end

        function buildDampingOperator(self)
            % Build the unit-speed spectral damping operator.
            %
            % - Topic: Internal
            % - Declaration: buildDampingOperator(self)
            % - Parameter self: adaptive-damping instance to update
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
            end
            self.assumedEffectiveHorizontalGridResolution = self.wvt.effectiveHorizontalGridResolution;
            self.dampAg_q = [];
            self.dampAg_0 = [];
            self.horizontalDamping_ = [];

            if isa(self.wvt,"WVTransformFreeSurfaceBoussinesq")
                self.buildBoussinesqDampingOperator();
                return
            end

            kl_max = pi/self.assumedEffectiveHorizontalGridResolution;
            if isa(self.wvt,"WVTransformFreeSurfaceQG")
                j_max = length(self.wvt.apvMode);
                j_index = length(self.wvt.apvMode);
            else
                j_max = self.wvt.effectiveJMax;
                j_index = find(self.wvt.j == self.wvt.effectiveJMax);
            end
            [K,L,~] = self.wvt.kljGrid;
            [Qkl,Qj,self.k_no_damp,self.k_damp,self.j_no_damp,self.j_damp] = self.spectralVanishingViscosityFilter(kl_max, j_max);
            prefactor_xy = self.assumedEffectiveHorizontalGridResolution/(pi^2);
            prefactor_z = (pi*pi*self.wvt.Lr2(j_index)/(self.assumedEffectiveHorizontalGridResolution)^2)*prefactor_xy;

            Lr2inv = 1./self.wvt.Lr2;
            self.damp = -prefactor_xy*Qkl.*(K.^2 +L.^2) ;
            if ~isa(self.wvt,"WVGeometryDoublyPeriodicBarotropic")
                self.damp = self.damp - prefactor_z*Qj.*Lr2inv;
            end
            if isa(self.wvt,"WVTransformFreeSurfaceQG")
                nonzeroIndex = self.wvt.klNonzero;
                self.dampAg_q = self.damp(:,nonzeroIndex);
                horizontalDamp = -prefactor_xy*Qkl(1,nonzeroIndex).*(K(1,nonzeroIndex).^2+L(1,nonzeroIndex).^2);
                self.horizontalDamping_ = horizontalDamp;
                self.dampAg_0 = repmat(horizontalDamp,self.wvt.activeEndpointCount,1);
            end
        end

        function [Qkl,Qj,kl_cutoff, kl_damp, j_cutoff, j_damp] = spectralVanishingViscosityFilter(self, kl_max, j_max)
            % Build horizontal and vertical spectral-vanishing filters.
            %
            % - Topic: Internal
            % - Declaration: [Qkl,Qj,kl_cutoff,kl_damp,j_cutoff,j_damp] = spectralVanishingViscosityFilter(kl_max,j_max)
            % - Parameter kl_max: maximum resolved horizontal wavenumber in radians per meter
            % - Parameter j_max: maximum resolved vertical-mode number
            % - Returns Qkl: horizontal filter on the spectral grid
            % - Returns Qj: vertical filter on the spectral grid
            % - Returns kl_cutoff: exact horizontal zero-damping cutoff in radians per meter
            % - Returns kl_damp: estimated horizontal significant-damping wavenumber in radians per meter
            % - Returns j_cutoff: exact vertical zero-damping cutoff
            % - Returns j_damp: estimated vertical significant-damping mode
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
                kl_max
                j_max
            end
            wvt_ = self.wvt;
            dkl_min = min(wvt_.dk, wvt_.dl);
            kl_cutoff = dkl_min*(kl_max/dkl_min)^(3/4);

            b = sqrt(-log(0.1));
            kl_damp = (kl_max+b*kl_cutoff)/(1+b); % approximately

            [K,L,J] = wvt_.kljGrid;
            verticalMode = wvt_.j;
            if isa(wvt_,"WVTransformFreeSurfaceQG")
                verticalMode = wvt_.apvMode;
                J = repmat(verticalMode,1,wvt_.Nkl);
            end
            Kh = sqrt(K.^2 + L.^2);

            Qkl = exp( - ((abs(Kh)-kl_max)./(abs(Kh)-kl_cutoff)).^2 );
            Qkl(abs(Kh)<kl_cutoff) = 0;
            Qkl(abs(Kh)>kl_max) = 1;

            hasAPVCutoff = isa(wvt_,"WVTransformFreeSurfaceQG") && ~isnan(self.apvCutoffFraction);
            if wvt_.Nj > 2 || hasAPVCutoff
                if hasAPVCutoff
                    j_cutoff = self.apvCutoffFraction*j_max;
                else
                    dj = verticalMode(2)-verticalMode(1);
                    j_cutoff = dj*(j_max/dj)^(3/4);
                end
                j_damp = (j_max+b*j_cutoff)/(1+b); % approximately
                Qj = exp( - ((J-j_max)./(J-j_cutoff)).^2 );
                Qj(J<=j_cutoff) = 0;
                Qj(J>j_max) = 1;
            else
                j_cutoff = 0;
                j_damp = 0;
                Qj = ones(size(J));
            end
        end

        % function [Qkl,Qj,kl_cutoff, kl_damp, j_cutoff, j_damp] = spectralVanishingViscosityFilter(self, options)
        %     % Builds the spectral vanishing viscosity operator
        %     %
        %     % - Declaration: spectralVanishingViscosityFilter(self, options)
        %     % - Parameter self: an instance of WVAdaptiveDamping
        %     % - Parameter options: struct with field shouldAssumeAntialiasing
        %     % - Returns: Qkl, Qj, kl_cutoff, kl_damp
        %     arguments
        %         self WVAdaptiveDamping {mustBeNonempty}
        %         options.shouldAssumeAntialiasing logical = false
        %     end
        %     wvt_ = self.wvt;
        %     k_max = max(wvt_.k);
        %     l_max = max(wvt_.l);
        %     j_max = max(wvt_.j);
        %     if options.shouldAssumeAntialiasing == 1
        %         k_max = 2*k_max/3;
        %         l_max = 2*l_max/3;
        %         j_max = 2*j_max/3;
        %     end
        % 
        %     kl_max = min(k_max,l_max);
        %     dkl_min = min(wvt_.dk, wvt_.dl);
        %     kl_cutoff = dkl_min*(kl_max/dkl_min)^(3/4);
        % 
        %     b = sqrt(-log(0.1));
        %     kl_damp = (kl_max+b*kl_cutoff)/(1+b); % approximately
        % 
        %     [K,L,J] = wvt_.kljGrid;
        %     Kh = sqrt(K.^2 + L.^2);
        % 
        %     Qkl = exp( - ((abs(Kh)-kl_max)./(abs(Kh)-kl_cutoff)).^2 );
        %     Qkl(abs(Kh)<kl_cutoff) = 0;
        %     Qkl(abs(Kh)>kl_max) = 1;
        % 
        %     if wvt_.Nj > 2
        %         dj = wvt_.j(2)-wvt_.j(1);
        %         j_cutoff = dj*(j_max/dj)^(3/4);
        %         j_damp = (j_max+b*j_cutoff)/(1+b); % approximately
        %         Qj = exp( - ((J-j_max)./(J-j_cutoff)).^2 );
        %         Qj(J<j_cutoff) = 0;
        %         Qj(J>j_max) = 1;
        %     else
        %         j_cutoff = 0;
        %         j_damp = 0;
        %         Qj = ones(size(J));
        %     end
        % end
        % 
        function dampingTimeScale = dampingTimeScale(self)
            % Return the inverse maximum unit-speed damping coefficient.
            %
            % Despite the historical method name, this value has units of
            % meters because `damp` has units of inverse meters. For a
            % nonzero flow, divide this value by `wvt.uvMax` to obtain the
            % shortest instantaneous e-folding time in seconds.
            %
            % - Topic: Properties
            % - Declaration: dampingTimeScale = dampingTimeScale()
            % - Returns dampingTimeScale: inverse maximum absolute entry of `damp`, in meters
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
            end
            values = self.damp(:);
            for name = string(fieldnames(self.boussinesqDamping_)).', values = [values; self.boussinesqDamping_.(name)(:)]; end %#ok<AGROW>
            dampingTimeScale = 1/max(abs(values));
        end
        
        function [Fp, Fm, F0] = addSpectralForcing(self, wvt, Fp, Fm, F0)
            % Add adaptive damping to wave-vortex coefficient tendencies.
            %
            % - Declaration: addSpectralForcing(self, wvt, Fp, Fm, F0)
            % - Parameter wvt: transform evaluating the forcing
            % - Parameter Fp: accumulated `Ap` tendency
            % - Parameter Fm: accumulated `Am` tendency
            % - Parameter F0: accumulated `A0` tendency
            % - Returns Fp: damped `Ap` tendency
            % - Returns Fm: damped `Am` tendency
            % - Returns F0: damped `A0` tendency
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
                wvt WVTransform {mustBeNonempty}
                Fp double {mustBeNonempty}
                Fm double {mustBeNonempty}
                F0 double {mustBeNonempty}
            end
            uvMax = wvt.uvMax;
            Fp = Fp + uvMax * self.damp .* wvt.Ap;
            Fm = Fm + uvMax * self.damp .* wvt.Am;
            F0 = F0 + uvMax * self.damp .* wvt.A0;
        end

        function F0 = addPotentialVorticitySpectralForcing(self, wvt, F0)
            % Add adaptive damping to the QGPV coefficient tendency.
            %
            % - Declaration: addPotentialVorticitySpectralForcing(self, wvt, F0)
            % - Parameter wvt: QG transform evaluating the forcing
            % - Parameter F0: accumulated `A0` tendency
            % - Returns F0: damped `A0` tendency
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
                wvt WVTransform {mustBeNonempty}
                F0 double {mustBeNonempty}
            end
            F0 = F0 + wvt.uvMax * self.damp .* wvt.A0;
        end

        function tendency = addQuasigeostrophicSpectralForcing(self,wvt,tendency,physicalState)
            % Add adaptive damping to free-surface QG coefficient families.
            %
            % `Ag_q` receives horizontal and vertical-mode damping. `Ag_0`
            % receives horizontal damping only because its rows identify
            % active endpoints, not successively smaller vertical scales.
            % The horizontally uniform `Amda` family is unchanged: it has no
            % nonlinear transfer in the present free-surface QG model.
            %
            % - Topic: Implement forcing evaluation
            % - Declaration: tendency = addQuasigeostrophicSpectralForcing(wvt,tendency,physicalState)
            % - Parameter wvt: free-surface QG transform evaluating the closure
            % - Parameter tendency: accumulated family-keyed coefficient tendency
            % - Parameter physicalState: optional shared physical reconstruction
            % - Returns tendency: coefficient tendency including adaptive damping
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
                wvt WVTransform {mustBeNonempty}
                tendency (1,1) struct
                physicalState (1,1) struct = struct()
            end
            [horizontal,vertical] = self.quasigeostrophicDampingContributions(wvt,physicalState);
            tendency.Ag_q = tendency.Ag_q+horizontal.Ag_q+vertical.Ag_q;
            tendency.Ag_0 = tendency.Ag_0+horizontal.Ag_0;
        end

        function [horizontal,vertical] = quasigeostrophicDampingContributions(self,wvt,physicalState)
            % Return the horizontal and vertical tendencies used by this forcing.
            %
            % Their sum is the complete damping tendency, including any
            % configured APV cutoff. Both contributions leave MDA unchanged.
            % - Topic: Implement forcing evaluation
            % - Parameter wvt: free-surface QG transform evaluating the closure
            % - Parameter physicalState: optional shared reconstruction containing uvMax
            % - Returns horizontal: horizontal coefficient tendency
            % - Returns vertical: APV-mode coefficient tendency
            arguments
                self (1,1) WVAdaptiveDamping
                wvt (1,1) WVTransformFreeSurfaceQG
                physicalState (1,1) struct = struct()
            end
            if isfield(physicalState,'uvMax')
                uvMax = physicalState.uvMax;
            else
                uvMax = wvt.uvMax;
            end
            horizontal = struct(Ag_q=uvMax*self.horizontalDamping_.*wvt.Ag_q, ...
                Ag_0=uvMax*self.dampAg_0.*wvt.Ag_0,Amda=zeros(size(wvt.Amda)));
            vertical = struct(Ag_q=uvMax*(self.dampAg_q-self.horizontalDamping_).*wvt.Ag_q, ...
                Ag_0=zeros(size(wvt.Ag_0)),Amda=zeros(size(wvt.Amda)));
        end

        function operator = coefficientDampingOperator(self)
            % Return unit-speed damping rates for the Boussinesq families.
            %
            % Rates have units m^-1 and the shapes of coefficientState().
            % Multiply by the current maximum physical horizontal speed.
            % - Topic: Inspect forcing or damping scales
            % - Returns operator: six-family rate structure, empty for other models
            operator = self.boussinesqDamping_;
        end

        function tendency = addBoussinesqSpectralForcing(self,wvt,tendency,physicalState)
            % Add adaptive damping without mixing families or oscillatory phases.
            % - Topic: Implement forcing evaluation
            % - Parameter wvt: owning Boussinesq transform
            % - Parameter tendency: accumulated reference-time coefficient rates
            % - Parameter physicalState: optional shared uvMax diagnostic
            % - Returns tendency: coefficient rates including damping
            arguments
                self (1,1) WVAdaptiveDamping
                wvt (1,1) WVTransformFreeSurfaceBoussinesq
                tendency (1,1) struct
                physicalState (1,1) struct = struct()
            end
            if isfield(physicalState,'uvMax')
                speed = physicalState.uvMax;
            else
                fields = wvt.reconstructFields(["u","v"]);
                speed = max(hypot(fields.u,fields.v),[],'all');
            end
            for name = string(fieldnames(self.boussinesqDamping_)).'
                tendency.(name) = tendency.(name)+speed*self.boussinesqDamping_.(name).*wvt.(name);
            end
        end

        function force = forcingWithResolutionOfTransform(self, wvtX2)
            % Create equivalent adaptive damping for another resolution.
            %
            % - Declaration: forcingWithResolutionOfTransform(self, wvtX2)
            % - Parameter wvtX2: compatible transform at the target resolution
            % - Returns force: adaptive damping owned by `wvtX2`
            arguments
                self WVAdaptiveDamping {mustBeNonempty}
                wvtX2 WVTransform {mustBeNonempty}
            end
            force = WVAdaptiveDamping(wvtX2,apvCutoffFraction=self.apvCutoffFraction);
        end
    end

    methods (Static, Access = private)
        function value = vanishingFilter(coordinate,maximum,cutoff)
            value = zeros(size(coordinate));
            active = coordinate>cutoff;
            value(active) = exp(-((coordinate(active)-maximum)./(coordinate(active)-cutoff)).^2);
            value(coordinate>=maximum & active) = 1;
        end

        function forcingTypes = forcingTypesForTransform(wvt)
            if isa(wvt,"WVTransformFreeSurfaceBoussinesq")
                forcingTypes = WVForcingType("BoussinesqSpectral");
            elseif isa(wvt,"WVTransformFreeSurfaceQG")
                forcingTypes = WVForcingType("QGSpectral");
            else
                forcingTypes = WVForcingType(["Spectral","PVSpectral"]);
            end
        end
    end

    methods (Static)
        function vars = classRequiredPropertyNames()
            % Returns the required property names for the class
            %
            % - Topic: CAAnnotatedClass requirement
            % - Declaration: classRequiredPropertyNames()
            % - Returns: vars
            arguments
            end
            vars = {'apvCutoffFraction'};
        end

        function propertyAnnotations = classDefinedPropertyAnnotations()
            % Returns the defined property annotations for the class
            %
            % - Topic: CAAnnotatedClass requirement
            % - Declaration: classDefinedPropertyAnnotations()
            % - Returns: propertyAnnotations
            arguments (Output)
                propertyAnnotations CAPropertyAnnotation
            end
            propertyAnnotations = CAPropertyAnnotation.empty(0,0);
            propertyAnnotations(end+1) = CANumericProperty('apvCutoffFraction',{},'1','free-surface QG APV cutoff fraction; NaN uses the standard cutoff');
        end
    end
end
