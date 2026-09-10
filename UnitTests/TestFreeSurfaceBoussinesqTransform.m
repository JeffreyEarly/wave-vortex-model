classdef TestFreeSurfaceBoussinesqTransform < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function pureAndMixedStatesRoundTrip(testCase)
            for profile = ["constant","exponential"]
                w = newTransform(profile,65);
                initial = mixedState(w);
                testCase.verifySize(initial.Aw_p,[4 length(w.klNonzero)])
                testCase.verifySize(initial.Ag_q,[3 length(w.klNonzero)])
                testCase.verifySize(initial.Ag_0,[2 length(w.klNonzero)])
                testCase.verifySize(initial.Aio,[3 1])
                testCase.verifySize(initial.Amda,[2 1])
                for family = ["Aw_p","Aw_m","Ag_q","Ag_0","Aio","Amda","mixed"]
                    w.removeAll();
                    if family=="mixed", assignState(w,initial); else, w.(family)=initial.(family); end
                    original = w.coefficientState();
                    for t = [0 1234]
                        w.t = t;
                        fields = w.reconstructFields(["u","v","w","eta","ssh"]);
                        [projected,assessment] = w.projectFields(fields);
                        testCase.verifyLessThan(assessment.relativeFieldEnergyError,1e-6,char(profile+" "+family))
                        testCase.verifyLessThan(coefficientEnergyError(w,projected,original),1e-6,char(profile+" "+family))
                        testCase.verifyEqual(w.coefficientState(),original)
                        testCase.verifyTrue(isreal(projected.Amda))
                    end
                end
            end
        end

        function operationsAndComponentsAgree(testCase)
            w = newTransform("exponential",65); assignState(w,mixedState(w));
            names = ["u","v","w","eta","eta_i","p_linear","ssh","qgpv"];
            full = w.reconstructFields(names); original = w.coefficientState();
            sums = structfun(@(v)zeros(size(v)),full,UniformOutput=false);
            for label = ["wave","apv","zeroapv","inertial","mda"]
                c = w.flowComponentWithName(char(label)); selected = w.reconstructFields(names,flowComponent=c);
                for name = names
                    testCase.verifyEqual(w.variableWithName(char(name+"_"+label)),selected.(name))
                    sums.(name) = sums.(name)+selected.(name);
                end
            end
            for name=names
                testCase.verifyEqual(w.(name),full.(name))
                testCase.verifyEqual(sums.(name),full.(name),AbsTol=2e-10)
            end
            testCase.verifyEqual(w.coefficientState(),original)
            testCase.verifyEqual(full.eta_i,full.eta-reshape(1+w.z/w.Lz,1,1,[]).*full.ssh,AbsTol=1e-12)
            testCase.verifyEqual(full.p_linear(:,:,end),w.rho0*w.g*full.ssh,AbsTol=1e-10)
        end

        function customComponentsRegisterInteriorDisplacement(testCase)
            w = newTransform("constant",33); assignState(w,mixedState(w));
            component = WVFlowComponent(w,coefficientMasks=struct(Aw_p=true,Aw_m=true,Ag_0=true));
            component.name = 'waves and boundary modes';
            component.shortName = 'waveboundary';
            component.abbreviatedName = 'waveboundary';
            w.addFlowComponent(component);
            expected = w.reconstructFields(["u","eta_i","ssh"],flowComponent=component);
            testCase.verifyEqual(w.eta_i_waveboundary,expected.eta_i)
            testCase.verifyEqual(w.u_waveboundary,expected.u)
            testCase.verifyEqual(w.ssh_waveboundary,expected.ssh)
        end

        function energyIncludesBalancedCrossTermsAndConserves(testCase)
            w = newTransform("exponential",65); assignState(w,mixedState(w));
            fields=w.reconstructFields(["u","v","w","eta","ssh"]);
            direct=physicalEnergyOfFields(w,fields);
            testCase.verifyEqual(w.totalEnergy,direct,RelTol=2e-13)
            energy=w.totalEnergy;
            for t=[1000 10000 100000]
                w.t=t; testCase.verifyEqual(w.totalEnergy,energy,RelTol=1e-7)
            end
            components=[w.flowComponentWithName('apv'),w.flowComponentWithName('zeroapv')];
            selfEnergy=w.totalEnergyOfFlowComponent(components(1))+w.totalEnergyOfFlowComponent(components(2));
            combined=w.totalEnergyOfFlowComponent(components(1)+components(2));
            testCase.verifyGreaterThan(abs(combined-selfEnergy),1e-8*combined)
            selected=w.reconstructFields(["u","v","w","eta","ssh"],flowComponent=components(1)+components(2));
            testCase.verifyEqual(combined,physicalEnergyOfFields(w,selected),RelTol=2e-13)
            w.removeAll(); w.Aw_p(1,1)=.01+.02i;
            expected=2*w.waveEquivalentDepth(1,w.klNonzeroKhUniqueIndex(1))*abs(w.Aw_p(1,1))^2;
            testCase.verifyEqual(w.totalEnergy,expected,RelTol=1e-7)
        end

        function phasesAndAllCoefficientSettersInvalidateFields(testCase)
            w=newTransform("constant",33); assignState(w,mixedState(w));
            original=w.coefficientState(); operators=w.scientificState();
            before=w.reconstructSpectralState();
            dt=1234; w.t=dt;
            equivalent=original;
            phase=exp(1i*w.waveFrequency(:,w.klNonzeroKhUniqueIndex)*dt);
            equivalent.Aw_p=original.Aw_p.*phase;
            equivalent.Aw_m=original.Aw_m.*conj(phase);
            equivalent.Aio=original.Aio*exp(1i*w.f*dt);
            after=w.reconstructSpectralState();
            w.t=0; reference=w.reconstructSpectralState(state=equivalent);
            testCase.verifyEqual(after,reference)
            testCase.verifyGreaterThan(norm(after.u-before.u,'fro'),1e-5)
            for name=string(fieldnames(original)).'
                prior=w.u; %#ok<NASGU>
                testCase.verifyTrue(isKey(w.variableCache,'u'))
                w.(name)=2*w.(name);
                testCase.verifyFalse(isKey(w.variableCache,'u'))
                testCase.verifyEqual(w.u,w.reconstructFields("u").u)
            end
            prior=w.u; %#ok<NASGU>
            w.t=111; testCase.verifyFalse(isKey(w.variableCache,'u'))
            at111=w.u;
            w.t0=111; testCase.verifyFalse(isKey(w.variableCache,'u'))
            testCase.verifyGreaterThan(norm(at111(:)-w.u(:)),1e-6)
            testCase.verifyEqual(w.scientificState(),operators)
            balanced=w.reconstructFields(["u_hat","eta","p_linear","ssh"],flowComponent=w.flowComponentWithName('balanced'));
            balancedCache=w.u_hat_balanced;
            w.t=1e5;
            testCase.verifyTrue(isKey(w.variableCache,'u_hat_balanced'))
            testCase.verifyEqual(w.u_hat_balanced,balancedCache)
            testCase.verifyEqual(w.reconstructFields(["u_hat","eta","p_linear","ssh"],flowComponent=w.flowComponentWithName('balanced')),balanced)
        end

        function linearEquationsAndEndpointsHoldForMixedState(testCase)
            for profile=["constant","exponential"]
                w=newTransform(profile,65); assignState(w,mixedState(w));
                state=w.coefficientState(); fields=w.reconstructSpectralState();
                tendency=state;
                omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
                tendency.Aw_p=1i*omega.*state.Aw_p; tendency.Aw_m=-1i*omega.*state.Aw_m;
                tendency.Aio=1i*w.f*state.Aio;
                tendency.Ag_q(:)=0; tendency.Ag_0(:)=0; tendency.Amda(:)=0;
                dt=w.reconstructSpectralState(state=tendency);
                k=w.k.'; l=w.l.'; Dz=w.verticalDerivativeMatrix;
                testCase.verifyLessThan(relativeResidual(dt.u-w.f*fields.v+1i*k.*fields.p/w.rho0,dt.u,w.f*fields.v,1i*k.*fields.p/w.rho0),1e-7)
                testCase.verifyLessThan(relativeResidual(dt.v+w.f*fields.u+1i*l.*fields.p/w.rho0,dt.v,w.f*fields.u,1i*l.*fields.p/w.rho0),1e-7)
                testCase.verifyLessThan(relativeResidual(dt.w+Dz*fields.p/w.rho0+w.N2.*fields.eta,dt.w,Dz*fields.p/w.rho0,w.N2.*fields.eta),2e-6)
                testCase.verifyLessThan(relativeResidual(1i*k.*fields.u+1i*l.*fields.v+Dz*fields.w,1i*k.*fields.u,1i*l.*fields.v,Dz*fields.w),1e-7)
                testCase.verifyLessThan(relativeResidual(dt.eta-fields.w,dt.eta,fields.w),1e-8)
                testCase.verifyLessThan(relativeResidual(dt.ssh(end,:)-fields.w(end,:),dt.ssh(end,:),fields.w(end,:)),1e-7)
                testCase.verifyLessThan(max(abs(fields.w(1,:))),1e-12)
                testCase.verifyEqual(fields.qgpv,1i*k.*fields.v-1i*l.*fields.u-w.f*Dz*fields.eta,AbsTol=1e-10)
            end
        end

        function inactiveEndpointsAndSouthernHemisphereRemainConsistent(testCase)
            for boundary=[Inf Inf;-.1 Inf].'
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],shouldAntialias=true,N2Function=@(z)1e-4*ones(size(z)),g0=boundary(1),gd=boundary(2),latitude=-30,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
                assignState(w,mixedState(w));
                testCase.verifySize(w.Ag_0,[sum(isfinite(boundary)),length(w.klNonzero)])
                fields=w.reconstructFields(["u","v","w","eta","ssh"]);
                [state,assessment]=w.projectFields(fields);
                testCase.verifyLessThan(assessment.relativeFieldEnergyError,1e-6)
                testCase.verifyLessThan(coefficientEnergyError(w,state,w.coefficientState()),1e-6)
                if isempty(w.activeEndpoint)
                    testCase.verifyEqual(w.u_zeroapv,zeros(w.spatialMatrixSize))
                end
                sampled=repmat(reshape(w.z.^2,1,1,[]),w.Nx,w.Ny,1);
                testCase.verifyEqual(w.diffZF(sampled),2*repmat(reshape(w.z,1,1,[]),w.Nx,w.Ny,1),AbsTol=1e-7)
                testCase.verifyEqual(w.diffZG(sampled),w.diffZ(sampled))
            end
        end

        function storedConstructorAndValidationAreExplicit(testCase)
            w=newTransform("constant",33); state=w.scientificState();
            clone=WVTransformFreeSurfaceBoussinesq(state);
            testCase.verifyEqual(clone.scientificState(),state)
            testCase.verifyEmpty(clone.verticalModes)
            assignState(w,mixedState(w)); assignState(clone,w.coefficientState());
            testCase.verifyEqual(clone.reconstructFields(["u","v","w","eta","p_linear","ssh"]),w.reconstructFields(["u","v","w","eta","p_linear","ssh"]))
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq(rmfield(state,'waveF')),'WVTransformFreeSurfaceBoussinesq:IncompleteScientificState')
            testCase.verifyError(@()assignFamily(w,'Aw_p',zeros(1,1)),'WVTransformFreeSurfaceBoussinesq:InvalidCoefficient')
            testCase.verifyError(@()assignFamily(w,'Amda',1i*ones(size(w.Amda))),'WVTransformFreeSurfaceBoussinesq:InvalidCoefficient')
            testCase.verifyError(@()w.projectFields(struct()),'WVTransformFreeSurfaceBoussinesq:InvalidFields')
            testCase.verifyError(@()w.nonlinearFlux(),'WVTransformFreeSurfaceBoussinesq:NonlinearDynamicsUnavailable')
            testCase.verifyError(@()WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],shouldAntialias=true,N2Function=@(z)1e-10*ones(size(z))),'WVTransformFreeSurfaceBoussinesq:UnsupportedStratification')
        end
    end

    methods (Static)
        function results=runStudy(outputPath)
            % Measure fixed-family projection and energy across sampling grids.
            arguments (Input)
                outputPath (1,1) string = ""
            end
            rows=struct([]);
            for profile=["constant","exponential"]
                for nz=[17 33 65]
                    try
                        w=newTransform(profile,nz);
                    catch exception
                        if ~ismember(string(exception.identifier),["WVTransformFreeSurfaceBoussinesq:UnderresolvedWaveGrid","IMBasisSet:StrictDiscreteModeCountRejected"]), rethrow(exception); end
                        row=struct(profile=profile,family="construction",nz=nz,nEVP=64,balancedNEVP=max(96,3*(nz+4)),waveCount=4,apvCount=3,zeroAPVCount=2,inertialCount=3,mdaCount=2,time=NaN,f=7.2921e-5,g0=NaN,gd=NaN,fieldError=NaN,coefficientError=NaN,continuityResidual=NaN,energyVariation=NaN,physicalEnergy=NaN,physicalFourierEnergyError=NaN,waveGramError=NaN,apvGramError=NaN,mdaGramError=NaN,inertialGramError=NaN,status="rejected",reason=string(exception.message));
                        rows=[rows;row]; %#ok<AGROW>
                        continue
                    end
                    initial=mixedState(w);
                    for family=["Aw_p","Aw_m","Ag_q","Ag_0","Aio","Amda","mixed"]
                        w.removeAll();
                        if family=="mixed", assignState(w,initial); else, w.(family)=initial.(family); end
                        original=w.coefficientState(); w.t=0; e0=w.totalEnergy;
                        for time=[0 1234 100000]
                            w.t=time;
                            fields=w.reconstructFields(["u","v","w","eta","ssh"]);
                            [recovered,a]=w.projectFields(fields);
                            row=struct(profile=profile,family=family,nz=nz,nEVP=w.nEVP,balancedNEVP=w.balancedNEVP,waveCount=length(w.waveMode),apvCount=length(w.apvMode),zeroAPVCount=length(w.activeEndpoint),inertialCount=length(w.inertialMode),mdaCount=length(w.mdaMode),time=time,f=w.f,g0=w.g0,gd=w.gd,fieldError=a.relativeFieldEnergyError,coefficientError=coefficientEnergyError(w,recovered,original),continuityResidual=a.continuityResidual,energyVariation=abs(w.totalEnergy-e0)/max(e0,realmin),physicalEnergy=w.totalEnergy,physicalFourierEnergyError=abs(physicalEnergyOfFields(w,fields)-w.totalEnergy)/max(w.totalEnergy,realmin),waveGramError=a.waveGramError,apvGramError=a.apvGramError,mdaGramError=a.mdaGramError,inertialGramError=a.inertialGramError,status="qualified",reason="");
                            rows=[rows;row]; %#ok<AGROW>
                        end
                    end
                end
            end
            results=struct2table(rows);
            if outputPath~="", writetable(results,outputPath); end
        end
    end
