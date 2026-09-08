classdef TestCompleteThermalModes < matlab.unittest.TestCase
    % Optional diffusion research; not part of core adiabatic-model qualification.
    methods (Test, TestTags="diffusion-research")
        function completeThermalModesResolveBothActiveEndpoints(testCase)
            folder=string(tempname); mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            r=TestCompleteThermalModes.runCompleteThermalStudy(folder,counts=257);
            testCase.verifyTrue(all(r.errors.withinTolerance))
            testCase.verifyLessThan(max(r.checks.sourceQGPV),1e-20)
            testCase.verifyLessThan(max(r.checks.sourceEndpointError),1e-16)
            testCase.verifyLessThan(max(r.checks.zeroDiffusionQGPV),1e-13)
            testCase.verifyLessThan(max(r.checks.eigenResidual),1e-12)
            testCase.verifyLessThan(max(r.checks.maximumGrowth),1e-15)
            testCase.verifyLessThan(max(r.checks.condition),100)
            testCase.verifyLessThan(max(r.checks.directComparisonRatio),.2)
            testCase.verifyLessThan(max(r.checks.surfaceGradientRelative),1e-5)
            testCase.verifyLessThan(max(r.checks.cosineGradientRelative),1e-9)
        end
        function thermalSineResponsePreservesRestAndNullModes(testCase)
            omega=2*pi/(365.25*86400);
            lambda=[0;-1e-8;-1]; source=[1;1+1i;.3];
            for time=[0 1e-9 1 86400]
                actual=thermalSineResponse(lambda,source,omega,time);
                expected=response(diag(lambda),source,omega,time);
                testCase.verifyLessThanOrEqual(norm(actual-expected),1e-12*norm(expected))
            end
        end
    end

    methods (Static)
        function result = runCompleteThermalStudy(folder,options)
            % Complete balanced modes on WKB polynomial space, with two active endpoints.
            arguments (Input)
                folder (1,1) string
                options.counts (1,:) double {mustBeInteger,mustBePositive} = [129 257 385]
                options.days (1,:) double {mustBeNonnegative} = [1 8 32 64 91.3125]
                options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 2049
                options.referenceCount (1,1) double {mustBeInteger,mustBePositive} = 385
                options.assemblyQuadratureCount (1,1) double {mustBeInteger,mustBeNonnegative} = 0
            end
            if ~isfolder(folder), mkdir(folder); end
            D=4000; scale=1300; f=2*7.2921e-5*sind(24); g=9.81; kh=2*pi/100e3; kappa=1e-5;
            T=365.25*86400; omega=2*pi/T; amplitude=10*pi/T;
            N2=@(z)(5.2e-3)^2*exp(2*z/scale);
            [z,weights]=studyGrid(options.quadratureCount,D);
            ref=reference(options.referenceCount,z,weights,D,N2,scale,kh,f,g,kappa);
            rows=table(); checks=table(); states=cell(length(options.counts),length(options.days)); referenceStates=cell(1,length(options.days));
            for n=options.counts
                r=completeThermalPage(n,z,weights,D,N2,scale,kh,f,g,kappa);
                if options.assemblyQuadratureCount>0
                    [za,wa]=studyGrid(options.assemblyQuadratureCount,D);
                    assembled=completeThermalPage(n,za,wa,D,N2,scale,kh,f,g,kappa);
                    conversion=r.polynomialCoefficients\assembled.polynomialCoefficients;
                    r.A=conversion*assembled.A/conversion;
                    r.source=conversion*assembled.source;
                end
                [U,lambda]=eig(r.A,'vector'); left=U\eye(n);
                source=amplitude*r.source; modalSource=left*source;
                roundTrip=U*modalSource;
                eigenResidual=norm(r.A*U-U.*lambda.','fro')/norm(r.A,'fro');
                sourceQGPV=sqrt(sum(weights.*abs(r.q*roundTrip).^2)/D);
                sourceEndpointError=max(abs(r.endpoint*roundTrip-[amplitude;0]));
                for day=options.days
                    t=day*86400;
                    % The augmented reference is independent of eigenvectors.
                    modal=thermalSineResponse(lambda,modalSource,omega,t);
                    c=U*modal; direct=response(r.A,source,omega,t);
                    cr=response(ref.A,amplitude*ref.source,omega,t);
                    referenceStates{find(options.days==day,1)}=studyState(ref,cr);
                    a=studyState(r,c);
                    states{find(options.counts==n,1),find(options.days==day,1)}=a;
                    row=studyComparison(a,studyState(ref,cr),weights,D,"completeWKB",n,options.referenceCount,day);
                    rows=[rows;row]; %#ok<AGROW>
                    control=studyComparison(a,studyState(r,direct),weights,D,"eigenVsDirect",n,n,day);
                    sourceControl=U*(modalSource*((1-cos(omega*t))/omega));
                    zeroDiffusionQGPV=sqrt(sum(weights.*abs(r.q*sourceControl).^2)/D);
                    gradient=r.bZ*c; referenceGradient=ref.bZ*cr;
                    gradientRelative=relative(gradient,referenceGradient,weights);
                    upper=z>=-100;
                    surfaceGradientRelative=relative(gradient(upper),referenceGradient(upper),weights(upper));
                    nativeGradientRelative=relative(r.nativeDz*(r.nativeBuoyancy*c),r.nativeBuoyancyZ*c,r.nativeWeights);
                    cosineGradientRelative=relative(cosineDerivative(r.nativeBuoyancy*c,r.nativeMapDerivative),r.nativeBuoyancyZ*c,r.nativeWeights);
                    checks=[checks;table(n,day,eigenResidual,cond(U),max(real(lambda)),sourceQGPV,sourceEndpointError,zeroDiffusionQGPV,max(control.absolute./control.allowance), ...
                        gradientRelative,surfaceGradientRelative,nativeGradientRelative,cosineGradientRelative, ...
                        VariableNames=["count","day","eigenResidual","condition","maximumGrowth","sourceQGPV","sourceEndpointError","zeroDiffusionQGPV","directComparisonRatio", ...
                        "gradientRelative","surfaceGradientRelative","nativeGradientRelative","cosineGradientRelative"])]; %#ok<AGROW>
                end
                fprintf('Complete WKB modes=%d complete\n',n);
                writetable(rows,fullfile(folder,'issue-353-complete-wkb-errors.csv'));
                writetable(checks,fullfile(folder,'issue-353-complete-wkb-checks.csv'));
            end
            result=struct(errors=rows,checks=checks,states={states},referenceStates={referenceStates},options=options,z=z,weights=weights);
        end
        function rows = compareCompleteThermalStudies(base,other)
            assert(isequal(base.z,other.z),'Compare studies with identical observation quadrature.');
            rows=table();
            for n=intersect(base.options.counts,other.options.counts)
                for day=intersect(base.options.days,other.options.days)
                    a=base.states{find(base.options.counts==n,1),find(base.options.days==day,1)};
                    b=other.states{find(other.options.counts==n,1),find(other.options.days==day,1)};
                    if base.options.referenceCount~=other.options.referenceCount
                        a=base.referenceStates{find(base.options.days==day,1)};
                        b=other.referenceStates{find(other.options.days==day,1)};
                    end
                    count=n; referenceCount=n;
                    if base.options.referenceCount~=other.options.referenceCount
                        count=base.options.referenceCount; referenceCount=other.options.referenceCount;
                    end
                    rows=[rows;studyComparison(a,b,base.weights,4000,"referenceQuadrature",count,referenceCount,day)]; %#ok<AGROW>
                end
            end
        end
    end
end

function r=completeThermalPage(n,z,w,D,N2,scale,kh,f,g,kappa)
% All WKB polynomial directions are retained before diagonalizing diffusion.
% Energy is the positive physical metric, not an APV boundary-weight metric.
[s,sz,szz]=mappedCoordinate(z,D,scale);
[P,P1,P2]=polynomials(s,n); Pz=sz.*P1; Pzz=sz.^2.*P2+szz.*P1;
E=-f./N2(z).*Pz; Ez=-f./N2(z).*(Pzz-2/scale*Pz);
surface=ones(1,n); bottom=(-1).^(0:n-1);
Bz=f*Pzz+f/g*(N2(z).*(1/D+2/scale*(1+z/D)))*surface;
field=[sqrt(w)*kh.*P;sqrt(w.*N2(z)).*E;f/sqrt(g)*surface];
[~,R]=qr(field,0); Q=eye(n)/R;
r.A=(Ez*Q)'*(kappa*w.*(Bz*Q));
r.source=-f*(Q'*surface');
r.bottomSource=f*(Q'*bottom');
r.phi=P*Q; r.b=(-N2(z).*E+f/g*(N2(z).*(1+z/D))*surface)*Q;
r.q=(-kh^2*P-f*Ez)*Q; r.ssh=f/g*surface*Q;
[~,ends]=polynomials([1;-1],n);
[~,endScale]=mappedCoordinate([0;-D],D,scale); ends=endScale.*ends;
r.endpoint=(-f./N2([0;-D]).*ends-[f/g*surface;zeros(size(bottom))])*Q;
r.energy=field*Q; r.bZ=Bz*Q; r.polynomialCoefficients=Q;
problem=IMInternalModes.geostrophicAPVModes(N2=N2,zDomain=[-D 0],g=g,g0=-g,gd=integral(N2,-D,0),surfaceBoundary="freeSurface");
solver=IMSolverSpectral(nEVP=n,coordinateKind="wkb").configuredForEVP(problem);
[zn,wn,Dz]=solver.nativeDifferentiationRule([-D 0]);
[sn,snz,snzz]=mappedCoordinate(zn,D,scale);
[~,Pn1,Pn2]=polynomials(sn,n); Pnz=snz.*Pn1; Pnzz=snz.^2.*Pn2+snzz.*Pn1;
r.nativeBuoyancy=(f*Pnz+f/g*(N2(zn).*(1+zn/D))*surface)*Q;
r.nativeBuoyancyZ=(f*Pnzz+f/g*(N2(zn).*(1/D+2/scale*(1+zn/D)))*surface)*Q;
r.nativeDz=Dz; r.nativeWeights=wn; r.nativeMapDerivative=snz;
end

function derivative=cosineDerivative(values,mapDerivative)
% FFT-backed cosine transforms and the Chebyshev derivative recurrence.
c=chebtech2.vals2coeffs(values); n=size(c,1); d=zeros(size(c));
d(n-1,:)=2*(n-1)*c(n,:);
for k=n-2:-1:1
    d(k,:)=d(k+2,:)+2*k*c(k+1,:);
end
d(1,:)=d(1,:)/2;
derivative=mapDerivative.*chebtech2.coeffs2vals(d);
end

function c=thermalSineResponse(lambda,source,omega,t)
% Exact forward sine response, including rest transient and null directions.
% Separate the cancelling linear terms before evaluating near the origin.
z=lambda*t; theta=omega*t;
remainder=expm1(z)-z;
small=abs(z)<.1;
term=z(small).^2/2; remainder(small)=term;
for k=3:16
    term=term.*z(small)/k; remainder(small)=remainder(small)+term;
end
sinRemainder=theta-sin(theta);
if abs(theta)<.1
    term=theta^3/6; sinRemainder=term;
    for k=2:7
        term=-term*theta^2/((2*k)*(2*k+1)); sinRemainder=sinRemainder+term;
    end
end
c=source.*(omega*remainder+lambda*sinRemainder+2*omega*sin(theta/2)^2)./(lambda.^2+omega^2);
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
