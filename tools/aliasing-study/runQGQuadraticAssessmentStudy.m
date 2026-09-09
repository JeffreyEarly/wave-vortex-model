function result = runQGQuadraticAssessmentStudy(outputDirectory)
% Write reproducible QG refinement, dense-control, cost and tendency evidence.
arguments (Input)
    outputDirectory (1,1) string
end
if isfolder(outputDirectory), error('WVStudy:OutputExists','Use a new evidence directory.'); end
mkdir(outputDirectory);
refinement=cell(6,1); boundary=cell(6,1); dense=cell(4,1); costs=cell(2,1); controls=cell(5,1); j=0; jd=0;
for profile=["constant","exponential"]
    for nz=[9 17 33]
        c=resolveStudyCase("cal-constant-17"); c.profile=profile; c.Nxy=[6 6]; c.Nz=nz; c.waveCount=3; c.Lxy=[1e4 1e4];
        data=prepareSourceStudy(c); p=prepareQGQuadraticAssessment(data); report=assessQGQuadraticResolution(p); a=assessQGAssembledTendency(data);
        j=j+1;
        refinement{j}=table(profile,nz,report.status,max(p.rows.samplingError),max(p.boundaries.gridError),max(p.rows.referenceFraction),nnz(p.rows.usesAbsoluteReference),a.energyNormRelativeError,a.referenceFraction,a.endpointRelativeError(1),a.endpointRelativeError(2),a.cancellationRatio,a.referenceWork.enstrophyWorkFraction,max(a.referenceWork.endpointWorkFraction),p.cost.evidencePreparationSeconds,a.cost.rhsSeconds,a.cost.referenceSeconds,VariableNames={'profile','Nz','status','productError','boundaryError','productReferenceFraction','absoluteReferenceMeasurements','assembledError','assembledReferenceFraction','surfaceError','bottomError','cancellationRatio','enstrophyWorkFraction','endpointWorkFraction','preparationSeconds','rhsSeconds','assembledReferenceSeconds'});
        boundary{j}=addvars(p.boundaries,repmat(profile,height(p.boundaries),1),repmat(nz,height(p.boundaries),1),Before=1,NewVariableNames={'profile','Nz'});
        disp(refinement{j});
        if nz==9 || nz==33
            full=prepareQGQuadraticAssessment(data,policy="dense"); dr=assessQGQuadraticResolution(full);
            jd=jd+1;
            dense{jd}=table(profile,nz,report.status,dr.status,max(p.rows.samplingError),max(full.rows.samplingError),height(p.rows),height(full.rows),full.cost.evidencePreparationSeconds,VariableNames={'profile','Nz','sampledStatus','denseStatus','sampledMaximumError','denseMaximumError','sampledMeasurements','denseMeasurements','denseSeconds'});
            assert(report.status==dr.status,'Sparse/dense calibration decisions disagree.');
        end
        if profile=="exponential" && nz==33
            writetable(p.rows,fullfile(outputDirectory,'resolved-products.csv'));
            writetable(p.inventory.interactions,fullfile(outputDirectory,'interaction-inventory.csv'));
            writeJSON(fullfile(outputDirectory,'resolved-configuration.json'),p.configuration);
            writeJSON(fullfile(outputDirectory,'resolved-coverage.json'),p.coverage);
        end
    end
    c=resolveStudyCase("cal-constant-17"); c.profile=profile; c.waveCount=3;
    data=prepareSourceStudy(c); times=zeros(1,3); repeated=zeros(1,5);
    for trial=1:3, p=prepareQGQuadraticAssessment(data); times(trial)=p.cost.evidencePreparationSeconds; end
    for trial=1:5, r=assessQGQuadraticResolution(p); repeated(trial)=r.cost.assessmentSeconds; end
    jcost=find(["constant","exponential"]==profile);
    costs{jcost}=table(profile,data.constructionSeconds,median(times),median(repeated),p.cost.retainedBytes,p.cost.workingMemoryEstimateBytes,p.cost.reservedProducts,VariableNames={'profile','sourcePreparationSeconds','incrementalPreparationSeconds','repeatAssessmentSeconds','retainedBytes','workingMemoryEstimateBytes','scalarMeasurements'});
    assert(median(times)<2 && median(repeated)<.25 && p.cost.retainedBytes<64*1024^2,'Calibration cost target exceeded.');
end
c=resolveStudyCase("cal-constant-17"); c.Nxy=[6 6]; c.waveCount=3; data=prepareSourceStudy(c);
j=0;
for kind=["mixed","apv","surface","bottom","collinear"]
    a=assessQGAssembledTendency(data,stateKind=kind); j=j+1;
    controls{j}=table(kind,a.maximumVelocity,a.energyNormRelativeError,a.errorOverStateAdvectionScale,a.referenceFraction,a.meanSourceNorm,a.cancellationRatio,a.referenceWork.enstrophyWorkFraction,max(a.referenceWork.endpointWorkFraction),VariableNames={'stateKind','maximumVelocity','relativeError','errorOverStateAdvectionScale','referenceFraction','meanSourceNorm','cancellationRatio','enstrophyWorkFraction','endpointWorkFraction'});
    writeJSON(fullfile(outputDirectory,"assembled-"+kind+".json"),a);
end
result=struct(refinement=vertcat(refinement{:}),boundaries=vertcat(boundary{:}),dense=vertcat(dense{:}),costs=vertcat(costs{:}),controls=vertcat(controls{:}));
for name=string(fieldnames(result)).', writetable(result.(name),fullfile(outputDirectory,name+".csv")); end
figureHandle=figure(Visible="off",Color="white",Position=[50 50 1000 420]); cleanup=onCleanup(@()close(figureHandle));
tiledlayout(1,2);
for profile=["constant","exponential"]
    nexttile; rows=result.refinement(result.refinement.profile==profile,:);
    semilogy(rows.Nz,rows.productError,'o-',rows.Nz,rows.boundaryError,'s-',rows.Nz,rows.assembledError,'^-',LineWidth=1.5);
    yline(.01,':','Boundary tolerance'); grid on; xlabel('Vertical grid points'); ylabel('Relative error');
    title(profile+" stratification"); legend('Sampled APV/endpoint products','Fixed boundary representation','Assembled QG tendency',Location='southwest');
end
sgtitle('QG assessment: 10 km domain, 3 APV modes, both active boundaries');
exportgraphics(figureHandle,fullfile(outputDirectory,'qg-refinement.png'),Resolution=160);
exportgraphics(figureHandle,fullfile(outputDirectory,'qg-refinement.pdf'),ContentType='vector');
end
function writeJSON(path,value)
fid=fopen(path,'w'); cleanup=onCleanup(@()fclose(fid)); fprintf(fid,'%s\n',jsonencode(value,PrettyPrint=true));
end
