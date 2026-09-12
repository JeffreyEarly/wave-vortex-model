function prepareRHSSchedulingStudy(folder)
% Save task-local scientific fixtures so qualification avoids repeated EVP solves.
if ~isfolder(folder), mkdir(folder); end
output=fullfile(fileparts(mfilename('fullpath')),'results');
specs=[8 33 3 4 2 3;8 65 3 4 2 3;16 65 6 8 4 6;24 129 10 12 8 8];
for profile=["constant","exponential"]
    for config=1:size(specs,1)
        spec=specs(config,:);
        if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
        w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[spec(1) spec(1) spec(2)],N2Function=N2,apvModeCount=spec(3),waveModeCount=spec(4),mdaModeCount=spec(5),inertialModeCount=spec(6),nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
        scientificState=w.scientificState(); seed=manuscriptEvolutionOperators(w,profile,padding=1); initial=seed.seed("mixed",.1);
        save(fullfile(folder,profile+"-"+config+".mat"),'scientificState','initial','profile','config');
        if config==1
            candidate=WVTransformFreeSurfaceBoussinesq(scientificState);
            candidate.addForcing(WVNonlinearAdvection(candidate));
            for field=string(fieldnames(initial)).', candidate.(field)=initial.(field); end
            candidate.t=327;
            run=@()evaluate(candidate);
            run();
            report=profileCodeHotspots(run,projectRoots=fileparts(fileparts(fileparts(output))),maxFunctions=25,maxLines=30);
            writetable(report.topProjectBySelfTime,fullfile(output,profile+'-profile-functions.csv'));
            writetable(report.topActionableLines,fullfile(output,profile+'-profile-lines.csv'));
        end
        fprintf('prepared %s config%d\n',profile,config);
    end
end
end
function rate=evaluate(w)
for iteration=1:10
    w.t=327+iteration;
    rate=w.coefficientTendency();
end
end
