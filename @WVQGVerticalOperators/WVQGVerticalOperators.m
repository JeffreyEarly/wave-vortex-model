classdef WVQGVerticalOperators < CAAnnotatedClass
    % Persist polynomial over-integration and physical-depth QGPV transforms.
    % These coordinates describe polynomial degree, not thermal eigenmodes.
    % Scientific construction does not change the thermal basis:
    % ```matlab
    % operators = WVQGVerticalOperators.fromGrid(z,2);
    % ```
    % - Topic: Create vertical operators
    % - Topic: Inspect vertical operators
    properties (SetAccess=private)
        % Native WKB Chebyshev nodes in meters, bottom to surface.
        % - Topic: Inspect vertical operators
        nativeZ
        % Over-integration nodes in meters, bottom to surface.
        % - Topic: Inspect vertical operators
        zQuadrature
        % Positive physical-depth integration weights in meters.
        % - Topic: Inspect vertical operators
        quadratureWeights
        % Interpolate independent interior QGPV to the quadrature grid.
        % - Topic: Inspect vertical operators
        qToQuadrature
        % Interpolate full-grid streamfunction or velocity to quadrature nodes.
        % - Topic: Inspect vertical operators
        phiToQuadrature
        % Physical-depth least-squares projection to independent QGPV nodes.
        % - Topic: Inspect vertical operators
        qFromQuadrature
        % Reconstruct interior QGPV from physical-norm polynomial coefficients.
        % - Topic: Inspect vertical operators
        qFromPolynomial
        % Map interior QGPV to coefficients whose squared norm is its integral.
        % - Topic: Inspect vertical operators
        qToPolynomial
    end
    properties (Dependent)
        % Interior physical nodes, without endpoint QGPV assumptions.
        % - Topic: Inspect vertical operators
        qNode
        % Increasing polynomial degrees, starting at zero.
        % - Topic: Inspect vertical operators
        polynomialDegree
    end
    methods
        function self=WVQGVerticalOperators(options)
            % Restore complete mathematical arrays without solving an EVP.
            % - Topic: Create vertical operators
            arguments (Input)
                options.nativeZ (:,1) double {mustBeFinite}
                options.zQuadrature (:,1) double {mustBeFinite}
                options.quadratureWeights (:,1) double {mustBePositive,mustBeFinite}
                options.qToQuadrature double {mustBeFinite}
                options.phiToQuadrature double {mustBeFinite}
                options.qFromQuadrature double {mustBeFinite}
                options.qFromPolynomial double {mustBeFinite}
                options.qToPolynomial double {mustBeFinite}
            end
            nz=length(options.nativeZ); nq=nz-2; nf=length(options.zQuadrature);
            shapes={[nf nq],[nf nz],[nq nf],[nq nq],[nq nq]};
            names=["qToQuadrature" "phiToQuadrature" "qFromQuadrature" "qFromPolynomial" "qToPolynomial"];
            if nz<5 || nf<nz || any(diff(options.nativeZ)<=0) || any(diff(options.zQuadrature)<=0) || length(options.quadratureWeights)~=nf
                error('WVQGVerticalOperators:InvalidGrid','Use increasing native and quadrature grids and one positive weight per quadrature node.');
            end
            for i=1:length(names)
                if ~isequal(size(options.(names(i))),shapes{i})
                    error('WVQGVerticalOperators:InvalidShape','%s must have size %s.',names(i),mat2str(shapes{i}));
                end
            end
            for name=string(fieldnames(options)).', self.(name)=options.(name); end
        end
        function value=get.qNode(self), value=self.nativeZ(2:end-1); end
        function value=get.polynomialDegree(self), value=(0:length(self.nativeZ)-3)'; end
        function rates=unitDampingRates(self)
            % Dimensionless spectral-vanishing rates with maximum one.
            % Multiply by Cz Umax/Delta_h to obtain inverse seconds.
            % - Topic: Inspect vertical operators
            degree=self.polynomialDegree; maximum=degree(end); cutoff=floor(maximum^.75);
            rates=zeros(size(degree)); active=degree>cutoff;
            rates(active)=exp(-((degree(active)-maximum)./(degree(active)-cutoff)).^2).*(degree(active)/maximum).^2;
        end
    end
    methods (Static)
        function self=fromGrid(z,quadratureFactor)
            % Build operators on an existing WKB Chebyshev grid.
            % - Topic: Create vertical operators
            arguments (Input)
                z (:,1) double {mustBeFinite}
                quadratureFactor (1,1) double {mustBeGreaterThanOrEqual(quadratureFactor,1),mustBeFinite}=2
            end
            data=WVInternal.qgVerticalOperators(z,ceil(quadratureFactor*length(z)));
            args=namedargs2cell(data); self=WVQGVerticalOperators(args{:});
        end
        function names=classRequiredPropertyNames()
            names={'nativeZ','zQuadrature','quadratureWeights','qToQuadrature','phiToQuadrature','qFromQuadrature','qFromPolynomial','qToPolynomial'};
        end
        function annotations=classDefinedPropertyAnnotations()
            annotations=[CADimensionProperty('nativeZ','m','native vertical grid'),CADimensionProperty('qNode','m','independent interior QGPV nodes'),CADimensionProperty('zQuadrature','m','nonlinear quadrature grid'),CADimensionProperty('polynomialDegree','1','vertical polynomial degree')];
            annotations(end+1)=CANumericProperty('quadratureWeights',{'zQuadrature'},'m','positive physical-depth weights');
            names={'qToQuadrature','phiToQuadrature','qFromQuadrature','qFromPolynomial','qToPolynomial'};
            dims={{'zQuadrature','qNode'},{'zQuadrature','nativeZ'},{'qNode','zQuadrature'},{'qNode','polynomialDegree'},{'polynomialDegree','qNode'}};
            units={'1','1','1','m-1/2','m1/2'};
            for i=1:length(names), annotations(end+1)=CANumericProperty(names{i},dims{i},units{i},names{i}); end
        end
    end
end
