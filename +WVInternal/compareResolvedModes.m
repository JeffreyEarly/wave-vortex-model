function [report,errors,candidate] = compareResolvedModes(basis,reference,nQuadrature,nModes)
% Independent EVP agreement in equivalent depth and physical H1 fields.
if nargin<4, nModes=numel(basis.modeNumber); end
rule=IMSolverSpectral(nEVP=nQuadrature,coordinateKind="wkb").configuredForEVP(basis.evp);
[z,w]=rule.nativeQuadratureRule(basis.zDomain);
candidate=prepare(basis,1:nModes);
refined=prepare(reference,1:numel(reference.modeNumber));
report=assessModeConvergence(candidate,refined,z,w);
if nargout>1
    summary=WVInternal.summarizeModeConvergence(report,nModes,Inf);
    errors=summary.modeError;
    errors(~summary.measured)=Inf;
end
    function value=prepare(source,columns)
        identity=struct(family=string(source.evp.modeFamily),columnLabels=string(source.modeNumber(columns)), ...
            normalization=string(source.normalization),zDomain=source.zDomain);
        if isfield(source.evp.parameters,"k"), identity.kappa=source.evp.parameters.k; end
        % Differentiate each stored profile in its native spectral representation.
        F=source.F(z); G=source.G(z); Fz=source.Fz(z); Gz=source.Gz(z);
        provenance=struct(solverClass="IMSolverSpectral",coordinateKind=string(source.solver.coordinateKind), ...
            nEVP=source.solver.nEVP,quadratureCoordinateKind="wkb",quadratureCount=nQuadrature);
        value=struct(identity=identity,values=struct(F=F(:,columns),G=G(:,columns)), ...
            derivatives=struct(F=Fz(:,columns),G=Gz(:,columns)),equivalentDepths=source.h(columns),provenance=provenance);
    end
end
