classdef TestFreeSurfaceObserverCoordinates < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function physicalQueriesInvertTheMovingMesh(testCase)
            wvt = newTransform();
            addReferenceProbes(wvt)
            original = wvt.coefficientState();
            x = [-0.3,2.4,wvt.Nx+1.2]*wvt.Lx/wvt.Nx;
            y = [1.7,-0.2,wvt.Ny+2.3]*wvt.Ly/wvt.Ny;
            xi = [-0.75,-0.3,-0.1]*wvt.Lz;
            for method = ["linear","spline"]
                ssh = wvt.variableAtPositionWithName(x,y,[],'ssh',interpolationMethod=method);
                z = xi+(1+xi/wvt.Lz).*ssh;
                [actualXi,actualZ,actualSSH] = wvt.variableAtPositionWithName(x,y,z,'testReferenceHeight','z_physical','ssh',interpolationMethod=method);
                testCase.verifyEqual(actualXi,xi,AbsTol=2e-11)
                testCase.verifyEqual(actualZ,z,AbsTol=2e-11)
                testCase.verifyEqual(actualSSH,ssh,AbsTol=1e-13)
                wrapped = wvt.variableAtPositionWithName(x+wvt.Lx,y-2*wvt.Ly,z,'testReferenceHeight',interpolationMethod=method);
                testCase.verifyEqual(wrapped,actualXi,AbsTol=2e-11)
            end
            testCase.verifyEqual(wvt.coefficientState(),original)
            testCase.verifyEqual([wvt.t,wvt.t0],[317,-29])
        end

        function endpointsOutsideQueriesAndParticlesUsePhysicalHeight(testCase)
            wvt = newTransform();
            addReferenceProbes(wvt)
            [crest,index] = max(wvt.ssh,[],'all');
            [ix,iy] = ind2sub([wvt.Nx,wvt.Ny],index);
            x = repmat(wvt.x(ix),1,5);
            y = repmat(wvt.y(iy),1,5);
            z = [-wvt.Lz,crest,crest/2,crest+1e-4,-wvt.Lz-1e-4];
            testCase.verifyGreaterThan(crest,0)
            for method = ["linear","spline"]
                [one,xi,ssh] = wvt.variableAtPositionWithName(x,y,z,'testOne','testReferenceHeight','ssh',interpolationMethod=method);
                testCase.verifyEqual(one,[1,1,1,0,0],AbsTol=5e-13)
                testCase.verifyEqual(xi(1:2),[-wvt.Lz,0],AbsTol=2e-11)
                testCase.verifyEqual(ssh,crest+zeros(size(x)),AbsTol=1e-13)
                % A physical positive-height query inside a crest is valid.
                testCase.verifyEqual(xi(3),(-crest/2)/(1+crest/wvt.Lz),AbsTol=2e-11)
            end
            model = WVModel(wvt);
            iz = 12;
            physicalZ = wvt.z_physical;
            particles = WVLagrangianParticles(model,name="coordinate probes",x=x(1),y=y(1),z=physicalZ(ix,iy,iz));
            rate = particles.fluxAtTime(wvt.t,particles.initialConditions());
            names = ["u","v","w"];
            for component = 1:3
                field = wvt.(names(component));
                testCase.verifyEqual(rate{component},field(ix,iy,iz),AbsTol=2e-13)
            end
        end

        function tracerUsesReferenceMaterialVelocityAndAnalyticDerivatives(testCase)
            wvt = newTransform();
            [X,Y,Xi] = ndgrid(wvt.x,wvt.y,wvt.z);
            k = 2*pi/wvt.Lx;
            l = 2*pi/wvt.Ly;
            phi = cos(k*X).*sin(l*Y).*(1+0.3*Xi/wvt.Lz)+0.2*Xi/wvt.Lz;
            phiX = -k*sin(k*X).*sin(l*Y).*(1+0.3*Xi/wvt.Lz);
            phiY = l*cos(k*X).*cos(l*Y).*(1+0.3*Xi/wvt.Lz);
            phiXi = (0.3*cos(k*X).*sin(l*Y)+0.2)/wvt.Lz;
            hatted = wvt.reconstructFields(["u_hat","v_hat","w_hat","ssh"]);
            gamma = 1+hatted.ssh/wvt.Lz;
            u = hatted.u_hat./gamma;
            v = hatted.v_hat./gamma;
            wi = (hatted.w_hat-(1+Xi/wvt.Lz).*hatted.w_hat(:,:,end))./gamma;
            expected = -u.*phiX-v.*phiY-wi.*phiXi;
            model = WVModel(wvt);
            tracer = WVTracer(model,name="material tracer",phi=phi,shouldAntialias=false);
            actual = tracer.fluxAtTime(wvt.t,{phi});
            testCase.verifyEqual(actual{1},expected,AbsTol=2e-13)
            wrongVertical = -u.*phiX-v.*phiY-wvt.w.*phiXi;
            testCase.verifyGreaterThan(norm(expected(:)-wrongVertical(:)),1e-7)
            constant = 2+zeros(size(phi));
            actual = tracer.fluxAtTime(wvt.t,{constant});
            testCase.verifyLessThan(max(abs(actual{1}),[],'all'),2e-13)
            filtered = WVTracer(model,name="filtered tracer",phi=phi,shouldAntialias=true);
            actual = filtered.fluxAtTime(wvt.t,{phi});
            projected = wvt.transformToSpatialDomainWithFourier(wvt.transformFromSpatialDomainWithFourier(expected));
            testCase.verifyEqual(actual{1},projected,AbsTol=2e-13)
        end
    end
end

function wvt = newTransform()
wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[12 10 33],N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,waveModeCount=2,inertialModeCount=2,shouldAntialias=true);
wvt.Aw_p(1,1) = 0.2+0.1i;
wvt.Aw_m(2,2) = -0.08+0.03i;
wvt.Aio(1) = 0.1-0.03i;
wvt.t = 317;
wvt.t0 = -29;
end

function addReferenceProbes(wvt)
annotation = WVVariableAnnotation('testReferenceHeight',{'x','y','z'},'m','reference-coordinate interpolation probe');
wvt.addOperation(WVOperation('testReferenceHeight',annotation,@(transform)repmat(reshape(transform.z,1,1,[]),transform.Nx,transform.Ny,1)));
annotation = WVVariableAnnotation('testOne',{'x','y','z'},'1','constant interpolation probe');
wvt.addOperation(WVOperation('testOne',annotation,@(transform)ones(transform.spatialMatrixSize)));
end
