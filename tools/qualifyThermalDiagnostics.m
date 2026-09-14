function results = qualifyThermalDiagnostics(outputDirectory,options)
% Qualify physical inventories and startup-aware integrated process budgets.
%
% This bounded control uses constant and exponential stratification, both
% endpoints, signed MDA means and a high-degree pressure perturbation. Sampling
% is denser during initial adjustment. All powers come from the actual RHS
% process breakdown and use the same full physical metrics as diagnostics.
% Native reconstructed integrals provide the independent inventory check.
%
% - Topic: Developer utilities
% - Parameter outputDirectory: directory for machine-readable qualification evidence
% - Parameter options.dampingFactory: optional callback returning target-owned damping forces
% - Parameter options.shouldRunUnforced: include the unforced control; default true
% - Returns results: inventory errors, directional rates and budget reconciliation tables
arguments (Input)
    outputDirectory (1,1) string
    options.dampingFactory = []
    options.shouldRunUnforced (1,1) logical = true
end
arguments (Output)
    results (1,1) struct
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
root=fileparts(fileparts(mfilename('fullpath'))); previous=path; cleanup=onCleanup(@()path(previous));
addpath(fullfile(root,'UnitTests','Fixtures'));
inventories=table(); directional=table(); budgets=table();
names=["totalEnergy","potentialEnstrophy","surfaceAnomalyVariance","bottomAnomalyVariance"];
cases=[false true]; if ~options.shouldRunUnforced, cases=true; end
for a=[0 1/1300]
    base=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[12 12 129],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=17,mdaModeCount=4,kappa_z=.01,shouldCheckQuadraticAliasing=true);
    for forced=cases
        w=WVTransformFreeSurfaceThermalQG(scientificState=base.scientificState);
        thermalManufacturedState(w,[2 3 4],1e4); w.Amda=[.1;-.2;.3;-.1];
        % A resolved high-degree perturbation makes the initial adjustment observable.
        c=zeros(w.thermalModeCount,1); c(end)=.5;
        w.Ath(:,1)=w.Ath(:,1)+w.polynomialToThermal(:,:,1)*c;
        if ~forced, w=w.withDiffusivity(0); end
        w.addForcing(WVNonlinearAdvection(w));
        if forced
            w.addForcing(WVSeasonalSurfaceAnomalyForcing(w,pattern=sin(2*pi*w.Y(:,:,1)/w.Ly),amplitude=1e-5,period=20000,phase=pi/2));
            w.addForcing(WVBottomFrictionQuadratic(w,Cd=1e-3));
            if ~isempty(options.dampingFactory), w.addForcing(options.dampingFactory(w)); end
        end
        [~,~,processes]=w.coefficientTendency();
        d=w.quadraticDiagnostics(tendency=processes.tendencies);
        direct=physicalIntegral(w);
        for name=names
            relative=abs(d.(name)-direct.(name))/max(abs(direct.(name)),realmin);
            inventories=[inventories;table(a,forced,name,relative,VariableNames={'inverseScale','forced','inventory','relativeError'})]; %#ok<AGROW>
        end
        original=w.coefficientState();
        for p=1:numel(processes.labels)
            tendency=processes.tendencies(p);
            % Central differentiation of a quadratic is exact apart from arithmetic.
            scale=max(norm(tendency.Ath,'fro')/max(norm(original.Ath,'fro'),realmin),norm(tendency.Amda)/max(norm(original.Amda),realmin));
            epsilon=1e-3/max(scale,realmin);
            assign(w,combineState(original,tendency,epsilon)); positive=physicalIntegral(w);
            assign(w,combineState(original,tendency,-epsilon)); negative=physicalIntegral(w);
            assign(w,original);
            for name=names
                reference=(positive.(name)-negative.(name))/(2*epsilon);
                actual=d.(name+"Tendency")(p);
                allowance=1e-9*max(abs(reference),abs(d.(name))*scale)+1e-25;
                directional=[directional;table(a,forced,processes.labels(p),name,actual,reference,abs(actual-reference)/allowance,VariableNames={'inverseScale','forced','process','inventory','actualRate','referenceRate','errorRatio'})]; %#ok<AGROW>
            end
        end
        model=WVModel(w);
        model.setupIntegrator(integratorType="exponential",initialStep=25,maximumStep=25,exponentialAdaptive=false);
        times=unique([0:5:100,100:50:1000,1000:100:20000]).';
        values=zeros(numel(times),numel(names)); powers=zeros(numel(times),numel(names),numel(processes.labels));
        for j=1:numel(times)
            if j>1, model.integrateToTime(times(j),shouldShowIntegrationDiagnostics=false); end
            [~,~,current]=w.coefficientTendency();
            assert(isequal(current.labels,processes.labels),'Process labels changed during a fixed configuration.');
            d=w.quadraticDiagnostics(tendency=current.tendencies);
            for k=1:numel(names)
                values(j,k)=d.(names(k)); powers(j,k,:)=d.(names(k)+"Tendency");
            end
        end
        coarse=unique([1:2:numel(times),numel(times)]);
        for k=1:numel(names)
            fineIntegral=reshape(trapz(times,powers(:,k,:),1),1,[]);
            coarseIntegral=reshape(trapz(times(coarse),powers(coarse,k,:),1),1,[]);
            change=values(end,k)-values(1,k);
            scale=max([abs(values(1,k)),abs(change),sum(abs(fineIntegral)),realmin]);
            fineResidual=abs(change-sum(fineIntegral))/scale;
            coarseResidual=abs(change-sum(coarseIntegral))/scale;
            startup=reshape(trapz(times(times<=100),powers(times<=100,k,:),1),1,[]);
            budgets=[budgets;table(a,forced,names(k),change,sum(fineIntegral),fineResidual,coarseResidual,sum(startup),VariableNames={'inverseScale','forced','inventory','change','integratedPower','fineResidual','coarseResidual','first100SecondsPower'})]; %#ok<AGROW>
        end
        trajectory=array2table([times,values],VariableNames=["time",names]);
        writetable(trajectory,fullfile(outputDirectory,sprintf('trajectory-%.0f-%d.csv',a*1300,forced)));
        work=table();
        for p=1:numel(processes.labels)
            for k=1:numel(names)
                work=[work;table(processes.labels(p),names(k),trapz(times,powers(:,k,p)),VariableNames={'process','inventory','integratedPower'})]; %#ok<AGROW>
            end
        end
        writetable(work,fullfile(outputDirectory,sprintf('work-%.0f-%d.csv',a*1300,forced)));
    end
