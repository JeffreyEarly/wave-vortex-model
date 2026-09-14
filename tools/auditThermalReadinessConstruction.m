function results=auditThermalReadinessConstruction(outputDirectory,options)
% Audit complete thermal pages on the bounded readiness Fourier inventories.
%
% The response check reconstructs the original weak generator independently
% and compares the runtime page with a direct augmented matrix exponential.
% Both endpoint source columns are included. The optional balanced solve is
% diagnostic evidence of the construction failure; it is never a fallback.
% Radius checks invoke buildThermalPage with its unchanged acceptance guards.
% They do not replace native-sampling, MDA or nonlinear factory qualification.
%
% - Topic: Developer utilities
% - Parameter outputDirectory: new destination for reproducible audit tables
% - Parameter options.sections: response and/or radii
% - Parameter options.horizontalCounts: selected square grids from 32,64,96
% - Parameter options.thermalCounts: selected complete spaces from 257,385
% - Parameter options.assemblyCount: fixed assembly count for the radius audit
% - Parameter options.shouldEvaluateBalanced: also record the original balanced eigenbasis diagnostic
% - Returns results: measurements, fixed physical configuration and requested audit scope
arguments (Input)
    outputDirectory (1,1) string
    options.sections (1,:) string {mustBeMember(options.sections,["response","radii"])} = ["response","radii"]
    options.horizontalCounts (1,:) double {mustBeMember(options.horizontalCounts,[32 64 96])} = [32 64 96]
    options.thermalCounts (1,:) double {mustBeMember(options.thermalCounts,[257 385])} = [257 385]
    options.assemblyCount (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.assemblyCount,385)} = 2057
    options.shouldEvaluateBalanced (1,1) logical = true
end
arguments (Output)
    results (1,1) struct
end
if isfolder(outputDirectory) && ~isempty(dir(fullfile(outputDirectory,'*.csv')))
    error('WV:ReadinessConstructionOutput','Use a new output directory so prior construction evidence remains intact.');
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
physics=struct(horizontalDomain=[5e5 5e5],depth=4000,N20=(5.2e-3)^2,inverseScale=1/1300,latitude=24,f=2*7.2921e-5*sind(24),g=9.81,kappa_z=1e-5,time=3600,sourceAmplitude=1e-7);
results=struct(physics=physics,options=options,response=table(),refinement=table(),pages=table());
if ismember("response",options.sections)
    [results.response,results.refinement]=responseAudit(physics,options.shouldEvaluateBalanced);
    writetable(results.response,fullfile(outputDirectory,'response.csv'));
    writetable(results.refinement,fullfile(outputDirectory,'assembly-refinement.csv'));
end
if ismember("radii",options.sections)
    results.pages=radiusAudit(physics,options,outputDirectory);
end
save(fullfile(outputDirectory,'audit.mat'),'results');
end

