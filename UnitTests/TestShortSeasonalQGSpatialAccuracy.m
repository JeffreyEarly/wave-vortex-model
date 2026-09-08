classdef TestShortSeasonalQGSpatialAccuracy < matlab.unittest.TestCase
    % Bounded spatial evidence for the existing seasonal authoring example.
    methods (TestMethodSetup)
        function examplePath(testCase)
            folder=fullfile(fileparts(fileparts(mfilename('fullpath'))),'Documentation','Examples');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (Test, TestTags="full")
        function physicalComparisonRetainsUnmatchedFourierContent(testCase)
            coarse=makeShortSeasonalQGModel();
            fine=makeShortSeasonalQGModel(gridSize=[36 36 65]);
            a=observe(coarse.wvt); b=observe(fine.wvt);
            equal=compare(a,b);
            testCase.verifyLessThan(max(equal.absolute),1e-10)
            % A mode outside the coarse band must contribute to the error.
            w=fine.wvt; column=find(w.kMode_wv(w.klNonzero)==9 & w.lMode_wv(w.klNonzero)==0,1);
            testCase.assertNotEmpty(column)
            state=w.coefficientState(); state.Ag_0(1,column)=1e-8;
            w.Ag_0=state.Ag_0;
            b=observe(w); difference=compare(a,b);
            delta=state; delta.Ag_q(:)=0; delta.Amda(:)=0;
            delta.Ag_0=state.Ag_0-coefficientOnGrid(coarse.wvt,w);
            inventory=w.quadraticDiagnostics(state=delta);
            measured=difference.absolute(difference.observable=="physicalEnergyNorm");
            testCase.verifyEqual(measured,sqrt(inventory.totalEnergy),RelTol=1e-9)
            testCase.verifyGreaterThan(difference.absolute(difference.observable=="ssh"),0)
        end
        function boundedRefinementEvidence(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            result=TestShortSeasonalQGSpatialAccuracy.runStudy(string(fixture.Folder));
            testCase.verifyTrue(all(isfinite(result.errors.absolute)))
            testCase.verifyEqual(result.configurations.mdaModeCount,2*ones(height(result.configurations),1))
            testCase.verifyLessThan(max(result.quadrature.absoluteDifference),1e-10)
            sampling=result.errors(result.errors.study=="sampling" & result.errors.observable=="qgpv",:);
            testCase.verifyLessThan(max(sampling.relative),1e-5)
            time=result.errors(result.errors.study=="time" & result.errors.observable=="qgpv",:);
            testCase.verifyLessThan(max(time.relative),1e-4)
            % Missing modal bandwidth must remain visible, even when energy
            % and sampling-grid differences are small.
            bandwidth=result.errors(result.errors.study=="bandwidth" & result.errors.observable=="qgpv",:);
            testCase.verifyGreaterThan(max(bandwidth.relative),.05)
        end
    end
    methods (Static)
        function errors=runEndpointConfirmation(folder)
            % Repeat only the three high-band cases implicated by #380.
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            originalPath=path;
            restorePath=onCleanup(@()path(originalPath));
            addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'Documentation','Examples'));
            grids=[257 385 513]; snapshots=cell(3,2);
            for i=1:3
                model=makeShortSeasonalQGModel(gridSize=[24 24 grids(i)],apvModeCount=84,timeStep=86400);
                w=model.wvt; w.removeForcing(w.forcingWithName('adaptive damping'));
                model.setupIntegrator(integratorType="exponential",initialStep=86400,maximumStep=86400,exponentialAdaptive=false);
                assert(isequal(w.activeEndpoint,[1;2]) && w.mdaModeCount==2);
                for j=1:2
                    model.integrateToTime(j*32*86400,shouldShowIntegrationDiagnostics=false);
                    assert(all(model.exponentialStatistics.acceptedStepSeconds==86400) && all(w.Amda==0));
                    snapshots{i,j}=observe(w);
                end
                fprintf('Endpoint confirmation Nz=%d complete\n',grids(i));
            end
            errors=table();
            for i=1:2
                for j=1:2
                    rows=compare(snapshots{i,j},snapshots{3,j});
                    rows.Nz=repmat(grids(i),height(rows),1); rows.referenceNz=repmat(513,height(rows),1); rows.day=repmat(32*j,height(rows),1);
                    errors=[errors;rows]; %#ok<AGROW>
                end
            end
            writetable(errors,fullfile(folder,'issue-353-endpoint-nonlinear.csv'));
            save(fullfile(folder,'endpoint-snapshots.mat'),'snapshots');
        end
        function result=runStudy(folder)
            arguments (Input)
                folder (1,1) string
            end
            if ~isfolder(folder), mkdir(folder); end
            % Nx=Ny, Nz, APV count, adaptive damping, actual step in days.
            matrix=[24 65 14 0 1;24 97 14 0 1;24 129 14 0 1; ...
                24 257 14 0 1;24 257 28 0 1;24 257 56 0 1;24 257 84 0 1; ...
                36 257 84 0 1;48 257 84 0 1; ...
                24 257 84 1 1;36 257 84 1 1;48 257 84 1 1; ...
                24 129 14 0 .5;48 257 84 0 .5;48 257 84 1 .5; ...
                24 385 84 0 1;24 513 84 0 1];
            snapshots=cell(size(matrix,1),2); configurations=struct([]); budgets=table(); spectra=table();
            for i=1:size(matrix,1)
                c=matrix(i,:); tic
                model=makeShortSeasonalQGModel(gridSize=[c(1) c(1) c(2)],apvModeCount=c(3),timeStep=c(5)*86400);
                w=model.wvt;
                if ~c(4), w.removeForcing(w.forcingWithName('adaptive damping')); end
                model.setupIntegrator(integratorType="exponential",initialStep=c(5)*86400,maximumStep=c(5)*86400,exponentialAdaptive=false);
                assert(isequal(w.activeEndpoint,[1;2]) && all(w.Amda==0));
                initial=observe(w);
                if i==1, referenceInitial=initial; end
                initialError=compare(initial,referenceInitial);
                assert(max(initialError.absolute)<1e-9,'Each grid must represent the same physical seed.');
                for j=1:2
                    model.integrateToTime(j*32*86400,shouldShowIntegrationDiagnostics=false);
                    assert(all(model.exponentialStatistics.acceptedStepSeconds==c(5)*86400));
                    assert(all(w.Amda==0),'This bounded case has zero MDA.');
                    snapshots{i,j}=observe(w);
                    b=snapshots{i,j}.budgets; b.caseId=repmat(i,height(b),1); b.day=repmat(j*32,height(b),1); budgets=[budgets;b]; %#ok<AGROW>
                    s=snapshots{i,j}.spectrum; s.caseId=repmat(i,height(s),1); s.day=repmat(j*32,height(s),1); spectra=[spectra;s]; %#ok<AGROW>
                end
                configurations=[configurations;struct(caseId=i,Nx=c(1),Ny=c(1),Nz=c(2),apvModeCount=c(3),mdaModeCount=w.mdaModeCount,adaptiveDamping=logical(c(4)),stepDays=c(5),apvGramError=w.apvGramError,quadraticAliasingError=w.quadraticAliasingError,seconds=toc)]; %#ok<AGROW>
                fprintf('Spatial case %d/%d: %gx%gx%g, APV %g, damping %g, %.1f s\n',i,size(matrix,1),c(1),c(1),c(2),c(3),c(4),toc);
            end
            % Final pairs in each family explicitly measure reference change.
            pairs=[7 17;16 17;1 3;2 3;4 7;5 7;6 7;7 9;8 9;10 12;11 12;3 13;9 14;12 15];
            study=["highBandSampling","highBandSampling","sampling","sampling","bandwidth","bandwidth","bandwidth","horizontal","horizontal","dampedSensitivity","dampedSensitivity","time","time","time"];
            errors=table();
            for i=1:size(pairs,1)
                for j=1:2
                    rows=compare(snapshots{pairs(i,1),j},snapshots{pairs(i,2),j});
                    rows.study=repmat(study(i),height(rows),1); rows.caseId=repmat(pairs(i,1),height(rows),1); rows.referenceId=repmat(pairs(i,2),height(rows),1); rows.day=repmat(j*32,height(rows),1);
                    errors=[errors;rows]; %#ok<AGROW>
                end
            end
            a=compare(snapshots{6,2},snapshots{7,2});
            b=compare(snapshots{6,2},snapshots{7,2},2*(2*257+1));
            quadrature=table(a.observable,abs(a.absolute-b.absolute),abs(a.relative-b.relative),VariableNames=["observable","absoluteDifference","relativeDifference"]);
            result=struct(configurations=struct2table(configurations),errors=errors,quadrature=quadrature,budgets=budgets,spectra=spectra);
            for name=string(fieldnames(result)).'
                writetable(result.(name),fullfile(folder,"issue-353-spatial-"+name+".csv"));
            end
            save(fullfile(folder,'spatial-snapshots.mat'),'snapshots','matrix');
        end
    end
