classdef TestFreeSurfaceResolutionTransfer < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function samplingRefinementPreservesResolvedContent(testCase)
            for type=["qg","boussinesq"]
                for profile=["constant","exponential"]
                    w=newTransform(type,profile); populate(w);
                    original=w.coefficientState(); forces=w.forcing;
                    [same,a]=w.waveVortexTransformWithResolution([8 8 65]);
                    testCase.verifyLessThan(stateError(same.coefficientState(),original),1e-12)
                    testCase.verifyLessThan(a.relativeFieldError,1e-12)
                    [fine,a]=w.waveVortexTransformWithResolution([12 10 97]);
                    verifyCounts(testCase,w,fine)
                    testCase.verifyEqual([fine.t fine.t0],[w.t w.t0])
                    testCase.verifyEqual(a.discardedEnergy,0)
                    testCase.verifyLessThan(a.relativeFieldError,1e-7)
                    [err,energy]=physicalDifference(w,fine);
                    testCase.verifyEqual(a.relativeFieldError,err,AbsTol=2e-12)
                    testCase.verifyEqual(a.sourceEnergy,energy,RelTol=1e-9)
                    [back,b]=fine.waveVortexTransformWithResolution([8 8 65]);
                    testCase.verifyLessThan(stateError(back.coefficientState(),original),1e-7)
                    testCase.verifyEqual(b.discardedEnergy,0)
                    testCase.verifyEqual(w.coefficientState(),original)
                    testCase.verifyTrue(all(w.forcing==forces))
                end
            end
        end
        function independentCountsAndDiscardedPhysicalField(testCase)
            for type=["qg","boussinesq"]
                w=newTransform(type,"exponential"); populate(w);
                options=struct(apvModeCount=2,mdaModeCount=1);
                if type=="boussinesq", options.waveModeCount=2; options.inertialModeCount=1; end
                args=namedargs2cell(options);
                [coarse,a]=w.waveVortexTransformWithResolution([6 6 65],args{:});
                testCase.verifyEqual(length(coarse.apvMode),2)
                testCase.verifyEqual(length(coarse.mdaMode),1)
                if type=="boussinesq"
                    testCase.verifyEqual(length(coarse.waveMode),2)
                    testCase.verifyEqual(length(coarse.inertialMode),1)
                end
                [err,energy]=physicalDifference(w,coarse);
                testCase.verifyEqual(a.relativeFieldError,err,AbsTol=2e-10)
                testCase.verifyGreaterThan(a.discardedEnergy,0)
                % The independently reconstructed missing state retains cross terms.
                lost=w.waveVortexTransformWithResolution([8 8 65]);
                [horizontal,~]=ismember([w.kMode_wv(w.klNonzero),w.lMode_wv(w.klNonzero)],[coarse.kMode_wv(coarse.klNonzero),coarse.lMode_wv(coarse.klNonzero)],'rows');
                for name=string(fieldnames(lost.coefficientState())).'
                    values=lost.(name); count=size(coarse.(name),1);
                    if ismember(name,["Aio","Amda"]), values(1:count)=0; else, values(1:count,horizontal)=0; end
                    lost.(name)=values;
                end
                zero=w.waveVortexTransformWithResolution([8 8 65]); clearState(zero);
                [~,lostEnergy]=physicalDifference(lost,zero);
                testCase.verifyEqual(a.discardedEnergy,lostEnergy,RelTol=1e-8)
                testCase.verifyEqual(a.relativeDiscardedFieldNorm,sqrt(lostEnergy/energy),AbsTol=1e-10)
                % Increasing each family count leaves newly admitted modes empty.
                options=struct(apvModeCount=4,mdaModeCount=3);
                if type=="boussinesq", options.waveModeCount=5; options.inertialModeCount=4; end
                args=namedargs2cell(options);
                [expanded,b]=w.waveVortexTransformWithResolution([8 8 65],args{:});
                testCase.verifyEqual(b.discardedEnergy,0)
                for name=string(fieldnames(expanded.coefficientState())).'
                    values=expanded.(name); oldCount=size(w.(name),1);
                    testCase.verifyEqual(values(oldCount+1:end,:),zeros(size(values(oldCount+1:end,:))))
                end
            end
        end
        function phaseNormalizationAndPhysicalLabels(testCase)
            w=newTransform("boussinesq","exponential"); populate(w);
            scientific=w.scientificState();
            % An equivalent inertial representation with reordered physical labels.
            order=[3 1 2]; scale=[-2 3 -.5];
            scientific.inertialF=scientific.inertialF(:,order).*scale;
            scientific.inertialFForward=scientific.inertialFForward(order,:)./scale.';
            scientific.inertialModeNumber=scientific.inertialModeNumber(order);
            scientific.inertialEquivalentDepth=scientific.inertialEquivalentDepth(order);
            target=WVTransformFreeSurfaceBoussinesq(scientific); target.t0=-917; target.t=9;
            before=target.coefficientState(); original=w.coefficientState();
            [state,a]=w.coefficientStateForTransform(target);
            testCase.verifyEqual(target.coefficientState(),before)
            testCase.verifyEqual(target.t,9)
            testCase.verifyEqual(w.coefficientState(),original)
            testCase.verifyEqual(state.Aio,original.Aio(order).*exp(1i*w.f*(target.t0-w.t0))./scale.',AbsTol=1e-14)
            omega=w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
            testCase.verifyEqual(state.Aw_p,original.Aw_p.*exp(1i*omega*(target.t0-w.t0)),AbsTol=1e-14)
            testCase.verifyEqual(state.Aw_m,original.Aw_m.*exp(-1i*omega*(target.t0-w.t0)),AbsTol=1e-14)
            testCase.verifyTrue(isreal(state.Amda))
            adopt(target,state); target.t=w.t;
            testCase.verifyLessThan(a.relativeFieldError,1e-12)
            testCase.verifyLessThan(physicalDifference(w,target),1e-12)
        end
        function incompatibleRepresentationsRejectWithoutMutation(testCase)
            w=newTransform("boussinesq","constant"); populate(w); original=w.coefficientState();
            s=w.scientificState(); s.Lxyz(1)=2*s.Lxyz(1);
            testCase.verifyError(@()w.coefficientStateForTransform(WVTransformFreeSurfaceBoussinesq(s)),'WV:TransferIncompatible')
            s=w.scientificState(); s.N2Function=@(z)2e-4+0*z;
            testCase.verifyError(@()w.coefficientStateForTransform(WVTransformFreeSurfaceBoussinesq(s)),'WV:TransferIncompatible')
            s=w.scientificState(); s.inertialF(:,1)=s.inertialF(:,1)+s.inertialF(:,2);
            testCase.verifyError(@()w.coefficientStateForTransform(WVTransformFreeSurfaceBoussinesq(s)),'WV:TransferModeMismatch')
            s=w.scientificState(); s.inertialModeNumber(2)=s.inertialModeNumber(1);
            testCase.verifyError(@()w.coefficientStateForTransform(WVTransformFreeSurfaceBoussinesq(s)),'WV:TransferIdentity')
            for parameter=["apvMu","waveFrequency"]
                s=w.scientificState(); s.(parameter)=2*s.(parameter);
                testCase.verifyError(@()w.coefficientStateForTransform(WVTransformFreeSurfaceBoussinesq(s)),'WV:TransferModeMismatch')
            end
            qg=newTransform("qg","constant");
            testCase.verifyError(@()w.coefficientStateForTransform(qg),'WV:TransferIncompatible')
            testCase.verifyError(@()w.coefficientStateForTransform(w,quadratureCount=65),'WV:TransferQuadrature')
            testCase.verifyEqual(w.coefficientState(),original)
        end
        function pureFamiliesAndStrictRequests(testCase)
            w=newTransform("boussinesq","exponential"); populate(w); initial=w.coefficientState();
            target=w.waveVortexTransformWithResolution([12 10 97]);
            for name=string(fieldnames(initial)).'
                clearState(w); w.(name)=initial.(name);
                [state,a]=w.coefficientStateForTransform(target); adopt(target,state);
                testCase.verifyLessThan(a.relativeFieldError,1e-7)
                testCase.verifyEqual(a.relativeFieldError,physicalDifference(w,target),AbsTol=2e-12)
                testCase.verifyEqual(a.discardedEnergy,0)
            end
            clearState(w); [~,a]=w.coefficientStateForTransform(target);
            testCase.verifyEqual([a.sourceEnergy a.targetEnergy a.errorEnergy a.relativeFieldError],[0 0 0 0])
            testCase.verifyError(@()w.coefficientStateForTransform(target,modeTolerance=1e-12),'WV:TransferModeMismatch')
            qg=newTransform("qg","exponential");
            testCase.verifyError(@()qg.waveVortexTransformWithResolution([8 8 65],apvModeCount=100),'IMBasisSet:InsufficientDiscreteSamples')
            testCase.verifyEqual(qg.apvModeCount,3)
        end
        function activeAndInactiveEndpointsSurviveTransfer(testCase)
            for type=["qg","boussinesq"]
                for endpoints=[Inf Inf;.02 Inf;Inf .03;.02 .03].'
                    w=newTransform(type,"constant",endpoints); populate(w);
                    [target,a]=w.waveVortexTransformWithResolution([10 8 81]);
                    testCase.verifyEqual(target.activeEndpoint,w.activeEndpoint)
                    testCase.verifySize(target.Ag_0,[length(w.activeEndpoint),length(target.klNonzero)])
                    testCase.verifyEqual(a.discardedEnergy,0)
                    testCase.verifyLessThan(physicalDifference(w,target),1e-7)
                end
            end
        end
        function forcingConversionIsExplicitAndAtomic(testCase)
            w=newTransform("boussinesq","exponential"); populate(w);
            [X,~,Z]=ndgrid(w.x,w.y,w.z);
            force=WVPrescribedBoussinesqSource(w,uRate=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),frequency=.0003,referenceTime=17,phase=.4);
            w.addForcing(force); target=w.waveVortexTransformWithResolution([12 10 97]);
            converted=target.forcing(1); [X,~,Z]=ndgrid(target.x,target.y,target.z);
            testCase.verifyEqual(converted.uRate,1e-7*cos(2*pi*X/target.Lx).*(1+Z/target.Lz),AbsTol=1e-17)
            testCase.verifyEqual([converted.frequency converted.referenceTime converted.phase],[.0003 17 .4])
            testCase.verifyTrue(converted.wvt==target)
            testCase.verifyTrue(force.wvt==w)
            s=w.scientificState(); s.Lxyz(1)=2*w.Lx;
            incompatible=WVTransformFreeSurfaceBoussinesq(s);
            testCase.verifyError(@()force.forcingWithResolutionOfTransform(incompatible),'WV:TransferIncompatible')
            % A newly constructed coarser registry cannot silently lose a forcing.
            [X,~,Z]=ndgrid(w.x,w.y,w.z);
            w.setForcing(WVPrescribedBoussinesqSource(w,uRate=1e-7*cos(4*pi*X/w.Lx).*(1+Z/w.Lz)));
            testCase.verifyError(@()w.waveVortexTransformWithResolution([4 4 65]),'WV:TransferForcing')
            w.setForcing(WVPrescribedBoussinesqSource(w,uRate=1e-7*cos(8*pi*X/w.Lx).*(1+Z/w.Lz)));
            testCase.verifyError(@()w.waveVortexTransformWithResolution([8 8 65]),'WV:TransferForcing')
            qg=newTransform("qg","constant"); populate(qg);
            force=WVTestForcing(qg,"unsupported",WVForcingType("QGSpatial"),uint8(200),1);
            qg.addForcing(force); state=qg.coefficientState(); registry=qg.forcing;
            testCase.verifyError(@()qg.waveVortexTransformWithResolution([10 8 81]),'WV:TransferForcing')
            testCase.verifyEqual(qg.coefficientState(),state)
            testCase.verifyTrue(all(qg.forcing==registry))
        end
        function transferredStateRestartsAndContinues(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            results=TestFreeSurfaceResolutionTransfer.runStudy(string(fixture.Folder));
            testCase.verifyLessThan(max(results.restartError),1e-12)
            testCase.verifyLessThan(max(results.relativeFieldError),1e-7)
        end
    end
    methods (Static)
        function results=runStudy(outputFolder)
            arguments (Input)
                outputFolder (1,1) string
            end
            if ~isfolder(outputFolder), mkdir(outputFolder); end
            rows=struct([]);
            for type=["qg","boussinesq"]
                for profile=["constant","exponential"]
                    w=newTransform(type,profile); populate(w);
                    if type=="qg"
                        w.addForcing(WVVerticalDiffusivity(w,kappa_z=1e-5));
                    else
                        [X,~,Z]=ndgrid(w.x,w.y,w.z);
                        w.addForcing(WVPrescribedBoussinesqSource(w,uRate=1e-7*cos(2*pi*X/w.Lx).*(1+Z/w.Lz),frequency=.0003,referenceTime=17,phase=.4));
                    end
                    [target,a]=w.waveVortexTransformWithResolution([12 10 97]);
                    [~,refined]=w.coefficientStateForTransform(target,quadratureCount=4*97+1);
                    control=WVModel(target); control.setupIntegrator(integratorType="fixed",deltaT=10);
                    control.integrateToTime(1634,shouldShowIntegrationDiagnostics=false); finalState=target.coefficientState();
                    checkpoint=w.waveVortexTransformWithResolution([12 10 97]);
                    m=WVModel(checkpoint); m.setupIntegrator(integratorType="fixed",deltaT=10);
                    key=type+"-"+profile; file=fullfile(outputFolder,key+".nc");
                    m.createNetCDFFileForModelOutput(char(file),outputInterval=100,shouldOverwriteExisting=true);
                    m.eulerianObservingSystem.addNetCDFOutputVariables('u','v','eta','ssh');
                    m.integrateToTime(1434,shouldShowIntegrationDiagnostics=false); m.closeNetCDFFile();
                    savedState=checkpoint.coefficientState();
                    save(fullfile(outputFolder,key+"-reference.mat"),'savedState','finalState');
                    continued=fullfile(outputFolder,key+"-continued.nc"); copyfile(file,continued);
                    resumed=WVModel.modelFromFile(char(continued)); closeFile=onCleanup(@()resumed.closeNetCDFFile());
                    assert(isequal(resumed.wvt.coefficientState(),savedState)); assert(resumed.wvt.t0==31);
                    resumed.setupIntegrator(integratorType="fixed",deltaT=10);
                    resumed.integrateToTime(1634,shouldShowIntegrationDiagnostics=false);
                    restartError=stateError(resumed.wvt.coefficientState(),finalState);
                    row=struct(model=type,profile=profile,sourceNz=65,targetNz=97,relativeFieldError=a.relativeFieldError,modeShapeError=a.maximumModeShapeError,discardedEnergy=a.discardedEnergy,quadratureDifference=abs(refined.relativeFieldError-a.relativeFieldError),restartError=restartError);
                    rows=[rows;row]; %#ok<AGROW>
                    clear closeFile
                end
            end
            results=struct2table(rows); writetable(results,fullfile(outputFolder,'issue-352-resolution-transfer.csv'));
        end
        function verifyRestartWithoutProvider(outputFolder)
            assert(isempty(which('IMSolverSpectral')),'The mode provider must be absent.')
            for type=["qg","boussinesq"]
                for profile=["constant","exponential"]
                    key=type+"-"+profile; ref=load(fullfile(outputFolder,key+"-reference.mat"));
                    m=WVModel.modelFromFile(char(fullfile(outputFolder,key+".nc"))); closeFile=onCleanup(@()m.closeNetCDFFile());
                    assert(isequal(m.wvt.coefficientState(),ref.savedState)); assert(m.wvt.t==1434 && m.wvt.t0==31);
                    m.setupIntegrator(integratorType="fixed",deltaT=10);
                    m.integrateToTime(1634,shouldShowIntegrationDiagnostics=false);
                    residual=stateError(m.wvt.coefficientState(),ref.finalState);
                    assert(residual<1e-12); fprintf('%s provider-free transfer continuation %.6g\n',key,residual);
                    clear closeFile
                end
            end
        end
    end
end

function w=newTransform(type,profile,endpoints)
if nargin<3, endpoints=[NaN NaN]; end
if profile=="constant", N2=@(z)1e-4+0*z; else, N2=@(z)1e-4*exp(2*z/700); end
args=namedargs2cell(struct(N2Function=N2,g0=endpoints(1),gd=endpoints(2),apvModeCount=3,mdaModeCount=2));
if type=="qg", w=WVTransformFreeSurfaceQG([1e5 1e5 1000],[8 8 65],args{:});
else, w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},shouldAntialias=true,waveModeCount=4,inertialModeCount=3); end
end
function populate(w)
w.t=1234; w.t0=31;
for name=string(fieldnames(w.coefficientState())).'
    a=w.(name); ordinal=reshape(1:numel(a),size(a)); scale=.002;
    if ismember(name,["Ag_q","Ag_0"]), scale=1e-8; end
    if name=="Amda", a=scale*cos(ordinal); else, a=scale*exp(1i*ordinal)./(1+ordinal); end
    w.(name)=a;