function [rows,refinement]=responseAudit(p,shouldEvaluateBalanced)
n=257; kh=13*2*pi/p.horizontalDomain(1); quadratures=[2057 4113];
rows=table(); states=cell(1,2);
initial=(1+.2i*cos((0:n-1)')) ./ (1+(0:n-1)').^3;
fine=independentAssembly(n,kh,quadratures(2),p);
initial=initial/norm(fine.energyFactor*initial);
for j=1:numel(quadratures)
    assembly=independentAssembly(n,kh,quadratures(j),p);
    A=assembly.generator; Q=assembly.coordinates; R=assembly.energyFactor;
    load=[-p.f*ones(n,1),p.f*(-1).^(0:n-1)'];
    augmented=[p.kappa_z*A,p.sourceAmplitude*Q'*load;zeros(2,n+2)];
    reference=expm(p.time*augmented);
    referenceOperator=reference(1:n,1:n);
    referenceState=Q*[referenceOperator*(R*initial),reference(1:n,n+1:n+2)];
    page=WVInternal.buildThermalPage(n,p.depth,p.N20,p.inverseScale,kh,p.f,p.g,quadratures(j));
    rates=p.kappa_z*page.rates;
    C=page.thermalToPolynomial; inverse=page.polynomialToThermal;
    operator=R*(C.*exp(p.time*rates).')*inverse/R;
    source=p.sourceAmplitude*page.sourceEndpoint;
    states{j}=C*[exp(p.time*rates).*(inverse*initial),integralFactors(rates,p.time).*source];
    row=struct(assemblyCount=quadratures(j),method="runtime nobalance",status="passed",condition=page.diagnostics.condition,inverseResidual=page.diagnostics.roundTrip,eigenResidual=page.diagnostics.eigenResidual,maximumUnitDiffusivityRate=max(real(page.rates)),operatorRelativeError=norm(operator-referenceOperator,'fro')/norm(referenceOperator,'fro'),homogeneousRelativeError=norm(R*(states{j}(:,1)-referenceState(:,1)))/norm(R*referenceState(:,1)),surfaceSourceRelativeError=norm(R*(states{j}(:,2)-referenceState(:,2)))/norm(R*referenceState(:,2)),bottomSourceRelativeError=norm(R*(states{j}(:,3)-referenceState(:,3)))/norm(R*referenceState(:,3)),endpointSourceResidual=page.diagnostics.endpointSourceResidual,conjugateInvolution=isequal(page.conjugateDirection(page.conjugateDirection),(1:n)'),identifier="",message="");
    rows=[rows;struct2table(row)]; %#ok<AGROW>
    if shouldEvaluateBalanced
        balanced=row; balanced.method="diagnostic balance";
        balanced.homogeneousRelativeError=NaN; balanced.surfaceSourceRelativeError=NaN; balanced.bottomSourceRelativeError=NaN; balanced.endpointSourceResidual=NaN; balanced.conjugateInvolution=false;
        try
            [V,lambda]=eig(A,'balance','vector'); V=V./vecnorm(V); left=V\eye(n);
            balanced.condition=cond(V); balanced.inverseResidual=norm(left*V-eye(n),'fro')/sqrt(n);
            balanced.eigenResidual=norm(A*V-V.*lambda.','fro')/(norm(A,'fro')*norm(V,'fro'));
            balanced.maximumUnitDiffusivityRate=max(real(lambda));
            modal=(V.*exp(p.time*p.kappa_z*lambda).')*left;
            balanced.operatorRelativeError=norm(modal-referenceOperator,'fro')/norm(referenceOperator,'fro');
            if ~isfinite(balanced.operatorRelativeError) || balanced.operatorRelativeError>1e-10, balanced.status="inaccurate propagator"; end
        catch exception
            balanced.status="failed"; balanced.identifier=string(exception.identifier); balanced.message=string(exception.message); balanced.operatorRelativeError=Inf;
        end
        rows=[rows;struct2table(balanced)]; %#ok<AGROW>
    end
end
refinement=table(); labels=["homogeneous","surface source","bottom source"];
for column=1:3
    error=physicalNorms(states{1}(:,column)-states{2}(:,column),fine,p,kh);
    scale=physicalNorms(states{2}(:,column),fine,p,kh);
    names=["qgpv","buoyancy","speed","ssh","surfaceAnomaly","bottomAnomaly","physicalEnergy"]';
    refinement=[refinement;table(repmat(labels(column),7,1),names,error,scale,error./max(scale,realmin),VariableNames={'response','observable','absoluteError','referenceNorm','relativeError'})]; %#ok<AGROW>
end
end

function rows=radiusAudit(p,o,outputDirectory)
rows=table();
for horizontalCount=o.horizontalCounts
    horizontal=WVGeometryDoublyPeriodic(p.horizontalDomain,[horizontalCount horizontalCount],Nz=1,shouldAntialias=true,shouldExcludeNyquist=true,shouldExcludeConjugates=true,conjugateDimension=2);
    kh=hypot(horizontal.k,horizontal.l); radii=uniquetol(kh(kh>0),1e-12,'DataScale',max(kh));
    for thermalCount=o.thermalCounts
        for index=1:numel(radii)
            clock=tic;
            row=struct(horizontalCount=horizontalCount,thermalCount=thermalCount,radiusIndex=index,radiusCount=numel(radii),kh=radii(index),assemblyCount=o.assemblyCount,status="passed",condition=NaN,inverseResidual=NaN,eigenResidual=NaN,maximumUnitDiffusivityRate=NaN,endpointSourceResidual=NaN,seconds=NaN,identifier="",message="");
            try
                page=WVInternal.buildThermalPage(thermalCount,p.depth,p.N20,p.inverseScale,radii(index),p.f,p.g,o.assemblyCount);
                row.condition=page.diagnostics.condition; row.inverseResidual=page.diagnostics.roundTrip; row.eigenResidual=page.diagnostics.eigenResidual;
                row.maximumUnitDiffusivityRate=max(real(page.rates)); row.endpointSourceResidual=page.diagnostics.endpointSourceResidual;
            catch exception
                row.status="failed"; row.identifier=string(exception.identifier); row.message=string(exception.message);
            end
            row.seconds=toc(clock); rows=[rows;struct2table(row)]; %#ok<AGROW>
            writetable(rows,fullfile(outputDirectory,'radius-pages.csv'));
            fprintf('T10 construction Nxy=%d thermal=%d radius=%d/%d status=%s seconds=%.3g\n',horizontalCount,thermalCount,index,numel(radii),row.status,row.seconds);
        end
    end
end
end

function assembly=independentAssembly(n,kh,count,p)
[x,weights]=legpts(count); z=p.depth*(x-1)/2; weights=weights(:)*p.depth/2;
r=WVInternal.thermalPolynomialFields(z,n,p.depth,p.N20,p.inverseScale,kh,p.f,p.g);
N2=p.N20*exp(2*p.inverseScale*z);
fields=[sqrt(weights)*kh.*r.psi;sqrt(weights.*N2).*r.eta;sqrt(p.g)*r.ssh];
[~,R]=qr(fields,0); Q=eye(n)/R;
generator=(r.etaZ*Q)'*(weights.*(r.buoyancyZ*Q));
endpoint=WVInternal.thermalPolynomialFields([0;-p.depth],n,p.depth,p.N20,p.inverseScale,kh,p.f,p.g);
assembly=struct(coordinates=Q,energyFactor=R,generator=generator,fields=r,endpoint=endpoint,weights=weights);
end

function factor=integralFactors(rates,time)
argument=time*rates; factor=time*ones(size(rates)); nonzero=argument~=0;
factor(nonzero)=time*expm1(argument(nonzero))./argument(nonzero);
end

function values=physicalNorms(c,assembly,p,kh)
r=assembly.fields; weights=assembly.weights; endpoint=assembly.endpoint.eta_i*c;
values=[sqrt(sum(weights.*abs(r.qgpv*c).^2)/p.depth);sqrt(sum(weights.*abs(r.buoyancy*c).^2)/p.depth);kh*sqrt(sum(weights.*abs(r.psi*c).^2)/p.depth);abs(r.ssh*c);abs(endpoint);norm(assembly.energyFactor*c)];
end
