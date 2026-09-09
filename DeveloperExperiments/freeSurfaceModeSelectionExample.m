function result = freeSurfaceModeSelectionExample(options)
% Inspect automatic v5 mode counts and the evidence that selected them.
%
% Run from the WVM authoring checkout with its declared dependencies active.
% The returned report is also available as wvt.constructionAssessment.
% This is an authoring example, not a new core public API.
arguments
    options.Nxyz (1,3) double {mustBeInteger,mustBePositive} = [8 8 65]
    options.Lxyz (1,3) double {mustBePositive} = [1e5 1e5 1000]
    options.N2Function function_handle = @(z)1e-4*ones(size(z))
    options.shouldPlot (1,1) logical = true
    options.outputDirectory (1,1) string = ""
end
[wvt,assessment]=WVTransformFreeSurfaceBoussinesq.fromStratification(options.Lxyz,options.Nxyz,N2Function=options.N2Function,latitude=30);
counts=assessment.pages(:,["kappa","candidateCount","convergedCount","gridSupportedCount","selectedCount","limitingMetric"]);
families=table(["APV";"MDA";"inertial"],[numel(wvt.apvMode);numel(wvt.mdaMode);numel(wvt.inertialMode)],VariableNames=["family","selectedCount"]);
disp(counts); disp(families); disp(assessment.cost);
result=struct(counts=counts,families=families,assessment=assessment);
if options.shouldPlot
    fig=figure(Color="white"); ax=axes(fig);
    plot(ax,counts.kappa,[counts.convergedCount,counts.gridSupportedCount,counts.selectedCount],'-o',LineWidth=1.4);
    xlabel(ax,'Horizontal wavenumber \kappa (rad m^{-1})'); ylabel(ax,'Wave modes per frequency sign');
    legend(ax,{'EVP convergence limit within candidate band','Physical-grid Gram limit','Retained modes after sampled quadratic checks'},Location='best');
    ylim(ax,[0,5*ceil(max(counts.convergedCount)/5)]);
    grid(ax,'on'); title(ax,sprintf('Automatic v5 initialization: %d vertical points',options.Nxyz(3)));
    if options.outputDirectory~=""
        if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
        exportgraphics(fig,fullfile(options.outputDirectory,'mode-counts.png'),Resolution=180);
        exportgraphics(fig,fullfile(options.outputDirectory,'mode-counts.pdf'),ContentType='vector');
    end
end
if options.outputDirectory~=""
    if ~isfolder(options.outputDirectory), mkdir(options.outputDirectory); end
    writetable(counts,fullfile(options.outputDirectory,'wave-counts.csv'));
    writetable(families,fullfile(options.outputDirectory,'family-counts.csv'));
    save(fullfile(options.outputDirectory,'assessment.mat'),'assessment');
end
end
