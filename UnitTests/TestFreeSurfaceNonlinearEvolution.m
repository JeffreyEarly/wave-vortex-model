classdef TestFreeSurfaceNonlinearEvolution < matlab.unittest.TestCase
    methods (TestClassSetup)
        function studyHelpers(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'tools','nonlinear-study')));
        end
    end
    methods (Test, TestTags="full")
        function explicitActivationUsesCoupledStageAndPreservesLinearDefault(testCase)
            w=fixture(); original=w.coefficientState();
            testCase.verifyEmpty(w.forcing)
            rate=w.coefficientTendency();
            for name=string(fieldnames(rate)).', testCase.verifyEqual(rate.(name),zeros(size(rate.(name)))); end
            context=WVInternal.freeSurfaceNonlinearStage(w);
            [expected,report,stage]=context.evaluate();
            w.addForcing(WVNonlinearAdvection(w));
            [actual,speed,diagnostics]=w.coefficientTendency();
            layout=WVInternal.freeSurfaceRealCoefficientLayout(w);
            testCase.verifyLessThan(norm(layout.pack(actual)-layout.pack(expected))/norm(layout.pack(expected)),2e-8)
            testCase.verifyEqual(speed,max(hypot(stage.physical.u,stage.physical.v),[],'all'))
            testCase.verifyEqual(diagnostics.totalEnergy,report.totalEnergy)
            testCase.verifyLessThan(diagnostics.solver.relativeResidual,5e-10)
            testCase.verifyEqual(w.coefficientState(),original)
            flux=w.fluxForForcing();
            testCase.verifyEqual(flux{"nonlinear advection"},actual)
            w.removeForcing("nonlinear advection");
            rate=w.coefficientTendency();
            for name=string(fieldnames(rate)).', testCase.verifyEqual(rate.(name),zeros(size(rate.(name)))); end
            testCase.verifyEqual(w.coefficientState(),original)
        end

        function physicalForcingWorkAndEndpointResponsesUseTheSameMetric(testCase)
            w=fixture(); w.addForcing(WVNonlinearAdvection(w));
            unforced=w.coefficientTendency();
            [X,Y,Z]=ndgrid(w.x,w.y,w.z);
            source=WVPrescribedBoussinesqSource(w,uRate=1e-7*(1+Z/w.Lz).*cos(2*pi*X/w.Lx),vRate=2e-7*(Z/w.Lz).^2.*sin(2*pi*Y/w.Ly),wRate=3e-8*(1+Z/w.Lz).^2,etaRate=1e-6*(1+.1*cos(2*pi*X/w.Lx)).*(1+Z/(2*w.Lz)),sourceCoordinates="physical",frequency=.003,referenceTime=29,phase=.4);
            w.addForcing(source);
            [rate,~,diagnostics]=w.coefficientTendency();
            flux=w.fluxForForcing(); response=flux{string(source.name)};
            total=flux{"nonlinear advection"};
            for name=string(fieldnames(rate)).', total.(name)=total.(name)+response.(name); end
            testCase.verifyEqual(total,rate)
            layout=WVInternal.freeSurfaceRealCoefficientLayout(w);
            testCase.verifyLessThan(norm(layout.pack(flux{"nonlinear advection"})-layout.pack(unforced))/norm(layout.pack(unforced)),2e-8)
            f=w.reconstructFields(["u","v","w","eta","ssh"]);
            scale=cos(source.frequency*(w.t-source.referenceTime)+source.phase);
            weights=reshape(w.verticalQuadratureWeights,1,1,[])/(w.Nx*w.Ny);
            gamma=1+f.ssh/w.Lz;
            expectedWork=sum(weights.*gamma.*scale.*(f.u.*source.uRate+f.v.*source.vRate+f.w.*source.wRate+1e-4*f.eta.*source.etaRate),'all');
            testCase.verifyEqual(diagnostics.prescribedWork,expectedWork,AbsTol=2e-16)
            boundary=WVInternal.freeSurfaceBoundaryOperator(w);
            targets=struct(ssh=zeros(w.Nx,w.Ny),surface=scale*source.etaRate(:,:,end),bottom=scale*source.etaRate(:,:,1));
            testCase.verifyEqual(boundary.apply(response),boundary.projectTarget(targets),AbsTol=2e-14)
            % The coefficient response's instantaneous full energy rate is
            % independently differenced at fixed clocks and fixed SSH target.
            original=w.coefficientState(); epsilon=.01;
            values=zeros(2,1);
            for i=1:2
                sign=3-2*i;
                for name=string(fieldnames(original)).', w.(name)=original.(name)+sign*epsilon*response.(name); end
                values(i)=w.nonlinearEnergy().totalEnergy;
            end
            for name=string(fieldnames(original)).', w.(name)=original.(name); end
            measuredWork=(values(1)-values(2))/(2*epsilon);
            % Finite-dimensional endpoint constraints can react against the
            % imposed source. Compute that reaction independently at the
            % shared metric; do not assert imposed work alone is conserved.
            ctx=WVInternal.freeSurfaceNonlinearStage(w);
            [~,forcedReport]=ctx.evaluate(w.coefficientState(),includeForcing=true);
            w.removeForcing(source);
            [~,unforcedReport]=ctx.evaluate(w.coefficientState(),includeForcing=true);
            reaction=forcedReport.constraintReactionWork-unforcedReport.constraintReactionWork;
            testCase.verifyEqual(measuredWork,expectedWork+reaction,AbsTol=2e-10)
        end
    end
end

function w=fixture()
w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=@(z)1e-4+0*z,apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,nEVP=128,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
helper=freeSurfaceWeakStudyHelpers(); state=helper.seedState(w);
x=find(w.kNonzero>0 & w.lNonzero==0,1); y=find(w.kNonzero==0 & w.lNonzero>0,1);
state.Aw_p(1,y)=.3*exp(.41i)*state.Aw_p(1,x); state.Aw_m=.2*exp(.63i)*state.Aw_p;
for name=string(fieldnames(state)).', w.(name)=state.(name); end
w.t=327; w.t0=-17;
end
