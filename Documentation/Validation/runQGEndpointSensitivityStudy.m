function result = runQGEndpointSensitivityStudy(folder)
% Isolate sampling, eigensolve, and readout errors at a fixed APV band.
% Requires the independent InternalModes exponential analytical solution.
arguments (Input)
    folder (1,1) string
end
if ~isfolder(folder), mkdir(folder); end
D = 4000; g = 9.81; f = 2*7.2921e-5*sind(24); kh = 2*pi/100e3;
N0 = 5.2e-3; b = 1300; N2 = @(z) N0^2*exp(2*z/b);
I = N0^2*b*(1-exp(-2*D/b))/2;
evp = IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0], ...
    g=g,g0=-I,gd=I,surfaceBoundary="freeSurface");
zeroProblem = IMGeostrophicZeroAPVModes.atWavenumber(N2=N2, ...
    zDomain=[-D 0],f0=f,g=g,k=kh,endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
solution = IMExponentialStratificationSolution(N0=N0,b=b,zDomain=[-D 0],g=g,f0=f);
exact = solution.internalModes(evp,nModes=84);
exactZero = solution.geostrophicZeroAPVModesAtWavenumber(kh, ...
    endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
grid = IMSolverSpectral(nEVP=385,coordinateKind="wkb").configuredForEVP(evp);
common = WVInternal.qgVerticalOperators(sort(grid.zNative),1543);
x = common.zQuadrature; w = common.quadratureWeights;
referenceFields = fields(exact,exactZero,x);
[referencePage,referenceEndpoint] = operators(referenceFields,N2(x),2/b*N2(x),x,w);
reference = evolve(referencePage,referenceEndpoint);
probe = (1:86).'.^-2;
referenceTendency = energyField(referenceFields,referencePage.generator*probe);
referenceEnergy = energyField(referenceFields,reference.coefficients);
referenceQ = referenceFields.F*reference.coefficients(1:84);
rows = struct([]);
for method = ["original","equilibrated"]
    for nEVP = [519 783 1167 1551]
        solver = IMSolverSpectral(nEVP=nEVP);
        if method == "original"
            basis = originalSolve(solver,evp,84);
        else
            basis = solver.solveEVP(evp,nModes=84);
        end
        % Reuse both basis objects, including the boundary modes, across grids.
        zero = solver.solveGeostrophicZeroAPVModes(zeroProblem);
        nativeFields = fields(basis,zero,x);
        orientation = sign(sum(nativeFields.F.*referenceFields.F,1));
        orientedProbe = [orientation.';ones(2,1)].*probe;
        grids = 385;
        if nEVP == 783, grids = [257 385 513]; end
        for Nz = grids
            grid = IMSolverSpectral(nEVP=Nz,coordinateKind="wkb").configuredForEVP(evp);
            [z,weights,Dz] = grid.nativeDifferentiationRule([-D 0]);
            weights = weights*(D/sum(weights));
            [transform,assessment] = basis.discreteTransform(z=z,weights=weights, ...
                variables=["F","G"],nModes=84,gramTolerance=.01,quadraticAliasingTolerance=.1);
            rule = WVInternal.qgVerticalOperators(z,2*Nz+1);
            P = rule.phiToQuadrature; qz = rule.zQuadrature; qw = rule.quadratureWeights;
            for variant = ["sampled","analyticN2","direct"]
                if variant == "direct"
                    sampled = fields(basis,zero,qz); n2 = N2(qz); n2z = 2/b*n2;
                else
                    sampled = fields(basis,zero,z);
                    sampled.F = transform.inverseMatrix(variable="F");
                    sampled.G = transform.inverseMatrix(variable="G");
                    for name = ["F","G","ZF","ZG"], sampled.(name) = P*sampled.(name); end
                    n2 = P*N2(z); n2z = P*(Dz*N2(z));
                    if variant == "analyticN2", n2z = 2/b*N2(qz); end
                end
                [page,endpoint,bcEndpoint] = operators(sampled,n2,n2z,qz,qw);
                response = evolve(page,endpoint);
                energy = energyField(nativeFields,response.coefficients);
                tendency = energyField(nativeFields,page.generator*orientedProbe);
                q = nativeFields.F*response.coefficients(1:84);
                row = struct(method=method,nEVP=nEVP,Nz=Nz,variant=variant, ...
                    surface=response.endpoint(1),bottom=response.endpoint(2), ...
                    surfaceError=abs(response.endpoint(1)-reference.endpoint(1)), ...
                    bottomError=abs(response.endpoint(2)-reference.endpoint(2)), ...
                    bottomReadoutDifference=abs((endpoint(2,:)-bcEndpoint(2,:))*response.coefficients), ...
                    qgpvRelative=sqrt(sum(w.*abs(q-referenceQ).^2)/sum(w.*abs(referenceQ).^2)), ...
                    energyRelative=norm(energy-referenceEnergy)/norm(referenceEnergy), ...
                    operatorRelative=norm(tendency-referenceTendency)/norm(referenceTendency), ...
                    eigendepthRelative=max(abs(basis.h-exact.h)./abs(exact.h)), ...
                    modeFRelative=max(vecnorm(nativeFields.F.*orientation-referenceFields.F)./vecnorm(referenceFields.F)), ...
                    gramError=assessment.prefixDiagnostics.gramError(84));
                rows = [rows;row]; %#ok<AGROW>
            end
        end
        fprintf('%s, nEVP=%d complete\n',method,nEVP);
    end
end
% Independently double the analytical operator quadrature.
coarse = WVInternal.qgVerticalOperators(sort(grid.zNative),771);
[page,endpoint] = operators(fields(exact,exactZero,coarse.zQuadrature), ...
    N2(coarse.zQuadrature),2/b*N2(coarse.zQuadrature),coarse.zQuadrature,coarse.quadratureWeights);
check = evolve(page,endpoint);
result.rows = struct2table(rows);
result.reference = table(reference.endpoint(1),reference.endpoint(2), ...
    abs(check.endpoint(1)-reference.endpoint(1)),abs(check.endpoint(2)-reference.endpoint(2)), ...
    max(abs(exact.metadata.rootResiduals)), ...
    VariableNames=["surface","bottom","surfaceQuadratureChange","bottomQuadratureChange","rootResidual"]);
writetable(result.rows,fullfile(folder,'issue-353-endpoint-controls.csv'));
writetable(result.reference,fullfile(folder,'issue-353-endpoint-reference.csv'));

    function a = fields(basis,zero,z)
        a = struct(F=basis.F(z),G=basis.G(z),ZF=zero.F(z),ZG=zero.G(z), ...
            Fs=basis.F(0),Gs=basis.G(0),Fb=basis.F(-D),Gb=basis.G(-D), ...
            ZFs=zero.F(0),h=basis.h(:).');
    end
    function [page,endpoint,bcEndpoint] = operators(a,n2,n2z,z,weights)
        mu = kh^2+f^2./(g*a.h);
        phi = [-a.F./mu,-a.ZF/kh^2]; surf = [-a.Fs./mu,-a.ZFs/kh^2];
        eta = f/g*[-a.G./mu,-a.ZG/kh^2]; etaz = [-f/g*a.F./(a.h.*mu),a.ZF/f];
        bz = -n2z.*(eta-f/g*(1+z/D)*surf)-n2.*(etaz-f/g/D*surf);
        page = WVInternal.densityDiffusionPage(phi,eta,etaz,bz,surf,weights,n2,kh,f,g,1e-5);
        endpoint = [[-f/g*(a.Gs-a.Fs)./mu;-f/g*a.Gb./mu],-f/g/kh^2*eye(2)];
        bcEndpoint = [[f/I*a.Fs./mu;f/I*a.Fb./mu],-f/g/kh^2*eye(2)];
    end
    function response = evolve(page,endpoint)
        T = 365.25*86400; omega = 2*pi/T;
        source = zeros(86,1); source(85) = -g/f*kh^2*10*pi/T;
        H = [page.energyGenerator,page.toEnergy*source,zeros(86,1); ...
            zeros(1,86),0,omega;zeros(1,86),-omega,0];
        y = expm(64*86400*H)*[zeros(87,1);1];
        c = page.fromEnergy*y(1:86);
        response = struct(coefficients=c,endpoint=endpoint*c);
    end
    function y = energyField(a,c)
        mu = kh^2+f^2./(g*a.h);
        phi = [-a.F./mu,-a.ZF/kh^2]*c;
        eta = f/g*[-a.G./mu,-a.ZG/kh^2]*c;
        surf = [-a.Fs./mu,-a.ZFs/kh^2]*c;
        y = [sqrt(w)*kh.*phi;sqrt(w.*N2(x)).*eta;f/sqrt(g)*surf];
    end
end

function basis = originalSolve(solver,evp,nModes)
% Historical unscaled control, confined to this authoring experiment.
solver = solver.configuredForEVP(evp);
[A,B] = evp.assemble(solver);
[V,L] = eig(A,B); values = diag(L);
valid = isfinite(real(values)) & isfinite(imag(values)) ...
    & abs(imag(values)) < 1e-8*max(1,abs(real(values)));
V = real(V(:,valid)); values = real(values(valid));
valid = evp.finiteGeneralizedEigenpairMask(V,B);
V = V(:,valid); values = values(valid);
selection = evp.selectModes(values(:),nModes,solver,A);
values = values(selection.sortIndex); values(selection.modeNumber == 0) = 0;
basis = evp.makeBasisSet(solver,V(:,selection.sortIndex),values(:).', ...
    selection.modeNumber,selection.modeSelectionDiagnostics);
basis = basis.orientModeSigns();
end
