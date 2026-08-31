classdef WVCoefficientAnnotation < WVVariableAnnotation
    % Describe one canonical coefficient family of a WVTransform.
    %
    % Coefficient annotations are the ordered state contract shared by the
    % integrator and NetCDF persistence. In addition to the ordinary numeric
    % annotation, they identify auxiliary coordinates, the public basis, the
    % persistence role, and whether a physically empty family is omitted from
    % NetCDF storage.
    %
    % - Topic: Create coefficient annotations
    % - Topic: Inspect coefficient annotations
    % - Declaration: classdef WVCoefficientAnnotation < WVVariableAnnotation

    properties (SetAccess = private)
        % Auxiliary coordinate variable names associated with this family.
        % - Topic: Inspect coefficient annotations
        auxiliaryCoordinates string

        % Scientific basis exposed by the public coefficient property.
        % - Topic: Inspect coefficient annotations
        canonicalBasis string

        % Persistence role of this family.
        % - Topic: Inspect coefficient annotations
        persistenceRole string

        % NetCDF treatment when the canonical family is physically empty.
        % - Topic: Inspect coefficient annotations
        emptyFamilyPolicy string

        % Numeric-domain description used for validation and inspection.
        % - Topic: Inspect coefficient annotations
        numericDomain string
    end

    methods
        function self = WVCoefficientAnnotation(name,dimensions,units,description,options)
            % Create a canonical coefficient-family annotation.
            %
            % - Topic: Create coefficient annotations
            % - Declaration: annotation = WVCoefficientAnnotation(name,dimensions,units,description,options)
            % - Parameter name: coefficient property and tendency-field name
            % - Parameter dimensions: ordered logical dimensions
            % - Parameter units: canonical state units
            % - Parameter description: short scientific description
            % - Parameter options.auxiliaryCoordinates: associated coordinate names
            % - Parameter options.canonicalBasis: public scientific basis
            % - Parameter options.persistenceRole: persistence role; default `canonicalState`
            % - Parameter options.emptyFamilyPolicy: `persist` or `omit`
            % - Parameter options.isComplex: whether values may be complex
            % - Returns annotation: coefficient-family annotation
            arguments
                name char {mustBeNonempty}
                dimensions
                units char
                description char {mustBeNonempty}
                options.auxiliaryCoordinates (1,:) string = strings(1,0)
                options.canonicalBasis (1,1) string {mustBeNonempty}
                options.persistenceRole (1,1) string {mustBeMember(options.persistenceRole,["canonicalState" "diagnostic"])} = "canonicalState"
                options.emptyFamilyPolicy (1,1) string {mustBeMember(options.emptyFamilyPolicy,["persist" "omit"])} = "persist"
                options.isComplex (1,1) logical = false
            end

            self@WVVariableAnnotation(name,dimensions,units,description,isComplex=options.isComplex);
            self.auxiliaryCoordinates = options.auxiliaryCoordinates;
            self.canonicalBasis = options.canonicalBasis;
            self.persistenceRole = options.persistenceRole;
            self.emptyFamilyPolicy = options.emptyFamilyPolicy;
            if options.isComplex
                self.numericDomain = "complex double";
            else
                self.numericDomain = "real double";
            end
            self.isVariableWithLinearTimeStep = false;
            self.isVariableWithNonlinearTimeStep = true;
            self.isDependentOnApAmA0 = true;
            if isempty(options.auxiliaryCoordinates)
                self.attributes('wvm_auxiliary_coordinates') = '';
            else
                self.attributes('wvm_auxiliary_coordinates') = char(join(options.auxiliaryCoordinates," "));
            end
            self.attributes('wvm_canonical_basis') = char(options.canonicalBasis);
            self.attributes('wvm_persistence_role') = char(options.persistenceRole);
            self.attributes('wvm_empty_family_policy') = char(options.emptyFamilyPolicy);
            self.attributes('wvm_numeric_domain') = char(self.numericDomain);
        end

        function tf = isPhysicallyPresent(self,wvt)
            % Return whether this family has a physical NetCDF variable.
            %
            % - Topic: Inspect coefficient annotations
            % - Declaration: tf = isPhysicallyPresent(annotation,wvt)
            % - Parameter wvt: transform containing the coefficient property
            % - Returns tf: true when the family should be allocated
            arguments
                self (1,1) WVCoefficientAnnotation
                wvt (1,1) WVTransform
            end
            tf = self.emptyFamilyPolicy ~= "omit" || ~isempty(wvt.(self.name));
        end
    end
end
