classdef TestSourceProjection < matlab.unittest.TestCase
    properties
        studyData
        transform
    end
    methods (TestClassSetup)
        function prepareIndependentAdapterAndModel(testCase)
            config=struct(profile="constant",Lz=1000,Lxy=[1e4 1e4],Nxy=[8 8],Nz=65,f=1e-4,g=9.81,waveCount=3,apvCount=2,mdaCount=2,inertialCount=3,evpOrders=[128 192],referenceOrders=[257 513],referenceAllowance=1e-4,eigenAllowance=1e-6,gramTolerance=1e-7);
            testCase.studyData=prepareSourceStudy(config);
            testCase.transform=WVTransformFreeSurfaceBoussinesq.fromStratification([1e4 1e4 1000],[8 8 65],N2Function=@(z)1e-4*ones(size(z)),waveModeCount=3,apvModeCount=2,mdaModeCount=2,inertialModeCount=3,nEVP=128,latitude=asind(1e-4/(2*7.2921e-5)));
        end
    end
    methods (Test)
        function waveSourceDualMatchesActualModel(testCase)
            data=testCase.studyData; wvt=testCase.transform;
            kl=[wvt.kNonzero(1),wvt.lNonzero(1)];
            [distance,v]=min(vecnorm(data.inventory.physicalVectors-kl,2,2));
            testCase.verifyLessThan(distance,1e-14)
            q=@(z)exp(z/1000);
            [x,y]=ndgrid(wvt.x,wvt.y); source=2*cos(kl(1)*x+kl(2)*y).*reshape(q(wvt.z),1,1,[]);
            zero=zeros(size(source));
            for component=["u","v","w","eta"]
                [context,counts]=sourceProjectionContext(data,v,component,"Q");
                result=measureProductProjection(context,q(data.z),q(data.zQ),zeros(2,1),counts);
                sources=struct(u=zero,v=zero,w=zero,eta=zero); sources.(component)=source;
                tendency=wvt.projectSources(sources);
                coefficients=result.sampleCoefficients{end};
                testCase.verifyEqual(coefficients(1:2:end),tendency.Aw_p(:,1),AbsTol=2e-11)
                testCase.verifyEqual(coefficients(2:2:end),tendency.Aw_m(:,1),AbsTol=2e-11)
            end
        end

        function meanSourceDualsMatchActualModel(testCase)
            data=testCase.studyData; wvt=testCase.transform;
            v=find(all(data.inventory.vectors==0,2)); q=@(z)exp(z/1000);
            values=repmat(reshape(q(wvt.z),1,1,[]),wvt.Nx,wvt.Ny,1); zero=zeros(size(values));
            for component=["u","v","eta"]
                [context,counts]=sourceProjectionContext(data,v,component,"Q");
                endpoints=zeros(2,1); if component=="eta", endpoints=q([-1000;0]); end
                result=measureProductProjection(context,q(data.z),q(data.zQ),endpoints,counts);
                sources=struct(u=zero,v=zero,w=zero,eta=zero); sources.(component)=values;
                tendency=wvt.projectSources(sources);
                if component=="eta", expected=tendency.Amda; else, expected=tendency.Aio; end
                testCase.verifyEqual(result.sampleCoefficients{end},expected,AbsTol=2e-10)
            end
        end

        function derivativesMatchConstantWaveEquation(testCase)
            data=testCase.studyData; p=find(data.inventory.magnitudes>0,1);
            B=data.wave{p}; k=data.inventory.magnitudes(p); h=B.basis.h(:).';
            expectedDF=(k^2*h-(data.profile.N2(data.zQ)-data.config.f^2)/data.config.g).*B.Q.G;
            expectedDG=B.Q.F./h;
            testCase.verifyLessThan(norm(B.Q.dF-expectedDF,'fro')/norm(expectedDF,'fro'),1e-6)
            testCase.verifyLessThan(norm(B.Q.dG-expectedDG,'fro')/norm(expectedDG,'fro'),1e-12)
            testCase.verifyLessThan(max(data.requiredConvergence,[],'all'),1e-6)
        end

        function channelInventoryIncludesEveryDeclaredVolumeTerm(testCase)
            channels=sourceChannelInventory();
            testCase.verifyEqual(height(channels),13)
            testCase.verifyEqual(nnz(channels.factor=="z"),4)
            testCase.verifyTrue(any(channels.name=="w*eta*dlogN2"))
            v=find(all(testCase.studyData.inventory.vectors==0,2));
            [context,counts,name]=sourceProjectionContext(testCase.studyData,v,"w","Q");
            testCase.verifyEmpty(context); testCase.verifyEmpty(counts);
            testCase.verifyEqual(name,"null-mean-w")
        end
    end
end
