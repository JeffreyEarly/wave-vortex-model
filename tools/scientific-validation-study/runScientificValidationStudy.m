function runScientificValidationStudy(workFolder)
% Three cases, independently changed timestep, quadrature, and modal inventory.
arguments
    workFolder (1,1) string
end
if ~isfolder(workFolder), mkdir(workFolder); end
folder=fileparts(mfilename('fullpath')); output=fullfile(folder,'results');
addpath(fullfile(fileparts(folder),'nonlinear-study'),fullfile(fileparts(folder),'thermodynamic-formulation-study'));
summary=struct([]); cases=struct([]);
for scenario=["waves","balanced","mixed"]
    profile="exponential"; if scenario=="waves", profile="constant"; end
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    specifications=[8 129 3 4 2 3;8 257 3 4 2 3;12 129 6 8 4 6];
    inventory=cell(1,3);
    for j=1:3
        file=fullfile(workFolder,profile+"-inventory"+j+".mat");
        if isfile(file), data=load(file,'scientificState'); inventory{j}=data.scientificState; continue; end
        spec=specifications(j,:);
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[spec(1) spec(1) spec(2)],N2Function=N2,apvModeCount=spec(3),waveModeCount=spec(4),mdaModeCount=spec(5),inertialModeCount=spec(6),nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
        scientificState=w.scientificState(); inventory{j}=scientificState; save(file,'scientificState');
    end
    w=WVTransformFreeSurfaceBoussinesq(inventory{1}); w.t0=-17;
    op=manuscriptEvolutionOperators(w,profile,padding=1); initial=op.seed(scenario,.1);
    frequency=w.waveFrequency(:,w.klNonzeroKhUniqueIndex); periods=2*pi./frequency(abs(initial.Aw_p)+abs(initial.Aw_m)>0);
    if scenario=="balanced", period=2*pi/w.f; cycles=2; else, period=max(periods); cycles=3; end
    duration=80*ceil(cycles*period/80);
    d=op.observe(327,initial,structfun(@(a)zeros(size(a)),initial,UniformOutput=false));
    item=struct(scenario=scenario,profile=profile,amplitude=.1,period=period,cycles=duration/period,duration=duration,initialSpeed=d.maximumSpeed,initialSSH=d.sshRMS,initialSurface=d.surfaceRMS,initialBottom=d.bottomRMS);
    if isempty(cases), cases=item; else, cases(end+1)=item; end %#ok<AGROW>
    writetable(struct2table(cases),fullfile(output,'cases.csv'));
    controls=["baseline","timeCoarse","timeFine","vertical","horizontal","modes"];
    reference=struct();
    for control=controls
        j=1; dt=20; padding=1;
        if control=="timeCoarse", dt=40; elseif control=="timeFine", dt=10; elseif control=="vertical", j=2; elseif control=="horizontal", padding=2; elseif control=="modes", j=3; end
        file=fullfile(workFolder,scenario+"-"+control+".mat");
        if isfile(file)
            data=load(file,'result'); result=data.result;
        else
            fprintf('START %s %s duration %.0fs dt%g\n',scenario,control,duration,dt);
            result=runValidationTrajectory(inventory{j},scenario,profile,duration=duration,deltaT=dt,padding=padding,reference=reference);
            save(file,'result','-v7.3');
        end
        if control=="baseline"
            reference=result;
            if result.summary.status~="completed", error('WVStudy:BaselineStopped','Baseline stopped; inspect the saved result before selecting a shorter common comparison window.'); end
        end
        row=result.summary; row.control=control;
        if isempty(summary), summary=row; else, summary(end+1)=row; end %#ok<AGROW>
        writetable(struct2table(summary),fullfile(output,'summary.csv'));
        writetable(result.diagnostics,fullfile(output,scenario+"-"+control+"-diagnostics.csv"));
        if ~isempty(result.errors), writetable(result.errors,fullfile(output,scenario+"-"+control+"-errors.csv")); end
        fprintf('DONE %s %s %s %.1fs wall dE/E %.3g\n',scenario,control,row.status,row.wallSeconds,row.energyChange);
    end
end
end
