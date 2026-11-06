function diagnoseAPVRefinement(sourceRoot)
% Compare the released APV solver with WVM's default-endpoint refinement path.
fprintf("MATLAB %s on %s\n",version,computer);
disp(version("-blas"))
disp(version("-lapack"))
disp(which("IMBackground"))
if isunix && ~ismac, system("cat /etc/os-release"); end

N2 = @(z) 1e-4*exp(2*z/700);
domain = [-1000 0];
background = IMBackground(N2=N2,zDomain=domain,g=9.81,latitude=30, ...
    rotationRate=7.2921e-5,rho0=1025,surfaceCondition="freeSurface");
columnGravity = integral(N2,domain(1),domain(2));
fprintf("Column acceleration %.17g (%s)\n",columnGravity,num2hex(columnGravity))
problem = IMInternalModes.geostrophicAPVModes(background,g0=-columnGravity,gd=columnGravity);
for Nz = [65 97]
    grid = IMSolverSpectral(nEVP=Nz,coordinateKind="wkb").configuredForEVP(problem);
    [z,weights] = grid.nativeDifferentiationRule(domain);
    weights = weights*(background.D/sum(weights));
    fprintf("GRID Nz=%d range=%s weightSum=%.17g\n",Nz,mat2str(z([1 end]).'),sum(weights))
    count = Nz+4;
    nEVP = 3*count;
    for attempt = 1:3
        solveAndAssess(problem,z,weights,nEVP,count)
        if Nz == 97 && attempt == 2
            solveAndAssess(problem,z,weights,nEVP,3)
        end
        nEVP = ceil(1.5*nEVP);
    end
end

fprintf("WVM PATH\n")
try
    source = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65], ...
        N2Function=N2,shouldAntialias=true,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
    fprintf("WVM source endpoints %.17g %.17g\n",source.g0,source.gd)
    target = source.waveVortexTransformWithResolution([12 10 97]);
    fprintf("WVM refinement passed with APV modes %s\n",mat2str(target.apvModeNumber.'))
catch exception
    fprintf("WVM refinement failed (%s)\n%s\n",exception.identifier,getReport(exception,"extended"));
end
assert(startsWith(string(which("WVTransformFreeSurfaceBoussinesq")),string(sourceRoot)))
end

function solveAndAssess(problem,z,weights,nEVP,count)
fprintf("SOLVE nEVP=%d nModes=%d\n",nEVP,count);
try
    basis = IMSolverSpectral(nEVP=nEVP).solveEVP(problem,nModes=count);
catch exception
    fprintf("EVP failed (%s): %s\n",exception.identifier,exception.message);
    return
end
fprintf("labels=%s h=%s inverseDepth=%s\n",mat2str(basis.modeNumber(1:3),17), ...
    mat2str(basis.h(1:3),17),mat2str(basis.inverseDepth(1:3),17))
F = basis.F(z);
G = basis.G(z);
g = problem.g;
first = 1:3;
Fz = basis.Fz(z);
Gz = basis.Gz(z);
fprintf("peakF=%s peakG=%s\n",mat2str(max(abs(F(:,first)),[],1),9),mat2str(max(abs(G(:,first)),[],1),9))
fprintf("maxODE Fz=%s Gz=%s\n",mat2str(max(abs(Fz(:,first)+problem.N2(z).*G(:,first)/g),[],1),9), ...
    mat2str(max(abs(Gz(:,first)-F(:,first)./basis.h(first)),[],1),9))
g0 = problem.parameters.g0;
gd = problem.parameters.gd;
fprintf("maxEndpoints top=%s bottom=%s\n",mat2str(abs((g+g0)*F(end,first)-g0*G(end,first)),9), ...
    mat2str(abs(g*F(1,first)+gd*G(1,first)),9))
for variable = ["F","G"]
    try
        recipe = basis.projectionRecipe(variable=variable);
        projection = IMProjection.fromRecipe(recipe,z,weights,columns=first,prepareRecovery=false);
        fprintf("%s targetGram=%s sampleGram=%s gramError=%.17g rank=%d\n",variable, ...
            mat2str(recipe.targetGramMatrix(first,first),9),mat2str(projection.gramMatrix,9), ...
            projection.gramError,projection.sampledGramRank)
    catch exception
        fprintf("Projection %s failed (%s): %s\n",variable,exception.identifier,exception.message);
    end
end
try
    [transform,assessment] = basis.discreteTransform(z=z,weights=weights,variables=["F","G"],gramTolerance=.01);
    fprintf("Fixed-grid transform passed with %d modes and first Gram error %.17g\n", ...
        numel(transform.modeNumber),assessment.prefixDiagnostics.gramError(1));
catch exception
    fprintf("Fixed-grid transform failed (%s): %s\n",exception.identifier,exception.message);
end
end
