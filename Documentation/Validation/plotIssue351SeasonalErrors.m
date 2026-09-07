function plotIssue351SeasonalErrors()
% Plot the recorded independent seasonal qualification results.
root = fileparts(mfilename('fullpath'));
base=readtable(fullfile(root,'issue-351-seasonal.csv')); high=readtable(fullfile(root,'issue-351-high-resolution.csv')); final=readtable(fullfile(root,'issue-351-default-resolution.csv')); data=[base;high;final];
data=data(data.stratificationScale==1300 & data.timeInYears==.25,:); data=sortrows(data,'APVModes');
f=figure(Visible='off',Color='white',Position=[100 100 900 480]);
semilogy(data.APVModes,100*data.qgpvError,'o-',LineWidth=2,DisplayName='QGPV'); hold on
semilogy(data.APVModes,100*data.enstrophyError,'s-',LineWidth=2,DisplayName='Potential enstrophy');
semilogy(data.APVModes,100*data.energyError,'d-',LineWidth=2,DisplayName='Physical energy');
yline(1,'--','1% field target',HandleVisibility='off',LabelHorizontalAlignment='left');
yline(2,':','2% inventory target',HandleVisibility='off',LabelHorizontalAlignment='left');
grid on; xlabel('Retained APV modes'); ylabel('Relative error (%)');
title({'Two active boundaries: quarter-year seasonal response','Exponential stratification, independent physical-depth reference'});
legend(Location='southwest'); set(findall(f,'-property','FontSize'),'FontSize',13);
exportgraphics(f,fullfile(root,'Issue351SeasonalErrors.png'),Resolution=180);
close(f)
end
