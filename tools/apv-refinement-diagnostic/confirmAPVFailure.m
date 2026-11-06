function confirmAPVFailure
% Compare the paired APV pencil with its static equations eliminated.
previousThreads = maxNumCompThreads(1);
restoreThreads = onCleanup(@()maxNumCompThreads(previousThreads));
N2 = @(z) 1e-4*exp(2*z/700);
domain = [-1000 0];
I = hex2num('3fa0e40bf5376f01');
background = IMBackground(N2=N2,zDomain=domain,g=9.81,latitude=30, ...
    rotationRate=7.2921e-5,rho0=1025,surfaceCondition="freeSurface");
problem = IMInternalModes.geostrophicAPVModes(background,g0=-I,gd=I);
system("lscpu | sed -n '/^Vendor ID:/p; /^Model name:/p'");
disp(version("-lapack"))
grid = IMSolverSpectral(nEVP=97,coordinateKind="wkb").configuredForEVP(problem);
[z,w] = grid.nativeDifferentiationRule(domain);
w = w*(background.D/sum(w));
for nEVP = [303 455]
    solver = IMSolverSpectral(nEVP=nEVP).configuredForEVP(problem);
    basis = solver.solveEVP(problem,nModes=101);
    fprintf("FULL nEVP=%d labels=%s h=%s\n",nEVP,mat2str(basis.modeNumber(1:3)),mat2str(basis.h(1:3),17));
    try
        transform = basis.discreteTransform(z=z,weights=w,variables=["F","G"],gramTolerance=.01);
        fprintf("FULL nEVP=%d Gram passed with %d modes\n",nEVP,numel(transform.modeNumber));
    catch exception
        fprintf("FULL nEVP=%d Gram failed (%s)\n",nEVP,exception.identifier);
    end
    [A,B,map] = problem.prepareSolvePencil(solver,[],[]);
    physical = map.nativeColumnScale;
    degree = repmat(max(1,0:nEVP-1).^(-2),1,2);
    row = max(max(abs(A.*physical),[],2),max(abs(B.*physical),[],2));
    row(row==0) = 1;
    A = (A./row).*(physical.*degree);
    B = (B./row).*(physical.*degree);
    static = all(B==0,2);
    Z = null(A(static,:));
    assert(size(Z,2)==nnz(~static),"Static APV equations did not reduce to a square pencil.")
    reducedB = B(~static,:)*Z;
    inverseDepth = map.restoreEigenvalues(eig(A(~static,:)*Z,reducedB));
    negative = sort(real(inverseDepth(real(inverseDepth)<0)));
    positive = sort(real(inverseDepth(real(inverseDepth)>0)));
    fprintf("REDUCED nEVP=%d staticRows=%d size=%d rankB=%d negative=%s firstPositive=%s\n", ...
        nEVP,nnz(static),size(Z,2),rank(reducedB),mat2str(negative.',17),mat2str(positive(1:2).',17));
end
try
    source = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65], ...
        N2Function=N2,g0=-I,gd=I,shouldAntialias=true,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
    fprintf("WVM source passed at Nz=%d with labels %s\n",source.Nz,mat2str(source.apvModeNumber.'));
    target = source.waveVortexTransformWithResolution([12 10 97]);
    fprintf("WVM target passed at Nz=%d with labels %s\n",target.Nz,mat2str(target.apvModeNumber.'));
catch exception
    fprintf("WVM path failed (%s)\n%s\n",exception.identifier,getReport(exception,"extended"));
end
end
