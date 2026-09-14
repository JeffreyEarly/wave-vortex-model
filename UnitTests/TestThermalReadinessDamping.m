classdef TestThermalReadinessDamping < matlab.unittest.TestCase
    properties
        scientificState
        targetScientificState
        canonical
    end
    methods (TestClassSetup)
        function construct(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools')));
            w=thermalTransform([12 12],17);
            testCase.scientificState=w.scientificState;
            target=thermalTransform([18 18],25);
            testCase.targetScientificState=target.scientificState;
            apv=WVTransformFreeSurfaceQG([w.Lx w.Ly w.Lz],[w.Nx w.Ny 129],N2Function=w.N2Function,latitude=w.latitude,g=w.g,apvModeCount=6,mdaModeCount=4);
            force=WVThermalAPVDamping.fromAPVTransform(w,apv,apvCutoffFraction=.5);
            testCase.canonical=configuration(force);
        end
    end
    methods (Test,TestTags="full")
        function horizontalWorkRetainsPhysicalCrossTerms(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
            force=thermalReadinessDamping(w,testCase.canonical);
            data=force.coefficientDampingData();
            [state,pair]=nonorthogonalState(w,data.horizontalRates);
            w.Ath=state.Ath; w.Amda=state.Amda;
            speed=.1;
            [horizontal,vertical]=force.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            testCase.verifyEqual(abs(vertical.Ath),zeros(size(w.Ath)));
            testCase.verifyEqual(vertical.Amda,zeros(size(w.Amda)));
            testCase.verifyEqual(horizontal.Amda,zeros(size(w.Amda)));
            testCase.verifyEqual(abs(horizontal.Ath(:,data.horizontalRates==0)),zeros(size(w.Ath(:,data.horizontalRates==0))));
            testCase.verifyTrue(any(data.horizontalRates==0) && any(data.horizontalRates<0));
            testCase.verifyEqual(force.maximumExplicitDampingRate(struct(uvMax=speed)),speed*max(-data.horizontalRates));
            testCase.verifyEqual(force.maximumExplicitDampingRate(struct(uvMax=0)),0);

            [energy,work]=physicalColumns(w,state,horizontal);
            expected=2*speed*data.horizontalRates.*energy;
            testCase.verifyEqual(work,expected,RelTol=2e-12,AbsTol=1e-22);
            diagnostic=w.quadraticDiagnostics(tendency=horizontal);
            testCase.verifyEqual(diagnostic.totalEnergyTendency,sum(work),RelTol=2e-9,AbsTol=1e-22);
            testCase.verifyLessThan(sum(work),0);
            testCase.verifyLessThanOrEqual(abs(sum(work)),2*force.maximumExplicitDampingRate(struct(uvMax=speed))*sum(energy)*(1+1e-12));

            first=pair; second=pair;
            rows=find(any(pair.Ath~=0,2)); first.Ath(rows(2),:)=0; second.Ath(rows(1),:)=0;
            combined=physicalColumns(w,pair,horizontal);
            separate=physicalColumns(w,first,horizontal)+physicalColumns(w,second,horizontal);
            testCase.verifyGreaterThan(abs(sum(combined-separate)),1e-4*sum(combined));
            w.Ath(:)=0;
            [h,v]=force.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            testCase.verifyEqual(abs(h.Ath),zeros(size(w.Ath))); testCase.verifyEqual(abs(v.Ath),zeros(size(w.Ath)));
            testCase.verifyEqual(w.Amda,state.Amda);
            testCase.verifyGreaterThan(w.totalEnergy,0);
        end

        function physicalFilterAndTendencySurviveResolutionTransfer(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
            target=WVTransformFreeSurfaceThermalQG(scientificState=testCase.targetScientificState);
            force=thermalReadinessDamping(w,testCase.canonical);
            copy=force.forcingWithResolutionOfTransform(target);
            testCase.verifyEqual(configuration(copy),configuration(force));
            sourceRates=force.coefficientDampingData().horizontalRates;
            targetRates=copy.coefficientDampingData().horizontalRates;
            [common,indices]=ismember([w.kMode_wv(w.klNonzero),w.lMode_wv(w.klNonzero)],[target.kMode_wv(target.klNonzero),target.lMode_wv(target.klNonzero)],'rows');
            testCase.verifyTrue(all(common));
            testCase.verifyEqual(targetRates(indices),sourceRates,AbsTol=8*eps*max(abs(sourceRates)));
            testCase.verifyNotEqual(target.effectiveHorizontalGridResolution,force.horizontalResolution);
            populatePolynomial(w,sourceRates);
            original=w.coefficientState();
            [mapped,assessment]=w.coefficientStateForTransform(target);
            testCase.verifyLessThan(assessment.relativeFieldError,1e-8);
            target.Ath=mapped.Ath; target.Amda=mapped.Amda;
            speed=.1;
            [sourceRate,sourceVertical]=force.quasigeostrophicDampingContributions(w,struct(uvMax=speed));
            [targetRate,targetVertical]=copy.quasigeostrophicDampingContributions(target,struct(uvMax=speed));
            testCase.verifyEqual(abs(sourceVertical.Ath),zeros(size(w.Ath)));
            testCase.verifyEqual(abs(targetVertical.Ath),zeros(size(target.Ath)));
            sourceDirection=WVTransformFreeSurfaceThermalQG(scientificState=w.scientificState,coefficientState=sourceRate);
            [mappedRate,rateAssessment]=sourceDirection.coefficientStateForTransform(target);
            testCase.verifyLessThan(rateAssessment.relativeFieldError,1e-8);
            difference=struct(Ath=targetRate.Ath-mappedRate.Ath,Amda=targetRate.Amda-mappedRate.Amda);
            reference=physicalColumns(target,mappedRate,mappedRate);
            error=physicalColumns(target,difference,difference);
            testCase.verifyLessThan(sqrt(sum(error)/sum(reference)),1e-8);
            testCase.verifyEqual(w.coefficientState(),original);
        end

        function annotatedRestoreRetainsTheSelectedCandidate(testCase)
            folder=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for variant=["horizontal","apv"]
                w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
                force=thermalReadinessDamping(w,testCase.canonical,variant=variant);
                populatePolynomial(w,force.coefficientDampingData().horizontalRates);
                w.t0=123; w.t=456; w.addForcing(force);
                path=fullfile(folder.Folder,variant+".nc"); file=w.writeToFile(char(path)); file.close();
                restored=WVTransform.waveVortexTransformFromFile(char(path));
                actual=restored.forcingWithName(force.name);
                testCase.verifyClass(actual,'WVThermalAPVDamping');
                testCase.verifyEqual(configuration(actual),configuration(force));
                testCase.verifyEqual(restored.coefficientState(),w.coefficientState());
                testCase.verifyEqual([restored.t0 restored.t],[w.t0 w.t]);
                testCase.verifyEmpty(fieldnames(restored.constructionAssessment));
                [h,v]=force.quasigeostrophicDampingContributions(w,struct(uvMax=.1));
                [rh,rv]=actual.quasigeostrophicDampingContributions(restored,struct(uvMax=.1));
                testCase.verifyEqual(rh,h); testCase.verifyEqual(rv,v);
                testCase.verifyEqual(actual.maximumExplicitDampingRate(struct(uvMax=.1)),force.maximumExplicitDampingRate(struct(uvMax=.1)));
            end
        end

        function candidatesChangeOnlyTheDeclaredVerticalRates(testCase)
            w=WVTransformFreeSurfaceThermalQG(scientificState=testCase.scientificState);
            original=testCase.canonical;
            apv=thermalReadinessDamping(w,original,variant="apv");
            horizontal=thermalReadinessDamping(w,original,variant="horizontal");
            testCase.verifyEqual(configuration(apv),original);
            expected=original; expected.apvVerticalRates(:)=0;
            testCase.verifyEqual(configuration(horizontal),expected);
            testCase.verifyTrue(any(original.apvVerticalRates<0));
            testCase.verifyEqual(testCase.canonical,original);
            testCase.verifyEmpty(w.forcing);
            invalid=original; invalid.apvVerticalRates(1)=NaN;
            testCase.verifyError(@()thermalReadinessDamping(w,invalid),'ThermalReadiness:ClosureConfiguration');
            invalid=original; invalid.unrecordedFilter=.5;
            testCase.verifyError(@()thermalReadinessDamping(w,invalid),'ThermalReadiness:ClosureConfiguration');
        end
    end
end

function w=thermalTransform(horizontalCount,thermalCount)
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[horizontalCount 129],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=thermalCount,mdaModeCount=4,kappa_z=1e-5);
end

function canonical=configuration(force)
canonical=struct();
for name=string(force.classRequiredPropertyNames()), canonical.(name)=force.(name); end
end

function [state,pair]=nonorthogonalState(w,rates)
state=w.coefficientState(); best=0;
for column=find(rates<0)
    page=w.klNonzeroKhUniqueIndex(column); G=w.thermalEnergyGram(:,:,page);
    score=abs(G)./sqrt(real(diag(G))*real(diag(G)).'); score(1:size(G,1)+1:end)=0;
    [value,entry]=max(score,[],'all','linear');
    if value>best
        best=value; [first,second]=ind2sub(size(G),entry); selected=column; gram=G;
    end
end
assert(best>1e-4,'The manufactured energy check needs two measurably nonorthogonal thermal directions.');
state.Ath(first,selected)=1/sqrt(gram(first,first));
state.Ath(second,selected)=exp(-1i*angle(gram(first,second)))/sqrt(gram(second,second));
pair=state;
low=find(rates==0,1); state.Ath(2,low)=.1/sqrt(w.thermalEnergyGram(2,2,w.klNonzeroKhUniqueIndex(low)));
state.Amda=[.02;-.01;.03;-.04];
end

function populatePolynomial(w,rates)
columns=[find(rates==0,1),find(rates<0,1,'last')];
for j=1:numel(columns)
    polynomial=zeros(w.thermalModeCount,1); polynomial(1:4)=100*[1;.2;-.1;.04]*(1+.3i*j);
    column=columns(j); page=w.klNonzeroKhUniqueIndex(column);
    w.Ath(:,column)=w.polynomialToThermal(:,:,page)*polynomial;
end
w.Amda=[.02;-.01;.03;-.04];
end

function [energy,work]=physicalColumns(w,state,direction)
% Independent physical-depth integration, including each conjugate partner.
% The state energy is quadratic, so the derivative carries the factor two.
[x,weights]=legpts(513); z=(x-1)*w.Lz/2; weights=weights(:)*w.Lz/2;
r=WVInternal.thermalPolynomialFields(z,w.thermalModeCount,w.Lz,w.N20,w.inverseScale,0,w.f,w.g);
N2=w.N20*exp(2*w.inverseScale*z);
energy=zeros(1,numel(w.klNonzero)); work=energy;
for page=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==page;
    polynomial=w.thermalToPolynomial(:,:,page)*state.Ath(:,columns);
    rate=w.thermalToPolynomial(:,:,page)*direction.Ath(:,columns);
    psi=r.psi*polynomial; eta=r.eta*polynomial; ssh=r.ssh*polynomial;
    dpsi=r.psi*rate; deta=r.eta*rate; dssh=r.ssh*rate;
    energy(columns)=sum(weights.*(w.khUnique(page)^2*abs(psi).^2+N2.*abs(eta).^2),1)+w.g*abs(ssh).^2;
    work(columns)=2*real(sum(weights.*(w.khUnique(page)^2*conj(psi).*dpsi+N2.*conj(eta).*deta),1)+w.g*conj(ssh).*dssh);
end
end
