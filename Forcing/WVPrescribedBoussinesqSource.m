classdef WVPrescribedBoussinesqSource < WVForcing
    % Apply fixed volume-source patterns with a prescribed cosine time dependence.
    %
    % Each rate is multiplied by cos(frequency*(t-referenceTime)+phase).
    % Momentum rates are in m/s^2; etaRate is the source of total displacement
    % in m/s. The pattern includes its endpoint values, not boundary sheets.
    % This experimental source uses the free-surface Boussinesq projector.
    %
    % ```matlab
    % force = WVPrescribedBoussinesqSource(wvt,uRate=1e-7*ones(wvt.Nx,wvt.Ny,wvt.Nz));
    % wvt.addForcing(force);
    % model = WVModel(wvt);
    % model.setupIntegrator(integratorType="fixed",deltaT=10);
    % ```
    %
    % - Topic: Create the forcing
    % - Topic: Inspect forcing configuration
    % - Topic: Implement forcing evaluation
    % - Topic: Forcing persistence
    properties (SetAccess = private)
        % Zonal acceleration pattern in m/s^2.
        % - Topic: Inspect forcing configuration
        uRate
        % Meridional acceleration pattern in m/s^2.
        % - Topic: Inspect forcing configuration
        vRate
        % Vertical acceleration pattern in m/s^2.
        % - Topic: Inspect forcing configuration
        wRate
        % Total-displacement source pattern in m/s.
        % - Topic: Inspect forcing configuration
        etaRate
        % Angular forcing frequency in rad/s; zero gives a constant source.
        % - Topic: Inspect forcing configuration
        frequency
        % Absolute time at which the specified phase applies, in seconds.
        % - Topic: Inspect forcing configuration
        referenceTime
        % Cosine phase at referenceTime in radians.
        % - Topic: Inspect forcing configuration
        phase
    end
    methods
        function self = WVPrescribedBoussinesqSource(wvt,options)
            % Construct a persistent controlled volume source.
            % - Topic: Create the forcing
            % - Declaration: self = WVPrescribedBoussinesqSource(wvt,options)
            % - Parameter wvt: free-surface Boussinesq transform
            % - Parameter options.uRate: Nx by Ny by Nz zonal acceleration; default zero
            % - Parameter options.vRate: Nx by Ny by Nz meridional acceleration; default zero
            % - Parameter options.wRate: Nx by Ny by Nz vertical acceleration; default zero
            % - Parameter options.etaRate: Nx by Ny by Nz total-displacement source; default zero
            % - Parameter options.frequency: nonnegative angular frequency; default zero
            % - Parameter options.referenceTime: absolute forcing time origin; default zero
            % - Parameter options.phase: phase at referenceTime; default zero
            % - Returns self: source ready for addForcing
            arguments (Input)
                wvt (1,1) WVTransformFreeSurfaceBoussinesq
                options.uRate double {mustBeReal,mustBeFinite} = zeros(wvt.Nx,wvt.Ny,wvt.Nz)
                options.vRate double {mustBeReal,mustBeFinite} = zeros(wvt.Nx,wvt.Ny,wvt.Nz)
                options.wRate double {mustBeReal,mustBeFinite} = zeros(wvt.Nx,wvt.Ny,wvt.Nz)
                options.etaRate double {mustBeReal,mustBeFinite} = zeros(wvt.Nx,wvt.Ny,wvt.Nz)
                options.frequency (1,1) double {mustBeReal,mustBeFinite,mustBeNonnegative} = 0
                options.referenceTime (1,1) double {mustBeReal,mustBeFinite} = 0
                options.phase (1,1) double {mustBeReal,mustBeFinite} = 0
            end
            for name = ["uRate","vRate","wRate","etaRate"]
                if ~isequal(size(options.(name)),[wvt.Nx wvt.Ny wvt.Nz])
                    error('WVPrescribedBoussinesqSource:InvalidShape','%s must have shape Nx by Ny by Nz.',name)
                end
            end
            self@WVForcing(wvt,'prescribed Boussinesq source',WVForcingType('NonhydrostaticSpatial'));
            for name = string(fieldnames(options)).', self.(name)=options.(name); end
        end
        function [u,v,w,eta] = addNonhydrostaticSpatialForcing(self,wvt,u,v,w,eta)
            % Add sources at the current absolute model time.
            % - Topic: Implement forcing evaluation
            scale=cos(self.frequency*(wvt.t-self.referenceTime)+self.phase);
            u=u+scale*self.uRate; v=v+scale*self.vRate;
            w=w+scale*self.wRate; eta=eta+scale*self.etaRate;
        end
        function force = forcingWithResolutionOfTransform(self,target)
            % Regrid prescribed rates when the target preserves their sampled content.
            %
            % Fourier identities and the stored WKB maps transfer each pattern.
            % A relative round-trip L2 residual above 1e-8 rejects the conversion;
            % an unrepresented forcing must be changed explicitly by the caller.
            %
            % - Topic: Forcing persistence
            % - Declaration: force = forcingWithResolutionOfTransform(target)
            % - Parameter target: compatible free-surface Boussinesq target
            % - Returns force: target-owned source with unchanged absolute clock
            arguments (Input)
                self WVPrescribedBoussinesqSource
                target WVTransformFreeSurfaceBoussinesq
            end
            options=struct(frequency=self.frequency,referenceTime=self.referenceTime,phase=self.phase);
            for name=["uRate","vRate","wRate","etaRate"]
                [options.(name),residual]=WVInternal.freeSurfaceSpatialTransfer(self.wvt,target,self.(name));
                if residual>1e-8
                    error('WVPrescribedBoussinesqSource:UnresolvedTransfer','Target cannot preserve %s: sampled round-trip L2 residual %.3g exceeds 1e-8.',name,residual)
                end
            end
            args=namedargs2cell(options);
            force=WVPrescribedBoussinesqSource(target,args{:});
        end
        function writeToGroup(self,group,annotations,attributes)
            % Write source arrays using the parent transform's spatial dimensions.
            % - Topic: Forcing persistence
            arguments (Input)
                self WVPrescribedBoussinesqSource
                group NetCDFGroup
                annotations CAPropertyAnnotation = CAPropertyAnnotation.empty(0,0)
                attributes = configureDictionary("string","string")
            end
            isPattern=ismember(string({annotations.name}),["uRate","vRate","wRate","etaRate"]);
            writeToGroup@CAAnnotatedClass(self,group,annotations(~isPattern),attributes);
            for annotation=annotations(isPattern)
                variableAttributes=annotation.attributes;
                variableAttributes('units')=annotation.units;
                variableAttributes('long_name')=annotation.description;
                group.addVariable(annotation.name,annotation.dimensions,self.(annotation.name),isComplex=false,attributes=variableAttributes);
            end
        end
    end
    methods (Static)
        function names = classRequiredPropertyNames()
            names={'uRate','vRate','wRate','etaRate','frequency','referenceTime','phase'};
        end
        function a = classDefinedPropertyAnnotations()
            a=CAPropertyAnnotation.empty(0,0);
            for name=["uRate","vRate","wRate","etaRate"]
                units='m s-2'; if name=="etaRate", units='m s-1'; end
                a(end+1)=CANumericProperty(char(name),{'x','y','z'},units,char(name));
            end
            a(end+1)=CANumericProperty('frequency',{},'rad s-1','angular forcing frequency');
            a(end+1)=CANumericProperty('referenceTime',{},'s','absolute forcing reference time');
            a(end+1)=CANumericProperty('phase',{},'rad','forcing phase at reference time');
        end
    end
end
