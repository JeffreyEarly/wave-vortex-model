classdef TestThermalDiagnostics < matlab.unittest.TestCase
    properties
        scientificStates
    end
    methods (TestClassSetup)
        function construct(testCase)
            testCase.scientificStates=cell(1,2);
            for j=1:2
                a=(j-1)/1300;
                w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4);
                testCase.scientificStates{j}=w.scientificState;
            end
        end
    end
    methods (Test, TestTags="full")
        function exactDeepWKBInterpolation(testCase)
            depth=4000; a=1/1300; [x,~]=legpts(513); z=depth*(x-1)/2;
            targets=1+2*expm1(a*z)/(-expm1(-depth*a)); expected=cos(8*acos(targets));
            for count=[33 65]
                nodes=-cos(pi*(0:count-1)'/(count-1));
                zNative=log1p((nodes-1)*(-expm1(-depth*a))/2)/a;
                P=WVInternal.thermalVerticalInterpolation(zNative,z,depth,a);
                testCase.verifyLessThan(max(abs(P*cos(8*acos(nodes))-expected)),2e-12);
            end
        end

        function inventoriesMatchIndependentPhysicalFields(testCase)
            for j=1:2
                w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificStates{j});
                setState(w); original=w.coefficientState();
                for selection=["mixed","thermal","mean"]
                    state=original;
                    if selection=="thermal", state.Amda=0*state.Amda; end
                    if selection=="mean", state.Ath=0*state.Ath; end
                    assign(w,state);
                    [d,s,m]=w.quadraticDiagnostics();
                    direct=physicalInventories(w);
                    for name=string(fieldnames(d)).'
                        testCase.verifyEqual(d.(name),direct.(name),RelTol=2e-9,AbsTol=1e-22);
                        testCase.verifyEqual(sum(s.(name))+m.(name),d.(name),RelTol=2e-15);
                    end
                    testCase.verifyEqual(w.totalEnergy,direct.totalEnergy,RelTol=2e-9);
                    testCase.verifyEqual(w.totalEnergySpatiallyIntegrated,w.totalEnergy);
                    testCase.verifyEqual(w.totalPotentialEnstrophy,direct.potentialEnstrophy,RelTol=2e-9);
                    if selection~="thermal"
                        testCase.verifyGreaterThan(m.potentialEnstrophy,0);
                        testCase.verifyGreaterThan(m.surfaceAnomalyVariance,0);
                        testCase.verifyGreaterThan(m.bottomAnomalyVariance,0);
                    end
                end
            end
        end
        function directionalRatesRetainCancellationAndBatchShape(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificStates{2}); setState(w);
            state=w.coefficientState();
            direction=struct(Ath=.2*state.Ath+1i*.1*circshift(state.Ath,1,2),Amda=flipud(state.Amda)/3);
            opposite=struct(Ath=-direction.Ath,Amda=-direction.Amda);
            [d,s,m]=w.quadraticDiagnostics(tendency=[direction opposite]);
            epsilon=1e-3;
            assign(w,combine(state,direction,epsilon)); plus=physicalInventories(w);
            assign(w,combine(state,direction,-epsilon)); minus=physicalInventories(w);
            assign(w,state);
            single=w.quadraticDiagnostics(tendency=direction);
            for name=string(fieldnames(plus)).'
                expected=(plus.(name)-minus.(name))/(2*epsilon);
                testCase.verifyEqual(d.(name+"Tendency"),[expected;-expected],RelTol=2e-8,AbsTol=1e-20);
                testCase.verifyEqual(d.(name+"Tendency")(1),single.(name+"Tendency"),RelTol=1e-14);
                testCase.verifyEqual(sum(s.(name+"Tendency"),2)+m.(name+"Tendency"),d.(name+"Tendency"),RelTol=1e-14);
            end
            testCase.verifyEqual(w.coefficientState(),state);
            testCase.verifyError(@()w.quadraticDiagnostics(state=struct(Ath=state.Ath)),'WV:DiagnosticState');
        end
        function componentsCrossTermsAndCacheLifecycle(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificStates{2});
            metric=w.physicalMetricOperators();
            G=w.thermalEnergyGram(:,:,1); score=abs(G)./sqrt(real(diag(G))*real(diag(G)).');
            score(1:size(G,1)+1:end)=0; [~,entry]=max(score,[],'all','linear');
            [i,j]=ind2sub(size(G),entry); w.Ath(i,1)=1; w.Ath(j,1)=exp(-1i*angle(G(i,j)));
            w.Amda=[.02;-.01;.03;-.04];
            mask=false(size(w.Ath)); mask(i,:)=true;
            first=WVFlowComponent(w,coefficientMasks=struct(Ath=mask));
            second=WVFlowComponent(w,coefficientMasks=struct(Ath=~mask,Amda=true));
            all=first+second; original=w.coefficientState();
            testCase.verifyEqual(w.totalEnergyOfFlowComponent(all),w.totalEnergy,RelTol=1e-14);
            e1=w.totalEnergyOfFlowComponent(first); e2=w.totalEnergyOfFlowComponent(second);
            assign(w,w.coefficientState(flowComponent=first)); a=physicalInventories(w);
            assign(w,original); assign(w,w.coefficientState(flowComponent=second)); b=physicalInventories(w);
            assign(w,original);
            testCase.verifyEqual(e1,a.totalEnergy,RelTol=2e-9);
            testCase.verifyEqual(e2,b.totalEnergy,RelTol=2e-9);
            testCase.verifyGreaterThan(abs(w.totalEnergy-e1-e2),1e-6*w.totalEnergy);
            before=w.u; w.Ath=2*w.Ath;
            testCase.verifyEqual(w.u,2*before,AbsTol=1e-13);
            testCase.verifyEqual(w.physicalMetricOperators(),metric);
            w.t=100; testCase.verifyEqual(w.physicalMetricOperators(),metric);
            other=w.withDiffusivity(1e-5);
            testCase.verifyEqual(other.quadraticDiagnostics(),w.quadraticDiagnostics());
        end
        function radialSpectraRMSAndTailsAgree(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificStates{2}); setState(w);
            [d,s]=w.physicalDiagnostics(); q=w.quadraticDiagnostics();
            testCase.verifyEqual(d.rms.qgpv^2,2*q.potentialEnstrophy/w.Lz,RelTol=2e-14);
            testCase.verifyEqual(d.rms.speed^2,2*q.kineticEnergy/w.Lz,RelTol=2e-14);
            testCase.verifyEqual(d.rms.ssh^2,2*q.surfacePotentialEnergy/w.g,RelTol=2e-14);
            for name=string(fieldnames(d.rms)).'
                testCase.verifyEqual(sum(s.(name)),d.rms.(name)^2,RelTol=2e-14);
                testCase.verifyGreaterThanOrEqual(d.horizontalTailFraction.(name),0);
                testCase.verifyLessThanOrEqual(d.horizontalTailFraction.(name),1);
            end
            w.Ath=0*w.Ath; w.Amda=0*w.Amda;
            d=w.physicalDiagnostics(); testCase.verifyEqual(d.horizontalTailFraction.qgpv,0);
        end
    end
end

function setState(w)
thermalManufacturedState(w,[2 3 4],10);
w.Amda=[.02;-.01;.03;-.04];
end
function assign(w,s)
w.Ath=s.Ath; w.Amda=s.Amda;
end
function s=combine(a,b,factor)
s=struct(Ath=a.Ath+factor*b.Ath,Amda=a.Amda+factor*b.Amda);
end
function d=physicalInventories(w)
f=w.reconstructFields(["u","v","eta","qgpv","ssh","endpointAnomalies"]);
weights=w.verticalQuadratureWeights;
integral=@(value)sum(weights.*squeeze(mean(value,[1 2])));
d=struct(kineticEnergy=integral(f.u.^2+f.v.^2)/2, ...
    interiorPotentialEnergy=integral(reshape(w.N2,1,1,[]).*f.eta.^2)/2, ...
    surfacePotentialEnergy=w.g*mean(f.ssh.^2,'all')/2,potentialEnstrophy=integral(f.qgpv.^2)/2, ...
    surfaceAnomalyVariance=mean(f.endpointAnomalies(:,:,1).^2,'all')/2, ...
    bottomAnomalyVariance=mean(f.endpointAnomalies(:,:,2).^2,'all')/2);
d.totalEnergy=d.kineticEnergy+d.interiorPotentialEnergy+d.surfacePotentialEnergy;
end
