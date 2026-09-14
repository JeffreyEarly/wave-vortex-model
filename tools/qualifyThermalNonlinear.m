function results=qualifyThermalNonlinear(outputDirectory)
% Bounded nonlinear interaction, invariant, refinement and RHS cost evidence.
arguments
    outputDirectory (1,1) string
end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
root=fileparts(fileparts(mfilename('fullpath'))); oldPath=path; cleanup=onCleanup(@()path(oldPath));
addpath(fullfile(root,'UnitTests','Fixtures'));
metadata=struct(matlab=version,architecture=computer('arch'),threads=maxNumCompThreads,precision="double",horizontalGrid=[12 12],warmupCalls=1,timedCalls=5);
writeJSON(fullfile(outputDirectory,'environment.json'),metadata);
interactions=table(); runs=table(); costs=table(); sampling=table(); bandwidth=table();
for a=[0 1/1300]
    finalFields=cell(1,3);
    for n=[17 25 33]
        w=construct(n,a,65); writeJSON(fullfile(outputDirectory,sprintf('construction-%d-%.0f.json',n,a*1300)),w.constructionAssessment.quadraticProducts); modes=thermalManufacturedState(w,[2 n-1 4],1000);
        [actual,~,timing]=w.nonlinearCoefficientTendency();
        ref=thermalConvolutionReference(w,modes,1025); fine=thermalConvolutionReference(w,modes,2049);
        adapter=w.linearEvolutionData(); scale=adapter.physicalErrorNorms(adapter.toModes(fine));
        allowance=[1e-22 1e-19 1e-19 1e-15 1e-15]+1e-8*scale;
        discrepancy=adapter.physicalErrorNorms(adapter.toModes(difference(actual,fine)));
        control=adapter.physicalErrorNorms(adapter.toModes(difference(ref,fine)));
        interactions=[interactions;table(a,n,max(discrepancy./allowance),max(control./allowance),VariableNames={'inverseScale','count','errorRatio','referenceRatio'})]; %#ok<AGROW>
        % Warm cached work, then report medians without interpreting whole-model speed.
        durations=zeros(5,3);
        for j=1:5
            [~,~,d]=w.nonlinearCoefficientTendency(); durations(j,:)=[d.reconstructionSeconds d.productSeconds d.projectionSeconds];
        end
        med=median(durations,1);
        costs=[costs;table(a,n,w.nonlinearQuadratureCount,med(1),med(2),med(3),timing.scratchBytesEstimate,timing.radiusGroups,VariableNames={'inverseScale','count','productCount','reconstructionSeconds','productSeconds','projectionSeconds','scratchBytesEstimate','radiusGroups'})]; %#ok<AGROW>
        % Native sampling does not enter product evaluation: compare fixed scientific maps.
        other=construct(n,a,129); thermalManufacturedState(other,[2 n-1 4],1000);
        otherTendency=other.nonlinearCoefficientTendency();
        nativeDifference=adapter.physicalErrorNorms(adapter.toModes(difference(actual,otherTendency)));
        sampleRatio=max(nativeDifference./allowance);
        % Compare reconstructed near-surface buoyancy-gradient tendency on each native grid.
        w.Ath=actual.Ath; other.Ath=otherTendency.Ath;
        gradient=w.diffZ(w.buoyancy); otherGradient=other.diffZ(other.buoyancy);
        common=otherGradient(:,:,1:2:end); gradientRelative=norm(gradient(:)-common(:))/max(norm(common(:)),realmin);
        sampling=[sampling;table(a,n,sampleRatio,gradientRelative,VariableNames={'inverseScale','count','nativeSamplingRatio','gradientRelative'})]; %#ok<AGROW>
        steps=5000; if n==17, steps=[10000 5000]; end
        for h=steps
            w=construct(n,a,65); thermalManufacturedState(w,[2 3 4],1e4); w.Amda=[.1;-.2;.3;-.1];
            initial=w.coefficientState(); before=invariants(w);
            w.addForcing(WVNonlinearAdvection(w)); model=WVModel(w);
            model.setupIntegrator(integratorType="exponential",initialStep=h,maximumStep=h,exponentialAdaptive=false);
            model.integrateToTime(1e5,shouldShowIntegrationDiagnostics=false);
            if h==5000, finalFields{find([17 25 33]==n,1)}=physicalFields(w); end
            after=invariants(w); drift=abs(after-before)./max(abs(before),realmin);
            change=norm(w.Ath-initial.Ath,'fro')/norm(initial.Ath,'fro');
            runs=[runs;table(a,n,h,model.exponentialStatistics.acceptedSteps,change,drift(1),drift(2),drift(3),drift(4),norm(w.Amda-initial.Amda),VariableNames={'inverseScale','count','step','accepted','stateChange','energyDrift','qVarianceDrift','surfaceVarianceDrift','bottomVarianceDrift','meanChange'})]; %#ok<AGROW>
        end
    end
    counts=[17 25];
    for i=1:2
        metrics=physicalDifference(finalFields{i},finalFields{3},w);
        bandwidth=[bandwidth;table(a,counts(i),metrics(1),metrics(2),metrics(3),metrics(4),metrics(5),VariableNames={'inverseScale','count','qRelative','buoyancyRelative','surfaceRelative','bottomRelative','surfaceGradientRelative'})]; %#ok<AGROW>
    end
