function validateThermalState(s)
% Validate canonical array shapes before cheap thermal construction.
% - Topic: Developer utilities
schema=WVInternal.thermalStateSchema();
for k=1:size(schema,1)
    name=schema{k,1};
    if ~isfield(s,name) || ~(isnumeric(s.(name)) || islogical(s.(name))) || any(~isfinite(s.(name)),'all')
        error('WV:ThermalStoredState','Missing or nonfinite scientific array %s.',name);
    end
    value=s.(name);
    if ~schema{k,6} && ~isreal(value), error('WV:ThermalStoredState','Scientific array %s must be real.',name); end
    if schema{k,5}
        if ~iscolumn(value) || isempty(value), error('WV:ThermalStoredState','Coordinate %s must be a nonempty column.',name); end
    else
        dims=schema{k,2}; expected=ones(1,max(2,numel(dims)));
        for j=1:numel(dims)
            if ~isfield(s,dims{j}), error('WV:ThermalStoredState','Missing dimension %s.',dims{j}); end
            expected(j)=numel(s.(dims{j}));
        end
        actual=size(value); actual(end+1:numel(expected))=1; expected(end+1:numel(actual))=1;
        if ~isequal(actual,expected), error('WV:ThermalStoredState','Invalid shape for scientific array %s.',name); end
    end
end
if s.schemaVersion~=2 || numel(s.domainSize)~=3 || any(s.domainSize<=0) || any(s.gridSize~=fix(s.gridSize)) || any(s.gridSize<4) || s.N20<=0 || s.g<=0 || s.rho0<=0 || s.kappa_z<0 || abs(s.latitude)>90 || abs(sind(s.latitude))<1e-8 || ~ismember(s.shouldAntialias,[0 1])
    error('WV:ThermalStoredState','Invalid schema, geometry, stratification or diffusivity.');
end
n=numel(s.thermalDirection); m=numel(s.mdaMode); nr=numel(s.khUnique);
if n<3 || ~isequal(s.thermalDirection,(1:n)') || ~isequal(s.polynomialDegree,(0:n-1)') || ~isequal(s.mdaMode,(1:m)') || ~isequal(s.activeEndpoint,[1;2]) || numel(s.z)~=s.gridSize(3) || any(diff(s.z)<=0) || abs(s.z(1)+s.domainSize(3))>1e-10*s.domainSize(3) || s.z(end)~=0 || any(s.verticalQuadratureWeights<=0)
    error('WV:ThermalStoredState','Invalid coordinates or endpoint configuration.');
end
if any(s.klNonzeroKhUniqueIndex<1 | s.klNonzeroKhUniqueIndex>nr | s.klNonzeroKhUniqueIndex~=fix(s.klNonzeroKhUniqueIndex)) || any(diff(s.khUnique)<=0) || any(s.khUnique<=0)
    error('WV:ThermalStoredState','Invalid radius grouping.');
end
for p=1:nr
    permutation=s.conjugateDirection(:,p);
    if ~isequal(sort(permutation),(1:n)') || ~isequal(permutation(permutation),(1:n)')
        error('WV:ThermalStoredState','Invalid conjugate-direction permutation.');
    end
    if norm(s.polynomialToThermal(:,:,p)*s.thermalToPolynomial(:,:,p)-eye(n),'fro')/sqrt(n)>1e-8
        error('WV:ThermalStoredState','Stored thermal inverse does not match its reconstruction.');
    end
end

if ~ismember(s.shouldCheckQuadraticAliasing,[0 1]) || s.nonlinearQuadratureTolerance<=0 || s.nonlinearQuadratureCount<0 || s.nonlinearQuadratureCount~=fix(s.nonlinearQuadratureCount) || s.nonlinearQuadratureResidual<0 || s.nonlinearReferenceResidual<0
    error('WV:ThermalStoredState','Invalid nonlinear quadrature policy.');
end
if s.shouldCheckQuadraticAliasing && (~s.shouldAntialias || s.nonlinearQuadratureCount<ceil(3*(n-1)/2)+1 || s.nonlinearQuadratureResidual>s.nonlinearQuadratureTolerance || s.nonlinearReferenceResidual>.2*s.nonlinearQuadratureTolerance)
    error('WV:ThermalStoredState','Stored nonlinear quadrature qualification is inconsistent.');
end
end
