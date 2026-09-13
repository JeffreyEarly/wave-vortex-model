function results=collectEvolvingToleranceResults(folders,outputFolder)
% Recompute anomaly-normalized errors and full positive quadratic field norms.
arguments (Input)
    folders (1,:) string
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
results=table();
for folder=folders
    controls=load(fullfile(folder,'fixed-controls.mat'));
    rows=readtable(fullfile(folder,'evolving-comparison.csv'),TextType='string');
    for k=1:height(rows)
        data=load(fullfile(folder,sprintf('trial-%g-%s-%g.mat',rows.waveAmplitude(k),rows.policy(k),rows.absoluteScale(k))));
        reference=load(fullfile(folder,sprintf('reference-%g.mat',rows.waveAmplitude(k))));
        a=data.actual; b=reference.tighter;
        if rows.policy(k)=="energy", peerPolicy="invariant"; else, peerPolicy="energy"; end
        peerFile=fullfile(folder,sprintf('trial-%g-%s-%g.mat',rows.waveAmplitude(k),peerPolicy,rows.absoluteScale(k)));
        rows.policyPairIdentical(k)=false;
        if isfile(peerFile)
            peer=load(peerFile);
            rows.policyPairIdentical(k)=isequaln(a.state,peer.actual.state) && isequal(a.trace(:,1:3),peer.actual.trace(:,1:3));
        end
        denominator=norm(reshape(b.fields.boundary-mean(b.fields.boundary,[1 2]),[],1));
        rows.boundaryError(k)=norm(a.fields.boundary(:)-b.fields.boundary(:))/denominator;
        rows.referenceError(k)=max(rows.referenceError(k),norm(reference.reference.fields.boundary(:)-b.fields.boundary(:))/denominator);
        rows.maximumError(k)=max([rows.boundaryError(k),rows.pvError(k),rows.velocityError(k),rows.displacementError(k)]);
        rows.boundaryChange(k)=norm(a.fields.boundary(:)-a.initialFields.boundary(:))/norm(reshape(a.initialFields.boundary-mean(a.initialFields.boundary,[1 2]),[],1));
        % Constant N2 makes the physical quadrature the Clenshaw-Curtis rule.
        [~,weights]=chebpts(size(b.fields.eta,3),[-1000 0]);
        weights=reshape(weights,1,1,[]);
        rows.positiveEnergyError(k)=sqrt(fieldEnergy(a.fields,b.fields,weights)/fieldEnergy(b.fields,[],weights));
        phaseError=0; largestPhaseError=0; templatePhaseError=0;
        for name=["Aw_p","Aw_m"]
            [~,largest]=max(abs(b.state.(name)),[],'all','linear');
            largestPhaseError=max(largestPhaseError,abs(angle(a.state.(name)(largest)/b.state.(name)(largest))));
            template=abs(controls.base.(name))>0;
            if rows.waveAmplitude(k)>0
                templatePhaseError=max(templatePhaseError,max(abs(angle(a.state.(name)(template)./b.state.(name)(template)))));
            end
            mask=abs(b.state.(name))>1e-6*max(abs(b.state.(name)),[],'all');
            if any(mask,'all')
                phaseError=max(phaseError,max(abs(angle(a.state.(name)(mask)./b.state.(name)(mask)))));
            end
        end
        rows.wavePhaseError(k)=phaseError;
        rows.largestWaveCoefficientPhaseError(k)=largestPhaseError;
        if rows.waveAmplitude(k)==0, templatePhaseError=NaN; end
        rows.imposedWavePhaseError(k)=templatePhaseError;
        rows.energyBudgetChange(k)=(a.finalBudget.totalEnergy-a.initialBudget.totalEnergy)/a.initialBudget.totalEnergy;
        rows.referenceEnergyBudgetChange(k)=(b.finalBudget.totalEnergy-b.initialBudget.totalEnergy)/b.initialBudget.totalEnergy;
    end
    results=[results;rows]; %#ok<AGROW> Four bounded wave amplitudes.
end
writetable(results,fullfile(outputFolder,'evolving-comparison.csv'));
end

function E=fieldEnergy(a,b,weights)
if isempty(b)
    u=a.velocity; eta=a.eta; ssh=a.eta(:,:,end)-a.boundary(:,:,1);
else
    u=a.velocity-b.velocity; eta=a.eta-b.eta;
    ssh=eta(:,:,end)-(a.boundary(:,:,1)-b.boundary(:,:,1));
end
E=.5*sum(weights.*(sum(u.^2,4)+1e-4*eta.^2),'all')+.5*9.81*sum(ssh.^2,'all');
end