end
writetable(inventories,fullfile(outputDirectory,'inventories.csv'));
writetable(directional,fullfile(outputDirectory,'directional-rates.csv'));
writetable(budgets,fullfile(outputDirectory,'budgets.csv'));
results=struct(inventories=inventories,directional=directional,budgets=budgets);
assert(all(inventories.relativeError<2e-8),'Independent inventories did not converge.');
assert(all(directional.errorRatio<1),'Independent directional powers failed.');
assert(all(budgets.fineResidual<2e-5),'Fine-sampling process budget did not reconcile.');
assert(all(budgets.fineResidual<=.4*budgets.coarseResidual+1e-9),'Process budget did not converge with temporal sampling.');
end
function state=combineState(state,direction,h)
state.Ath=state.Ath+h*direction.Ath; state.Amda=state.Amda+h*direction.Amda;
end
function assign(w,state)
w.Ath=state.Ath; w.Amda=state.Amda;
end
function d=physicalIntegral(w)
f=w.reconstructFields(["u","v","eta","qgpv","ssh","endpointAnomalies"]);
integ=@(v)sum(w.verticalQuadratureWeights.*squeeze(mean(v,[1 2])));
d=struct(totalEnergy=.5*integ(f.u.^2+f.v.^2+reshape(w.N2,1,1,[]).*f.eta.^2)+.5*w.g*mean(f.ssh.^2,'all'), ...
    potentialEnstrophy=.5*integ(f.qgpv.^2),surfaceAnomalyVariance=.5*mean(f.endpointAnomalies(:,:,1).^2,'all'),bottomAnomalyVariance=.5*mean(f.endpointAnomalies(:,:,2).^2,'all'));
end