end

function ag0=coefficientOnGrid(source,target)
[state,assessment]=source.coefficientStateForTransform(target);
assert(assessment.relativeFieldError<1e-9);
ag0=state.Ag_0;
end

function value=observe(w)
[psi,eta,q]=w.reconstructSpectralState();
[~,endpoint]=w.transformStateBack(w.Ag_q,w.Ag_0);
boundary=zeros(2,w.Nkl); boundary(:,w.klNonzero)=endpoint;
names=reshape(w.forcingNames(),1,[]); tendencies=struct([]);
for name=names
    tendencies=[tendencies w.coefficientTendency(excludingForcing=setdiff(names,name))]; %#ok<AGROW>
end
[inventory,spectrum]=w.quadraticDiagnostics(tendency=tendencies);
budgets=table(names.',VariableNames="process");
for name=string(fieldnames(inventory)).'
    if endsWith(name,"Tendency"), budgets.(name)=inventory.(name); inventory=rmfield(inventory,name); end
end
spectrum=table(w.kMode_wv(w.klNonzero),w.lMode_wv(w.klNonzero),spectrum.totalEnergy.',spectrum.potentialEnstrophy.',VariableNames=["kMode","lMode","energy","enstrophy"]);
value=struct(z=w.z,N2=w.N2,Lz=w.Lz,g=w.g,f=w.f,g0=w.g0,gd=w.gd,keys=[w.kMode_wv,w.lMode_wv],k=w.k,l=w.l,psi=psi,eta=eta,qgpv=q,ssh=w.f/w.g*psi(end,:),boundary=boundary,inventory=inventory,budgets=budgets,spectrum=spectrum);
end

function result=compare(a,b,count)
if nargin<3, count=2*max(length(a.z),length(b.z))+1; end
if length(a.z)>length(b.z), grid=a.z; else, grid=b.z; end
rule=WVInternal.qgVerticalOperators(grid,count);
Pa=WVInternal.qgVerticalInterpolation(a.z,rule.zQuadrature); Pb=WVInternal.qgVerticalInterpolation(b.z,rule.zQuadrature);
N2=Pb*b.N2; weights=rule.quadratureWeights;
keys=union(a.keys,b.keys,'rows'); factor=2*ones(1,size(keys,1)); factor(all(keys==0,2))=1;
[~,ia]=ismember(a.keys,keys,'rows'); [~,ib]=ismember(b.keys,keys,'rows');
A=fields(a,Pa,N2,rule.zQuadrature); B=fields(b,Pb,N2,rule.zQuadrature);
rows=struct([]); errorEnergy=0; referenceEnergy=0;
for name=["u","v","eta","qgpv","buoyancy","ssh","surfaceAnomaly","bottomAnomaly"]
    x=zeros(size(A.(name),1),size(keys,1)); y=x; x(:,ia)=A.(name); y(:,ib)=B.(name);
    metric=factor;
    if size(x,1)>1, metric=weights/b.Lz.*factor; end
    absolute=sqrt(sum(metric.*abs(x-y).^2,'all')); magnitude=sqrt(sum(metric.*abs(y).^2,'all'));
    rows=[rows;entry(name,absolute,magnitude)]; %#ok<AGROW>
    if ismember(name,["u","v","eta","ssh"])
        if name=="ssh", emetric=b.g/2*factor; else, emetric=weights/2.*factor; end
        if name=="eta", emetric=emetric.*N2; end
        errorEnergy=errorEnergy+sum(emetric.*abs(x-y).^2,'all'); referenceEnergy=referenceEnergy+sum(emetric.*abs(y).^2,'all');
    end
end
rows=[rows;entry("physicalEnergyNorm",sqrt(errorEnergy),sqrt(referenceEnergy))];
for name=string(fieldnames(b.inventory)).'
    magnitude=abs(b.inventory.(name));
    if name=="generalizedEnergy", magnitude=b.inventory.totalEnergy+abs(b.g0)*b.inventory.surfaceAnomalyVariance+abs(b.gd)*b.inventory.bottomAnomalyVariance; end
    rows=[rows;entry(name,abs(a.inventory.(name)-b.inventory.(name)),magnitude)]; %#ok<AGROW>
end
for name=["energy","enstrophy"]
    x=zeros(size(keys,1),1); y=x;
    [~,ka]=ismember(a.spectrum{:,1:2},keys,'rows'); [~,kb]=ismember(b.spectrum{:,1:2},keys,'rows');
    x(ka)=a.spectrum.(name); y(kb)=b.spectrum.(name);
    rows=[rows;entry(name+"Spectrum",sum(abs(x-y)),sum(abs(y)))]; %#ok<AGROW>
end
[~,ai,bi]=intersect(a.budgets.process,b.budgets.process,'stable');
a.budgets=a.budgets(ai,:); b.budgets=b.budgets(bi,:);
for name=string(b.budgets.Properties.VariableNames(2:end))
    for i=1:height(b.budgets)
        row=entry(b.budgets.process(i)+":"+name,abs(a.budgets.(name)(i)-b.budgets.(name)(i)),abs(b.budgets.(name)(i)));
        row.allowance=.01*row.referenceMagnitude+1e-6*sum(abs(b.budgets.(name)));
        rows=[rows;row]; %#ok<AGROW>
    end
end
result=struct2table(rows);
result.withinTolerance=result.absolute<=result.allowance;
end

function r=fields(s,P,N2,z)
r=struct(u=P*(-1i*reshape(s.l,1,[]).*s.psi),v=P*(1i*reshape(s.k,1,[]).*s.psi),eta=P*s.eta,qgpv=P*s.qgpv,ssh=s.ssh,surfaceAnomaly=s.boundary(1,:),bottomAnomaly=s.boundary(2,:));
r.buoyancy=-N2.*(r.eta-(1+z/s.Lz)*r.ssh);
end

function r=entry(name,absolute,magnitude)
relative=absolute/magnitude;
if absolute==0 && magnitude==0, relative=0; end
% Study-specific targets, not model defaults or universal acceptance gates.
relativeTolerance=NaN; absoluteTolerance=0;
switch name
    case "qgpv", relativeTolerance=.05; absoluteTolerance=1e-13;
    case "buoyancy", relativeTolerance=.001; absoluteTolerance=1e-10;
    case "ssh", relativeTolerance=.0001; absoluteTolerance=1e-8;
    case {"surfaceAnomaly","bottomAnomaly"}, relativeTolerance=.001; absoluteTolerance=1e-8;
    case "physicalEnergyNorm", relativeTolerance=.0001;
    case {"totalEnergy","generalizedEnergy","kineticEnergy","interiorPotentialEnergy","surfacePotentialEnergy"}, relativeTolerance=.0002;
    case {"surfaceAnomalyVariance","bottomAnomalyVariance"}, relativeTolerance=.002;
    case {"potentialEnstrophy","enstrophySpectrum"}, relativeTolerance=.1;
    case "energySpectrum", relativeTolerance=.001;
end
r=struct(observable=name,absolute=absolute,relative=relative,referenceMagnitude=magnitude,allowance=absoluteTolerance+relativeTolerance*magnitude);
end
