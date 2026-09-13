function auditValidationSnapshots(workFolder,options)
% Independent quadrature, source parity, physical-energy and spectrum controls.
arguments
    workFolder (1,1) string {mustBeFolder}
    options.scenarios string = ["waves","balanced","mixed"]
end
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
addpath(fullfile(fileparts(folder),'nonlinear-study'));
for scenario=options.scenarios
    resolution=struct([]); energyRows=struct([]); spectralRows=struct([]);
    profile="exponential"; if scenario=="waves", profile="constant"; end
    data=load(fullfile(workFolder,profile+"-inventory1.mat"));
    w=WVTransformFreeSurfaceBoussinesq(data.scientificState); w.t0=-17; w.addForcing(WVNonlinearAdvection(w));
    data=load(fullfile(workFolder,scenario+"-baseline.mat")); result=data.result;
    energy=prepareValidationEnergy(w,[32 32 513]); energyControl=prepareValidationEnergy(w,[48 48 769]);
    nativeEnergy=prepareValidationEnergy(w,[w.Nx w.Ny w.Nz]);
    original=manuscriptEvolutionOperators(w,profile,padding=1);
    selected=unique([1,ceil(numel(result.states)/2),numel(result.states)]);
    for j=1:numel(result.states)
        state=result.states{j}; time=327+result.comparisonTimes(j);
        e=energy(time,state); change=NaN; parity=NaN;
        if ismember(j,selected)
            change=abs(energyControl(time,state)-e);
            for name=string(fieldnames(state)).', w.(name)=state.(name); end
            w.t=time;
            actual=w.coefficientTendency(); oracle=original.rhs(time,state); parity=0;
            for name=string(fieldnames(actual)).'
                parity=max(parity,norm(actual.(name)-oracle.(name),'fro')/(1e-8*norm(actual.(name),'fro')+1e-18));
            end
            assert(parity<=1,'Native manuscript oracle differs from production.');
            modelEnergy=w.nonlinearEnergy();
            assert(abs(nativeEnergy(time,state)-modelEnergy.totalEnergy)<1e-12*modelEnergy.totalEnergy,'Energy quadrature does not recover native inventory.');
            p=WVInternal.prepareBoussinesqRHSAssessment(w);
            candidate=WVInternal.evaluateBoussinesqRHSAssessment(p,[8 8 129]);
            reference=WVInternal.evaluateBoussinesqRHSAssessment(p,[16 16 257],crossingOrder=16);
            controls={WVInternal.evaluateBoussinesqRHSAssessment(p,[24 24 257],crossingOrder=16),WVInternal.evaluateBoussinesqRHSAssessment(p,[16 16 385],crossingOrder=32)};
            check=WVInternal.assessBoussinesqRHSResolution(candidate,reference,controls);
            for k=1:height(check.rows)
                row=table2struct(check.rows(k,:)); row.scenario=scenario; row.time=time; row.status=check.status;
                if isempty(resolution), resolution=row; else, resolution(end+1)=row; end %#ok<AGROW>
            end
        end
        native=result.diagnostics.energy(result.diagnostics.time==time);
        row=struct(scenario=scenario,time=time,energy=e,nativeDiagnosticEnergy=native,referenceChange=change,sourceParityFraction=parity);
        if isempty(energyRows), energyRows=row; else, energyRows(end+1)=row; end %#ok<AGROW>
    end
    for control=["baseline","modes"]
        index=1; if control=="modes", index=3; end
        data=load(fullfile(workFolder,profile+"-inventory"+index+".mat"));
        w=WVTransformFreeSurfaceBoussinesq(data.scientificState); w.t0=-17;
        data=load(fullfile(workFolder,scenario+"-"+control+".mat"));
        state=data.result.finalState;
        for name=string(fieldnames(state)).', w.(name)=state.(name); end
        w.t=327+data.result.summary.durationCompleted;
        fields=w.reconstructFields(["u","v","w","ssh"]); gamma=1+fields.ssh/w.Lz;
        power=zeros(w.Nx,w.Ny);
        for name=["u","v","w"]
            spectrum=fft2(sqrt(gamma).*fields.(name))/(w.Nx*w.Ny);
            power=power+.5*sum(abs(spectrum).^2.*reshape(w.verticalQuadratureWeights,1,1,[]),3);
        end
        [k,l]=ndgrid(ifftshift(-floor(w.Nx/2):ceil(w.Nx/2)-1),ifftshift(-floor(w.Ny/2):ceil(w.Ny/2)-1));
        expected=.5*sum(reshape(w.verticalQuadratureWeights,1,1,[]).*gamma.*(fields.u.^2+fields.v.^2+fields.w.^2),'all')/(w.Nx*w.Ny);
        assert(abs(sum(power,'all')-expected)<1e-12*expected,'Kinetic spectrum violates Parseval normalization.');
        radius=k.^2+l.^2;
        for bin=unique(radius(:)).'
            row=struct(scenario=scenario,control=control,kappaSquared=bin,kineticEnergy=sum(power(radius==bin)),totalKineticEnergy=sum(power,'all'));
            if isempty(spectralRows), spectralRows=row; else, spectralRows(end+1)=row; end %#ok<AGROW>
        end
    end
    writetable(struct2table(resolution),fullfile(output,scenario+'-rhs-resolution.csv'));
    writetable(struct2table(energyRows),fullfile(output,scenario+'-energy-quadrature.csv'));
    writetable(struct2table(spectralRows),fullfile(output,scenario+'-kinetic-spectra.csv'));
    fprintf('AUDIT %s complete\n',scenario);
end
end
