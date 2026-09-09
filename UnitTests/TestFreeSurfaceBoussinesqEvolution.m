classdef TestFreeSurfaceBoussinesqEvolution < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function genericSourcesAgreeWithIndependentEnergyPairings(testCase)
            for profile=["constant","exponential"]
                w=TestFreeSurfaceBoussinesqEvolution.newTransform(profile);
                [X,Y,Z]=ndgrid(w.x,w.y,w.z);
                sources=struct(u=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),v=2e-7*sin(2*pi*Y/w.Ly).*(Z/w.Lz).^2,w=3e-8*cos(2*pi*(X/w.Lx+Y/w.Ly)).*(1+Z/w.Lz),eta=1e-6*(1+.2*cos(2*pi*X/w.Lx)).*(1+Z/(2*w.Lz)));
                w.t0=31; w.t=1234;
                actual=w.projectSources(sources);
                expected=energyPairings(w,sources);
                testCase.verifyLessThan(familyError(w,actual,expected),2e-7)
                testCase.verifyError(@()w.projectSources(rmfield(sources,'w')),'WVTransformFreeSurfaceBoussinesq:InvalidSources')
                sources.ssh=zeros(w.Nx,w.Ny);
                testCase.verifyError(@()w.projectSources(sources),'WVTransformFreeSurfaceBoussinesq:InvalidSources')
            end
        end
        function divergentWaveSourceAgreesWithGenericGFormula(testCase)
            w=TestFreeSurfaceBoussinesqEvolution.newTransform("exponential");
            [X,~,Z]=ndgrid(w.x,w.y,w.z);
            zero=zeros(size(X));
            sources=struct(u=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),v=zero,w=zero,eta=zero);
            actual=w.projectSources(sources);
            Su=w.transformFromSpatialDomainWithFourier(sources.u);
            for j=1:length(w.klNonzero)
                p=w.klNonzeroKhUniqueIndex(j); index=w.klNonzero(j);
                divergence=1i*w.kNonzero(j)*Su(:,index);
                b=(w.verticalDerivativeMatrix*divergence)./(w.N2-w.f^2);
                h=w.waveEquivalentDepth(:,p); G=w.waveG(:,:,p);
                expected=(1i*w.g*h.*(w.waveGForward(:,:,p)*b)-1i*h.*G(end,:).'*(divergence(end)+w.g*b(end)))./(2*w.khNonzero(j)*h);
                testCase.verifyEqual(actual.Aw_p(:,j),expected,AbsTol=1e-14)
                testCase.verifyEqual(actual.Aw_m(:,j),expected,AbsTol=1e-14)
            end
            testCase.verifyLessThan(norm(actual.Ag_q,'fro'),1e-20)
            testCase.verifyLessThan(norm(actual.Ag_0,'fro'),1e-20)
        end
        function manufacturedSourceAndForcedEquationsAgree(testCase)
            for profile=["constant","exponential"]
                w=TestFreeSurfaceBoussinesqEvolution.newTransform(profile);
                [sources,B]=TestFreeSurfaceBoussinesqEvolution.resolvedSource(w);
                w.t0=31; w.t=127;
                expected=phaseState(w,B,w.t-w.t0,-1);
                actual=w.projectSources(sources);
                testCase.verifyLessThan(familyError(w,actual,expected),2e-7)
                addSource(w,sources);
                testCase.verifyError(@()w.coefficientAbsoluteTolerances(1e-6),'WVTransformFreeSurfaceBoussinesq:AdaptiveIntegrationUnavailable')
                initial=initialState(w); setState(w,initial);
                m=WVModel(w); m.setupIntegrator(integratorType="fixed",deltaT=10);
                m.integrateToTime(527,shouldShowIntegrationDiagnostics=false);
                reference=exactState(w,initial,B,127,527);
                testCase.verifyLessThan(familyError(w,w.coefficientState(),reference),2e-6)
                verifyForcedEquations(testCase,w,sources)
                testCase.verifyGreaterThan(norm(w.Aio),0)
                testCase.verifyTrue(isreal(w.Amda))
            end
        end
        function fixedStepConvergenceAndRestart(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for profile=["constant","exponential"]
                base=TestFreeSurfaceBoussinesqEvolution.newTransform(profile);
                [sources,~]=TestFreeSurfaceBoussinesqEvolution.resolvedSource(base);
                % Isolate time integration from the fixed spatial projection error.
                B=base.projectSources(sources);
                scientific=base.scientificState(); initial=initialState(base);
                errors=zeros(1,3);
                for i=1:3
                    w=WVTransformFreeSurfaceBoussinesq(scientific); w.t0=31; w.t=127;
                    setState(w,initial); addSource(w,sources);
                    m=WVModel(w); m.setupIntegrator(integratorType="fixed",deltaT=80/2^(i-1));
                    m.integrateToTime(1727,shouldShowIntegrationDiagnostics=false);
                    errors(i)=familyError(w,w.coefficientState(),exactState(w,initial,B,127,1727));
                    if i==3, uninterrupted=w; end
                end
                testCase.verifyGreaterThan(errors(1)/errors(2),10)
                testCase.verifyGreaterThan(errors(2)/errors(3),8)
                w=WVTransformFreeSurfaceBoussinesq(scientific); w.t0=31; w.t=127;
                setState(w,initial); addSource(w,sources);
                m=WVModel(w); m.setupIntegrator(integratorType="fixed",deltaT=20);
                filePath=fullfile(fixture.Folder,char(profile+".nc"));
                m.createNetCDFFileForModelOutput(filePath,outputInterval=400);
                m.eulerianObservingSystem.addNetCDFOutputVariables('u','v','w','eta','p','ssh');
                m.integrateToTime(927,shouldShowIntegrationDiagnostics=false); m.closeNetCDFFile();
                resumed=WVModel.modelFromFile(filePath);
                closeFile=onCleanup(@()resumed.closeNetCDFFile());
                testCase.verifyEmpty(resumed.wvt.verticalModes)
                testCase.verifyEqual(resumed.wvt.t,927)
                testCase.verifyEqual(resumed.wvt.t0,31)
                for name=string(fieldnames(scientific)).'
                    if ~isa(scientific.(name),'function_handle')
                        restored=resumed.wvt.scientificState(); testCase.verifyEqual(restored.(name),scientific.(name))
                    end
                end
                testCase.verifyEqual(resumed.wvt.forcing(1).referenceTime,17)
                resumed.setupIntegrator(integratorType="fixed",deltaT=20);
                resumed.integrateToTime(1727,shouldShowIntegrationDiagnostics=false);
                testCase.verifyLessThan(familyError(resumed.wvt,resumed.wvt.coefficientState(),uninterrupted.coefficientState()),1e-12)
                for component=["wave","balanced","inertial","mda"]
                    c=resumed.wvt.flowComponentWithName(component); u=uninterrupted.flowComponentWithName(component);
                    testCase.verifyEqual(resumed.wvt.totalEnergyOfFlowComponent(c),uninterrupted.totalEnergyOfFlowComponent(u),RelTol=2e-12)
                end
                testCase.verifyEqual(resumed.wvt.p,uninterrupted.p,AbsTol=1e-10)
                clear closeFile
                fprintf('%s RK4 errors: %.6g %.6g %.6g\n',profile,errors)
            end
        end
        function endpointConfigurationsRoundTrip(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for endpoints=[Inf Inf;.02 Inf;Inf .03;.02 .03].'
                w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,g0=endpoints(1),gd=endpoints(2),apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
                w.t0=29; w.t=123; setState(w,initialState(w));
                file=fullfile(fixture.Folder,'state.nc'); nc=w.writeToFile(file,shouldOverwriteExisting=true); nc.close();
                r=WVTransform.waveVortexTransformFromFile(file);
                actual=r.coefficientState(); expected=w.coefficientState();
                if isempty(expected.Ag_0)
                    testCase.verifySize(actual.Ag_0,size(expected.Ag_0))
                    actual=rmfield(actual,'Ag_0'); expected=rmfield(expected,'Ag_0');
                end
                testCase.verifyEqual(actual,expected)
                testCase.verifyEqual(r.reconstructFields(["u","v","w","eta","p","ssh"]),w.reconstructFields(["u","v","w","eta","p","ssh"]))
                testCase.verifyEqual(r.activeEndpoint,w.activeEndpoint)
                zero=zeros(w.Nx,w.Ny,w.Nz); s=struct(u=zero,v=zero,w=zero,eta=zero);
                testCase.verifyEqual(r.projectSources(s),w.projectSources(s))
            end
        end
    end
    methods (Static)
        function results=runStudy(outputFolder)
            % Generate source, evolution and restart evidence and independent checkpoints.
            arguments (Input)
                outputFolder (1,1) string
            end
            if ~isfolder(outputFolder), mkdir(outputFolder); end
            rows=struct([]);
            for profile=["constant","exponential"]
                base=TestFreeSurfaceBoussinesqEvolution.newTransform(profile);
                [sources,B]=TestFreeSurfaceBoussinesqEvolution.resolvedSource(base);
                projected=base.projectSources(sources);
                sourceError=familyError(base,projected,B);
                scientific=base.scientificState(); initial=initialState(base);
                for dt=[80 40 20]
                    w=WVTransformFreeSurfaceBoussinesq(scientific); w.t0=31; w.t=127;
                    setState(w,initial); addSource(w,sources);
                    m=WVModel(w); m.setupIntegrator(integratorType="fixed",deltaT=dt);
                    m.integrateToTime(1727,shouldShowIntegrationDiagnostics=false);
                    timeError=familyError(w,w.coefficientState(),exactState(w,initial,projected,127,1727));
                    totalError=familyError(w,w.coefficientState(),exactState(w,initial,B,127,1727));
                    row=struct(profile=profile,nz=w.Nz,deltaT=dt,startTime=127,finalTime=1727,referenceTime=w.t0,sourceProjectionError=sourceError,timeIntegrationError=timeError,totalCoefficientError=totalError,restartError=NaN);
                    rows=[rows;row]; %#ok<AGROW>
                    if dt==20, finalState=w.coefficientState(); end
                end
                checkpoint=WVTransformFreeSurfaceBoussinesq(scientific); checkpoint.t0=31; checkpoint.t=127;
                setState(checkpoint,initial); addSource(checkpoint,sources);
                m=WVModel(checkpoint); m.setupIntegrator(integratorType="fixed",deltaT=20);
                checkpointFile=fullfile(outputFolder,profile+".nc");
                m.createNetCDFFileForModelOutput(char(checkpointFile),outputInterval=400,shouldOverwriteExisting=true);
                m.eulerianObservingSystem.addNetCDFOutputVariables('u','v','w','eta','p','ssh');
                m.integrateToTime(927,shouldShowIntegrationDiagnostics=false); m.closeNetCDFFile();
                savedState=checkpoint.coefficientState();
                save(fullfile(outputFolder,profile+"-reference.mat"),'finalState','savedState');
                % Keep the checkpoint untouched for a separate provider-free process.
                continuationFile=fullfile(outputFolder,profile+"-continued.nc");
                copyfile(checkpointFile,continuationFile);
                resumed=WVModel.modelFromFile(char(continuationFile));
                closeFile=onCleanup(@()resumed.closeNetCDFFile());
                resumed.setupIntegrator(integratorType="fixed",deltaT=20);
                resumed.integrateToTime(1727,shouldShowIntegrationDiagnostics=false);
                rows(end).restartError=familyError(resumed.wvt,resumed.wvt.coefficientState(),finalState);
                clear closeFile
            end
            results=struct2table(rows);
            writetable(results,fullfile(outputFolder,'issue-366-forced-evolution.csv'));
        end
        function verifyRestartWithoutProvider(outputFolder)
            % Run in a fresh MATLAB process with no InternalModes path entries.
            assert(isempty(which('IMSolverSpectral')),'The mode solver must be unavailable in this process.')
            for profile=["constant","exponential"]
                ref=load(fullfile(outputFolder,profile+"-reference.mat"));
                file=fullfile(outputFolder,profile+".nc");
                m=WVModel.modelFromFile(char(file)); closeFile=onCleanup(@()m.closeNetCDFFile());
                assert(isempty(m.wvt.verticalModes)); assert(m.wvt.t==927 && m.wvt.t0==31);
                assert(isequal(m.wvt.coefficientState(),ref.savedState));
                m.setupIntegrator(integratorType="fixed",deltaT=20);
                m.integrateToTime(1727,shouldShowIntegrationDiagnostics=false);
                error=familyError(m.wvt,m.wvt.coefficientState(),ref.finalState);
                assert(error<1e-12); fprintf('%s provider-free continuation error %.6g\n',profile,error);
                clear closeFile
            end
        end
        function w=newTransform(profile)
            if profile=="constant", N2=@(z)1e-4+0*z; else, N2=@(z)1e-4*exp(2*z/700); end
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
        end
        function [sources,B]=resolvedSource(w)
            B=initialState(w);
            for name=string(fieldnames(B)).', B.(name)=1e-4*B.(name); end
            % Equal instantaneous wave signs give eta=ssh=0 for their source.
            B.Aw_m=B.Aw_p;
            for j=1:length(w.klNonzero)
                p=w.klNonzeroKhUniqueIndex(j); k2=w.khNonzero(j)^2;
                psi=-w.apvF(end,:)*(B.Ag_q(:,j)./w.apvMu(:,p))-w.zeroAPVF(end,:,p)*B.Ag_0(:,j)/k2;
                B.Ag_0(end,j)=B.Ag_0(end,j)+k2*psi/w.zeroAPVF(end,end,p);
            end
            originalT=w.t; originalT0=w.t0; w.t=0; w.t0=0;
            fields=w.reconstructSpectralState(state=B);
            assert(max(abs(fields.ssh),[],'all')<1e-15)
            for name=["u","v","w","eta"], sources.(name)=w.transformToSpatialDomainWithFourier(fields.(name)); end
            w.t=originalT; w.t0=originalT0;
        end
    end
end

function setState(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
function state=initialState(w)
state=w.coefficientState();
for name=string(fieldnames(state)).'
    a=state.(name); ordinal=reshape(1:numel(a),size(a));
    scale=.002; if ismember(name,["Ag_q","Ag_0"]), scale=1e-8; end
    if name=="Amda", a=scale*cos(ordinal); else, a=scale*exp(1i*ordinal)./(1+ordinal); end
    state.(name)=a;
end
end
function addSource(w,s)
w.addForcing(WVPrescribedBoussinesqSource(w,uRate=s.u,vRate=s.v,wRate=s.w,etaRate=s.eta,frequency=.0003,referenceTime=17,phase=.4));
end
function a=phaseState(w,a,time,sign)
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
a.Aw_p=a.Aw_p.*exp(sign*1i*omega*time); a.Aw_m=a.Aw_m.*exp(-sign*1i*omega*time); a.Aio=a.Aio.*exp(sign*1i*w.f*time);
end
function state=exactState(w,initial,B,start,stop)
state=initial;
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
for name=string(fieldnames(B)).'
    frequency=0;
    if name=="Aw_p", frequency=omega; elseif name=="Aw_m", frequency=-omega; elseif name=="Aio", frequency=w.f; end
    phase=.4-.0003*17;
    factor=.5*exp(1i*frequency*w.t0).*(exp(1i*phase)*integratedExponential(.0003-frequency,start,stop)+exp(-1i*phase)*integratedExponential(-.0003-frequency,start,stop));
    state.(name)=state.(name)+B.(name).*factor;
    if name=="Amda", state.Amda=real(state.Amda); end
end
end
function value=integratedExponential(omega,a,b)
x=omega*(b-a)/2; ratio=ones(size(x)); nonzero=x~=0; ratio(nonzero)=sin(x(nonzero))./x(nonzero);
value=(b-a)*exp(1i*omega*(a+b)/2).*ratio;
end
function result=energyPairings(w,s)
% Independent definition: full polarizations and generalized-energy Gram.
for name=["u","v","w","eta"], S.(name)=w.transformFromSpatialDomainWithFourier(s.(name)); end
result=structfun(@(a)zeros(size(a)),w.coefficientState(),UniformOutput=false);
zero=result;
for j=1:length(w.klNonzero)
    index=w.klNonzero(j);
    for family=["Aw_p","Aw_m","Ag_q","Ag_0"]
        count=size(result.(family),1); norms=zeros(count); pair=complex(zeros(count,1)); states=cell(count,1);
        for m=1:count
            a=zero; a.(family)(m,j)=1; R=w.reconstructSpectralState(state=a); states{m}=R;
            pair(m)=sum(w.verticalQuadratureWeights.*(conj(R.u(:,index)).*S.u(:,index)+conj(R.v(:,index)).*S.v(:,index)+conj(R.w(:,index)).*S.w(:,index)+w.N2.*conj(R.eta(:,index)).*S.eta(:,index)));
            if isfinite(w.g0), pair(m)=pair(m)+w.g0*conj(R.eta(end,index)-R.ssh(end,index))*S.eta(end,index); end
            if isfinite(w.gd), pair(m)=pair(m)+w.gd*conj(R.eta(1,index))*S.eta(1,index); end
        end
        for m=1:count
            for n=1:count
                norms(m,n)=pairFields(w,states{m},states{n},index,true);
            end
        end
        result.(family)(:,j)=norms\pair;
    end
end
index=find(w.k==0 & w.l==0,1);
result.Aio=.5*exp(-1i*w.f*(w.t-w.t0))*((w.inertialF'*(w.verticalQuadratureWeights.*w.inertialF))\(w.inertialF'*(w.verticalQuadratureWeights.*(S.u(:,index)-1i*S.v(:,index)))));
metric=diag(w.verticalQuadratureWeights.*w.N2); if isfinite(w.g0), metric(end,end)=metric(end,end)+w.g0; end; if isfinite(w.gd), metric(1,1)=metric(1,1)+w.gd; end
result.Amda=real((w.mdaG'*metric*w.mdaG)\(w.mdaG'*metric*S.eta(:,index)));
end
function value=pairFields(w,A,B,index,generalized)
value=0;
for name=["u","v","w","eta"]
    metric=w.verticalQuadratureWeights; if name=="eta", metric=metric.*w.N2; end
    value=value+sum(metric.*conj(A.(name)(:,index)).*B.(name)(:,index));
end
value=value+w.g*conj(A.ssh(end,index))*B.ssh(end,index);
if generalized
    if isfinite(w.g0), value=value+w.g0*conj(A.eta(end,index)-A.ssh(end,index))*(B.eta(end,index)-B.ssh(end,index)); end
    if isfinite(w.gd), value=value+w.gd*conj(A.eta(1,index))*B.eta(1,index); end
end
end
function value=familyError(w,actual,expected)
zero=structfun(@(a)zeros(size(a)),expected,UniformOutput=false); d=0; r=0;
for name=string(fieldnames(expected)).'
    D=zero; R=zero; D.(name)=actual.(name)-expected.(name); R.(name)=expected.(name);
    D=w.reconstructSpectralState(state=D); R=w.reconstructSpectralState(state=R);
    for j=1:w.Nkl
        factor=1; if w.k(j)==0 && w.l(j)==0, factor=.5; end
        d=d+factor*real(pairFields(w,D,D,j,false)); r=r+factor*real(pairFields(w,R,R,j,false));
    end
end
value=sqrt(d/max(r,realmin));
end
function verifyForcedEquations(testCase,w,sources)
R=w.reconstructSpectralState(); a=w.coefficientState(); d=w.coefficientTendency();
omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
d.Aw_p=d.Aw_p+1i*omega.*a.Aw_p; d.Aw_m=d.Aw_m-1i*omega.*a.Aw_m; d.Aio=d.Aio+1i*w.f*a.Aio;
D=w.reconstructSpectralState(state=d);
scale=cos(.0003*(w.t-17)+.4);
for name=["u","v","w","eta"], S.(name)=scale*w.transformFromSpatialDomainWithFourier(sources.(name)); end
residuals={D.u-w.f*R.v+1i*w.k.'.*R.p/w.rho0-S.u,D.v+w.f*R.u+1i*w.l.'.*R.p/w.rho0-S.v,D.w+w.verticalDerivativeMatrix*R.p/w.rho0+w.N2.*R.eta-S.w,D.eta-R.w-S.eta};
scales={D.u,w.f*R.v,D.v,w.f*R.u,D.w,w.N2.*R.eta,D.eta,R.w};
for j=1:4
    denominator=norm(scales{2*j-1},'fro')+norm(scales{2*j},'fro');
    testCase.verifyLessThan(norm(residuals{j},'fro')/max(denominator,realmin),3e-6)
end
testCase.verifyLessThan(norm(D.ssh(end,:)-R.w(end,:))/max(norm(R.w(end,:)),realmin),2e-7)
testCase.verifyLessThan(norm(R.w(1,:)),1e-12)
% Positive work identity, independent of the signed projection metric.
work=0; energyRate=0;
for j=1:w.Nkl
    factor=2; if w.k(j)==0 && w.l(j)==0, factor=1; end
    energyRate=energyRate+factor*real(pairFields(w,R,D,j,false));
    for name=["u","v","w","eta"]
        metric=w.verticalQuadratureWeights; if name=="eta", metric=metric.*w.N2; end
        work=work+factor*real(sum(metric.*conj(R.(name)(:,j)).*S.(name)(:,j)));
    end
end
testCase.verifyLessThan(abs(energyRate-work)/max(abs(work),realmin),2e-6)
end
