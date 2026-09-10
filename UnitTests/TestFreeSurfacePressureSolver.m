classdef TestFreeSurfacePressureSolver < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addStudyPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
        end
    end

    methods (Test, TestTags="full")
        function nonflatManufacturedPressureAgreesWithDenseOracle(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfacePressureSolver(wvt);
            [ssh,force,expected,solenoidal] = manufacturedState(wvt);
            [pressure,report] = solver.solve(ssh,force,expected(:,:,end),tolerance=1e-12);
            [dense,denseReport] = solveFreeSurfacePressureReference(ssh,force,expected(:,:,end),wvt.z,wvt.Lz,derivatives(wvt));
            testCase.verifyEqual(pressure,expected,AbsTol=3e-10)
            testCase.verifyEqual(pressure,dense,AbsTol=3e-10)
            for name = ["u","v","w"]
                testCase.verifyEqual(report.acceleration.(name),solenoidal.(name),AbsTol=3e-11)
                testCase.verifyEqual(report.acceleration.(name),denseReport.acceleration.(name),AbsTol=3e-11)
                testCase.verifyEqual(report.metricGradient.(name),force.(name)-report.acceleration.(name),AbsTol=1e-17)
            end
            testCase.verifyLessThan(report.scaledRelativeResidual,5e-12)
            testCase.verifyLessThan(report.interiorDivergence,3e-12)
            testCase.verifyLessThan(report.endpointDivergence,3e-12)
            testCase.verifyLessThan(report.bottomAcceleration,3e-12)
            testCase.verifyLessThan(report.surfacePressureResidual,3e-10)
            testCase.verifyGreaterThan(report.iterations,1)
            testCase.verifyLessThan(report.iterations,50)
            [restarted,restartedReport] = solver.solve(ssh,force,expected(:,:,end),tolerance=1e-12,restart=3,maxIterations=60);
            testCase.verifyEqual(restarted,dense,AbsTol=3e-10)
            testCase.verifyGreaterThan(restartedReport.iterations,3)
            testCase.verifyLessThanOrEqual(restartedReport.iterations,60)
            fprintf('Nonflat pressure: iterations=%d, scaled residual=%.4g, dense error=%.4g\n',report.iterations,report.scaledRelativeResidual,max(abs(pressure-dense),[],'all'));
        end

        function flatReferenceIncludesMeanAndRealNyquist(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfacePressureSolver(wvt);
            [X,Y,S] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
            nx = reshape((-1).^(0:wvt.Nx-1),[],1,1);
            ny = reshape((-1).^(0:wvt.Ny-1),1,[],1);
            k = 2*pi/wvt.Lx;
            l = 2*pi/wvt.Ly;
            expected = .7*S+.2*cos(k*X).*sin(l*Y).*(1+S.^3)+.1*nx.*S.^2+.05*ny.*(1+S.^3)+.07*nx.*ny.*S;
            force.u = -.2*k*sin(k*X).*sin(l*Y).*(1+S.^3);
            force.v = .2*l*cos(k*X).*cos(l*Y).*(1+S.^3);
            force.w = (.7+.6*cos(k*X).*sin(l*Y).*S.^2+.2*nx.*S+.15*ny.*S.^2+.07*nx.*ny)/wvt.Lz;
            testCase.verifyEqual(wvt.diffX(nx.*ones(size(X))),zeros(size(X)),AbsTol=1e-15)
            testCase.verifyEqual(wvt.diffY(ny.*ones(size(X))),zeros(size(X)),AbsTol=1e-15)
            [actual,report] = solver.solve(zeros(wvt.Nx,wvt.Ny),force,expected(:,:,end),tolerance=1e-12);
            testCase.verifyEqual(actual,expected,AbsTol=2e-11)
            testCase.verifyLessThanOrEqual(report.iterations,2)
            testCase.verifyLessThan(report.interiorDivergence,1e-12)
            testCase.verifyLessThan(solver.referenceBlockCount,wvt.Nx*wvt.Ny)
            % The same factors serve another stage; coefficient/clock state
            % has no role in this instantaneous geometry-only diagnostic.
            wvt.t = 91;
            stateBefore = wvt.coefficientState();
            [ssh,nonflatForce,nonflatExpected] = manufacturedState(wvt);
            solver.solve(ssh,nonflatForce,nonflatExpected(:,:,end));
            again = solver.solve(zeros(wvt.Nx,wvt.Ny),force,expected(:,:,end),tolerance=1e-12);
            testCase.verifyEqual(again,actual,AbsTol=0)
            testCase.verifyEqual(wvt.coefficientState(),stateBefore)
            testCase.verifyEqual(wvt.t,91)
            fprintf('Flat pressure including Nyquist: iterations=%d, scaled residual=%.4g\n',report.iterations,report.scaledRelativeResidual);
        end

        function endpointDivergenceRemainsAnIndependentDiagnostic(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfacePressureSolver(wvt);
            [ssh,force,expected] = manufacturedState(wvt);
            [X,Y,S] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
            % Deliberately unresolved vertical forcing exposes the endpoint
            % equations that the boundary conditions replace.
            force.w = force.w+.03*cos(2*pi*X/wvt.Lx).*cos(2*pi*Y/wvt.Ly).*sin(35*S);
            [actual,report] = solver.solve(ssh,force,expected(:,:,end),tolerance=1e-12);
            [dense,denseReport] = solveFreeSurfacePressureReference(ssh,force,expected(:,:,end),wvt.z,wvt.Lz,derivatives(wvt));
            testCase.verifyEqual(actual,dense,AbsTol=1e-9)
            testCase.verifyLessThan(report.interiorDivergence,1e-11)
            testCase.verifyLessThan(report.bottomAcceleration,1e-11)
            testCase.verifyLessThan(report.surfacePressureResidual,1e-10)
            testCase.verifyGreaterThan(report.endpointDivergence,1e-7)
            testCase.verifyEqual(report.endpointDivergence,denseReport.endpointDivergence,AbsTol=1e-11)
            testCase.verifyEqual(report.endpointDivergence,max(report.bottomDivergence,report.surfaceDivergence),AbsTol=0)
            fprintf('Endpoint divergence: interior=%.4g, bottom=%.4g, surface=%.4g\n',report.interiorDivergence,report.bottomDivergence,report.surfaceDivergence);
        end

        function nonconvergenceAndInvalidInputsFailExplicitly(testCase)
            wvt = newTransform();
            solver = WVInternal.freeSurfacePressureSolver(wvt);
            [ssh,force,expected] = manufacturedState(wvt);
            testCase.verifyError(@()solver.solve(ssh,force,expected(:,:,end),maxIterations=1,tolerance=1e-13),'WV:PressureSolverConvergence')
            testCase.verifyError(@()solver.solve(-wvt.Lz*ones(size(ssh)),force,expected(:,:,end)),'WV:InvalidFreeSurfaceGeometry')
            testCase.verifyError(@()solver.solve(ssh,rmfield(force,'u'),expected(:,:,end)),'WV:PressureSolverForce')
            testCase.verifyError(@()solver.solve(ssh(1:end-1,:),force,expected(:,:,end)),'WV:PressureSolverShape')
            zero = zeros(wvt.Nx,wvt.Ny,wvt.Nz);
            [pressure,report] = solver.solve(zeros(size(ssh)),struct(u=zero,v=zero,w=zero),zeros(size(ssh)));
            testCase.verifyEqual(pressure,zero,AbsTol=0)
            testCase.verifyEqual(report.iterations,0)
        end
    end
end

function wvt = newTransform()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([80000 60000 100],[6 6 17],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,waveModeCount=3,inertialModeCount=2,nEVP=128);
end

function derivative = derivatives(wvt)
derivative = struct(x=@(field)wvt.diffX(field),y=@(field)wvt.diffY(field),xi=@(field)wvt.diffZ(field));
end

function [ssh,force,pressure,solenoidal] = manufacturedState(wvt)
[X,Y,S] = ndgrid(wvt.x,wvt.y,1+wvt.z/wvt.Lz);
k = 2*pi/wvt.Lx;
l = 2*pi/wvt.Ly;
ssh = 12*cos(k*X(:,:,1))+8*sin(l*Y(:,:,1));
gamma = 1+ssh/wvt.Lz;
betaX = S.*(-12*k*sin(k*X))./gamma;
betaY = S.*(8*l*cos(l*Y))./gamma;
pressure = .2*cos(k*X).*sin(l*Y).*(1+S.^3)+.4*S;
px = -.2*k*sin(k*X).*sin(l*Y).*(1+S.^3);
py = .2*l*cos(k*X).*cos(l*Y).*(1+S.^3);
pxi = (.6*cos(k*X).*sin(l*Y).*S.^2+.4)/wvt.Lz;
solenoidal.u = .003*cos(k*X).*S;
solenoidal.v = zeros(size(X));
solenoidal.w = .003*k*wvt.Lz*sin(k*X).*S.^2/2;
force.u = gamma.*(px-betaX.*pxi)+solenoidal.u;
force.v = gamma.*(py-betaY.*pxi)+solenoidal.v;
force.w = -gamma.*(betaX.*px+betaY.*py)+(1./gamma+gamma.*(betaX.^2+betaY.^2)).*pxi+solenoidal.w;
end
