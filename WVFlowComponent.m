classdef WVFlowComponent < handle & matlab.mixin.Heterogeneous
    % Select resolved coefficient families and compose flow components.
    %
    % In the legacy wave-vortex models, each degree of freedom has an analytical
    % solution to the equations of motion. This class groups together
    % solutions of a particular type and provides a mapping between their
    % analytical solutions and their numerical representation.
    %
    % Component masks identify the coefficient locations occupied by the
    % family. This indexing is an important part of the abstraction: one
    % analytical mode, identified by horizontal mode numbers, vertical mode,
    % amplitude, and phase, may require a primary coefficient and a Hermitian
    % conjugate stored at different locations or even in different members of
    % `Ap`, `Am`, and `A0`.
    %
    % Primary components provide that mapping between mode numbers,
    % `WVOrthogonalSolution` objects, and coefficient locations. They also
    % define the degrees of freedom carried by each mode. Diagnostic or total
    % components may combine those masks without introducing a new independent
    % solution family.
    %
    % Family-keyed selectors also support models with independently shaped
    % coefficient arrays. Selecting coefficients does not imply that their
    % physical energies are orthogonal; model-specific diagnostics retain
    % cross terms. Analytical initialization remains a primary-mode capability.
    %
    % ```matlab
    % component = WVFlowComponent(wvt,coefficientMasks=struct(Amda=true));
    % fields = wvt.reconstructFields("eta",flowComponent=component);
    % ```
    %
    % - Topic: Initialization
    % - Topic: Masks
    % - Topic: Properties
    properties (Access=private)
        bitmask = 0
    end
    properties
        % name of the flow feature
        %
        % long-form version of the feature name, e.g., "internal gravity wave"
        % - Topic: Properties
        name

        % name of the flow feature
        %
        % camel-case version of the feature name, e.g., "internalGravityWave"
        % - Topic: Properties
        shortName

        % abbreviated name
        %
        % abreviated feature name, e.g., "igw" for internal gravity waves.
        % - Topic: Properties
        abbreviatedName

        % reference to the wave vortex transform
        %
        % reference to the WVTransform instance
        % - Topic: Properties
        wvt

        % returns a mask indicating where solutions live in the Ap matrix.
        %
        % Returns a 'mask' (matrix with 1s or 0s) indicating where
        % different solution types live in the Ap matrix.
        %
        % - Topic: Masks
        maskAp

        % returns a mask indicating where solutions live in the Am matrix.
        %
        % Returns a 'mask' (matrix with 1s or 0s) indicating where
        % different solution types live in the Am matrix.
        %
        % - Topic: Masks
        maskAm

        % returns a mask indicating where solutions live in the A0 matrix.
        %
        % Returns a 'mask' (matrix with 1s or 0s) indicating where
        % different solution types live in the A0 matrix.
        %
        % - Topic: Masks
        maskA0
    end

    properties (Access = private)
        familyMasks_ (1,1) struct = struct()
    end

    properties (Dependent, SetAccess = private)
        % Masks keyed by the transform's canonical coefficient families.
        %
        % Omitted families select zero. Legacy masks remain live aliases.
        % - Topic: Masks
        coefficientMasks
    end

    properties (Dependent)
        % Whether the legacy A0 mask selects any coefficients.
        % Use coefficientMasks for models with other canonical families.
        % - Topic: Masks
        hasPVComponent logical
        % Whether the legacy Ap or Am mask selects any coefficients.
        % Use coefficientMasks for models with other canonical families.
        % - Topic: Masks
        hasWaveComponent logical
    end

    methods
        function self = WVFlowComponent(wvt,options)
            % Create a selector for resolved coefficient families.
            %
            % Supply scalar zero/one or exact family-shaped masks through
            % `coefficientMasks`. New-family masks are fixed at construction.
            % Masks must preserve the concrete model's conjugate symmetries.
            %
            % - Topic: Initialization
            % - Declaration: solnGroup = WVFlowComponent(wvt,options)
            % - Parameter wvt: instance of a WVTransform
            % - Parameter options.coefficientMasks: family-keyed scalar structure; omitted families select zero
            % - Parameter options.maskAp: legacy positive-wave selector
            % - Parameter options.maskAm: legacy negative-wave selector
            % - Parameter options.maskA0: legacy zero-frequency selector
            % - Returns solnGroup: resolved coefficient selector
            arguments
                wvt WVTransform {mustBeNonempty}
                options.maskAp = 0
                options.maskAm = 0
                options.maskA0 = 0
                options.coefficientMasks (1,1) struct = struct()
            end
            self.wvt = wvt;
            self.maskAp = options.maskAp;
            self.maskAm = options.maskAm;
            self.maskA0 = options.maskA0;
            annotations = wvt.coefficientStateAnnotations();
            names = string({annotations.name});
            for name = string(fieldnames(options.coefficientMasks)).'
                if ~ismember(name,names)
                    error('WVFlowComponent:UnknownFamily','Unknown coefficient family %s.',name)
                end
                mask = options.coefficientMasks.(name);
                if ~(isnumeric(mask) || islogical(mask)) || ~isreal(mask) || any(~ismember(mask(:),[0 1])) || (~isscalar(mask) && ~isequal(size(mask),size(wvt.(name))))
                    error('WVFlowComponent:InvalidMask','Mask %s must be zero/one and scalar or exactly the coefficient-family shape.',name)
                end
                if ismember(name,["Ap" "Am" "A0"])
                    legacyName = "mask"+name;
                    if ~isequal(options.(legacyName),0)
                        error('WVFlowComponent:DuplicateMask','Specify %s through coefficientMasks or its legacy option, not both.',name)
                    end
                    self.(legacyName) = logical(mask);
                else
                    self.familyMasks_.(name) = logical(mask);
                end
            end
        end

        function masks = get.coefficientMasks(self)
            annotations = self.wvt.coefficientStateAnnotations();
            masks = struct();
            for annotation = annotations
                name = annotation.name;
                if ismember(string(name),["Ap" "Am" "A0"])
                    masks.(name) = self.(['mask' name]);
                elseif isfield(self.familyMasks_,name)
                    masks.(name) = self.familyMasks_.(name);
                else
                    masks.(name) = false;
                end
            end
        end

        function bool = contains(self,otherComponent)
            % Test containment of selections in the same resolved state.
            %
            % Physically empty families contribute no selected modes.
            % - Topic: Masks
            % - Declaration: bool = contains(otherComponent)
            % - Parameter otherComponent: selector belonging to the same transform
            % - Returns bool: true when every selected coefficient is contained
            if self.wvt ~= otherComponent.wvt
                error('WVFlowComponent:DifferentTransform','Components must belong to the same transform.')
            end
            first = self.coefficientMasks;
            second = otherComponent.coefficientMasks;
            bool = true;
            for familyName = string(fieldnames(first)).'
                if isempty(self.wvt.(familyName)), continue; end
                a = first.(familyName); b = second.(familyName);
                bool = bool && all(~b(:) | a(:));
            end
        end

        function h = plus(f,g)
            % Form the union of two selections on the same transform.
            %
            % Overlapping modes are selected once. Energies of the two
            % components are not assumed to be additive.
            % - Topic: Masks
            % - Declaration: h = plus(f,g)
            % - Parameter f: first selector
            % - Parameter g: second selector on the same transform
            % - Returns h: component selecting the union of both masks
            if f.wvt ~= g.wvt
                error('WVFlowComponent:DifferentTransform','Components must belong to the same transform.')
            end
            h = WVFlowComponent(f.wvt);
            h.name = join(cat(2,string(f.name),string(g.name)),' + ');
            h.shortName = join(cat(2,string(f.shortName),string(g.shortName)),'');
            h.abbreviatedName = join(cat(2,string(f.abbreviatedName),string(g.abbreviatedName)),'_');
            h.maskAp = f.maskAp | g.maskAp;
            h.maskAm = f.maskAm | g.maskAm;
            h.maskA0 = f.maskA0 | g.maskA0;
            first = f.coefficientMasks;
            second = g.coefficientMasks;
            for familyName = setdiff(string(fieldnames(first)),["Ap" "Am" "A0"]).'
                h.familyMasks_.(familyName) = first.(familyName) | second.(familyName);
            end
        end

        function bool = get.hasPVComponent(self)
            arguments (Input)
                self WVFlowComponent
            end
            arguments (Output)
                bool logical
            end
            bool = any(self.maskA0(:));
        end

        function bool = get.hasWaveComponent(self)
            arguments (Input)
                self WVFlowComponent
            end
            arguments (Output)
                bool logical
            end
            bool = any(self.maskAp(:)) | any(self.maskAm(:));
        end

        function [Ap,Am,A0] = randomAmplitudes(self,options)
            % returns random amplitude for a valid flow state
            %
            % Returns Ap, Am, A0 matrices initialized with random amplitude
            % for this flow component. These resulting matrices will have
            % the correct symmetries for a valid flow state.
            % Models with other canonical families must initialize those
            % families explicitly; this legacy analytical API rejects them.
            %
            % - Topic: Initialization
            % - Declaration: Ap,Am,A0] = randomAmplitudes()
            % - Returns Ap: matrix of size [Nj Nkl]
            % - Returns Am: matrix of size [Nj Nkl]
            % - Returns A0: matrix of size [Nj Nkl]
            arguments (Input)
                self WVFlowComponent {mustBeNonempty}
                options.shouldOnlyRandomizeOrientations (1,1) double {mustBeMember(options.shouldOnlyRandomizeOrientations,[0 1])} = 0
            end
            arguments (Output)
                Ap double
                Am double
                A0 double
            end
            
            annotations = self.wvt.coefficientStateAnnotations();
            if any(~ismember(string({annotations.name}),["Ap" "Am" "A0"]))
                error('WVFlowComponent:UnsupportedAnalyticalModes','Random analytical-mode initialization is not defined for these coefficient families. Initialize the canonical families explicitly.')
            end
            if self.hasPVComponent
                A0 = zeros(self.wvt.spectralMatrixSize);
                validModes = self.maskA0 & self.wvt.totalFlowComponent.maskOfPrimaryModesForCoefficientMatrix(WVCoefficientMatrix.A0);
                if any(validModes(:))
                    A0 = ((randn(self.wvt.spectralMatrixSize) + sqrt(-1)*randn(self.wvt.spectralMatrixSize))/sqrt(2));
                    A0(~validModes) = 0;
                    A0(self.wvt.Kh == 0) = sqrt(2)*real(A0(self.wvt.Kh == 0));
                    if options.shouldOnlyRandomizeOrientations == 1
                        A0(logical(validModes)) = A0(logical(validModes)) ./ abs(A0(logical(validModes)));
                    end
                end
            else
                A0 = 0;
            end

            if self.hasWaveComponent
                Ap = zeros(self.wvt.spectralMatrixSize);
                Am = zeros(self.wvt.spectralMatrixSize);

                validModes = self.maskAp & self.wvt.totalFlowComponent.maskOfPrimaryModesForCoefficientMatrix(WVCoefficientMatrix.Ap);
                if any(validModes(:))
                    Ap = ((randn(self.wvt.spectralMatrixSize) + sqrt(-1)*randn(self.wvt.spectralMatrixSize))/sqrt(2));
                    Ap(~validModes) = 0;
                    if options.shouldOnlyRandomizeOrientations == 1
                        Ap(logical(validModes)) = Ap(logical(validModes)) ./ abs(Ap(logical(validModes)));
                    end

                    conjugateModes = self.maskAm & self.wvt.totalFlowComponent.maskOfConjugateModesForCoefficientMatrix(WVCoefficientMatrix.Am);
                    if any(conjugateModes(:))
                        Am(logical(conjugateModes)) = conj(Ap(logical(conjugateModes)));
                    end
                end
                
                validModes = self.maskAm & self.wvt.totalFlowComponent.maskOfPrimaryModesForCoefficientMatrix(WVCoefficientMatrix.Am);
                if any(validModes(:))
                    primaryAm = ((randn(self.wvt.spectralMatrixSize) + sqrt(-1)*randn(self.wvt.spectralMatrixSize))/sqrt(2));
                    if options.shouldOnlyRandomizeOrientations == 1
                        primaryAm(logical(validModes)) = primaryAm(logical(validModes)) ./ abs(primaryAm(logical(validModes)));
                    end
                    Am(logical(validModes)) = primaryAm(logical(validModes));
                end
            else
                Ap = 0;
                Am = 0;
            end
        end

        function [Ap,Am,A0] = randomAmplitudesWithSpectrum(self,options)
            % initialize with coefficients following a specified spectrum
            %
            % This allows you to initialize amplitudes following a spectrum
            % defined in terms of wavenumber and vertical mode.
            %
            % - Topic: Initialization
            % - Declaration: Ap,Am,A0] = randomAmplitudesWithSpectrum(options)
            % - Parameter A0Spectrum: (optional) function_handle with signature @(k,j), defaults to a white spectrum.
            % - Parameter ApmSpectrum: (optional) function_handle with signature @(k,j), defaults to a white spectrum.
            % - Parameter shouldOnlyRandomizeOrientations: boolean indicating whether randomness in amplitudes should be eliminated (default 0)
            % - Returns Ap: matrix of size [Nj Nkl]
            % - Returns Am: matrix of size [Nj Nkl]
            % - Returns A0: matrix of size [Nj Nkl]
            arguments (Input)
                self WVFlowComponent {mustBeNonempty}
                options.A0Spectrum = @isempty
                options.ApmSpectrum = @isempty
                options.shouldOnlyRandomizeOrientations (1,1) double {mustBeMember(options.shouldOnlyRandomizeOrientations,[0 1])} = 0
            end
            arguments (Output)
                Ap double
                Am double
                A0 double
            end
 
            [Ap,Am,A0] = self.randomAmplitudes(shouldOnlyRandomizeOrientations=options.shouldOnlyRandomizeOrientations);
            hasRandomA0 = any(A0(:));
            hasRandomApm = any(Ap(:)) || any(Am(:));

            kRadial = self.wvt.kRadial;
            Kh = self.wvt.Kh;
            J = self.wvt.J;
            dk = kRadial(2)-kRadial(1);
            for iK=1:length(kRadial)
                indicesForK = kRadial(iK)-dk/2 < Kh & Kh <= kRadial(iK)+dk/2;
                for iJ=1:length(self.wvt.j)
                    % this is faster than logical indexing
                    indicesForKJ = find(indicesForK & J == self.wvt.j(iJ));
                    nIndicesForKJ = length(indicesForKJ);

                    if hasRandomA0
                        if isequal(options.A0Spectrum,@isempty)
                            energyPerA0Component = (kRadial(iK)+dk/2 - max(kRadial(iK)-dk/2,0))/nIndicesForKJ;
                        else
                            energyPerA0Component = integral(@(k) options.A0Spectrum(k,J(iJ)),max(kRadial(iK)-dk/2,0),kRadial(iK)+dk/2)/nIndicesForKJ;
                        end
                        A0(indicesForKJ) = A0(indicesForKJ).*sqrt(energyPerA0Component./(self.wvt.A0_TE_factor(indicesForKJ) ));
                    end

                    if hasRandomApm
                        if isequal(options.ApmSpectrum,@isempty)
                            energyPerApmComponent = (kRadial(iK)+dk/2 - max(kRadial(iK)-dk/2,0))/nIndicesForKJ/2;
                        else
                            energyPerApmComponent = integral(@(k) options.ApmSpectrum(k,J(iJ)),max(kRadial(iK)-dk/2,0),kRadial(iK)+dk/2)/nIndicesForKJ/2;
                        end
                        Ap(indicesForKJ) = Ap(indicesForKJ).*sqrt(energyPerApmComponent./(self.wvt.Apm_TE_factor(indicesForKJ) ));
                        Am(indicesForKJ) = Am(indicesForKJ).*sqrt(energyPerApmComponent./(self.wvt.Apm_TE_factor(indicesForKJ) ));
                    end
                end
            end
            A0(isnan(A0)) = 0;
            Ap(isnan(Ap)) = 0;
            Am(isnan(Am)) = 0;
        end
    end

    % methods (Sealed)
    %     function tf = eq(obj1, obj2)
    %         tf = eq@handle(obj1, obj2);
    %     end
    % 
    %     function tf = ne(obj1, obj2)
    %         tf = ne@handle(obj1, obj2);
    %     end
    % end
    
end
