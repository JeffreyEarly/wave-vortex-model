function results = qualifyThermalConstruction(outputDirectory)
% Compare runtime thermal construction against the preserved research harness.
% This is a construction/reconstruction assessment, not WVModel integration.
arguments
    outputDirectory (1,1) string
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
sourceRoot=fileparts(fileparts(mfilename('fullpath')));
oldPath=path; cleanup=onCleanup(@()path(oldPath));
addpath(fullfile(sourceRoot,'Documentation','Experiments','Diffusion'));
baseline=TestCompleteThermalModes.runCompleteThermalStudy(fullfile(outputDirectory,'prototype'));
D=4000; N20=(5.2e-3)^2; a=1/1300; kh=2*pi/100e3; f=2*7.2921e-5*sind(24); g=9.81; kappa=1e-5;
omega=2*pi/(365.25*86400); amplitude=10*pi/(365.25*86400);
z=baseline.z; weights=baseline.weights;
rows=table(); evidence=table();
for n=[129 257 385]
    page=WVInternal.buildThermalPage(n,D,N20,a,kh,f,g,2049);
    r=WVInternal.thermalPolynomialFields(z,n,D,N20,a,kh,f,g);
    C=page.thermalToPolynomial; rates=kappa*page.rates; source=amplitude*page.sourceEndpoint(:,1);
    for iTime=1:numel(baseline.options.days)
        day=baseline.options.days(iTime); time=day*86400;
        % Scalar analytic convolution is only an assessment driver; T3 owns evolution.
        amplitudes=source.*(omega*exp(rates*time)-rates*sin(omega*time)-omega*cos(omega*time))./(rates.^2+omega^2);
        c=C*amplitudes;
        physical=struct(q=r.qgpv*c,b=r.buoyancy*c,ssh=r.ssh*c,endpoint=r.eta_i([1 end],:)*c);
        endpointFields=WVInternal.thermalPolynomialFields([0;-D],n,D,N20,a,kh,f,g);
        physical.endpoint=endpointFields.eta_i*c;
        physical.energy=[sqrt(weights)*kh.*(r.psi*c);sqrt(weights.*(N20*exp(2*a*z))).*(r.eta*c);sqrt(g)*(r.ssh*c)];
        original=baseline.states{find(baseline.options.counts==n,1),iTime};
        reference=baseline.referenceStates{iTime};
        rows=[rows;compare(physical,original,reference,weights,D,n,day)]; %#ok<AGROW>
    end
    sn=-cos(pi*(0:n-1)'/(n-1)); zn=log1p((sn-1)*(-expm1(-D*a))/2)/a;
    native=WVInternal.thermalPolynomialFields(zn,n,D,N20,a,kh,f,g);
    derivative=WVInternal.thermalChebyshev(native.buoyancy*c,"derivative",depth=D,inverseScale=a);
    gradientError=norm(derivative-native.buoyancyZ*c)/norm(native.buoyancyZ*c);
    evidence=[evidence;table(n,page.diagnostics.eigenResidual,page.diagnostics.roundTrip,page.diagnostics.condition,max(real(rates)),amplitude*max(page.diagnostics.sourceQGPV),amplitude*page.diagnostics.endpointSourceResidual,gradientError,VariableNames={'count','eigenResidual','inverseResidual','condition','maximumGrowth','sourceQGPV','sourceEndpointResidual','nativeDerivativeRelative'})]; %#ok<AGROW>
end
% Fixed-space assembly refinement is evaluated as a physical-state difference.
n=257; fine=WVInternal.buildThermalPage(n,D,N20,a,kh,f,g,4097); r=WVInternal.thermalPolynomialFields(z,n,D,N20,a,kh,f,g);
coarse=WVInternal.buildThermalPage(n,D,N20,a,kh,f,g,2049);
refinement=table();
for iTime=1:numel(baseline.options.days)
    day=baseline.options.days(iTime); t=day*86400; states=cell(1,2);
    for iPage=1:2
        if iPage==1, p=coarse; else, p=fine; end
        lambda=kappa*p.rates;
        amp=amplitude*p.sourceEndpoint(:,1).*(omega*exp(lambda*t)-lambda*sin(omega*t)-omega*cos(omega*t))./(lambda.^2+omega^2);
        c=p.thermalToPolynomial*amp;
        e=WVInternal.thermalPolynomialFields([0;-D],n,D,N20,a,kh,f,g);
        states{iPage}=struct(q=r.qgpv*c,b=r.buoyancy*c,ssh=r.ssh*c,endpoint=e.eta_i*c,energy=[sqrt(weights)*kh.*(r.psi*c);sqrt(weights.*(N20*exp(2*a*z))).*(r.eta*c);sqrt(g)*(r.ssh*c)]);
    end
    refinement=[refinement;compare(states{1},states{2},baseline.referenceStates{iTime},weights,D,n,day)]; %#ok<AGROW>
end
writetable(rows,fullfile(outputDirectory,'runtime-construction.csv'));
writetable(evidence,fullfile(outputDirectory,'runtime-evidence.csv'));
writetable(refinement,fullfile(outputDirectory,'assembly-refinement.csv'));
results=struct(comparison=rows,evidence=evidence,assemblyRefinement=refinement);
assert(all(rows.prototypeRatio<.2),'Runtime construction differs from the preserved prototype.');
assert(all(rows.referenceRatio(rows.count>=257)<=1),'Previously qualified thermal response failed.');
assert(any(rows.referenceRatio(rows.count==129)>1),'The historical low-resolution failure must remain visible.');
assert(all(refinement.prototypeRatio<.2),'Assembly reference is insufficiently converged.');
assert(all(evidence.nativeDerivativeRelative<1e-9),'Mapped native derivative failed.');
end

function rows=compare(actual,original,reference,w,D,n,day)
names=["qgpv","buoyancy","ssh","surfaceAnomaly","bottomAnomaly","physicalEnergyNorm"]';
magnitude=norms(reference,w,D);
allowance=[1e-13;1e-10;1e-8;1e-8;1e-8;0]+[.05;.001;.0001;.001;.001;.0001].*magnitude;
prototypeError=difference(actual,original,w,D); referenceError=difference(actual,reference,w,D);
rows=table(repmat(n,6,1),repmat(day,6,1),names,prototypeError,referenceError,allowance,prototypeError./allowance,referenceError./allowance,VariableNames={'count','day','observable','prototypeError','referenceError','allowance','prototypeRatio','referenceRatio'});
end
function v=difference(a,b,w,D)
names=fieldnames(a); d=struct();
for k=1:numel(names), d.(names{k})=a.(names{k})-b.(names{k}); end
v=norms(d,w,D);
end
function v=norms(a,w,D)
v=[sqrt(sum(w.*abs(a.q).^2)/(2*D));sqrt(sum(w.*abs(a.b).^2)/(2*D));abs(a.ssh)/sqrt(2);abs(a.endpoint)/sqrt(2);norm(a.energy)/2];
end
