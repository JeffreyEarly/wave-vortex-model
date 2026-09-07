classdef TestFreeSurfaceQGDiffusionQualification < matlab.unittest.TestCase
    % Independent physical-depth qualification of two-active-boundary diffusion.
    % runStudy reports failed physical accuracy targets without weakening them.
    methods (Test, TestTags="full")
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
        function results = runStudy(options)
            % Report seasonal errors at fixed physical parameters from rest.
            % Add UnitTests to the path, then call this method explicitly.
            % A failed target is a qualification result, not a test assertion.
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
                        passed = all([bError qError sshError endpointError]<1e-2) && all([energyError enstrophyError]<2e-2) && all([energyBudgetError enstrophyBudgetError]<5e-2);
                        index = index+1;
                        rows{index} = table(scale,nz,size(r.qState,2)-2,w.mdaModeCount,fraction,bError,qError,sshError,endpointError,energyError,enstrophyError,energyBudgetError,enstrophyBudgetError,qConsistency,passed,VariableNames={'stratificationScale','Nz','APVModes','MDAModes','timeInYears','buoyancyError','qgpvError','sshError','endpointError','energyError','enstrophyError','energyBudgetError','enstrophyBudgetError','qgpvConsistency','passed'});
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
