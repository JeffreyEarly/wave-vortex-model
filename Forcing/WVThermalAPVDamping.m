classdef WVThermalAPVDamping < WVForcing
    % Apply a fixed APV-coordinate closure with a complete thermal complement.
    %
    % For each horizontal radius, P diagnoses APV and zero-APV coordinates
    % from the complete thermal state. L is the minimum-positive-energy right
    % inverse of P. Vertical damping is L*D*P; P*L=I and the complement I-L*P
    % is unchanged. Horizontal damping acts on every Ath direction. MDA is
    % unchanged. This named closure matches the selected APV coordinate rates,
    % not the full reconstructed APV trajectory. Physical energy includes cross
    % terms and its vertical damping work is measured, not assumed negative.
    %
    % The canonical constructor accepts frozen diagnostic arrays. It rebuilds
    % numerical maps without a scientific mode solve; fromAPVTransform freezes
    % an explicitly selected, independently constructed APV diagnostic band.
    %
    % ```matlab
    % force = WVThermalAPVDamping.fromAPVTransform(thermal,apv,apvCutoffFraction=.5);
    % thermal.addForcing(force);
    % ```
    %
    % - Topic: Create the forcing
    % - Topic: Inspect frozen closure
    % - Topic: Evaluate damping
    % - Topic: Forcing persistence
    properties (SetAccess=private)
        % Frozen physical APV sampling depths in meters.
        % - Topic: Inspect frozen closure
        apvZ
        % Ordinal coordinates of the frozen diagnostic APV band.
        % - Topic: Inspect frozen closure
        dampingAPVMode
        % Frozen sampled QGPV-to-APV projection, dimensionless.
        % - Topic: Inspect frozen closure
        apvForward
        % Inverse squared APV deformation radii, in m^-2.
        % - Topic: Inspect frozen closure
        apvInverseLr2
        % Endpoint response numerator in seconds per meter.
        % - Topic: Inspect frozen closure
        apvEndpointNumerator
        % Frozen vertical APV damping rates per physical speed, in m^-1.
        % - Topic: Inspect frozen closure
        apvVerticalRates
        % Frozen horizontal filter resolution in meters.
        % - Topic: Inspect frozen closure
        horizontalResolution
        % Frozen horizontal cutoff wavenumber in m^-1.
        % - Topic: Inspect frozen closure
        horizontalCutoff
        % APV ordinal cutoff fraction; NaN records the legacy automatic cutoff.
        % - Topic: Inspect frozen closure
        apvCutoffFraction
        % Surface squared buoyancy frequency defining the frozen profile.
        % - Topic: Inspect frozen closure
        sourceN20
        % Exponential inverse stratification scale, in m^-1.
        % - Topic: Inspect frozen closure
        sourceInverseScale
        % Fixed column depth in meters.
        % - Topic: Inspect frozen closure
        sourceDepth
        % Fixed latitude in degrees.
        % - Topic: Inspect frozen closure
        sourceLatitude
        % Fixed gravity in m/s^2.
        % - Topic: Inspect frozen closure
        sourceGravity
        % Frozen APV surface acceleration in m/s^2.
        % - Topic: Inspect frozen closure
        sourceG0
        % Frozen APV bottom acceleration in m/s^2.
        % - Topic: Inspect frozen closure
        sourceGd
    end
    properties (Constant)
        % Ordered surface and bottom coordinates of the frozen response.
        % - Topic: Inspect frozen closure
        dampingEndpoint = [1;2]
    end
    properties (Access=private,Transient)
        data_
    end
    methods
        function self=WVThermalAPVDamping(wvt,options)
            % Restore the closure from authoritative diagnostic arrays.
            % - Topic: Create the forcing
            arguments
                wvt (1,1) WVTransformFreeSurfaceThermalQG
                options.apvZ (:,1) double {mustBeReal,mustBeFinite}
                options.dampingAPVMode (:,1) double {mustBeInteger,mustBePositive}
                options.apvForward double {mustBeReal,mustBeFinite}
                options.apvInverseLr2 (:,1) double {mustBeReal,mustBeFinite}
                options.apvEndpointNumerator (2,:) double {mustBeReal,mustBeFinite}
                options.apvVerticalRates (:,1) double {mustBeReal,mustBeFinite,mustBeNonpositive}
                options.horizontalResolution (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.horizontalCutoff (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.apvCutoffFraction (1,1) double = NaN
                options.sourceN20 (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceInverseScale (1,1) double {mustBeReal,mustBeFinite}
                options.sourceDepth (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceLatitude (1,1) double {mustBeReal,mustBeFinite}
                options.sourceGravity (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceG0 (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
                options.sourceGd (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
            end
            n=numel(options.dampingAPVMode);
            if options.horizontalCutoff>pi/options.horizontalResolution
                error('WV:ThermalDampingFilter','The frozen horizontal cutoff must not exceed pi/horizontalResolution.');
            end
            if numel(unique(options.dampingAPVMode))~=n
                error('WV:ThermalDampingShape','Frozen APV coordinates must have unique ordinal labels.');
            end
            if ~isequal(size(options.apvForward),[n,numel(options.apvZ)]) || numel(options.apvInverseLr2)~=n || numel(options.apvVerticalRates)~=n || size(options.apvEndpointNumerator,2)~=n || n+2>wvt.thermalModeCount
                error('WV:ThermalDampingShape','Supply a complete frozen APV band and at least APV count plus two thermal directions.');
            end
            expected=[wvt.N20,wvt.inverseScale,wvt.Lz,wvt.latitude,wvt.g];
            actual=[options.sourceN20,options.sourceInverseScale,options.sourceDepth,options.sourceLatitude,options.sourceGravity];
            if any(abs(expected-actual)>1e-12*max(abs(expected),realmin)) || options.apvZ(1)~=-wvt.Lz || options.apvZ(end)~=0 || any(diff(options.apvZ)<=0)
                error('WV:ThermalDampingPhysics','The frozen diagnostic profile, depth, latitude and gravity must match the thermal transform.');
            end
            if ~isreal(options.apvCutoffFraction) || ~(isnan(options.apvCutoffFraction) || (options.apvCutoffFraction>=0 && options.apvCutoffFraction<1))
                error('WV:ThermalDampingCutoff','Use a cutoff fraction in [0,1), or NaN for the recorded automatic rule.');
            end
            self@WVForcing(wvt,'APV-mapped thermal damping',WVForcingType.QGSpectral);
            self.isClosure=true;
            for name=string(fieldnames(options)).', self.(name)=options.(name); end
            self.data_=WVInternal.thermalAPVDampingData(wvt,options);
        end

        function data=coefficientDampingData(self)
            % Return fixed coordinate maps and norm bounds for audit/diagnosis.
            % - Topic: Inspect frozen closure
            % - Developer: true
            data=self.data_;
        end

        function [horizontal,vertical]=quasigeostrophicDampingContributions(self,wvt,physicalState)
            % Return the two actual closure contributions with unchanged MDA.
            % The supplied physicalState.uvMax is authoritative for this stage.
            % Without it, direct evaluation falls back to native-grid uvMax;
            % pass the qualified nonlinear speed to compare with a model RHS.
            % - Topic: Evaluate damping
            arguments
                self
                wvt (1,1) WVTransformFreeSurfaceThermalQG
                physicalState (1,1) struct = struct()
            end
            if wvt~=self.wvt, error('WV:ThermalDampingOwner','Evaluate this forcing only on its owning transform.'); end
            if isfield(physicalState,'uvMax'), speed=physicalState.uvMax; else, speed=wvt.uvMax; end
            horizontal=struct(Ath=speed*self.data_.horizontalRates.*wvt.Ath,Amda=zeros(size(wvt.Amda)));
            vertical=struct(Ath=complex(zeros(size(wvt.Ath))),Amda=zeros(size(wvt.Amda)));
            for p=1:numel(self.data_.pages)
                columns=wvt.klNonzeroKhUniqueIndex==p; page=self.data_.pages{p};
                vertical.Ath(:,columns)=speed*page.lift*(self.data_.verticalRates.*(page.projection*wvt.Ath(:,columns)));
            end
        end

        function [tendency,horizontal,vertical]=addQuasigeostrophicSpectralForcing(self,wvt,tendency,physicalState)
            % Add the same horizontal and vertical rates used by diagnostics.
            % - Topic: Evaluate damping
            % - Declaration: [tendency,horizontal,vertical] = addQuasigeostrophicSpectralForcing(wvt,tendency,physicalState)
            % - Parameter wvt: owning thermal transform
            % - Parameter tendency: accumulated family-keyed coefficient tendency
            % - Parameter physicalState: optional authoritative stage uvMax; native speed is the fallback
            % - Returns tendency: accumulated tendency including both damping contributions
            % - Returns horizontal: actual horizontal coefficient tendency
            % - Returns vertical: actual lifted APV coefficient tendency
            if nargin<4, physicalState=struct(); end
            [horizontal,vertical]=self.quasigeostrophicDampingContributions(wvt,physicalState);
            tendency.Ath=tendency.Ath+horizontal.Ath+vertical.Ath;
        end

        function rate=maximumExplicitDampingRate(self,stageState)
            % Bound the complete operator in positive physical energy norm.
            % - Topic: Evaluate damping
            % - Developer: true
            rate=stageState.uvMax*self.data_.maximumUnitSpeedRate;
        end

        function force=forcingWithResolutionOfTransform(self,wvt)
            % Retain the frozen physical closure on a compatible target space.
            %
            % The diagnostic band and physical filter scales remain fixed.
            % Insufficient target bandwidth or incompatible physics rejects.
            % - Topic: Forcing persistence
            options=struct();
            for name=string(self.classRequiredPropertyNames()), options.(name)=self.(name); end
            args=namedargs2cell(options); force=WVThermalAPVDamping(wvt,args{:});
        end
    end
    methods (Static)
        function self=fromAPVTransform(wvt,apv,options)
            % Freeze an existing APV band and its actual adaptive filter rates.
            % - Topic: Create the forcing
            arguments
                wvt (1,1) WVTransformFreeSurfaceThermalQG
                apv (1,1) WVTransformFreeSurfaceQG
                options.apvCutoffFraction (1,1) double = NaN
            end
            if ~isequal([wvt.Lx wvt.Ly wvt.Lz],[apv.Lx apv.Ly apv.Lz]) || wvt.latitude~=apv.latitude || wvt.g~=apv.g || ~isequal(apv.activeEndpoint,[1;2]) || max(abs(apv.N2./(wvt.N20*exp(2*wvt.inverseScale*apv.z))-1),[],'all')>1e-9 || ~isequal([wvt.Nx wvt.Ny],[apv.Nx apv.Ny])
                error('WV:ThermalDampingPhysics','Use matching geometry/profile/gravity and both active endpoints for the diagnostic APV transform.');
            end
            legacy=WVAdaptiveDamping(apv,apvCutoffFraction=options.apvCutoffFraction);
            vertical=legacy.dampAg_q(:,1)-legacy.dampAg_0(1,1);
            numerator=(apv.f/apv.g)*[apv.apvG(end,:)-apv.apvF(end,:);apv.apvG(1,:)];
            self=WVThermalAPVDamping(wvt,apvZ=apv.z,dampingAPVMode=apv.apvMode,apvForward=apv.apvFForward,apvInverseLr2=1./apv.Lr2,apvEndpointNumerator=numerator,apvVerticalRates=vertical,horizontalResolution=legacy.assumedEffectiveHorizontalGridResolution,horizontalCutoff=legacy.k_no_damp,apvCutoffFraction=options.apvCutoffFraction,sourceN20=wvt.N20,sourceInverseScale=wvt.inverseScale,sourceDepth=wvt.Lz,sourceLatitude=wvt.latitude,sourceGravity=wvt.g,sourceG0=apv.g0,sourceGd=apv.gd);
        end

        function names=classRequiredPropertyNames()
            % Return the frozen arrays and physical configuration.
            % - Topic: Forcing persistence
            names={'apvZ','dampingAPVMode','apvForward','apvInverseLr2','apvEndpointNumerator','apvVerticalRates','horizontalResolution','horizontalCutoff','apvCutoffFraction','sourceN20','sourceInverseScale','sourceDepth','sourceLatitude','sourceGravity','sourceG0','sourceGd'};
        end

        function a=classDefinedPropertyAnnotations()
            % Describe the fixed diagnostic band without serializing caches.
            % - Topic: Forcing persistence
            a=CAPropertyAnnotation.empty(0,0);
            a(end+1)=CADimensionProperty('apvZ','m','Frozen diagnostic sample depth');
            a(end+1)=CADimensionProperty('dampingAPVMode','1','Frozen APV ordinal coordinate');
            a(end+1)=CADimensionProperty('dampingEndpoint','1','Ordered surface and bottom coordinates');
            a(end+1)=CANumericProperty('apvForward',{'dampingAPVMode','apvZ'},'1','Frozen sampled QGPV projector');
            a(end+1)=CANumericProperty('apvInverseLr2',{'dampingAPVMode'},'m-2','Inverse squared deformation radii');
            a(end+1)=CANumericProperty('apvEndpointNumerator',{'dampingEndpoint','dampingAPVMode'},'s m-1','Frozen endpoint response numerator');
            a(end+1)=CANumericProperty('apvVerticalRates',{'dampingAPVMode'},'m-1','Frozen APV vertical rates per speed');
            names={'horizontalResolution','horizontalCutoff','apvCutoffFraction','sourceN20','sourceInverseScale','sourceDepth','sourceLatitude','sourceGravity','sourceG0','sourceGd'};
            units={'m','m-1','1','s-2','m-1','m','degrees','m s-2','m s-2','m s-2'};
            for k=1:numel(names), a(end+1)=CANumericProperty(names{k},{},units{k},names{k}); end %#ok<AGROW> Fixed closure metadata.
        end
    end
end
