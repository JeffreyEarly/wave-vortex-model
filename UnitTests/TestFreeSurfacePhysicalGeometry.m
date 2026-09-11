classdef TestFreeSurfacePhysicalGeometry < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function physicalStreamfunctionAndMaterialVelocityAgree(testCase)
            % Construct physical incompressible flow from a streamfunction,
            % then independently form its contravariant flux components.
            D=100; k=2*pi/1000; amplitude=1e-4;
            xi=-D*(1+cos(pi*(0:16)'/16))/2;
            x=(0:7)'*1000/8; y=(0:5)'*1000/6;
            [X,Y,Xi]=ndgrid(x,y,xi);
            ssh=2*cos(k*X(:,:,1))+.4*sin(k*Y(:,:,1));
            sshX=-2*k*sin(k*X(:,:,1)); sshY=.4*k*cos(k*Y(:,:,1));
            depth=Xi+(1+Xi/D).*ssh;
            u=2*amplitude*sin(k*X).*(depth+D);
            v=.02*ones(size(u));
            w=-amplitude*k*cos(k*X).*(depth+D).^2;
            gamma=1+ssh/D;
            fluxZ=w-(1+Xi/D).*(u.*sshX+v.*sshY);
            hatted=struct(u=gamma.*u,v=gamma.*v,w=fluxZ,eta=.03*cos(k*X).*(1+Xi/D),ssh=ssh);
            actual=WVInternal.freeSurfacePhysicalFields(hatted,xi,D,sshX,sshY);
            testCase.verifyEqual(actual.u,u,AbsTol=1e-16)
            testCase.verifyEqual(actual.v,v,AbsTol=1e-16)
            testCase.verifyEqual(actual.w,w,AbsTol=1e-16)
            testCase.verifyEqual(actual.z,depth)
            testCase.verifyEqual(actual.z(:,:,1),-D*ones(size(ssh)))
            testCase.verifyEqual(actual.z(:,:,end),ssh)
            testCase.verifyEqual((actual.z-ssh)./gamma,Xi,AbsTol=3e-14)
            sshT=w(:,:,end)-u(:,:,end).*sshX-v(:,:,end).*sshY;
            referenceRate=(w-(1+Xi/D).*(sshT+u.*sshX+v.*sshY))./gamma;
            testCase.verifyEqual(actual.w_i,referenceRate,AbsTol=2e-16)
            testCase.verifyEqual(actual.w_i(:,:,[1 end]),zeros(8,6,2),AbsTol=2e-16)
            testCase.verifyEqual(actual.z-actual.eta,Xi-actual.eta_i,AbsTol=3e-14)
        end

        function flatSurfaceRetainsInstantaneousSurfaceMotion(testCase)
            % Even at ssh=0, w_i differs from physical w when ssh is moving.
            xi=linspace(-100,0,17)'; s=reshape(1+xi/100,1,1,[]);
            hatted=struct(u=ones(4,4,17),v=zeros(4,4,17),w=repmat(.1*s.^2,4,4),eta=zeros(4,4,17),ssh=zeros(4));
            actual=WVInternal.freeSurfacePhysicalFields(hatted,xi,100,zeros(4),zeros(4));
            testCase.verifyEqual(actual.u,hatted.u)
            testCase.verifyEqual(actual.w,hatted.w)
            testCase.verifyEqual(actual.w_i,repmat(.1*(s.^2-s),4,4),AbsTol=2e-17)
            testCase.verifyEqual(actual.eta_i,hatted.eta)
        end

        function invalidSurfaceRejectsBeforeDivision(testCase)
            xi=linspace(-100,0,5)';
            hatted=struct(u=zeros(4,4,5),v=zeros(4,4,5),w=zeros(4,4,5),eta=zeros(4,4,5),ssh=zeros(4));
            for badHeight=[-100 -101 NaN Inf]
                hatted.ssh(1)=badHeight;
                testCase.verifyError(@()WVInternal.freeSurfacePhysicalFields(hatted,xi,100,zeros(4),zeros(4)),'WV:InvalidFreeSurfaceGeometry')
            end
        end
    end
end
