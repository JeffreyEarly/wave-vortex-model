classdef TestFreeSurfaceInitializationReuse < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function refinedCandidateMatchesIndependentFinalPair(testCase)
            N2=@(z)1e-4*exp(2*z/700);
            [w,a]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2);
            [control,b]=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2,nEVP=a.nEVP,referenceNEVP=a.referenceNEVP);
            testCase.verifyEqual([a.nEVP a.referenceNEVP],[104 156])
            testCase.verifyEqual(a.cost.waveEigensolves,3*(numel(w.khUnique)+1))
            testCase.verifyEqual(rmfield(w.scientificState(),{'N2Function','rhoFunction'}),rmfield(control.scientificState(),{'N2Function','rhoFunction'}))
            testCase.verifyEqual(withoutAssessmentTimers(rmfield(a,'cost')),withoutAssessmentTimers(rmfield(b,'cost')))
        end

        function reusedVariableAndZeroPagesMatchFreshSolves(testCase)
            w=makeTransform();
            state=w.scientificState();
            state.waveModeCountByKh=mod((1:numel(w.khUnique)).',4);
            options=waveOptions(w);
            [fresh,bases,solves]=WVInternal.buildFreeSurfaceWaveState(state,options);
            [reused,~,reuseSolves]=WVInternal.buildFreeSurfaceWaveState(state,options,bases);
            testCase.verifyEqual(reused,fresh)
            testCase.verifyEqual(solves,nnz(state.waveModeCountByKh)+1)
            testCase.verifyEqual(reuseSolves,0)
            reordered=IMBasisCollection(fliplr(bases.bases),kappa=bases.kappa,basisIndex=numel(bases.bases):-1:1);
            mapped=WVInternal.buildFreeSurfaceWaveState(state,options,reordered);
            testCase.verifyEqual(mapped,fresh)
            state.waveModeCountByKh(:)=0;
            [fresh,bases,solves]=WVInternal.buildFreeSurfaceWaveState(state,options);
            [reused,~,reuseSolves]=WVInternal.buildFreeSurfaceWaveState(state,options,bases);
            testCase.verifyEqual(reused,fresh)
            testCase.verifyEqual([solves reuseSolves],[1 0])
        end

        function incompatibleScientificConfigurationIsRejected(testCase)
            w=makeTransform(); state=w.scientificState(); options=waveOptions(w);
            [~,bases]=WVInternal.buildFreeSurfaceWaveState(state,options);
            for name=["nEVP","inertialModeCount","latitude","rotationRate","g"]
                changed=options; changed.(name)=changed.(name)+1;
                testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(state,changed,bases),'WV:IncompatibleWaveReference')
            end
            changed=state; changed.N2Function=@(z)2e-4+0*z;
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(changed,options,bases),'WV:IncompatibleWaveReference')
            changed=state; changed.Lxyz(3)=changed.Lxyz(3)+1;
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(changed,options,bases),'WV:IncompatibleWaveReference')
            changed=state; changed.khUnique(1)=changed.khUnique(1)+eps(changed.khUnique(1));
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(changed,options,bases),'WV:IncompatibleWaveReference')
            changed=state; changed.waveModeCountByKh(1)=1;
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(changed,options,bases),'WV:IncompatibleWaveReference')
            changed=state; changed.waveModeCountByKh(1)=0;
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(changed,options,bases),'WV:IncompatibleWaveReference')
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(state,options,struct()),'WV:IncompatibleWaveReference')
        end

        function normalizationCoordinatesAndBoundariesAreRejected(testCase)
            w=makeTransform(); state=w.scientificState(); options=waveOptions(w);
            [~,bases]=WVInternal.buildFreeSurfaceWaveState(state,options);
            entries=bases.bases; entries{1}.normalization="unity";
            changed=IMBasisCollection(entries,kappa=bases.kappa);
            testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(state,options,changed),'WV:IncompatibleWaveReference')
            for changedPart=["coordinate","surface","bottom"]
                coordinate="wkb"; surface=IMBoundaryCondition(a=0,b=1,c=1,d=0); bottom=IMBoundaryCondition.dirichlet();
                if changedPart=="coordinate", coordinate="z"; end
                if changedPart=="surface", surface=IMBoundaryCondition.dirichlet(); end
                if changedPart=="bottom", bottom=IMBoundaryCondition(a=0,b=1,c=1,d=0); end
                evp=IMInternalModes.waveModesAtWavenumber(N2=state.N2Function,zDomain=[-w.Lz 0],k=bases.kappa(2),f0=w.f,g=w.g,surfaceBoundary=surface,bottomBoundary=bottom);
                entries=bases.bases;
                entries{2}=IMSolverSpectral(nEVP=options.nEVP,coordinateKind=coordinate).solveEVP(evp,nModes=state.waveModeCountByKh(1));
                changed=IMBasisCollection(entries,kappa=bases.kappa);
                testCase.verifyError(@()WVInternal.buildFreeSurfaceWaveState(state,options,changed),'WV:IncompatibleWaveReference')
            end
        end
    end
end

function w=makeTransform()
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 8e4 1000],[8 6 33],N2Function=@(z)1e-4+0*z,waveModeCount=3,inertialModeCount=2,apvModeCount=3,mdaModeCount=2);
end

function options=waveOptions(w)
options=struct(nEVP=w.nEVP,inertialModeCount=numel(w.inertialMode),latitude=w.latitude,rotationRate=w.rotationRate,g=w.g);
end

function value=withoutAssessmentTimers(value)
% Only elapsed assessment time varies inside the scientific reports.
if isstruct(value)
    if isfield(value,'assessmentSeconds'), value=rmfield(value,'assessmentSeconds'); end
    for i=1:numel(value)
        for name=string(fieldnames(value)).'
            value(i).(name)=withoutAssessmentTimers(value(i).(name));
        end
    end
elseif iscell(value)
    value=cellfun(@withoutAssessmentTimers,value,UniformOutput=false);
elseif istable(value)
    for name=string(value.Properties.VariableNames)
        value.(name)=withoutAssessmentTimers(value.(name));
    end
end
end
