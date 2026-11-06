function stressAPVRefinement
% Probe the signed APV mode across solve resolutions and roundoff-scale inputs.
fprintf("MATLAB %s on %s\n",version,computer);
disp(version("-blas"))
if isunix && ~ismac
    system("lscpu | sed -n '/^CPU(s):/p; /^Vendor ID:/p; /^Model name:/p'");
end
N2 = @(z) 1e-4*exp(2*z/700);
domain = [-1000 0];
background = IMBackground(N2=N2,zDomain=domain,g=9.81,latitude=30, ...
    rotationRate=7.2921e-5,rho0=1025,surfaceCondition="freeSurface");
I = integral(N2,domain(1),domain(2));
referenceDepth = -2.131069429888769;
defaultThreads = maxNumCompThreads;
mismatches = 0;
cases = 0;
for threads = unique([1 defaultThreads])
    maxNumCompThreads(threads);
    for offset = [-4 -2 -1 0 1 2 4]
        cases = cases+1;
        mismatches = mismatches+probe(I+offset*eps(I),455,threads);
    end
end
maxNumCompThreads(defaultThreads);
for nEVP = [301:305 450:454 456:460 683]
    cases = cases+1;
    mismatches = mismatches+probe(I,nEVP,defaultThreads);
end
fprintf("STRESS SUMMARY cases=%d failures=%d\n",cases,mismatches)

    function failed = probe(endpointMagnitude,nEVP,threads)
        problem = IMInternalModes.geostrophicAPVModes(background,g0=-endpointMagnitude,gd=endpointMagnitude);
        solver = IMSolverSpectral(nEVP=nEVP);
        try
            basis = solver.solveEVP(problem,nModes=101);
            failed = basis.modeNumber(1) ~= -1 || abs(basis.h(1)-referenceDepth)>1e-7;
            fprintf("THREADS=%d nEVP=%d I=%s leadingLabel=%d h=%.17g mismatch=%d\n", ...
                threads,nEVP,num2hex(endpointMagnitude),basis.modeNumber(1),basis.h(1),failed)
            if failed
                grid = IMSolverSpectral(nEVP=97,coordinateKind="wkb").configuredForEVP(problem);
                [z,w] = grid.nativeDifferentiationRule(domain);
                try
                    basis.discreteTransform(z=z,weights=w*(1000/sum(w)),variables=["F","G"],gramTolerance=.01);
                    fprintf("Stress case passed the 97-point Gram check\n")
                catch exception
                    fprintf("Stress Gram failed (%s): %s\n",exception.identifier,exception.message)
                end
                inspectPairs(problem,solver.configuredForEVP(problem))
            end
        catch exception
            failed = true;
            fprintf("THREADS=%d nEVP=%d I=%s failed (%s): %s\n", ...
                threads,nEVP,num2hex(endpointMagnitude),exception.identifier,exception.message);
        end
    end
end

function inspectPairs(problem,solver)
[A,B,map] = problem.prepareSolvePencil(solver,[],[]);
physical = map.nativeColumnScale;
n = solver.nEVP;
degree = repmat(max(1,0:n-1).^(-2),1,2);
row = max(max(abs(A.*physical),[],2),max(abs(B.*physical),[],2));
row(row==0) = 1;
A = A./row;
B = B./row;
[V,D] = eig(A.*(physical.*degree),B.*(physical.*degree));
[V,r] = problem.prepareGeneralizedEigenpairs(solver,A,B,(physical.*degree).'.*V,diag(D));
r = map.restoreEigenvalues(r);
mapped = map.publicEigenvalues(V,r);
[negative,order] = sort(mapped.values(mapped.values<0));
qualified = mapped.qualified(mapped.values<0);
fprintf("PREPARED NEGATIVE inverseDepth=%s qualified=%s\n",mat2str(negative.',17),mat2str(qualified(order).'))
end
