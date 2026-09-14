classdef TestFreeSurfaceThermalQG < matlab.unittest.TestCase
    properties
        constantState
        exponentialState
    end
    methods (TestClassSetup)
        function construct(testCase)
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4*ones(size(z)),thermalModeCount=17,mdaModeCount=4);
            testCase.constantState=w.scientificState;
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4*exp(2*z/1300),thermalModeCount=17,mdaModeCount=4);
            testCase.exponentialState=w.scientificState;
        end
    end
    methods (Test, TestTags="full")
        function manufacturedPressureAndProjection(testCase)
            w=newTransform(testCase.constantState);
            c=zeros(w.thermalModeCount,1); c(1:3)=10*[1+.2/3;1;.4/3];
            w.Ath(:,1)=w.polynomialToThermal(:,:,1)*c;
            w.Ath(:,2)=.5*w.polynomialToThermal(:,:,1)*c;
            fields=w.reconstructFields(["psi","u","v","eta","eta_i","buoyancy","qgpv","ssh","endpointAnomalies"]);
            z=reshape(w.z,1,1,[]); s=1+2*z/w.Lz;
            k=w.k(w.klNonzero(1)); l=w.l(w.klNonzero(1));
            theta=k*reshape(w.x,[],1)+l*reshape(w.y,1,[]);
            k2=w.k(w.klNonzero(2)); l2=w.l(w.klNonzero(2));
            theta2=k2*reshape(w.x,[],1)+l2*reshape(w.y,1,[]);
            phase=2*cos(theta)+cos(theta2);
            psi=10*(1+s+.2*s.^2).*phase;
            eta=-w.f/1e-4*10*(1+.4*s)*(2/w.Lz).*phase;
            q=-(k^2+l^2)*psi+w.f^2/1e-4*4/w.Lz^2*4.*phase;
            testCase.verifyEqual(fields.psi,psi,AbsTol=2e-10);
            testCase.verifyEqual(fields.u,10*(1+s+.2*s.^2).*(2*l*sin(theta)+l2*sin(theta2)),AbsTol=1e-13);
            testCase.verifyEqual(fields.v,-10*(1+s+.2*s.^2).*(2*k*sin(theta)+k2*sin(theta2)),AbsTol=1e-13);
            testCase.verifyEqual(fields.eta,eta,AbsTol=2e-10);
            testCase.verifyEqual(fields.qgpv,q,AbsTol=2e-13);
            testCase.verifyEqual(fields.buoyancy,-1e-4*fields.eta_i,AbsTol=1e-15);
            testCase.verifyEqual(fields.endpointAnomalies,fields.eta_i(:,:,[end 1]),AbsTol=1e-12);
            [state,residual]=w.projectState(fields.qgpv,fields.endpointAnomalies);
            testCase.verifyEqual(state.Ath,w.Ath,AbsTol=1e-9);
            testCase.verifyLessThan(residual.qgpvRMS,1e-13);
            testCase.verifyLessThan(max(residual.endpointRMS),1e-10);
            rate=w.projectQuasigeostrophicSpatialTendency(fields.qgpv,fields.endpointAnomalies);
            testCase.verifyEqual(rate.Ath,w.Ath,AbsTol=1e-9);
        end
        function mappedCalculusAndResampling(testCase)
            for a=[0 1/1300]
                n=65; s=-cos(pi*(0:n-1)'/(n-1)); D=1000;
                if a==0, J=2/D*ones(n,1); else, z=log1p((s-1)*(-expm1(-D*a))/2)/a; J=2*a*exp(a*z)/(-expm1(-D*a)); end
                values=(1+2i)*(s.^5+2*s.^2);
                first=(1+2i)*(5*s.^4+4*s).*J;
                second=(1+2i)*((20*s.^3+4).*J.^2+(5*s.^4+4*s).*a.*J);
                actual=WVInternal.thermalChebyshev(values,"derivative",depth=D,inverseScale=a);
                actual2=WVInternal.thermalChebyshev(values,"derivative",depth=D,inverseScale=a,order=2);
                testCase.verifyEqual(actual,first,AbsTol=1e-12);
                testCase.verifyEqual(actual2,second,AbsTol=2e-12);
                padded=WVInternal.thermalChebyshev(values,"resample",count=129);
                restored=WVInternal.thermalChebyshev(padded,"resample",count=n);
                testCase.verifyEqual(restored,values,AbsTol=1e-13);
            end
        end
        function independentMeansAndDiffusivity(testCase)
            w=newTransform(testCase.exponentialState);
            w.Amda=[.001;-.002;.003;-.001];
            w.Ath(2,1)=.001+.002i;
            before=w.reconstructFields(["psi","eta","qgpv","endpointAnomalies"]);
            other=w.withDiffusivity(0);
            testCase.verifyEqual(other.coefficientState(),w.coefficientState());
            testCase.verifyEqual(other.reconstructFields(["psi","eta","qgpv","endpointAnomalies"]),before);
            testCase.verifyEqual(abs(other.kappa_z*other.thermalRatesPerDiffusivity),zeros(size(other.thermalRatesPerDiffusivity)));
            testCase.verifyNotEqual(w.thermalModeCount,w.mdaModeCount);
            testCase.verifyError(@()setMean(w,1i*ones(4,1)),'WV:ThermalMeanShape');
            integral=-sum(w.verticalQuadratureWeights.*w.N2.*w.mdaG,1);
            testCase.verifyLessThan(norm(integral*w.mdaGeneratorPerDiffusivity)/norm(integral),1e-9);
        end
        function strictSourcesAndMeanRejection(testCase)
            for state={testCase.constantState,testCase.exponentialState}
                w=newTransform(state{1});
                pattern=cos(2*pi*reshape(w.x,[],1)/w.Lx).*ones(1,w.Ny);
                for endpoint=1:2
                    Fb=zeros(w.Nx,w.Ny,2); Fb(:,:,endpoint)=1e-6*pattern;
                    rate=w.projectQuasigeostrophicSpatialTendency(zeros(w.Nx,w.Ny,w.Nz),Fb);
                    w.Ath=rate.Ath;
                    fields=w.reconstructFields(["qgpv","endpointAnomalies"]);
                    testCase.verifyEqual(fields.endpointAnomalies,Fb,AbsTol=1e-10);
                    testCase.verifyLessThan(max(abs(fields.qgpv),[],'all'),1e-12);
                    testCase.verifyEqual(rate.Amda,zeros(4,1));
                end
                testCase.verifyError(@()w.projectQuasigeostrophicSpatialTendency(ones(w.Nx,w.Ny,w.Nz),zeros(w.Nx,w.Ny,2)),'WV:ThermalMeanSource');
            end
        end
        function cachedOperationsAndComponents(testCase)
            w=newTransform(testCase.exponentialState);
            w.Ath(3,1)=.001;
            first=w.variableWithName('u');
            testCase.verifyEqual(first,w.reconstructFields("u").u);
            testCase.verifyTrue(isKey(w.variableCache,'u'));
            maps=w.thermalToPolynomial;
            w.Ath=2*w.Ath;
            testCase.verifyFalse(isKey(w.variableCache,'u'));
            testCase.verifyEqual(w.u,2*first,AbsTol=1e-14);
            testCase.verifyEqual(w.thermalToPolynomial,maps);
            w.Amda(2)=.01;
            thermal=w.reconstructFields("eta",flowComponent=w.flowComponentWithName('ath'));
            mean=w.reconstructFields("eta",flowComponent=w.flowComponentWithName('amda'));
            testCase.verifyEqual(thermal.eta+mean.eta,w.eta,AbsTol=1e-12);
            testCase.verifyEqual(w.reconstructFields("endpointAnomalies").endpointAnomalies,w.eta_i(:,:,[end 1]),AbsTol=1e-12);
        end
        function snapshotWithoutProvider(testCase)
            w=newTransform(testCase.constantState); w.Ath(2,1)=.01+.02i; w.Amda(2)=.001; w.t=123;
            fileName=[tempname '.nc']; cleanup=onCleanup(@()delete(fileName));
            file=w.writeToFile(fileName); file.close();
            originalPath=path; pathCleanup=onCleanup(@()path(originalPath));
            providerRoot=string(fileparts(fileparts(which('IMInternalModes'))));
            paths=string(strsplit(path,pathsep)); provider=startsWith(paths,providerRoot+filesep) | paths==providerRoot;
            rmpath(char(join(paths(provider),pathsep)));
            testCase.assertEmpty(which('IMInternalModes'));
            restored=WVTransform.waveVortexTransformFromFile(fileName);
            testCase.verifyEqual(restored.scientificState,w.scientificState);
            testCase.verifyEqual(restored.coefficientState(),w.coefficientState());
            testCase.verifyEqual(restored.t,123);
            testCase.verifyEqual(restored.reconstructFields(["qgpv","eta","endpointAnomalies"]),w.reconstructFields(["qgpv","eta","endpointAnomalies"]));
            testCase.verifyEmpty(fieldnames(restored.constructionAssessment));
        end
        function publishedConstructionThroughTransform(testCase)
            w=WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 4000],[4 4 513],N2Function=@(z)(5.2e-3)^2*exp(2*z/1300),thermalModeCount=257,mdaModeCount=4,assemblyQuadratureCount=2049);
            pattern=cos(2*pi*reshape(w.x,[],1)/w.Lx).*ones(1,w.Ny);
            source=zeros(w.Nx,w.Ny,2); source(:,:,1)=10*pi/(365.25*86400)*pattern;
            rate=w.projectQuasigeostrophicSpatialTendency(zeros(w.Nx,w.Ny,w.Nz),source);
            w.Ath=rate.Ath;
            fields=w.reconstructFields(["qgpv","endpointAnomalies","buoyancy"]);
            testCase.verifyLessThan(max(abs(fields.qgpv),[],'all'),1e-20);
            testCase.verifyEqual(fields.endpointAnomalies,source,AbsTol=1e-16);
            derivative=w.diffZ(fields.buoyancy);
            r=WVInternal.thermalPolynomialFields(w.z,257,4000,w.N20,w.inverseScale,w.khUnique(1),w.f,w.g);
            analytic=zeros(w.Nx,w.Ny,w.Nz);
            for column=1:numel(w.klNonzero)
                c=w.thermalToPolynomial(:,:,1)*w.Ath(:,column);
                phase=exp(1i*(w.k(w.klNonzero(column))*reshape(w.x,[],1)+w.l(w.klNonzero(column))*reshape(w.y,1,[])));
                analytic=analytic+2*real(reshape(r.buoyancyZ*c,1,1,[]).*phase);
            end
            testCase.verifyLessThan(norm(derivative(:)-analytic(:))/norm(analytic(:)),1e-8);
            testCase.verifySize(w.thermalRatesPerDiffusivity,[257 1]);
            testCase.verifyLessThan(w.constructionAssessment.thermal{1}.nativeGramError,w.gramTolerance);
        end
        function unsupportedPathsAndCorruptState(testCase)
            w=newTransform(testCase.constantState);
            testCase.verifyError(@()w.coefficientTendency(),'WV:ThermalEvolutionUnavailable');
            testCase.verifyError(@()w.reconstructFields("w"),'WV:ThermalField');
            testCase.verifyError(@()w.nonlinearFlux(),'WV:ThermalEvolutionUnavailable');
            s=w.scientificState; s.polynomialToThermal(1,1,1)=NaN;
            testCase.verifyError(@()newTransform(s),'WV:ThermalStoredState');
            testCase.verifyError(@()WVTransformFreeSurfaceThermalQG.fromStratification([1e5 1e5 1000],[4 4 65],N2Function=@(z)1e-4*(1+.1*cos(z/100)),thermalModeCount=17,mdaModeCount=4),'WV:ThermalStratification');
        end
    end
end
function w=newTransform(s)
w=WVTransformFreeSurfaceThermalQG(scientificState=s);
end
function setMean(w,a)
w.Amda=a;
end