end
end
function clearState(w)
for name=string(fieldnames(w.coefficientState())).', w.(name)=zeros(size(w.(name))); end
end
function adopt(w,state)
for name=string(fieldnames(state)).', w.(name)=state.(name); end
end
function verifyCounts(testCase,source,target)
for name=["apvModeNumber","mdaModeNumber","activeEndpoint"]
    testCase.verifyEqual(target.(name),source.(name))
end
if isa(source,'WVTransformFreeSurfaceBoussinesq')
    testCase.verifyEqual(target.waveModeNumber,source.waveModeNumber)
    testCase.verifyEqual(target.inertialModeNumber,source.inertialModeNumber)
end
end
function error=stateError(actual,expected)
error=0;
for name=string(fieldnames(expected)).'
    error=max(error,norm(actual.(name)-expected.(name),'fro')/max(norm(expected.(name),'fro'),realmin));
end
end
function fields=spectralFields(w)
if isa(w,'WVTransformFreeSurfaceBoussinesq'), fields=w.reconstructSpectralState();
else
    [psi,eta]=w.reconstructSpectralState();
    fields=struct(u=-1i*w.l.'.*psi,v=1i*w.k.'.*psi,w=zeros(size(psi)),eta=eta,ssh=(w.f/w.g)*psi);
