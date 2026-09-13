classdef ThermalInterfaceFixture < WVTransform
    % Manufactured interface fixture; contains no thermal mode solver or QG physics.
    properties
        Ath
        totalEnergySpatiallyIntegrated = 0
        totalEnergy = 0
        isHydrostatic = true
        inertialPeriod = 1
    end
    properties (SetAccess=private)
        thermalDirection = (1:3)'
        horizontalColumn = (1:2)'
        sample = (1:4)'
        reconstruction
        source
        reconstructionCount = 0
    end
    methods
        function self = ThermalInterfaceFixture(options)
            arguments
                options.reconstruction (4,3) double {mustBeReal,mustBeFinite}
                options.source (3,2) double {mustBeFinite}
                options.Ath (3,2) double {mustBeFinite}
                options.t (1,1) double {mustBeReal,mustBeFinite} = 0
            end
            self@WVTransform(WVForcingType.QGSpectral);
            self.hasWaveComponent = false;
            self.hasPVComponent = false;
            self.reconstruction = options.reconstruction;
            self.source = options.source;
            self.Ath = options.Ath;
            self.t = options.t;
            a = WVVariableAnnotation('probeField',{'sample','horizontalColumn'},'m','Manufactured displacement',isComplex=true);
            a.isDependentOnApAmA0 = true;
            self.addOperation(WVOperation('probeField',a,@(w)w.evaluateField()));
        end
        function set.Ath(self,value)
            arguments
                self
                value (3,2) double {mustBeFinite}
            end
            self.Ath = value;
            self.clearVariableCacheOfApAmA0DependentVariables();
        end
        function field = evaluateField(self)
            self.reconstructionCount = self.reconstructionCount+1;
            field = self.reconstruction*self.Ath;
        end
        function fields = reconstructFields(self,names)
            arguments
                self
                names (1,:) string {mustBeMember(names,"probeField")}
            end
            fields = struct();
            for name = names
                fields.(name) = self.variableWithName(char(name));
            end
        end
        function annotations = coefficientStateAnnotations(self)
            annotations = self.propertyAnnotationWithName('Ath');
        end
        function tendency = coefficientTendency(self)
            tendency = struct(Ath=(1+self.t)*self.source);
        end
        function tolerances = coefficientAbsoluteTolerances(self,scale)
            tolerances = struct(Ath=scale*ones(size(self.Ath)));
        end
        function varargout = nonlinearFlux(~) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Use the family-keyed prescribed tendency.');
        end
        function out = waveVortexTransformWithResolution(~,~) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Resolution transfer is outside this fixture.');
        end
        function out = transformFromSpatialDomainWithFg(~,~) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Legacy projection is unsupported.');
        end
        function out = transformFromSpatialDomainWithGg(~,~) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Legacy projection is unsupported.');
        end
        function out = transformToSpatialDomainWithF(~,varargin) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Legacy reconstruction is unsupported.');
        end
        function out = transformToSpatialDomainWithG(~,varargin) %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:Unsupported','Legacy reconstruction is unsupported.');
        end
    end
    methods (Static)
        function names = spatialDimensionNames()
            names = {'sample','horizontalColumn'};
        end
        function names = spectralDimensionNames()
            names = {'thermalDirection','horizontalColumn'};
        end
        function names = classRequiredPropertyNames()
            names = {'reconstruction','source','Ath','t'};
        end
        function annotations = classDefinedPropertyAnnotations()
            annotations = CAPropertyAnnotation.empty(0,0);
            annotations(end+1) = CADimensionProperty('thermalDirection','','Manufactured directions');
            annotations(end+1) = CADimensionProperty('horizontalColumn','','Manufactured columns');
            annotations(end+1) = CADimensionProperty('sample','','Manufactured samples');
            annotations(end+1) = CANumericProperty('reconstruction',{'sample','thermalDirection'},'','Stored reconstruction map');
            annotations(end+1) = CANumericProperty('source',{'thermalDirection','horizontalColumn'},'m s-1','Manufactured source',isComplex=true);
            annotations(end+1) = WVCoefficientAnnotation('Ath',{'thermalDirection','horizontalColumn'},'m','Manufactured amplitudes',canonicalBasis="manufactured",isComplex=true);
            annotations(end+1) = CANumericProperty('t',{},'s','Time');
        end
        function [w,file] = waveVortexTransformFromFile(path,options)
            arguments
                path char
                options.iTime (1,1) double {mustBeMember(options.iTime,1)} = 1
                options.shouldReadOnly (1,1) logical = true
            end
            file = NetCDFFile(path,shouldReadOnly=options.shouldReadOnly);
            try
                w = CAAnnotatedClass.annotatedClassFromGroup(file);
            catch exception
                file.close();
                rethrow(exception);
            end
            if nargout < 2
                file.close();
            end
        end
        function w = scientificFactory() %#ok<STOUT> This unsupported path always throws.
            error('ThermalInterfaceFixture:ScientificConstructionDisabled','Scientific construction is deliberately disabled in this fixture.');
        end
    end
end
