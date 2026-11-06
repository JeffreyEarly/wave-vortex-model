function [report,errors,candidate] = compareResolvedModes(basis,reference,nQuadrature,nModes)
% Independent EVP agreement in equivalent depth and physical H1 fields.
if nargin<4, nModes=numel(basis.modeNumber); end
rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(basis.evp);
[z,w]=rule.nativeQuadratureRule(basis.zDomain);
identity=struct(family=string(basis.evp.modeFamily),columnLabels=string(basis.modeNumber(1:nModes)),normalization=string(basis.normalization),zDomain=basis.zDomain);
if isfield(basis.evp.parameters,'k'), identity.kappa=basis.evp.parameters.k; end
candidate=prepare(basis); refined=prepare(reference);
report=assessModeConvergence(candidate,refined,z,w);
errors=inf(nModes,1);
for j=1:numel(errors)
    rows=report.measurements.columnLabel==report.identity.columnLabels(j) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
    if nnz(rows)==3 && all(report.measurements.status(rows)=="measured")
        errors(j)=max(report.measurements.value(rows));
    end
end
    function value=prepare(source)
        % Differentiate each stored profile in its native spectral representation.
        fields=struct(F=source.F(z),G=source.G(z),dF=source.Fz(z),dG=source.Gz(z));
        value=struct(identity=identity,values=struct(F=fields.F(:,1:nModes),G=fields.G(:,1:nModes)),derivatives=struct(F=fields.dF(:,1:nModes),G=fields.dG(:,1:nModes)),equivalentDepths=source.h(1:nModes),provenance=struct(solverClass="IMSolverSpectral",coordinateKind=string(source.solver.coordinateKind),nEVP=source.solver.nEVP,quadratureCoordinateKind="wkb",quadratureCount=nQuadrature,source="actual construction basis"));
    end
end
