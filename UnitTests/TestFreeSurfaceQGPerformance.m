classdef TestFreeSurfaceQGPerformance < matlab.unittest.TestCase
    % Check the optimized paths against physical reconstructions and budgets.
    methods (Test, TestTags="full")
        function endpointPlanesMatchPaddedTransformsAndFollowState(testCase)
            for endpoints=[Inf Inf;-.1 Inf;Inf .1;-.1 .1].'
                for antialias=[true false]
                    w=WVTransformFreeSurfaceQG([100e3 120e3 1000],[8 12 33],N2Function=@(z)1e-4*ones(size(z)), ...
                        g0=endpoints(1),gd=endpoints(2),mdaGramTolerance=.1,shouldAntialias=antialias);
                    state=TestFreeSurfaceQGPerformance.mixedState(w);
                    for multiplier=[1 -2]
                        w.Ag_q=multiplier*state.Ag_q; w.Ag_0=multiplier*state.Ag_0; w.Amda=state.Amda;
                        [q,u,v,b,ub,vb,phiHat]=w.quasigeostrophicSpatialState();
                        [psi,~,qHat]=w.reconstructSpectralState();
                        testCase.verifyEqual(phiHat,psi(:,w.klNonzero))
                        testCase.verifyEqual(q,w.transformToSpatialDomainWithFourier(qHat))
                        testCase.verifyEqual(u,w.u)
                        testCase.verifyEqual(v,w.v)
                        [~,endpointsHat]=w.transformStateBack(w.Ag_q,w.Ag_0);
                        padded=complex(zeros(w.Nz,w.Nkl));
                        padded(1:w.activeEndpointCount,w.klNonzero)=endpointsHat;
                        expected=w.transformToSpatialDomainWithFourier(padded);
                        testCase.verifyEqual(b,expected(:,:,1:w.activeEndpointCount))
                        iz=[w.Nz 1]; iz=iz(w.activeEndpoint);
                        testCase.verifyEqual(ub,u(:,:,iz))
                        testCase.verifyEqual(vb,v(:,:,iz))
                        spatial=zeros(w.spatialMatrixSize); spatial(:,:,1:w.activeEndpointCount)=b;
                        projected=w.transformFromSpatialDomainWithFourier(spatial);
                        interior=w.transformFromSpatialDomainWithFourier(q);
                        [expectedQ,expectedZero]=w.transformStateForward(interior(:,w.klNonzero),projected(1:w.activeEndpointCount,w.klNonzero));
                        actual=w.projectQuasigeostrophicSpatialTendency(q,b);
                        testCase.verifyEqual(actual.Ag_q,expectedQ)
                        testCase.verifyEqual(actual.Ag_0,expectedZero)
                    end
                end
            end
        end

        function dragUsesSuppliedSpectrumWithoutReconstruction(testCase)
            w=TestFreeSurfaceQGPerformance.transform(); w.removeAllForcing();
            state=TestFreeSurfaceQGPerformance.mixedState(w);
            w.Ag_q=state.Ag_q; w.Ag_0=state.Ag_0;
            force=WVBottomFrictionQuadratic(w); w.addForcing(force);
            blank=struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda)));
            [~,~,~,~,~,~,phiHat]=w.quasigeostrophicSpatialState();
            direct=force.addQuasigeostrophicSpectralForcing(w,blank);
            w.Ag_q(:)=0; w.Ag_0(:)=0;
            supplied=force.addQuasigeostrophicSpectralForcing(w,blank,struct(phiHat=phiHat));
            testCase.verifyEqual(supplied,direct)
            testCase.verifyGreaterThan(norm(supplied.Ag_q,'fro'),0)
            w.Ag_q=state.Ag_q; w.Ag_0=state.Ag_0;
            profile clear; profile on
            cleanup=onCleanup(@()profile('off'));
            actual=w.coefficientTendency();
            profile off; info=profile('info'); clear cleanup
            entry=info.FunctionTable(strcmp({info.FunctionTable.FunctionName},'WVTransformFreeSurfaceQG.reconstructSpectralState'));
            testCase.verifyEqual(entry.NumCalls,1)
            testCase.verifyEqual(actual,direct)
        end

        function batchedBudgetsMatchEachDirectionalDerivative(testCase)
            w=TestFreeSurfaceQGPerformance.transform();
            state=TestFreeSurfaceQGPerformance.mixedState(w);
            first=struct(Ag_q=.3*state.Ag_q+1e-9,Ag_0=-.2*state.Ag_0,Amda=cos((1:w.mdaModeCount).')*.01);
            second=struct(Ag_q=-first.Ag_q,Ag_0=2i*first.Ag_0,Amda=-first.Amda);
            zero=struct(Ag_q=zeros(size(w.Ag_q)),Ag_0=zeros(size(w.Ag_0)),Amda=zeros(size(w.Amda)));
            tendencies=[first second zero];
            [batch,spectrum]=w.quadraticDiagnostics(state=state,tendency=tendencies);
            inventory=w.quadraticDiagnostics(state=state);
            for name=["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "potentialEnstrophy" "totalEnergy"]
                testCase.verifyEqual(batch.(name),inventory.(name))
                testCase.verifySize(batch.(name+"Tendency"),[3 1])
                testCase.verifySize(spectrum.(name+"Tendency"),[3 length(w.klNonzero)])
                testCase.verifyEqual(batch.(name+"Tendency")(3),0)
            end
            for k=1:length(tendencies)
                [single,byWavenumber]=w.quadraticDiagnostics(state=state,tendency=tendencies(k));
                plus=state; minus=state; h=1e-4;
                for name=["Ag_q" "Ag_0" "Amda"]
                    plus.(name)=state.(name)+h*tendencies(k).(name);
                    minus.(name)=state.(name)-h*tendencies(k).(name);
                end
                dp=w.quadraticDiagnostics(state=plus); dm=w.quadraticDiagnostics(state=minus);
                for name=["kineticEnergy" "interiorPotentialEnergy" "surfacePotentialEnergy" "potentialEnstrophy" "totalEnergy"]
                    testCase.verifyEqual(batch.(name+"Tendency")(k),single.(name+"Tendency"),RelTol=1e-12,AbsTol=1e-25)
                    testCase.verifyEqual(spectrum.(name+"Tendency")(k,:),byWavenumber.(name+"Tendency"),RelTol=1e-12,AbsTol=1e-25)
                    testCase.verifyEqual(batch.(name+"Tendency")(k),(dp.(name)-dm.(name))/(2*h),RelTol=1e-7,AbsTol=1e-20)
                end
            end
            malformed=tendencies; malformed(2).Amda=NaN(size(w.Amda));
            testCase.verifyError(@()w.quadraticDiagnostics(state=state,tendency=malformed),'WVTransformFreeSurfaceQG:InvalidCoefficient')
        end

        function positiveNormFactorsMatchQuadratureIncludingNullAndStiffStates(testCase)
            for kappa=[0 1e-5]
                w=TestFreeSurfaceQGPerformance.transform(); w.removeAllForcing();
                w.addForcing(WVVerticalDiffusivity(w,kappa_z=kappa));
                e=WVDensityDiffusionIntegrator(w);
                state=TestFreeSurfaceQGPerformance.mixedState(w);
                full=e.toModes(state);
                candidates={full,full*1e-12,zeros(size(full))};
                for family=["Ag_q" "Ag_0" "Amda"]
                    single=state;
                    for other=setdiff(["Ag_q" "Ag_0" "Amda"],family), single.(other)(:)=0; end
                    candidates{end+1}=e.toModes(single); %#ok<AGROW>
                end
                stiff=zeros(size(full)); [~,index]=min(e.rates); stiff(index)=1e-7;
                neutral=zeros(size(full)); [~,index]=min(abs(e.rates)); neutral(index)=1e-7;
                candidates=[candidates,{stiff,neutral,full-(1-1e-10)*full}]; %#ok<AGROW>
                scale=TestFreeSurfaceQGPerformance.quadratureNorms(e,full);
                for k=1:length(candidates)
                    a=candidates{k};
                    expected=TestFreeSurfaceQGPerformance.quadratureNorms(e,a);
                    actual=e.physicalErrorNorms(a);
                    % The absolute bound covers roundoff in nearly null fields.
                    testCase.verifyLessThanOrEqual(abs(actual-expected),2e-10*expected+2e-14*scale*norm(a)/norm(full))
                    testCase.verifyGreaterThanOrEqual(actual,zeros(1,4))
                end
                testCase.verifyEqual(e.physicalErrorNorms(zeros(size(full))),zeros(1,4))
                testCase.verifyError(@()e.physicalErrorNorms(full.'),'WV:DensityDiffusionState')
                invalid=full; invalid(1)=NaN;
                testCase.verifyError(@()e.physicalErrorNorms(invalid),'WV:DensityDiffusionState')
                invalid=full; invalid(end)=1i;
                testCase.verifyError(@()e.physicalErrorNorms(invalid),'WV:DensityDiffusionMeanReality')
            end
        end

        function normFactorsAreLazyAndRecreatedWithDiffusionOperators(testCase)
            w=TestFreeSurfaceQGPerformance.transform(); w.removeAllForcing();
            force=WVVerticalDiffusivity(w,kappa_z=1e-5); w.addForcing(force);
            e=WVDensityDiffusionIntegrator(w); a=e.toModes(TestFreeSurfaceQGPerformance.mixedState(w));
            profile clear; profile on
            cleanup=onCleanup(@()profile('off'));
            expected=e.physicalErrorNorms(a);
            w.t=123; e.setModalState(2*a);
            testCase.verifyEqual(e.physicalErrorNorms(a),expected)
            profile off; info=profile('info'); clear cleanup
            selected=contains(string({info.FunctionTable.FunctionName}),'buildPhysicalNormFactors');
            testCase.verifyEqual(sum([info.FunctionTable(selected).NumCalls]),1)
            force.kappa_z=2e-5;
            other=WVDensityDiffusionIntegrator(w); b=other.modalState();
            testCase.verifyEqual(other.physicalErrorNorms(b),TestFreeSurfaceQGPerformance.quadratureNorms(other,b),RelTol=1e-10)
            force.shouldForceMeanDensityAnomaly=false;
            disabled=WVDensityDiffusionIntegrator(w); b=disabled.modalState();
            testCase.verifyEqual(disabled.physicalErrorNorms(b),TestFreeSurfaceQGPerformance.quadratureNorms(disabled,b),RelTol=1e-10)
        end

        function seasonalSupportMatchesFullRatesAndTracksReplacement(testCase)
            for kappa=[0 1e-5]
                w=TestFreeSurfaceQGPerformance.transform(); w.removeAllForcing();
                w.addForcing(WVVerticalDiffusivity(w,kappa_z=kappa));
                e=WVDensityDiffusionIntegrator(w);
                for amplitude=[1e-7 0 -2e-7]
                    if any(w.forcingNames()=="seasonal surface anomaly"), w.removeForcing(force); end
                    pattern=repmat(sin(2*pi*w.y.'/w.Ly),w.Nx,1);
                    pattern=pattern+1e-15*repmat(cos(2*pi*w.x/w.Lx),1,w.Ny);
                    force=WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=amplitude,phase=.3);
                    w.addForcing(force);
                    Fb=zeros(w.Nx,w.Ny,2); Fb(:,:,1)=amplitude*pattern;
                    source=e.toModes(w.projectQuasigeostrophicSpatialTendency(zeros(w.spatialMatrixSize),Fb));
                    for t=[0 86400 .25*force.period 3*force.period]
                        omega=2*pi/force.period;
                        plus=TestFreeSurfaceQGPerformance.harmonic(e.rates,omega,t);
                        minus=TestFreeSurfaceQGPerformance.harmonic(e.rates,-omega,t);
                        expected=source.*((exp(1i*force.phase)*plus-exp(-1i*force.phase)*minus)/(2i));
                        testCase.verifyEqual(e.seasonalCoefficients(t),expected)
                    end
                end
                w.removeForcing(force);
                testCase.verifyEqual(e.seasonalCoefficients(86400),complex(zeros(size(e.rates))))
            end
        end
    end
    methods (Static, Access=private)
        function w=transform()
            w=WVTransformFreeSurfaceQG([500e3 500e3 4000],[8 8 65],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300));
        end
        function state=mixedState(w)
            q=reshape(sin(1:numel(w.Ag_q))+1i*cos((1:numel(w.Ag_q))/3),size(w.Ag_q))*1e-9;
            b=reshape(cos(1:numel(w.Ag_0))+1i*sin((1:numel(w.Ag_0))/3),size(w.Ag_0))*1e-12;
            state=struct(Ag_q=q,Ag_0=b,Amda=.01*cos((1:w.mdaModeCount).'));
        end
        function values=quadratureNorms(e,a)
            % Original physical quadrature, independent of the cached QR factors.
            state=e.fromModes(a); balanced=[state.Ag_q;state.Ag_0];
            weights=e.operators.weights/e.wvt.Lz; variance=zeros(1,4);
            for p=1:length(e.wvt.khUnique)
                columns=e.wvt.klNonzeroKhUniqueIndex==p; r=e.operators.reconstruction{p}; b=balanced(:,columns);
                variance=variance+2*[sum(weights.*abs(r.q*b).^2,'all'),sum(weights.*abs(r.buoyancy*b).^2,'all'), ...
                    e.wvt.khUnique(p)^2*sum(weights.*abs(r.phi*b).^2,'all'),sum(abs(r.endpoint*b).^2,'all')];
            end
            r=e.operators.mda.reconstruction; b=state.Amda;
            variance=variance+[sum(weights.*abs(r.q*b).^2),sum(weights.*abs(r.buoyancy*b).^2),0,sum(abs(r.endpoint*b).^2)];
            values=sqrt(variance);
        end
        function value=harmonic(lambda,omega,t)
            z=(lambda-1i*omega)*t;
            ratio=ones(size(z)); nonzero=z~=0;
            ratio(nonzero)=expm1(z(nonzero))./z(nonzero);
            value=t*exp(1i*omega*t).*ratio;
        end
    end
end