end
writetable(interactions,fullfile(outputDirectory,'interactions.csv'));
writetable(runs,fullfile(outputDirectory,'nonlinear-runs.csv'));
writetable(costs,fullfile(outputDirectory,'rhs-cost.csv'));
writetable(sampling,fullfile(outputDirectory,'sampling-refinement.csv'));
writetable(bandwidth,fullfile(outputDirectory,'bandwidth-refinement.csv'));
results=struct(interactions=interactions,runs=runs,costs=costs,sampling=sampling,bandwidth=bandwidth);
assert(all(interactions.errorRatio<=1) && all(interactions.referenceRatio<=.2),'Manufactured interactions failed.');
assert(all(sampling.nativeSamplingRatio<=1),'Native sampling changed the product projection.');
assert(all(runs.stateChange>.001),'Nonlinear study did not evolve appreciably.');
assert(all(runs.energyDrift(runs.step==5000)<1e-6),'Fine-step energy drift failed.');
end
function w=construct(n,a,sampling)
w=WVTransformFreeSurfaceThermalQG.fromStratification([5e5 5e5 1000],[12 12 sampling],N2Function=@(z)1e-4*exp(2*a*z),thermalModeCount=n,mdaModeCount=4,kappa_z=0,shouldCheckQuadraticAliasing=true);
end
function value=invariants(w)
f=w.reconstructFields(["qgpv","endpointAnomalies"]);
weights=reshape(w.verticalQuadratureWeights/w.Lz,1,1,[]);
value=[w.totalEnergy,mean(sum(weights.*f.qgpv.^2,3),'all'),mean(f.endpointAnomalies(:,:,1).^2,'all'),mean(f.endpointAnomalies(:,:,2).^2,'all')];
end
function c=difference(a,b)
c=struct(Ath=a.Ath-b.Ath,Amda=a.Amda-b.Amda);
end

function f=physicalFields(w)
f=w.reconstructFields(["qgpv","buoyancy","endpointAnomalies"]);
f.gradient=w.diffZ(f.buoyancy);
end
function values=physicalDifference(a,b,w)
weights=reshape(w.verticalQuadratureWeights/w.Lz,1,1,[]);
rms=@(x)sqrt(mean(sum(weights.*abs(x).^2,3),'all'));
values=[rms(a.qgpv-b.qgpv)/rms(b.qgpv),rms(a.buoyancy-b.buoyancy)/rms(b.buoyancy),0,0,0];
for i=1:2
    delta=a.endpointAnomalies(:,:,i)-b.endpointAnomalies(:,:,i); ref=b.endpointAnomalies(:,:,i);
    values(i+2)=norm(delta(:))/norm(ref(:));
end
upper=w.z>-.1*w.Lz; delta=a.gradient(:,:,upper)-b.gradient(:,:,upper); ref=b.gradient(:,:,upper);
values(5)=norm(delta(:))/norm(ref(:));
end

function writeJSON(file,value)
fid=fopen(file,'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