end
end
function [error,energy]=physicalDifference(source,target)
% Independent full-field reconstruction, including all family cross terms.
S=spectralFields(source); T=spectralFields(target);
if source.Nz>=target.Nz, grid=source.z; else, grid=target.z; end
rule=WVInternal.qgVerticalOperators(grid,4*max(source.Nz,target.Nz)+1);
Ps=WVInternal.qgVerticalInterpolation(source.z,rule.zQuadrature); Pt=WVInternal.qgVerticalInterpolation(target.z,rule.zQuadrature);
keys=union([source.kMode_wv,source.lMode_wv],[target.kMode_wv,target.lMode_wv],'rows');
[hasS,is]=ismember(keys,[source.kMode_wv,source.lMode_wv],'rows');
[hasT,it]=ismember(keys,[target.kMode_wv,target.lMode_wv],'rows');
factor=ones(1,size(keys,1)); factor(all(keys==0,2))=.5;
energy=0; difference=0;
for name=["u","v","w","eta","ssh"]
    if name=="ssh"
        s=zeros(1,size(keys,1)); t=s; s(:,hasS)=S.ssh(end,is(hasS)); t(:,hasT)=T.ssh(end,it(hasT)); metric=source.g*factor;
    else
        s=zeros(length(rule.zQuadrature),size(keys,1)); t=s;
        s(:,hasS)=Ps*S.(name)(:,is(hasS)); t(:,hasT)=Pt*T.(name)(:,it(hasT));
        metric=rule.quadratureWeights.*factor;
        if name=="eta", metric=metric.*source.N2Function(rule.zQuadrature); end
    end
    energy=energy+sum(metric.*abs(s).^2,'all'); difference=difference+sum(metric.*abs(s-t).^2,'all');
end
error=sqrt(difference/max(energy,realmin));
end
