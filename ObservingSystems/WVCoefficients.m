classdef WVCoefficients < WVObservingSystem
    % Integrate and record the wave-vortex coefficients
    %
    % WVCoefficients supplies the ordered coefficient families declared by
    % `coefficientStateAnnotations` to a WVModel integrator.

    properties (GetAccess=public, SetAccess=public)
        absTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
        tolerancePolicy (1,1) string {mustBeMember(tolerancePolicy,["energy","family"])} = "energy"
        pvAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
        surfaceAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
        bottomAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
    end

    properties (Access=private)
        coefficientFamilyNames (1,:) string = strings(1,0)
        coefficientFamilyShapes (1,:) cell = cell(1,0)
    end

    methods
        function self = WVCoefficients(model,options)
            % Create a coefficient observer with local spectral tolerances.
            %
            % Family scaling is available for v5 free-surface QG and Boussinesq.
            % Empty invariant scales match the energy floor at the first retained
            % mode and lowest nonzero wavenumber, separately for each endpoint.
            % Boundary scales use displacement anomalies, in m^(3/2); PV uses m/s.
            %
            % - Topic: Initialization
            % - Declaration: self = WVCoefficients(model,options)
            % - Parameter model: owning WVModel
            % - Parameter options: energy scale, policy, and optional invariant scales
            % - Returns self: coefficient observing system
            arguments
                model WVModel
                options.absTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
                options.tolerancePolicy (1,1) string {mustBeMember(options.tolerancePolicy,["energy","family"])} = "energy"
                options.pvAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
                options.surfaceAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
                options.bottomAbsTolerance double {mustBeReal,mustBeFinite,mustBePositive} = []
            end

            self@WVObservingSystem(model,"wave-vortex coefficient flux");
            for name=string(fieldnames(options)).'
                self.(name)=options.(name);
            end

            annotations = self.wvt.coefficientStateAnnotations();
            self.coefficientFamilyNames = string({annotations.name});
            self.coefficientFamilyShapes = arrayfun(@(annotation)size(self.wvt.(annotation.name)),annotations,UniformOutput=false);
            self.nFluxComponents = length(annotations);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %
        % Integrated variables
        %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function nArray = lengthOfFluxComponents(self)
            % return an array containing the numel of each flux component.
            nArray = zeros(length(self.coefficientFamilyShapes),1);
            for iFamily = 1:length(self.coefficientFamilyShapes)
                nArray(iFamily) = prod(self.coefficientFamilyShapes{iFamily});
            end
        end

        function contract = portableImplementationContract(self)
            % Return the paired portable implementation contract.
            %
            % - Topic: Internal
            % - Declaration: contract = portableImplementationContract(self)
            % - Returns contract: versioned data-only observer contract
            % - Developer: true
            familyNames = self.coefficientFamilyNames;
            payload = struct("name",string(self.name),"absTolerance",double(self.absTolerance),"coefficientFamilies",familyNames);
            if self.tolerancePolicy=="energy" && isempty(self.pvAbsTolerance) && isempty(self.surfaceAbsTolerance) && isempty(self.bottomAbsTolerance) && (isequal(familyNames,["Ap" "Am" "A0"]) || isequal(familyNames,"A0"))
                contract = self.supportedPortableImplementationContract("WVCoefficients",payload);
            else
                contract = WVInternal.portableImplementationContract(string(class(self)),"WVCoefficients","unavailable","The portable runtime does not implement this coefficient-family layout or tolerance policy.",payload);
            end
        end

        function Y0 = absErrorTolerance(self)
            toleranceState = self.wvt.coefficientAbsoluteTolerances(self.absTolerance);
            scales=struct(pvAbsTolerance=self.pvAbsTolerance,surfaceAbsTolerance=self.surfaceAbsTolerance,bottomAbsTolerance=self.bottomAbsTolerance);
            if self.tolerancePolicy=="family"
                toleranceState=WVInternal.familyCoefficientTolerances(self.wvt,toleranceState,self.absTolerance,scales);
            elseif any(structfun(@(value)~isempty(value),scales))
                error('WVCoefficients:InvalidTolerancePolicy','Invariant scales require tolerancePolicy="family".');
            end
            Y0 = cell(length(self.coefficientFamilyNames),1);
            for iFamily = 1:length(self.coefficientFamilyNames)
                Y0{iFamily} = toleranceState.(self.coefficientFamilyNames(iFamily));
            end
        end

        function Y0 = initialConditions(self)
            Y0 = cell(length(self.coefficientFamilyNames),1);
            for iFamily = 1:length(self.coefficientFamilyNames)
                Y0{iFamily} = self.wvt.(self.coefficientFamilyNames(iFamily));
            end
        end

        function nlF = fluxAtTime(self,t,y0)
            self.updateIntegratorValues(t,y0)

            tendency = self.wvt.coefficientTendency();
            nlF = cell(1,length(self.coefficientFamilyNames));
            for iFamily = 1:length(self.coefficientFamilyNames)
                nlF{iFamily} = tendency.(self.coefficientFamilyNames(iFamily));
            end
        end

        function updateIntegratorValues(self,t,y0)
            self.wvt.t = t;
            for iFamily = 1:length(self.coefficientFamilyNames)
                name = self.coefficientFamilyNames(iFamily);
                self.wvt.(name) = reshape(y0{iFamily},self.coefficientFamilyShapes{iFamily});
            end
        end

        function os = observingSystemWithResolutionOfTransform(self,wvtX2)
            %create a new WVObservingSystem with a new resolution
            %
            % Subclasses to should override this method an implement the
            % correct logic.
            %
            % - Topic: Initialization
            % - Declaration: os = observingSystemWithResolutionOfTransform(self,wvtX2)
            % - Parameter wvtX2: the WVTransform with increased resolution
            % - Returns force: a new instance of WVObservingSystem
            os = WVCoefficients(wvtX2,self.name);
        end
    end

    methods (Static)
        % Useful to make a plot
        % [alpha0, alphapm] = model.absoluteErrorTolerance(absTolerance=1e-6);
        % E_noise_kr = wvt.transformToRadialWavenumber(wvt.A0_TE_factor .* alpha0 .* alpha0);
        % plot(wvt.kRadial,E_noise_kr/dk,LineWidth=2,Color=0*[1 1 1])
        function [alpha0, alphapm] = errorTolerances(wvt,absTolerance)
            alpha0 = ones(wvt.spectralMatrixSize);
            alphapm = ones(wvt.spectralMatrixSize);
            AbsErrorSpectrum = @isempty;
            kRadial = wvt.kRadial;
            Kh = wvt.Kh;
            J = wvt.J;
            dk = kRadial(2)-kRadial(1);
            for iK=1:length(kRadial)
                indicesForK = kRadial(iK)-dk/2 < Kh & Kh <= kRadial(iK)+dk/2;
                for iJ=1:length(wvt.j)
                    % this is faster than logical indexing
                    indicesForKJ = find(indicesForK & J == wvt.j(iJ));
                    nIndicesForKJ = length(indicesForKJ);

                    if isequal(AbsErrorSpectrum,@isempty)
                        energyPerA0Component = (kRadial(iK)+dk/2 - max(kRadial(iK)-dk/2,0))/nIndicesForKJ;
                        energyPerApmComponent = energyPerA0Component;
                    else
                        energyPerA0Component = integral(@(k) A0AbsErrorSpectrum(k,J(iJ)),max(kRadial(iK)-dk/2,0),kRadial(iK)+dk/2)/nIndicesForKJ;
                        energyPerApmComponent = integral(@(k) ApmAbsErrorSpectrum(k,J(iJ)),max(kRadial(iK)-dk/2,0),kRadial(iK)+dk/2)/nIndicesForKJ/2;
                    end
                    if wvt.hasPVComponent == true
                        alpha0(indicesForKJ) = absTolerance*sqrt(energyPerA0Component./(wvt.A0_TE_factor(indicesForKJ) ));
                    end
                    if wvt.hasWaveComponent == true
                        alphapm(indicesForKJ) = absTolerance*sqrt(energyPerApmComponent./(wvt.Apm_TE_factor(indicesForKJ) ));
                    end
                end
            end

            alpha0(isinf(alpha0)) = 1;
            alphapm(isinf(alphapm)) = 1;
        end

        function vars = classRequiredPropertyNames()
            vars = {'absTolerance','tolerancePolicy','pvAbsTolerance','surfaceAbsTolerance','bottomAbsTolerance'};
        end

        function propertyAnnotations = classDefinedPropertyAnnotations()
            arguments (Output)
                propertyAnnotations CAPropertyAnnotation
            end
            propertyAnnotations = CAPropertyAnnotation.empty(0,0);
            propertyAnnotations(end+1) = CAPropertyAnnotation('tolerancePolicy','energy or family adaptive coefficient metric');
            propertyAnnotations(end+1) = CAPropertyAnnotation('pvAbsTolerance','PV spectral amplitude scale (m s-1); empty selects reference calibration');
            propertyAnnotations(end+1) = CAPropertyAnnotation('surfaceAbsTolerance','surface displacement spectral amplitude scale (m3/2); empty selects reference calibration');
            propertyAnnotations(end+1) = CAPropertyAnnotation('bottomAbsTolerance','bottom displacement spectral amplitude scale (m3/2); empty selects reference calibration');
            propertyAnnotations(end+1) = CANumericProperty('absTolerance', {}, 'm2 s-1','coefficient-error scale used to construct mode-dependent adaptive tolerances');
        end
    end
end
