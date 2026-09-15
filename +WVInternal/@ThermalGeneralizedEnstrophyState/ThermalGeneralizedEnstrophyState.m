classdef ThermalGeneralizedEnstrophyState < CAAnnotatedClass
    % Canonical native thermal generalized-enstrophy closure state.
    %
    % The retained polynomial eigenbasis, dual and spectrum make restart and
    % cutoff changes independent of quadrature assembly and eigensolves.
    properties (SetAccess=private)
        schemaVersion
        generalizedPolynomialDegree
        generalizedDirection
        generalizedRadius
        generalizedEndpoint
        generalizedHorizontalAxis
        sourceN20
        sourceInverseScale
        sourceDepth
        sourceLatitude
        sourceCoriolis
        sourceGravity
        sourceHorizontalDomain
        boundaryWeightMultiplier
        effectiveBoundaryDepth
        boundaryWeights
        constructionQuadratureCount
        polynomialEigenvectors
        polynomialDuals
        generalizedEigenvalues
        singularValueUncertainty
        eigenvalueUncertainty
        clusterUpperOrdinal
        eigenvalueNormalization
        energyFormDrift
        generalizedFormDrift
        generalizedOperatorDrift
        energyOrthogonalityResidual
        generalizedDiagonalizationResidual
        factorizationResidual
        energyFactorReciprocalCondition
    end

    methods
        function self=ThermalGeneralizedEnstrophyState(options)
            % Restore the canonical state without scientific construction.
            arguments
                options.schemaVersion (1,1) double {mustBeInteger,mustBePositive}
                options.generalizedPolynomialDegree (:,1) double {mustBeInteger,mustBeNonnegative}
                options.generalizedDirection (:,1) double {mustBeInteger,mustBePositive}
                options.generalizedRadius (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.generalizedEndpoint (:,1) double {mustBeInteger,mustBePositive}
                options.generalizedHorizontalAxis (:,1) double {mustBeInteger,mustBePositive}
                options.sourceN20 (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceInverseScale (1,1) double {mustBeReal,mustBeFinite}
                options.sourceDepth (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceLatitude (1,1) double {mustBeReal,mustBeFinite}
                options.sourceCoriolis (1,1) double {mustBeReal,mustBeFinite,mustBeNonzero}
                options.sourceGravity (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.sourceHorizontalDomain (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.boundaryWeightMultiplier (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.effectiveBoundaryDepth (1,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.boundaryWeights (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.constructionQuadratureCount (1,1) double {mustBeInteger,mustBePositive}
                options.polynomialEigenvectors double {mustBeReal,mustBeFinite}
                options.polynomialDuals double {mustBeReal,mustBeFinite}
                options.generalizedEigenvalues double {mustBeReal,mustBeFinite,mustBePositive}
                options.singularValueUncertainty double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.eigenvalueUncertainty double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.clusterUpperOrdinal double {mustBeInteger,mustBePositive}
                options.eigenvalueNormalization (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
                options.energyFormDrift (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.generalizedFormDrift (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.generalizedOperatorDrift (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.energyOrthogonalityResidual (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.generalizedDiagonalizationResidual (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.factorizationResidual (:,1) double {mustBeReal,mustBeFinite,mustBeNonnegative}
                options.energyFactorReciprocalCondition (:,1) double {mustBeReal,mustBeFinite,mustBePositive}
            end
            self@CAAnnotatedClass();
            n=numel(options.generalizedDirection); p=numel(options.generalizedRadius);
            if n==0 || p==0
                error('WV:ThermalGeneralizedEnstrophyState','The stored native thermal closure state must contain directions and radii.');
            end
            validShape=size(options.polynomialEigenvectors,1)==n && size(options.polynomialEigenvectors,2)==n && size(options.polynomialEigenvectors,3)==p && ...
                size(options.polynomialDuals,1)==n && size(options.polynomialDuals,2)==n && size(options.polynomialDuals,3)==p;
            matrices={options.generalizedEigenvalues,options.singularValueUncertainty,options.eigenvalueUncertainty,options.clusterUpperOrdinal};
            validMatrices=all(cellfun(@(x)size(x,1)==n && size(x,2)==p && ndims(x)<=2,matrices));
            evidence={options.eigenvalueNormalization,options.energyFormDrift,options.generalizedFormDrift,options.generalizedOperatorDrift,options.energyOrthogonalityResidual,options.generalizedDiagonalizationResidual,options.factorizationResidual,options.energyFactorReciprocalCondition};
            validEvidence=all(cellfun(@(x)numel(x)==p,evidence));
            if options.sourceInverseScale==0
                expectedBoundaryDepth=options.sourceDepth/4;
            else
                expectedBoundaryDepth=tanh(options.sourceInverseScale*options.sourceDepth/2)/(2*options.sourceInverseScale);
            end
            expectedBoundaryWeights=options.boundaryWeightMultiplier*options.sourceCoriolis^2/expectedBoundaryDepth*ones(2,1);
            if options.schemaVersion~=1 || ~isequal(options.generalizedPolynomialDegree,(0:n-1)') || ...
                    ~isequal(options.generalizedDirection,(1:n)') || ~isequal(options.generalizedEndpoint,[1;2]) || ...
                    ~isequal(options.generalizedHorizontalAxis,[1;2]) || numel(options.sourceHorizontalDomain)~=2 || ...
                    any(diff(options.generalizedRadius)<=0) || numel(options.boundaryWeights)~=2 || ...
                    ~validShape || ~validMatrices || ~validEvidence || ...
                    any(diff(options.generalizedEigenvalues,1,1)<0,'all') || ...
                    any(sqrt(options.generalizedEigenvalues)-options.singularValueUncertainty<=0,'all') || ...
                    any(abs(options.eigenvalueUncertainty-(2*sqrt(options.generalizedEigenvalues).*options.singularValueUncertainty+options.singularValueUncertainty.^2))> ...
                    1e-12*max(options.eigenvalueUncertainty,realmin),'all') || ...
                    any(options.clusterUpperOrdinal<(1:n)' | options.clusterUpperOrdinal>n,'all') || ...
                    any(options.eigenvalueNormalization~=options.generalizedEigenvalues(end,:).') || ...
                    abs(options.effectiveBoundaryDepth/expectedBoundaryDepth-1)>1e-12 || ...
                    any(abs(options.boundaryWeights./expectedBoundaryWeights-1)>1e-12) || ...
                    mod(options.constructionQuadratureCount,2)~=0 || options.constructionQuadratureCount<4*n+2 || ...
                    max([options.energyFormDrift;options.generalizedFormDrift;options.generalizedOperatorDrift;options.energyOrthogonalityResidual;options.generalizedDiagonalizationResidual;options.factorizationResidual],[],'all')>1e-8 || ...
                    any(options.energyFactorReciprocalCondition<eps)
                error('WV:ThermalGeneralizedEnstrophyState','The stored native thermal closure state has inconsistent dimensions or coordinates.');
            end
            for page=1:p
                upper=options.clusterUpperOrdinal(:,page);
                sigma=sqrt(options.generalizedEigenvalues(:,page));
                uncertainty=options.singularValueUncertainty(:,page);
                expectedUpper=zeros(n,1); first=1; right=sigma(1)+uncertainty(1);
                for j=2:n+1
                    if j<=n && sigma(j)-uncertainty(j)<=right
                        right=max(right,sigma(j)+uncertainty(j));
                        continue
                    end
                    expectedUpper(first:j-1)=j-1;
                    if j<=n, first=j; right=sigma(j)+uncertainty(j); end
                end
                if ~isequal(upper,expectedUpper) || any(diff(upper)<0) || any(upper(upper)~=upper) || norm(options.polynomialDuals(:,:,page)*options.polynomialEigenvectors(:,:,page)-eye(n),2)>1e-8
                    error('WV:ThermalGeneralizedEnstrophyState','The stored generalized spectrum has an invalid cluster partition or polynomial dual.');
                end
                first=1;
                for last=unique(upper).'
                    lambdaA=options.generalizedEigenvalues(first,page); lambdaB=options.generalizedEigenvalues(last,page);
                    if last>first && (lambdaB-lambdaA)/lambdaB>1e-8
                        error('WV:ThermalGeneralizedEnstrophyState','A stored uncertainty-connected cluster spans more than 1e-8 in lambda.');
                    end
                    first=last+1;
                end
            end
            for name=string(fieldnames(options)).', self.(name)=options.(name); end
        end
    end

    methods (Static)
        function self=fromTransform(wvt,options)
            % Construct and qualify a native closure state for this transform.
            arguments
                wvt (1,1) WVTransformFreeSurfaceThermalQG
                options.boundaryWeightMultiplier (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1
            end
            state=WVInternal.buildThermalGeneralizedEnstrophyState(wvt,options.boundaryWeightMultiplier);
            args=namedargs2cell(state);
            self=WVInternal.ThermalGeneralizedEnstrophyState(args{:});
        end

        function names=classRequiredPropertyNames()
            names={'schemaVersion','generalizedPolynomialDegree','generalizedDirection','generalizedRadius','generalizedEndpoint','generalizedHorizontalAxis', ...
                'sourceN20','sourceInverseScale','sourceDepth','sourceLatitude','sourceCoriolis','sourceGravity','sourceHorizontalDomain', ...
                'boundaryWeightMultiplier','effectiveBoundaryDepth','boundaryWeights','constructionQuadratureCount', ...
                'polynomialEigenvectors','polynomialDuals','generalizedEigenvalues','singularValueUncertainty', ...
                'eigenvalueUncertainty','clusterUpperOrdinal','eigenvalueNormalization','energyFormDrift', ...
                'generalizedFormDrift','generalizedOperatorDrift','energyOrthogonalityResidual','generalizedDiagonalizationResidual','factorizationResidual','energyFactorReciprocalCondition'};
        end

        function a=classDefinedPropertyAnnotations()
            a=CAPropertyAnnotation.empty(0,0);
            a(end+1)=CADimensionProperty('generalizedPolynomialDegree','1','Complete Legendre polynomial degrees');
            a(end+1)=CADimensionProperty('generalizedDirection','1','Ordered generalized-enstrophy directions');
            a(end+1)=CADimensionProperty('generalizedRadius','m-1','Distinct horizontal radii');
            a(end+1)=CADimensionProperty('generalizedEndpoint','1','Surface then bottom endpoint codes');
            a(end+1)=CADimensionProperty('generalizedHorizontalAxis','1','Ordered horizontal domain axes');
            a(end+1)=CANumericProperty('schemaVersion',{},'1','Native thermal closure state schema');
            names={'sourceN20','sourceInverseScale','sourceDepth','sourceLatitude','sourceCoriolis','sourceGravity','boundaryWeightMultiplier','effectiveBoundaryDepth','constructionQuadratureCount'};
            units={'s-2','m-1','m','degrees','s-1','m s-2','1','m','1'};
            for k=1:numel(names), a(end+1)=CANumericProperty(names{k},{},units{k},names{k}); end %#ok<AGROW>
            a(end+1)=CANumericProperty('boundaryWeights',{'generalizedEndpoint'},'s-2 m-1','Weighted endpoint-displacement variance coefficients');
            a(end+1)=CANumericProperty('sourceHorizontalDomain',{'generalizedHorizontalAxis'},'m','Horizontal domain lengths defining the canonical radius grid');
            a(end+1)=CANumericProperty('polynomialEigenvectors',{'generalizedPolynomialDegree','generalizedDirection','generalizedRadius'},'m^(1/2)','Energy-normalized generalized-enstrophy eigenvectors');
            a(end+1)=CANumericProperty('polynomialDuals',{'generalizedDirection','generalizedPolynomialDegree','generalizedRadius'},'m^(-1/2)','Dual polynomial generalized-enstrophy coordinates');
            a(end+1)=CANumericProperty('generalizedEigenvalues',{'generalizedDirection','generalizedRadius'},'m-2','Positive generalized-enstrophy eigenvalues');
            a(end+1)=CANumericProperty('singularValueUncertainty',{'generalizedDirection','generalizedRadius'},'m-1','Estimated singular-value uncertainty');
            a(end+1)=CANumericProperty('eigenvalueUncertainty',{'generalizedDirection','generalizedRadius'},'m-2','Derived generalized-eigenvalue uncertainty estimate');
            a(end+1)=CANumericProperty('clusterUpperOrdinal',{'generalizedDirection','generalizedRadius'},'1','Upper ordinal of each uncertainty-connected cluster');
            names={'eigenvalueNormalization','energyFormDrift','generalizedFormDrift','generalizedOperatorDrift','energyOrthogonalityResidual','generalizedDiagonalizationResidual','factorizationResidual','energyFactorReciprocalCondition'};
            units={'m-2','1','1','1','1','1','1','1'};
            for k=1:numel(names), a(end+1)=CANumericProperty(names{k},{'generalizedRadius'},units{k},names{k}); end %#ok<AGROW>
        end
    end
end
