classdef TestFreeSurfaceQGDiffusionQualification < matlab.unittest.TestCase
    % Independent physical-depth qualification of two-active-boundary diffusion.
    % runStudy reports numerical errors without a universal acceptance threshold.
    methods (Test, TestTags="full")
        function endpointEvolutionIdentifiesCancellation(testCase)
            folder=string(tempname); mkdir(folder);
            cleanup=onCleanup(@()rmdir(folder,'s'));
            result=TestFreeSurfaceQGDiffusionQualification.runEndpointEvolutionStudy(folder,bands=[433 865 1297],days=64,quadratureCount=4097,referenceCount=257);
            r=result.rows; bottom=r(r.endpoint=="bottom",:);
            % An isolated surface source has no direct bottom action. Its
            % bottom response is accumulated diffusion, including sign.
            testCase.verifyLessThan(max(abs(bottom.sourceTendency)),1e-20)
            testCase.verifyLessThan(max(abs(bottom.state-bottom.diffusionIntegral)),1e-9)
            testCase.verifyLessThan(max(abs(r.referenceBudgetResidual)),1e-8)
            surface=r(r.endpoint=="surface",:); omega=2*pi/(365.25*86400);
            testCase.verifyEqual(surface.sourceIntegral,5*(1-cos(omega*64*86400))*ones(3,1),AbsTol=1e-8)
            % The favorable 865-mode error is not monotone band convergence.
            error=abs(bottom.state-bottom.referenceState);
            testCase.verifyLessThan(error(2),error(1)/10)
            testCase.verifyLessThan(error(2),error(3)/5)
            testCase.verifyLessThan(bottom.representationError(2),-1e-5)
            testCase.verifyGreaterThan(bottom.evolutionError(2),1e-5)
            testCase.verifyLessThan(max(abs(r.decompositionResidual)),1e-10)
            % Missing surface-layer gradients dominate the bottom action of
            % the projected-reference operator residual at this time.
            testCase.verifyGreaterThan(bottom.surfaceLayerGradientResidual,.9*bottom.operatorResidualTendencyError)
            testCase.verifyLessThan(max(abs(bottom.referenceWeakResidual)),1e-15)
        end
        function independentEndpointsHaveSeparateReferenceAllowances(testCase)
            D=4000; scale=1300; f=2*7.2921e-5*sind(24); T=365.25*86400;
            [z,weights]=studyGrid(1025,D);
            N2=@(z)(5.2e-3)^2*exp(2*z/scale);
            a=reference(257,z,weights,D,N2,scale,2*pi/100e3,f,9.81,1e-5);
            b=reference(385,z,weights,D,N2,scale,2*pi/100e3,f,9.81,1e-5);
            for time=[64*86400 T/4]
                ac=10*pi/T*response(a.A,a.source,2*pi/T,time);
                bc=10*pi/T*response(b.A,b.source,2*pi/T,time);
                r=studyComparison(studyState(a,ac),studyState(b,bc),weights,D,"reference",257,385,time/86400);
                % Each endpoint has its own absolute-plus-relative allowance;
                % a large surface signal cannot mask a bottom discrepancy.
                testCase.verifyTrue(all(r.withinTolerance))
                testCase.verifyLessThan(r.referenceMagnitude(r.observable=="bottomAnomaly"),1e-3)
            end
        end
        function publicEstimatesAgreeWithIndependentFields(testCase)
            for scale = [Inf 1300]
                w = newTransform(33,scale);
                coarse = newTransform(65,scale);
                fine = newTransform(129,scale);
                f = WVSeasonalSurfaceAnomalyForcing(w,pattern=cos(2*pi*w.Y(:,:,1)/w.Ly),amplitude=1e-7);
                closure = WVVerticalDiffusivity(w,kappa_z=1e-5);
                time = f.period/4;
                actual = closure.assessSeasonalResponse(f,time,referenceTransforms={coarse,fine});
                [z,weights] = gauss(513,w.Lz);
                [~,p] = min(abs(w.khUnique-2*pi/w.Ly));
                [a,ap,as] = modelPage(w,p,z,weights,scale,1e-5);
                [b,bp,bs] = modelPage(fine,p,z,weights,scale,1e-5);
                ac = ap.fromEnergy*response(ap.energyGenerator,ap.toEnergy*as,2*pi/f.period,time)*f.amplitude;
                bc = bp.fromEnergy*response(bp.energyGenerator,bp.toEnergy*bs,2*pi/f.period,time)*f.amplitude;
                ad = ap.generator*ac+f.amplitude*as;
                bd = bp.generator*bc+f.amplitude*bs;
                expectedQ = sqrt(sum(weights.*abs(a.q*ac-b.q*bc).^2)/(2*w.Lz));
                expectedB = sqrt(sum(weights.*abs(a.b*ac-b.b*bc).^2)/(2*w.Lz));
                expectedEnergy = abs(norm(a.energy*ac)^2-norm(b.energy*bc)^2)/4;
                expectedEnergyRate = abs(real((a.energy*ac)'*(a.energy*ad)-(b.energy*bc)'*(b.energy*bd)))/2;
                testCase.verifyEqual(actual.total.absolute.qgpv,expectedQ,RelTol=2e-4)
                testCase.verifyEqual(actual.total.absolute.buoyancy,expectedB,RelTol=2e-4)
                testCase.verifyEqual(actual.total.absolute.energy,expectedEnergy,RelTol=2e-3)
                testCase.verifyEqual(actual.total.absolute.energyTendency,expectedEnergyRate,RelTol=2e-3)
                % Independent integration count must not set the measured modal error.
                refined = closure.assessSeasonalResponse(f,time,referenceTransforms={coarse,fine},quadratureCount=513);
                testCase.verifyEqual(actual.total.absolute.qgpv,refined.total.absolute.qgpv,RelTol=1e-6)
                testCase.verifyLessThan(actual.configuration.stratificationRelativeDifference(1),1e-6)
            end
        end

        function independentReferenceConverges(testCase)
            [z,weights] = gauss(601,4000);
            f = 2*7.2921e-5*sind(24);
            kh = 2*pi/100e3;
            period = 365.25*86400;
            for scale = [Inf 1300]
                N2 = @(z)(5.2e-3)^2*exp(2*z/scale);
                coarse = reference(129,z,weights,4000,N2,scale,kh,f,9.81,1e-5);
                fine = reference(193,z,weights,4000,N2,scale,kh,f,9.81,1e-5);
                for fraction = [.25 .5 .75 1]
                    a = response(coarse.A,coarse.source,2*pi/period,fraction*period);
                    b = response(fine.A,fine.source,2*pi/period,fraction*period);
                    testCase.verifyLessThan(relative(coarse.b*a,fine.b*b,weights),1e-3)
                    testCase.verifyLessThan(relative(coarse.q*a,fine.q*b,weights),1e-3)
                    testCase.verifyLessThan(norm(coarse.endpoint*a-fine.endpoint*b)/norm(fine.endpoint*b),1e-3)
                    testCase.verifyLessThan(abs(norm(coarse.energy*a)^2/norm(fine.energy*b)^2-1),2e-3)
                    testCase.verifyLessThan(abs(sum(weights.*abs(coarse.q*a).^2)/sum(weights.*abs(fine.q*b).^2)-1),2e-3)
                end
                % A zero-PV inversion of a unit displacement source at each endpoint.
                for source = [fine.source,fine.bottomSource]
                    testCase.verifyLessThan(norm(fine.q*source)/(kh^2*norm(fine.phi*source)),1e-6)
                end
                testCase.verifyEqual(fine.endpoint*[fine.source,fine.bottomSource],eye(2),AbsTol=1e-6)
            end
        end

        function strictForcingHasZeroIndependentPV(testCase)
            for scale = [Inf 1300]
                w = newTransform(65,scale);
                w.removeAllForcing();
                period = 365.25*86400;
                pattern = cos(2*pi*w.Y(:,:,1)/w.Ly);
                forcing = WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=1e-7,period=period,phase=pi/2);
                w.addForcing(forcing);
                tendency = w.coefficientTendency();
                testCase.verifyEqual(tendency.Ag_q,zeros(size(w.Ag_q)),AbsTol=0)
                testCase.verifyEqual(tendency.Amda,zeros(size(w.Amda)),AbsTol=0)
                w.Ag_q = tendency.Ag_q;
                w.Ag_0 = tendency.Ag_0;
                [~,~,~,endpoint] = w.quasigeostrophicSpatialState();
                testCase.verifyEqual(endpoint(:,:,1),1e-7*pattern,AbsTol=1e-20)
                testCase.verifyEqual(endpoint(:,:,2),zeros(w.Nx,w.Ny),AbsTol=1e-20)
                [z,weights] = gauss(257,w.Lz);
                [~,p] = min(abs(w.khUnique-2*pi/w.Ly));
                [r,~,source] = modelPage(w,p,z,weights,scale,0);
                testCase.verifyLessThan(norm(r.q*source)/(w.khUnique(p)^2*norm(r.phi*source)),1e-6)
                testCase.verifyEqual(r.endpoint*source,[1;0],AbsTol=1e-6)
                % With diffusion disabled the exact sine integral multiplies this source.
                field = r.q*source*period/pi;
                testCase.verifyLessThan(norm(field)/(w.khUnique(p)^2*norm(r.phi*source)*period/pi),1e-6)
            end
        end

        function independentWeakAssemblyAndQuadratureAgree(testCase)
            for scale = [Inf 1300]
                w = newTransform(65,scale);
                closure = WVVerticalDiffusivity(w,kappa_z=1e-5);
                operators = closure.densityDiffusionOperators();
                [z,weights] = gauss(257,w.Lz);
                [zFine,weightsFine] = gauss(513,w.Lz);
                page = operators.pages{1};
                [r,~,~] = modelPage(w,1,z,weights,scale,1e-5);
                fine = sampled(r.nativePhi,w,zFine,weightsFine,scale,w.khUnique(1));
                X = page.fromEnergy;
                mass = (r.energy*X)'*(r.energy*X);
                weak = (r.etaZ*X)'*(1e-5*weights.*(r.bZ*X));
                weakFine = (fine.etaZ*X)'*(1e-5*weightsFine.*(fine.bZ*X));
                testCase.verifyLessThan(norm(weak-weakFine,'fro')/norm(weakFine,'fro'),1e-6)
                testCase.verifyLessThan(norm(mass*page.energyGenerator-weak,'fro')/norm(weak,'fro'),1e-4)
            end
        end

        function inwardFluxSignsMatchStrongThermalTendency(testCase)
            D = 4000;
            kappa = 7e-6;
            [z,weights] = gauss(129,D);
            f = 2*7.2921e-5*sind(24);
            for scale = [Inf 1300]
                N2 = @(z)(5.2e-3)^2*exp(2*z/scale);
                r = reference(17,z,weights,D,N2,scale,2*pi/100e3,f,9.81,kappa);
                for offset = [0 1]
                    % b=(z/D+offset)^2 supplies nonzero flux at either end.
                    buoyancyZ = 2*(z/D+offset)/D;
                    surfaceFlux = 2*kappa*offset/D;
                    bottomFlux = -2*kappa*(-1+offset)/D;
                    strong = -r.eta'*(weights*(2*kappa/D^2));
                    weak = r.etaZ'*(kappa*weights.*buoyancyZ)-r.etaEndpoint'*[surfaceFlux;bottomFlux];
                    testCase.verifyLessThan(norm(strong-weak)/norm(strong),1e-10)
                    testCase.verifyEqual(sum(weights)*(2*kappa/D^2),surfaceFlux+bottomFlux,RelTol=1e-12)
                end
            end
        end

        function meanDiffusionConvergesToInsulatedHeatSolution(testCase)
            for scale = [Inf 1300]
                errors = zeros(1,2);
                for i = 1:2
                    counts = [65 129];
                    w = newTransform(counts(i),scale);
                    closure = WVVerticalDiffusivity(w,kappa_z=1e-5);
                    op = closure.densityDiffusionOperators();
                    [z,weights] = gauss(513,w.Lz);
                    G = interpolateSamples(w.mdaG,w,z,scale);
                    buoyancy = -((5.2e-3)^2*exp(2*z/scale)).*G;
                    initial = w.mdaGForward*(-1e-6*(1+.2*cos(pi*(w.z+w.Lz)/w.Lz))./w.N2);
                    time = .2*w.Lz^2/(pi^2*1e-5);
                    m = op.mda;
                    final = m.fromEnergy*expm(time*m.energyGenerator)*m.toEnergy*initial;
                    target = 1e-6*(1+.2*exp(-.2)*cos(pi*(z+w.Lz)/w.Lz));
                    errors(i) = relative(buoyancy*final,target,weights);
                    testCase.verifyLessThan(abs(weights'*(buoyancy*(final-initial)))/(weights'*(buoyancy*initial)),1e-8)
                end
                testCase.verifyLessThan(errors(2),errors(1))
                testCase.verifyLessThan(errors(2),1e-2)
            end
        end
    end

    methods (Static)
        function result = runEndpointEvolutionStudy(folder,options)
            % Diagnose endpoint error without changing the resolved model basis.
            arguments (Input)
                folder (1,1) string
                options.bands (1,:) double {mustBeInteger,mustBePositive} = [217 433 865 1297 1729]
                options.days (1,:) double {mustBeNonnegative} = [1 8 32 64 91.3125]
                options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 8193
                options.referenceCount (1,1) double {mustBeInteger,mustBePositive} = 385
            end
            if ~isfolder(folder), mkdir(folder); end
            D=4000; scale=1300; N0=5.2e-3; g=9.81; f=2*7.2921e-5*sind(24);
            kh=2*pi/100e3; T=365.25*86400; omega=2*pi/T; amplitude=10*pi/T; kappa=1e-5;
            N2=@(z)N0^2*exp(2*z/scale); I=integral(N2,-D,0);
            evp=IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=g,g0=-I,gd=I,surfaceBoundary="freeSurface");
            solution=IMExponentialStratificationSolution(N0=N0,b=scale,zDomain=[-D 0],g=g,f0=f);
            basis=solution.internalModes(evp,nModes=max(options.bands));
            basis=basis.addNormalization("raw",@(~,~)1); basis.normalization="raw";
            zero=solution.geostrophicZeroAPVModesAtWavenumber(kh,endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
            [z,weights]=studyGrid(options.quadratureCount,D);
            ref=reference(options.referenceCount,z,weights,D,N2,scale,kh,f,g,kappa);
            F=basis.F(z); G=basis.G(z); ZF=zero.F(z); ZG=zero.G(z);
            Fs=basis.F(0); Gs=basis.G(0); Gb=basis.G(-D);
            referenceResponses=cell(size(options.days));
            for j=1:length(options.days)
                referenceResponses{j}=endpointResponse(ref.A,amplitude*ref.source,ref.endpoint,omega,options.days(j)*86400);
            end
            rows=table();
            for count=options.bands
                h=basis.h(1:count); mu=kh^2+f^2./(g*h);
                phi=[-F(:,1:count)./mu,-ZF/kh^2]; surf=[-Fs(1:count)./mu,-zero.F(0)/kh^2];
                eta=f/g*[-G(:,1:count)./mu,-ZG/kh^2]; etaZ=[-f/g*F(:,1:count)./(h.*mu),ZF/f];
                bZ=-2/scale*N2(z).*(eta-f/g*(1+z/D)*surf)-N2(z).*(etaZ-f/g/D*surf);
                page=WVInternal.densityDiffusionPage(phi,eta,etaZ,bZ,surf,weights,N2(z),kh,f,g,kappa);
                field=[sqrt(weights)*kh.*phi;sqrt(weights.*N2(z)).*eta;f/sqrt(g)*surf];
                endpoint=[[-f/g*(Gs(1:count)-Fs(1:count))./mu;-f/g*Gb(1:count)./mu],-f/g/kh^2*eye(2)];
                E=endpoint*page.fromEnergy; A=page.energyGenerator;
                source=zeros(count+2,1); source(count+1)=-g/f*kh^2*amplitude;
                source=page.toEnergy*source;
                % A diagnostic positive-energy projection of reference states
                % onto existing columns, not a production transform or basis fit.
                V=field*page.fromEnergy; P=(V'*V)\(V'*ref.energy);
                residual=A*P-P*ref.A; sourceResidual=source-P*(amplitude*ref.source);
                % Localize the operator residual to physical buoyancy-gradient
                % representation, with reference weak consistency kept separate.
                kernel=(E/(V'*V))*(etaZ*page.fromEnergy)';
                kernel=kernel.*(kappa*weights');
                gradientDifference=bZ*page.fromEnergy*P-ref.bZ;
                layers=[z>-100,z>=-D+100 & z<=-100,z<-D+100];
                gradientResidual=cell(1,3);
                for layer=1:3
                    gradientResidual{layer}=(kernel.*layers(:,layer)')*gradientDifference;
                end
                referenceWeakResidual=kernel*ref.bZ-E*P*ref.A;
                for j=1:length(options.days)
                    day=options.days(j); t=day*86400;
                    a=endpointResponse(A,source,E,omega,t); b=referenceResponses{j};
                    projected=P*b.state; evolution=a.state-projected;
                    c=page.fromEnergy*a.state; dc=page.fromEnergy*(A*a.state);
                    directSource=E*source*sin(omega*t); refSource=ref.endpoint*(amplitude*ref.source)*sin(omega*t);
                    values=[E*a.state,ref.endpoint*b.state, ...
                        (E*P-ref.endpoint)*b.state,E*evolution, ...
                        E*A*a.state,ref.endpoint*ref.A*b.state,directSource,refSource, ...
                        endpoint(:,1:count)*c(1:count),endpoint(:,count+1:end)*c(count+1:end), ...
                        endpoint(:,1:count)*dc(1:count),endpoint(:,count+1:end)*dc(count+1:end), ...
                        a.diffusionIntegral,b.diffusionIntegral,a.sourceIntegral,b.sourceIntegral, ...
                        E*A*evolution,E*residual*b.state,(E*P-ref.endpoint)*ref.A*b.state, ...
                        E*sourceResidual*sin(omega*t),gradientResidual{1}*b.state, ...
                        gradientResidual{2}*b.state,gradientResidual{3}*b.state,referenceWeakResidual*b.state];
                    row=array2table(values,VariableNames=["state","referenceState","representationError","evolutionError", ...
                        "diffusionTendency","referenceDiffusionTendency","sourceTendency","referenceSourceTendency", ...
                        "apvState","boundaryState","apvDiffusionTendency","boundaryDiffusionTendency", ...
                        "diffusionIntegral","referenceDiffusionIntegral","sourceIntegral","referenceSourceIntegral", ...
                        "feedbackTendencyError","operatorResidualTendencyError","representationTendencyError","projectedSourceResidual", ...
                        "surfaceLayerGradientResidual","interiorGradientResidual","bottomLayerGradientResidual","referenceWeakResidual"]);
                    row.APV=repmat(count,2,1); row.day=repmat(day,2,1); row.endpoint=["surface";"bottom"];
                    row.quadratureCount=repmat(options.quadratureCount,2,1); row.referenceCount=repmat(options.referenceCount,2,1);
                    row.budgetResidual=row.state-row.diffusionIntegral-row.sourceIntegral;
                    row.referenceBudgetResidual=row.referenceState-row.referenceDiffusionIntegral-row.referenceSourceIntegral;
                    row.decompositionResidual=row.state-row.referenceState-row.representationError-row.evolutionError;
                    rows=[rows;row]; %#ok<AGROW>
                    fprintf('Endpoint evolution APV=%d day=%.4f complete\n',count,day);
                    writetable(rows,fullfile(folder,'issue-353-endpoint-evolution.csv'));
                end
            end
            result=struct(rows=rows,rootResidual=max(abs(basis.metadata.rootResiduals)));
        end
        function result = runAnalyticalRetainedBandStudy(folder)
            % Direct analytical APV bands are a diagnostic, not a new WVM basis.
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            D=4000; scale=1300; N0=5.2e-3; g=9.81; f=2*7.2921e-5*sind(24);
            kh=2*pi/100e3; T=365.25*86400; times=[64*86400 T/4]; kappa=1e-5;
            N2=@(z)N0^2*exp(2*z/scale); I=integral(N2,-D,0);
            evp=IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=g,g0=-I,gd=I,surfaceBoundary="freeSurface");
            solution=IMExponentialStratificationSolution(N0=N0,b=scale,zDomain=[-D 0],g=g,f0=f);
            basis=solution.internalModes(evp,nModes=1729);
            % Avoid repeated all-mode evaluations in analytical normalization.
            % A column rescaling leaves the physical response invariant; the
            % existing diffusion page supplies well-conditioned coordinates.
            basis=basis.addNormalization("raw",@(~,~)1); basis.normalization="raw";
            zero=solution.geostrophicZeroAPVModesAtWavenumber(kh,endpoints=["surface","bottom"],surfaceBoundary="freeSurface");
            fprintf('Analytical 1729-mode catalog ready\n');
            rows=table();
            for quadratureCount=[8193 16385]
                [z,weights]=studyGrid(quadratureCount,D);
                ref=reference(385,z,weights,D,N2,scale,kh,f,g,kappa);
                F=basis.F(z); G=basis.G(z); ZF=zero.F(z); ZG=zero.G(z);
                Fs=basis.F(0); Gs=basis.G(0); Gb=basis.G(-D);
                bands=[84 217 325 433 865 1297 1729];
                if quadratureCount==16385, bands=1729; end
                for count=bands
                    h=basis.h(1:count); mu=kh^2+f^2./(g*h);
                    r.phi=[-F(:,1:count)./mu,-ZF/kh^2]; surf=[-Fs(1:count)./mu,-zero.F(0)/kh^2];
                    eta=f/g*[-G(:,1:count)./mu,-ZG/kh^2]; etaZ=[-f/g*F(:,1:count)./(h.*mu),ZF/f];
                    bZ=-2/scale*N2(z).*(eta-f/g*(1+z/D)*surf)-N2(z).*(etaZ-f/g/D*surf);
                    page=WVInternal.densityDiffusionPage(r.phi,eta,etaZ,bZ,surf,weights,N2(z),kh,f,g,kappa);
                    r.q=[F(:,1:count),zeros(length(z),2)]; r.ssh=f/g*surf;
                    r.b=-N2(z).*(eta-f/g*(1+z/D)*surf);
                    r.energy=[sqrt(weights)*kh.*r.phi;sqrt(weights.*N2(z)).*eta;f/sqrt(g)*surf];
                    r.endpoint=[[-f/g*(Gs(1:count)-Fs(1:count))./mu;-f/g*Gb(1:count)./mu],-f/g/kh^2*eye(2)];
                    source=zeros(count+2,1); source(count+1)=-g/f*kh^2*10*pi/T;
                    for j=1:2
                        c=page.fromEnergy*response(page.energyGenerator,page.toEnergy*source,2*pi/T,times(j));
                        cr=10*pi/T*response(ref.A,ref.source,2*pi/T,times(j));
                        a=studyState(r,c); b=studyState(ref,cr);
                        if count==84 && j==1
                            assert(abs(a.endpoint(2)+.00151079010900586)<1e-10,'Raw-column response must match the independently normalized 84-mode control.');
                        end
                        row=studyComparison(a,b,weights,D,"analyticalBand",count,385,times(j)/86400);
                        row.quadratureCount=repmat(quadratureCount,6,1);
                        if quadratureCount==8193 && count==1729
                            previousCoefficients{j}=c; %#ok<AGROW>
                        elseif quadratureCount==16385
                            % Compare complete states on the fine physical
                            % grid, using identical raw modal coordinates.
                            row=studyComparison(a,studyState(r,previousCoefficients{j}),weights,D,"analyticalQuadrature",count,count,times(j)/86400);
                            row.quadratureCount=repmat(quadratureCount,6,1);
                            row.withinTolerance=row.absolute<=.2*row.allowance;
                        end
                        rows=[rows;row]; %#ok<AGROW>
                    end
                    fprintf('Analytical APV=%d, quadrature=%d complete\n',count,quadratureCount);
                    writetable(rows,fullfile(folder,'issue-353-band-analytical.csv'));
                end
            end
            result=struct(errors=rows,rootResidual=max(abs(basis.metadata.rootResiduals)));
        end
        function result = runRetainedBandStudy(folder)
            % Hold the scientific solve and sampling fixed across APV prefixes.
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            D=4000; scale=1300; g=9.81; f=2*7.2921e-5*sind(24); kh=2*pi/100e3;
            T=365.25*86400; times=[64*86400 T/4]; amplitude=10*pi/T; kappa=1e-5;
            N2=@(z)(5.2e-3)^2*exp(2*z/scale);
            [z,weights]=studyGrid(2049,D);
            counts=[129 193 257 385]; referenceStates=cell(4,2); rows=table();
            for i=1:4
                ref=reference(counts(i),z,weights,D,N2,scale,kh,f,g,kappa);
                for j=1:2
                    c=amplitude*response(ref.A,ref.source,2*pi/T,times(j));
                    referenceStates{i,j}=studyState(ref,c);
                end
            end
            for i=1:3
                for j=1:2
                    rows=[rows;studyComparison(referenceStates{i,j},referenceStates{4,j},weights,D,"reference",counts(i),385,times(j)/86400)]; %#ok<AGROW>
                end
            end
            % Change operator quadrature independently, then express the
            % polynomial reference in the original reference coordinates.
            [zf,wf]=studyGrid(4097,D);
            refined=reference(385,zf,wf,D,N2,scale,kh,f,g,kappa);
            for j=1:2
                c=amplitude*response(refined.A,refined.source,2*pi/T,times(j));
                commonC=ref.polynomialCoefficients\(refined.polynomialCoefficients*c);
                rows=[rows;studyComparison(studyState(ref,commonC),referenceStates{4,j},weights,D,"referenceQuadrature",4097,2049,times(j)/86400)]; %#ok<AGROW>
            end
            writetable(rows,fullfile(folder,'issue-353-band-errors.csv'));
            fprintf('Independent reference and doubled quadrature complete\n');
            I=integral(N2,-D,0);
            w=WVTransformFreeSurfaceQG([100e3 100e3 D],[4 4 1025], ...
                apvModeCount=433,mdaModeCount=2,N2Function=N2,latitude=24, ...
                g0=-I,gd=I,shouldAntialias=false);
            [~,pageIndex]=min(abs(w.khUnique-kh));
            bands=[84 217 325 433]; states=cell(4,2); consistency=table();
            for i=1:4
                [r,page,source]=modelPage(w,pageIndex,z,weights,scale,kappa,bands(i));
                for j=1:2
                    c=amplitude*page.fromEnergy*response(page.energyGenerator,page.toEnergy*source,2*pi/T,times(j));
                    states{i,j}=studyState(r,c);
                    % Modal QGPV is the evolved state; pressure derivatives
                    % supply an independent consistency measurement.
                    derivedQ=r.q*c; states{i,j}.q=r.qState*c;
                    consistency=[consistency;table(bands(i),times(j)/86400,relative(derivedQ,states{i,j}.q,weights),VariableNames=["APV","day","qgpvConsistency"])]; %#ok<AGROW>
                    rows=[rows;studyComparison(states{i,j},referenceStates{4,j},weights,D,"retainedBand",bands(i),385,times(j)/86400)]; %#ok<AGROW>
                end
                fprintf('Fixed 1025 samples, APV=%d complete\n',bands(i));
            end
            for j=1:2
                rows=[rows;studyComparison(states{2,j},states{4,j},weights,D,"modalReference",217,433,times(j)/86400); ...
                    studyComparison(states{3,j},states{4,j},weights,D,"modalReference",325,433,times(j)/86400)]; %#ok<AGROW>
            end
            % Double comparison quadrature without changing either evolution.
            [rf,~,~]=modelPage(w,pageIndex,zf,wf,scale,kappa,433);
            for j=1:2
                c=amplitude*page.fromEnergy*response(page.energyGenerator,page.toEnergy*source,2*pi/T,times(j));
                cr=amplitude*response(ref.A,ref.source,2*pi/T,times(j));
                fineC=refined.polynomialCoefficients\(ref.polynomialCoefficients*cr);
                fineState=studyState(rf,c); fineState.q=rf.qState*c;
                doubled=studyComparison(fineState,studyState(refined,fineC),wf,D,"comparisonQuadrature",433,385,times(j)/86400);
                baseline=rows(rows.study=="retainedBand" & rows.count==433 & rows.day==times(j)/86400,:);
                doubled.absolute=abs(doubled.absolute-baseline.absolute);
                doubled.relative=doubled.absolute./baseline.referenceMagnitude;
                doubled.withinTolerance=doubled.absolute<=.2*baseline.allowance;
                rows=[rows;doubled]; %#ok<AGROW>
            end
            result=struct(errors=rows,consistency=consistency);
            writetable(rows,fullfile(folder,'issue-353-band-errors.csv'));
            writetable(consistency,fullfile(folder,'issue-353-band-consistency.csv'));
            save(fullfile(folder,'band-states.mat'),'states','referenceStates','bands','counts','z','weights');
        end
        function results = runStudy(options)
            % Report seasonal errors at fixed physical parameters from rest.
            % Add UnitTests to the path, then call this method explicitly.
            % Callers decide which observable errors their application can accept.
            arguments (Input)
                options.gridCounts (1,:) double {mustBeInteger,mustBePositive} = [33 65 129]
                options.scales (1,:) double {mustBePositive} = [Inf 1300]
                options.maximumAPVCount (1,1) double {mustBePositive} = Inf
                options.referenceCount (1,1) double {mustBeInteger,mustBePositive} = 193
                options.timeFractions (1,:) double {mustBePositive} = [.25 .5 .75 1]
            end
            arguments (Output)
                results table
            end
            if isfinite(options.maximumAPVCount) && fix(options.maximumAPVCount) ~= options.maximumAPVCount
                error('WV:QualificationModeCount','Use a positive integer APV count or Inf for the full retained family.');
            end
            period = 365.25*86400;
            f = 2*7.2921e-5*sind(24);
            kh = 2*pi/100e3;
            [z,weights] = gauss(max(801,2*max(options.gridCounts)+1),4000);
            rows = cell(length(options.scales)*length(options.gridCounts)*length(options.timeFractions),1);
            index = 0;
            for scale = options.scales
                N2 = @(z)(5.2e-3)^2*exp(2*z/scale);
                ref = reference(options.referenceCount,z,weights,4000,N2,scale,kh,f,9.81,1e-5);
                for nz = options.gridCounts
                    w = newTransform(nz,scale);
                    [~,p] = min(abs(w.khUnique-kh));
                    [r,page,source] = modelPage(w,p,z,weights,scale,1e-5,options.maximumAPVCount);
                    for fraction = options.timeFractions
                        time = fraction*period;
                        cr = response(ref.A,ref.source,2*pi/period,time);
                        dr = ref.A*cr+ref.source*sin(2*pi*fraction);
                        c = page.fromEnergy*response(page.energyGenerator,page.toEnergy*source,2*pi/period,time);
                        dc = page.generator*c+source*sin(2*pi*fraction);
                        bError = relative(r.b*c,ref.b*cr,weights);
                        qError = relative(r.q*c,ref.q*cr,weights);
                        sshError = abs(r.ssh*c-ref.ssh*cr)/max(abs(ref.ssh*cr),realmin);
                        endpointError = norm(r.endpoint*c-ref.endpoint*cr)/max(norm(ref.endpoint*cr),realmin);
                        energyError = abs(norm(r.energy*c)^2/norm(ref.energy*cr)^2-1);
                        enstrophyError = abs(sum(weights.*abs(r.q*c).^2)/sum(weights.*abs(ref.q*cr).^2)-1);
                        energyBudget = 2*real((r.energy*c)'*(r.energy*dc));
                        referenceEnergyBudget = 2*real((ref.energy*cr)'*(ref.energy*dr));
                        enstrophyBudget = 2*real((r.q*c)'*(weights.*(r.q*dc)));
                        referenceEnstrophyBudget = 2*real((ref.q*cr)'*(weights.*(ref.q*dr)));
                        energyBudgetError = abs(energyBudget-referenceEnergyBudget)/max(abs(referenceEnergyBudget),realmin);
                        enstrophyBudgetError = abs(enstrophyBudget-referenceEnstrophyBudget)/max(abs(referenceEnstrophyBudget),realmin);
                        qConsistency = relative(r.q*c,r.qState*c,weights);
                        index = index+1;
                        rows{index} = table(scale,nz,size(r.qState,2)-2,w.mdaModeCount,fraction,bError,qError,sshError,endpointError,energyError,enstrophyError,energyBudgetError,enstrophyBudgetError,qConsistency,VariableNames={'stratificationScale','Nz','APVModes','MDAModes','timeInYears','buoyancyError','qgpvError','sshError','endpointError','energyError','enstrophyError','energyBudgetError','enstrophyBudgetError','qgpvConsistency'});
                        disp(rows{index})
                    end
                end
            end
            results = vertcat(rows{:});
        end
    end
end

function w = newTransform(nz,scale)
% One mode in a 100 km tile equals mode 5 in the 500 km experiment.
% The isolated single-mode linear problem has no horizontal aliasing products.
N2 = @(z)(5.2e-3)^2*exp(2*z/scale);
gPrime = integral(N2,-4000,0);
w = WVTransformFreeSurfaceQG([100e3 100e3 4000],[4 4 nz],N2Function=N2,latitude=24,g0=-gPrime,gd=gPrime,shouldAntialias=false);
end

function [r,page,source] = modelPage(w,p,z,weights,scale,kappa,maximumAPVCount)
if nargin < 7, maximumAPVCount = Inf; end
count = min(w.apvModeCount,maximumAPVCount);
indices = [1:count,w.apvModeCount+(1:2)];
C = [-w.apvF./w.apvMu(:,p).',-w.zeroAPVF(:,:,p)/w.khUnique(p)^2];
C = C(:,indices);
r = sampled(C,w,z,weights,scale,w.khUnique(p));
r.nativePhi = C;
r.qState = [interpolateSamples(w.apvF(:,1:count),w,z,scale),zeros(length(z),2)];
closure = WVVerticalDiffusivity(w,kappa_z=kappa);
operators = closure.densityDiffusionOperators();
page = operators.pages{p};
if count < w.apvModeCount
    rStored = operators.reconstruction{p};
    page = WVInternal.densityDiffusionPage(rStored.phi(:,indices),rStored.eta(:,indices),rStored.etaZ(:,indices),rStored.buoyancyZ(:,indices),rStored.phiSurface(:,indices),operators.weights,operators.N2,w.khUnique(p),w.f,w.g,kappa);
end
source = zeros(size(C,2),1);
source(end-1) = -w.g/w.f*w.khUnique(p)^2;
end

function values = interpolateSamples(native,w,z,scale)
[s,~,~] = mappedCoordinate(z,w.Lz,scale);
P = polynomials(s,w.Nz);
V = polynomials(mappedCoordinate(w.z,w.Lz,scale),w.Nz);
values = P*(V\native);
end
function r=reference(n,z,w,D,N2,scale,kh,f,g,kappa)
[P,Pz,Pzz]=polynomials(2*z/D+1,n); Pz=Pz*2/D; Pzz=Pzz*(2/D)^2;
E=-f./N2(z).*Pz; Ez=-f./N2(z).*(Pzz-2/scale*Pz);
surface=ones(1,n); bottom=(-1).^(0:n-1);
Bz=f*Pzz+f/g*(N2(z).*(1/D+2/scale*(1+z/D)))*surface;
field=[sqrt(w)*kh.*P;sqrt(w.*N2(z)).*E;f/sqrt(g)*surface];
[~,R]=qr(field,0); Q=eye(n)/R;
r.A=(Ez*Q)'*(kappa*w.*(Bz*Q));
r.source=-f*(Q'*surface');
r.bottomSource=f*(Q'*bottom');
r.phi=P*Q;
r.b=(-N2(z).*E+f/g*(N2(z).*(1+z/D))*surface)*Q;
r.q=(-kh^2*P-f*Ez)*Q;
r.ssh=f/g*surface*Q;
[~,ends]=polynomials([1;-1],n); ends=ends*2/D;
r.eta=E*Q; r.etaZ=Ez*Q;
r.etaEndpoint=(-f./N2([0;-D]).*ends)*Q;
r.endpoint=(-f./N2([0;-D]).*ends-[f/g*surface;zeros(size(bottom))])*Q;
r.energy=field*Q;
r.polynomialCoefficients=Q;
r.bZ=Bz*Q;
end
function r=sampled(C,w,zq,wq,scale,kh)
D=w.Lz;
[s,sz,szz]=mappedCoordinate(zq,D,scale);
[P,P1,P2]=polynomials(s,w.Nz); native=polynomials(mappedCoordinate(w.z,w.Lz,scale),w.Nz); coeff=native\C;
phi=P*coeff; phiz=(sz.*P1)*coeff; phizz=(sz.^2.*P2+szz.*P1)*coeff;
N2=(5.2e-3)^2*exp(2*zq/scale); eta=-w.f./N2.*phiz; etaz=-w.f./N2.*(phizz-2/scale*phiz);
r.phi=phi; r.etaZ=etaz;
r.bZ=w.f*phizz+w.f/w.g*(N2.*(1/D+2/scale*(1+zq/D)))*C(end,:);
r.b=-N2.*eta+w.f/w.g*(N2.*(1+zq/D))*C(end,:);
r.q=-kh^2*phi-w.f*etaz; r.ssh=w.f/w.g*C(end,:);
[~,e]=polynomials([1;-1],w.Nz);
if isinf(scale), es=2/D*ones(2,1); else, es=2/scale*exp([0;-D]/scale)/(1-exp(-D/scale)); end
r.endpoint=-w.f./((5.2e-3)^2*exp(2*[0;-D]/scale)).*(es.*e*coeff)-[w.f/w.g*C(end,:);zeros(1,size(C,2))];
r.energy=[sqrt(wq)*kh.*phi;sqrt(wq.*N2).*eta;w.f/sqrt(w.g)*C(end,:)];
end
function x=response(A,s,omega,t)
% A real sine source from rest, evaluated by an augmented matrix exponential.
n=length(s); H=[A,s,zeros(n,1);zeros(1,n),0,omega;zeros(1,n),-omega,0]; y=expm(t*H)*[zeros(n+1,1);1]; x=y(1:n);
end
function [P,P1,P2]=polynomials(x,n)
x=x(:); P=zeros(length(x),n); P1=P; P2=P; P(:,1)=1;
if n>1, P(:,2)=x; P1(:,2)=1; end
for k=2:n-1
    P(:,k+1)=((2*k-1)*x.*P(:,k)-(k-1)*P(:,k-1))/k;
    P1(:,k+1)=((2*k-1)*(P(:,k)+x.*P1(:,k))-(k-1)*P1(:,k-1))/k;
    P2(:,k+1)=((2*k-1)*(2*P1(:,k)+x.*P2(:,k))-(k-1)*P2(:,k-1))/k;
end
end
function [z,w]=gauss(n,D)
b=(1:n-1)'./sqrt(4*(1:n-1)'.^2-1); [V,d]=eig(diag(b,1)+diag(b,-1),'vector'); [s,i]=sort(d); z=D*(s-1)/2; w=D*V(1,i)'.^2;
end
function e=relative(x,y,w)
e=sqrt(sum(w.*abs(x-y).^2)/sum(w.*abs(y).^2));
end

function [s,sz,szz] = mappedCoordinate(z,D,scale)
if isinf(scale)
    s=2*(z+D)/D-1; sz=2/D*ones(size(z)); szz=zeros(size(z));
else
    s=2*(exp(z/scale)-exp(-D/scale))/(1-exp(-D/scale))-1;
    sz=2/scale*exp(z/scale)/(1-exp(-D/scale)); szz=sz/scale;
end
end

function [z,weights]=studyGrid(count,D)
[x,weights]=legpts(count);
z=D*(x-1)/2; weights=weights(:)*D/2;
end
function state=studyState(r,c)
state=struct(q=r.q*c,b=r.b*c,ssh=r.ssh*c,endpoint=r.endpoint*c,energy=r.energy*c);
end
function rows=studyComparison(a,b,weights,D,study,count,referenceCount,day)
names=["qgpv","buoyancy","ssh","surfaceAnomaly","bottomAnomaly","physicalEnergyNorm"];
absolute=[sqrt(sum(weights.*abs(a.q-b.q).^2)/(2*D)); ...
    sqrt(sum(weights.*abs(a.b-b.b).^2)/(2*D));abs(a.ssh-b.ssh)/sqrt(2); ...
    abs(a.endpoint-b.endpoint)/sqrt(2);norm(a.energy-b.energy)/2];
referenceMagnitude=[sqrt(sum(weights.*abs(b.q).^2)/(2*D)); ...
    sqrt(sum(weights.*abs(b.b).^2)/(2*D));abs(b.ssh)/sqrt(2); ...
    abs(b.endpoint)/sqrt(2);norm(b.energy)/2];
allowance=[1e-13;1e-10;1e-8;1e-8;1e-8;0]+[.05;.001;.0001;.001;.001;.0001].*referenceMagnitude;
relative=absolute./referenceMagnitude; relative(absolute==0 & referenceMagnitude==0)=0;
withinTolerance=absolute<=allowance;
if study=="reference" || study=="referenceQuadrature", withinTolerance=absolute<=.2*allowance; end
rows=table(repmat(study,6,1),repmat(count,6,1),repmat(referenceCount,6,1),repmat(day,6,1),names.',absolute,relative,referenceMagnitude,allowance,withinTolerance, ...
    VariableNames=["study","count","referenceCount","day","observable","absolute","relative","referenceMagnitude","allowance","withinTolerance"]);
end

function result=endpointResponse(A,source,E,omega,t)
% Independently accumulate signed source and diffusion endpoint integrals.
n=length(source);
H=zeros(n+6); H(1:n,1:n)=A; H(1:n,n+1)=source;
H(n+1,n+2)=omega; H(n+2,n+1)=-omega;
H(n+(3:4),1:n)=E*A; H(n+(5:6),n+1)=E*source;
y0=zeros(n+6,1); y0(n+2)=1; y=expm(t*H)*y0;
result=struct(state=y(1:n),diffusionIntegral=y(n+(3:4)),sourceIntegral=y(n+(5:6)));
end
