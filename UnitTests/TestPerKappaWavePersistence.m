classdef TestPerKappaWavePersistence < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function storedOperatorsAndCountsRoundTrip(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for zeroWaves=[false true]
                w=makeTransform(zeroWaves); populate(w);
                file=fullfile(fixture.Folder,sprintf('state-%d.nc',zeroWaves));
                nc=w.writeToFile(file,shouldOverwriteExisting=true); nc.close();
                [restored,nc]=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
                cleanup=onCleanup(@()nc.close());
                before=w.scientificState(); after=restored.scientificState();
                for name=string(fieldnames(before)).'
                    if isa(before.(name),'function_handle')
                        testCase.verifyEqual(after.(name)(w.z),before.(name)(w.z))
                    else
                        testCase.verifyEqual(after.(name),before.(name))
                    end
                end
                verifyState(testCase,restored.coefficientState(),w.coefficientState());
                testCase.verifyEqual([restored.t restored.t0],[w.t w.t0])
                testCase.verifyEqual(nc.hasDimensionWithName('waveMode'),~zeroWaves)
                testCase.verifyEqual(nc.hasVariableWithName('Aw_p'),~zeroWaves)
                testCase.verifyEqual(restored.reconstructFields(["u","v","w","eta","ssh"]),w.reconstructFields(["u","v","w","eta","ssh"]))
                clear cleanup
            end
        end

        function legacyUniformFileDefaultsToFullPrefixes(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
            populate(w);
            file=fullfile(fixture.Folder,'legacy-uniform.nc');
            properties=setdiff(w.requiredProperties,{'waveModeCountByKh'});
            nc=w.writeToFile(file,properties{:},shouldAddRequiredProperties=false);
            testCase.verifyFalse(nc.hasVariableWithName('waveModeCountByKh'))
            nc.close();
            restored=WVTransformFreeSurfaceBoussinesq.waveVortexTransformFromFile(file);
            testCase.verifyEqual(restored.waveModeCountByKh,repmat(length(w.waveMode),size(w.khUnique)))
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState())
        end

        function countTransferAccountsForDiscardedModes(testCase)
            w=makeTransform(false); populate(w);
            original=w.coefficientState();
            [fine,a]=w.waveVortexTransformWithResolution([8 8 97]);
            testCase.verifyEqual(fine.waveModeCountByKh,w.waveModeCountByKh)
            testCase.verifyEqual(a.discardedEnergy,0)
            testCase.verifyLessThan(a.relativeFieldError,1e-7)
            counts=max(w.waveModeCountByKh-1,0);
            [coarse,a]=w.waveVortexTransformWithResolution([8 8 65],waveModeKappa=w.khUnique,waveModeCount=counts);
            testCase.verifyEqual(coarse.waveModeCountByKh,counts)
            testCase.verifyGreaterThan(a.discardedEnergy,0)
            lost=WVTransformFreeSurfaceBoussinesq(w.scientificState());
            lost.t=w.t; lost.t0=w.t0;
            for family=["Aw_p","Aw_m"]
                values=w.(family);
                for c=1:length(w.klNonzero)
                    values(1:counts(w.klNonzeroKhUniqueIndex(c)),c)=0;
                end
                lost.(family)=values;
            end
            energy=lost.physicalEnergy();
            testCase.verifyEqual(a.discardedEnergy,energy.totalEnergy,RelTol=1e-8)
            testCase.verifyEqual(coarse.Aw_p(~coarse.activeWaveModes),zeros(nnz(~coarse.activeWaveModes),1))
            [expanded,b]=coarse.waveVortexTransformWithResolution([8 8 65],waveModeKappa=w.khUnique,waveModeCount=w.waveModeCountByKh);
            testCase.verifyEqual(b.discardedEnergy,0)
            newModes=expanded.waveMode>counts(expanded.klNonzeroKhUniqueIndex).';
            testCase.verifyEqual(expanded.Aw_p(newModes),zeros(nnz(newModes),1))
            testCase.verifyEqual(w.coefficientState(),original)
        end

        function horizontalRefinementNeedsNewCounts(testCase)
            w=makeTransform(false); populate(w);
            testCase.verifyError(@()w.waveVortexTransformWithResolution([12 10 65]),'WV:TransferWaveCountMap')
            [coarse,a]=w.waveVortexTransformWithResolution([6 6 65]);
            for p=1:length(coarse.khUnique)
                [~,i]=min(abs(w.khUnique-coarse.khUnique(p)));
                testCase.verifyEqual(coarse.waveModeCountByKh(p),w.waveModeCountByKh(i))
            end
            testCase.verifyGreaterThan(a.discardedEnergy,0)
            [uniform,~]=w.waveVortexTransformWithResolution([12 10 65],waveModeCount=4);
            testCase.verifyEqual(uniform.waveModeCountByKh,4*ones(size(uniform.khUnique)))
        end

        function modelOutputRestartsWithInactiveStorage(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for zeroWaves=[false true]
                w=makeTransform(zeroWaves); populate(w);
                [X,~,Z]=ndgrid(w.x,w.y,w.z);
                w.addForcing(WVPrescribedBoussinesqSource(w,uRate=1e-8*cos(2*pi*X/w.Lx).*(1+Z/w.Lz)));
                control=WVModel(w.waveVortexTransformWithResolution([8 8 65]));
                control.setupIntegrator(integratorType="fixed",deltaT=10);
                control.integrateToTime(180,shouldShowIntegrationDiagnostics=false);
                model=WVModel(w); model.setupIntegrator(integratorType="fixed",deltaT=10);
                file=fullfile(fixture.Folder,sprintf('model-%d.nc',zeroWaves));
                model.createNetCDFFileForModelOutput(file,outputInterval=10,shouldOverwriteExisting=true);
                model.eulerianObservingSystem.addNetCDFOutputVariables('u','w','ssh');
                model.integrateToTime(140,shouldShowIntegrationDiagnostics=false);
                saved=w.coefficientState(); model.closeNetCDFFile();
                resumed=WVModel.modelFromFile(file); cleanup=onCleanup(@()resumed.closeNetCDFFile());
                verifyState(testCase,resumed.wvt.coefficientState(),saved);
                testCase.verifyEqual(resumed.wvt.waveModeCountByKh,w.waveModeCountByKh)
                resumed.setupIntegrator(integratorType="fixed",deltaT=10);
                resumed.integrateToTime(180,shouldShowIntegrationDiagnostics=false);
                actual=resumed.wvt.coefficientState(); expected=control.wvt.coefficientState();
                for name=string(fieldnames(actual)).'
                    testCase.verifyEqual(actual.(name),expected.(name),AbsTol=1e-14)
                end
                testCase.verifyEqual(w.Aw_p(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
                clear cleanup
            end
        end
    end
end

function verifyState(testCase,actual,expected)
for name=string(fieldnames(expected)).'
    testCase.verifyEqual(real(actual.(name)),real(expected.(name)))
    testCase.verifyEqual(imag(actual.(name)),imag(expected.(name)))
end
end

function w=makeTransform(zeroWaves)
Lxyz=[1e5 1e5 1000]; Nxyz=[8 8 65]; N2=@(z)1e-4+0*z;
base=WVTransformFreeSurfaceBoussinesq.fromStratification(Lxyz,Nxyz,N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=4,inertialModeCount=3);
counts=mod((1:length(base.khUnique)).',5);
if zeroWaves, counts(:)=0; end
w=WVTransformFreeSurfaceBoussinesq.fromStratification(Lxyz,Nxyz,N2Function=N2,waveModeKappa=base.khUnique,waveModeCount=counts,inertialModeCount=2,apvModeCount=3,mdaModeCount=2);
end

function populate(w)
w.t=100; w.t0=17;
for name=string(fieldnames(w.coefficientState())).'
    values=w.(name); index=reshape(1:numel(values),size(values));
    scale=.002; if ismember(name,["Ag_q","Ag_0"]), scale=1e-9; end
    values=scale*exp(1i*index)./(1+index);
    if ismember(name,["Aw_p","Aw_m"]), values=complex(values); values(~w.activeWaveModes)=0; end
    if name=="Amda", values=real(values); end
    w.(name)=values;
end
end
