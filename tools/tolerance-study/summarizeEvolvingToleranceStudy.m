function summarizeEvolvingToleranceStudy(outputFolder)
% Plot endpoint deformation and family error control from saved trajectories.
arguments (Input)
    outputFolder (1,1) string
end
controls=load(fullfile(outputFolder,'fixed-controls.mat'));
files=dir(fullfile(outputFolder,'trial-*.mat'));
for k=1:numel(files)
    data=load(fullfile(files(k).folder,files(k).name));
    [~,controller]=max(data.actual.trace(:,4:end),[],2);
    fprintf('%s: %d attempts; boundary change %.3g\n',files(k).name,numel(controller),norm(data.actual.fields.boundary(:)-data.actual.initialFields.boundary(:))/norm(reshape(data.actual.initialFields.boundary-mean(data.actual.initialFields.boundary,[1 2]),[],1)));
end
data=load(fullfile(outputFolder,'reference-0.mat'));
a=data.tighter;
n=256; % Fourier interpolation for display only; the integration grid is unchanged.
x=(0:n-1)*8*controls.scale.radius/n/1000;
b0=a.initialFields.boundary(:,:,1); b1=a.fields.boundary(:,:,1);
b0=real(interpft(interpft(b0,n,1),n,2)); b1=real(interpft(interpft(b1,n,1),n,2));
% Remove only the common initial horizontal mean to expose the vortex anomaly.
offset=mean(b0,'all'); b0=b0-offset; b1=b1-offset;
fprintf('Core aspect ratio: %.8f initially, %.8f finally.\n',coreAspect(b0,x),coreAspect(b1,x));
limits=max(abs([b0(:);b1(:)]));
figureHandle=figure(Visible='off',Position=[100 100 1000 430]);
tiledlayout(1,2,TileSpacing='compact');
levels=linspace(-limits,limits,17);
nexttile; contourf(x,x,b0.',levels,LineColor='none'); axis equal; xlim([20 60]); ylim([20 60]); clim([-limits limits]); bar=colorbar; bar.Label.String='Boundary displacement (m)'; title('Initial surface anomaly'); xlabel('x (km)'); ylabel('y (km)');
nexttile; contourf(x,x,b1.',levels,LineColor='none'); axis equal; xlim([20 60]); ylim([20 60]); clim([-limits limits]); bar=colorbar; bar.Label.String='Boundary displacement (m)'; title(sprintf('After %.2g L/U, zero initial waves',controls.options.turnovers)); xlabel('x (km)'); ylabel('y (km)');
exportgraphics(figureHandle,fullfile(outputFolder,'balanced-deformation.png'),Resolution=160);
close(figureHandle);
end

function ratio=coreAspect(b,x)
[X,Y]=ndgrid(x);
weight=max(b-.1*max(b,[],'all'),0); weight=weight/sum(weight,'all');
X=X-sum(weight.*X,'all'); Y=Y-sum(weight.*Y,'all');
cross=sum(weight.*X.*Y,'all');
C=[sum(weight.*X.^2,'all'),cross;cross,sum(weight.*Y.^2,'all')];
d=eig(C); ratio=sqrt(max(d)/min(d));
end
