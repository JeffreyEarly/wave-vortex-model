classdef TestFreeSurfaceManuscriptProjection < matlab.unittest.TestCase
    properties
        inventories
    end
    properties (TestParameter)
        inventory = {1,2}
    end
    methods (TestClassSetup)
        function buildInventories(testCase)
            options = struct(N2Function=@(z)1e-4+zeros(size(z)),apvModeCount=2,mdaModeCount=2,inertialModeCount=2,waveModeCount=3,shouldAntialias=true);
            args = namedargs2cell(options);
            base = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:});
            choices = [3;2;0];
            options.waveModeCount = choices(1+mod((0:numel(base.khUnique)-1).',3));
            args = namedargs2cell(options);
            ragged = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:},waveModeKappa=base.khUnique);
            options.waveModeCount = 0;
            args = namedargs2cell(options);
            empty = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],args{:});
            testCase.inventories = {ragged.scientificState(),empty.scientificState()};
        end
    end
    methods (Test, TestTags="full")
        function arbitrarySourcesMatchManuscriptQuadrature(testCase,inventory)
            w = transform(testCase,inventory);
            [X,Y,Z] = ndgrid(w.x,w.y,w.z);
            column = find(w.kNonzero>0 & w.lNonzero==0,1);
            k = w.kNonzero(column); l = w.lNonzero(column);
            profile = @(z) [1+.2*z/w.Lz,(z/w.Lz).^2,.3+z/w.Lz,1-.4*z/w.Lz];
            amplitude = [1+.2i,-.3+.7i,.1-.2i,.03+.02i];
            meanAmplitude = [.2,-.1,.05,.02];
            names = ["u","v","w","eta"];
            for j = 1:4
                a = profile(Z(:)); a = reshape(a(:,j),size(Z));
                source.(names(j)) = a.*(2*real(amplitude(j)*exp(1i*(k*X+l*Y)))+meanAmplitude(j));
            end
            actual = w.projectSources(source);
            expected = manuscriptSource(w,column,profile,amplitude,meanAmplitude);
            for name = string(fieldnames(expected)).'
                testCase.verifyEqual(actual.(name),expected.(name),RelTol=3e-9,AbsTol=2e-12)
            end
            testCase.verifyEqual(actual.Aw_p(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
            testCase.verifyEqual(actual.Aw_m(~w.activeWaveModes),zeros(nnz(~w.activeWaveModes),1))
        end

        function pressureGradientsLeaveOnlyWaveSurfaceTerm(testCase,inventory)
            w = transform(testCase,inventory);
            [X,Y,Z] = ndgrid(w.x,w.y,w.z);
            column = find(w.kNonzero>0 & w.lNonzero==0,1);
            k = w.kNonzero(column); l = w.lNonzero(column); kh = hypot(k,l);
            harmonic = exp(1i*(k*X+l*Y)); amplitude = 230+71i;
            page = w.klNonzeroKhUniqueIndex(column);
            for surface = [0,1]
                % Analytic polynomial pressure and derivatives, with p(bottom)=0.
                p = amplitude*(1+Z/w.Lz).*(surface+Z/w.Lz);
                pz = amplitude*((surface+1)/w.Lz+2*Z/w.Lz^2);
                source = struct(u=2*real(-1i*k*p.*harmonic/w.rho0),v=2*real(-1i*l*p.*harmonic/w.rho0),w=2*real(-pz.*harmonic/w.rho0),eta=zeros(size(Z)));
                actual = w.projectSources(source); expected = w.coefficientState();
                count = w.waveModeCountByKh(page); modes = 1:count;
                for sigma = [1,-1]
                    name = "Aw_p"; if sigma<0, name="Aw_m"; end
                    expected.(name)(modes,column) = (-1i*kh*amplitude*surface/(2*w.rho0))*w.waveG(end,modes,page).'.*exp(-sigma*1i*w.waveFrequency(modes,page)*(w.t-w.t0));
                end
                for name = string(fieldnames(expected)).'
                    testCase.verifyEqual(actual.(name),expected.(name),RelTol=2e-9,AbsTol=2e-13)
                end
                if surface==1 && count>0, testCase.verifyGreaterThan(norm(actual.Aw_p),1e-8); end
            end
        end

        function completeLinearEquationsCancelBasisPhases(testCase,inventory)
            w = transform(testCase,inventory); mixed = w.coefficientState();
            families = string(fieldnames(mixed)).';
            for name = families
                a = mixed.(name); index = reshape(1:numel(a),size(a));
                a = exp(.37i*index)./(1+index);
                if ismember(name,["Ag_q","Ag_0"]), a=1e-8*a; end
                if name=="Amda", a=real(a); end
                if ismember(name,["Aw_p","Aw_m"]), a(~w.activeWaveModes)=0; end
                mixed.(name)=a;
            end
            maximumResidual = 0;
            for selection = [families,"mixed"]
                state = w.coefficientState();
                if selection=="mixed", state=mixed; else, state.(selection)=mixed.(selection); end
                rate = w.coefficientState();
                omega = w.waveFrequency(:,w.klNonzeroKhUniqueIndex);
                omega(~w.activeWaveModes)=0;
                rate.Aw_p = 1i*omega.*state.Aw_p;
                rate.Aw_m = -1i*omega.*state.Aw_m;
                rate.Aio = 1i*w.f*state.Aio;
                fields = w.reconstructSpectralState(state=state);
                timeDerivative = w.reconstructSpectralState(state=rate);
                linear = struct(u=w.f*fields.v-1i*w.k.'.*fields.p/w.rho0,v=-w.f*fields.u-1i*w.l.'.*fields.p/w.rho0,w=-w.verticalDerivativeMatrix*fields.p/w.rho0-w.N2.*fields.eta,eta=fields.w);
                scale = max([norm(fields.u(:)),norm(fields.v(:)),norm(fields.eta(:)),1]);
                for name = ["u","v","w","eta"]
                    residual = timeDerivative.(name)-linear.(name);
                    maximumResidual = max(maximumResidual,norm(residual(:))/scale);
                    source.(name) = w.transformToSpatialDomainWithFourier(residual);
                end
                % Include the fifth linear equation before extracting sources.
                testCase.verifyEqual(timeDerivative.ssh(end,:),fields.w(end,:),AbsTol=2e-11*scale)
                actual = w.projectSources(source);
                for name = families, testCase.verifyLessThan(norm(actual.(name)(:)),2e-9*scale); end
            end
            testCase.verifyLessThan(maximumResidual,2e-10)
            testCase.verifyEqual([w.t,w.t0],[327,-17])
            fprintf('Manuscript complete-linear residual, inventory %d: %.6g\n',inventory,maximumResidual)
        end
    end
end

function w = transform(testCase,inventory)
w = WVTransformFreeSurfaceBoussinesq(testCase.inventories{inventory});
w.t = 327; w.t0 = -17;
testCase.assertEqual(numel(w.activeEndpoint),2)
end

function expected = manuscriptSource(w,column,profile,amplitude,meanAmplitude)
% Independent Gauss integration of manuscript generalized-energy functionals.
% Do not use stored forward/pairing matrices or the runtime polarization helper.
[z,q,I] = gaussRule(w.z);
values = profile(z).*amplitude;
ends = profile([0;-w.Lz]).*amplitude;
meanValues = profile(z).*meanAmplitude;
meanEnds = profile([0;-w.Lz]).*meanAmplitude;
expected = w.coefficientState(); k=w.kNonzero(column); l=w.lNonzero(column);
kh=hypot(k,l); page=w.klNonzeroKhUniqueIndex(column);
F=I*w.apvF; G=I*w.apvG;
curl=1i*k*values(:,2)-1i*l*values(:,1);
Gpair=G.'*(q.*1e-4.*values(:,4))/w.g+(w.g0/(w.g+w.g0))*w.apvG(end,:).'*ends(1,4)+(w.gd/w.g)*w.apvG(1,:).'*ends(2,4);
expected.Ag_q(:,column)=F.'*(q.*curl)/w.Lz-(w.f/w.Lz)*Gpair;
F=I*w.zeroAPVF(:,:,page); G=I*w.zeroAPVG(:,:,page);
Fs=w.zeroAPVF(end,:,page); Gs=w.zeroAPVG(end,:,page); Gb=w.zeroAPVG(1,:,page); B=Gs-Fs;
% Full signed physical Gram of the boundary-normalized state columns.
eta=-(w.f/(w.g*kh^2))*G; ssh=-(w.f/(w.g*kh^2))*Fs;
etaSurface=-(w.f/(w.g*kh^2))*B; etaBottom=-(w.f/(w.g*kh^2))*Gb;
u=1i*l*F/kh^2; v=-1i*k*F/kh^2;
gram=u'*(q.*u)+v'*(q.*v)+eta'*(q.*1e-4.*eta)+w.g*(ssh'*ssh)+w.g0*(etaSurface'*etaSurface)+w.gd*(etaBottom'*etaBottom);
pair=u'*(q.*values(:,1))+v'*(q.*values(:,2))+eta'*(q.*1e-4.*values(:,4))+w.g0*etaSurface'*ends(1,4)+w.gd*etaBottom'*ends(2,4);
expected.Ag_0(:,column)=gram\pair;
for mode=1:w.waveModeCountByKh(page)
    F=I*w.waveF(:,mode,page); G=I*w.waveG(:,mode,page);
    h=w.waveEquivalentDepth(mode,page); omega=sqrt(w.f^2+w.g*h*kh^2);
    for sigma=[1,-1]
        pair=sum(q.*(F.*((k*omega+1i*sigma*w.f*l)*values(:,1)+(l*omega-1i*sigma*w.f*k)*values(:,2))/(omega*kh)+1i*kh*h*G.*values(:,3)-sigma*kh*h*1e-4*G.*values(:,4)/omega));
        name="Aw_p"; if sigma<0, name="Aw_m"; end
        expected.(name)(mode,column)=exp(-sigma*1i*omega*(w.t-w.t0))*pair/(2*h);
    end
end
F=I*w.inertialF;
expected.Aio=.5*exp(-1i*w.f*(w.t-w.t0))*(F.'*(q.*(meanValues(:,1)-1i*meanValues(:,2))))./w.inertialEquivalentDepth;
G=I*w.mdaG;
gram=(G.'*(q.*1e-4.*G)+w.g0*w.mdaG(end,:).'*w.mdaG(end,:)+w.gd*w.mdaG(1,:).'*w.mdaG(1,:))/w.g;
pair=(G.'*(q.*1e-4.*meanValues(:,4))+w.g0*w.mdaG(end,:).'*meanEnds(1,4)+w.gd*w.mdaG(1,:).'*meanEnds(2,4))/w.g;
expected.Amda=real(sign(diag(gram)).*pair);
end

function [z,q,I] = gaussRule(nodes)
% Golub-Welsch quadrature plus barycentric evaluation of retained polynomials.
n=96; off=(1:n-1)./sqrt(4*(1:n-1).^2-1);
[V,D]=eig(diag(off,1)+diag(off,-1)); [x,order]=sort(diag(D));
depth=nodes(end)-nodes(1); z=nodes(1)+(x+1)*depth/2;
q=depth*(V(1,order).').^2;
b=(-1).^(0:numel(nodes)-1); b([1 end])=b([1 end])/2;
I=b./(z-nodes.'); I=I./sum(I,2);
end