end

function w=newTransform(profile,nz)
if profile=="constant", N2=@(z)1e-4*ones(size(z)); else, N2=@(z)1e-4*exp(2*z/700); end
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 nz],shouldAntialias=true,N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
end
function state=mixedState(w)
state=w.coefficientState();
for name=string(fieldnames(state)).'
    a=state.(name); ordinal=reshape(1:numel(a),size(a));
    if name=="Ag_q" || name=="Ag_0", scale=1e-8; else, scale=.002; end
    if name=="Amda", a=scale*cos(ordinal); else, a=scale*exp(1i*ordinal)./(1+ordinal); end
    state.(name)=a;
end
end
function assignState(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
function assignFamily(w,name,value), w.(name)=value; end
function value=physicalEnergyOfFields(w,fields)
weights=reshape(w.verticalQuadratureWeights,1,1,[]); N2=reshape(w.N2,1,1,[]);
ssh=w.ssh; gamma=1+ssh/w.Lz; alpha=reshape(1+w.z/w.Lz,1,1,[]);
fields.w=fields.w-alpha.*(fields.u.*w.diffX(ssh)+fields.v.*w.diffY(ssh));
fields.u=gamma.*fields.u; fields.v=gamma.*fields.v;
value=sum(weights.*(fields.u.^2+fields.v.^2+fields.w.^2+N2.*fields.eta.^2),'all')/(2*w.Nx*w.Ny)+w.g*mean(fields.ssh.^2,'all')/2;
end
function value=coefficientEnergyError(w,actual,expected)
% Sum each family's positive error energy separately: leakage into two
% families must not cancel when checking a mixed-state coefficient error.
zero=structfun(@(a)zeros(size(a)),expected,UniformOutput=false);
valueD=0; valueR=0;
for family=string(fieldnames(expected)).'
    difference=zero; reference=zero;
    difference.(family)=actual.(family)-expected.(family);
    reference.(family)=expected.(family);
    D=w.reconstructSpectralState(state=difference); R=w.reconstructSpectralState(state=reference);
    weights=w.verticalQuadratureWeights; factor=ones(1,w.Nkl); factor(w.k==0 & w.l==0)=.5;
    for name=["u","v","w","eta"]
        if name=="eta", metric=weights.*w.N2; else, metric=weights; end
        valueD=valueD+sum(factor.*metric.*abs(D.(name)).^2,'all'); valueR=valueR+sum(factor.*metric.*abs(R.(name)).^2,'all');
    end
    valueD=valueD+w.g*sum(factor.*abs(D.ssh(end,:)).^2); valueR=valueR+w.g*sum(factor.*abs(R.ssh(end,:)).^2);
end
value=sqrt(valueD/max(valueR,realmin));
end
function value=relativeResidual(residual,varargin)
scale=0; for i=1:length(varargin), scale=scale+norm(varargin{i},'fro'); end
value=norm(residual,'fro')/max(scale,realmin);
end
