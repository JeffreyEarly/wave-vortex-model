function selection = selectStudyInteractions(inventory,pageDifficulty)
% Select bounded geometry stresses, then budgeted tail/coverage additions.
arguments
    inventory (1,1) struct
    pageDifficulty (:,1) double {mustBeNonnegative}
end
rows=inventory.interactions; pages=table2array(rows(:,7:9));
k=inventory.magnitudes(pages); maximum=max(k(:,1:2),[],2); minimum=min(k(:,1:2),[],2);
positive=inventory.magnitudes(inventory.magnitudes>0);
anchors=positive(unique(round(linspace(1,length(positive),min(6,length(positive))))));
% Integer closure was established by the inventory. The physical cross
% product distinguishes transverse directions from collinear interactions.
k1=[rows.k1x rows.k1y]; k2=[rows.k2x rows.k2y];
transverse=abs(k1(:,1).*k2(:,2)-k1(:,2).*k2(:,1))./(vecnorm(k1,2,2).*vecnorm(k2,2,2));
roles=[-k(:,3)./maximum,k(:,3)./maximum,minimum./maximum,-transverse];
fixed=zeros(0,1);
for anchor=anchors.'
    distance=abs(maximum-anchor); candidates=find(distance<=min(distance)+1e-12*max(positive));
    for role=1:4
        candidatesRemaining=setdiff(candidates,fixed,'stable');
        if isempty(candidatesRemaining), continue; end
        [~,order]=sortrows([roles(candidatesRemaining,role),candidatesRemaining],[1 2]);
        fixed(end+1,1)=candidatesRemaining(order(1)); %#ok<AGROW>
    end
end
fixed=unique(fixed,'stable');
features=[k/max(positive),transverse];
addition=zeros(0,1); difficulty=max(pageDifficulty(pages(:,1:2)),[],2);
for j=1:min(12,height(rows)-length(fixed))
    selected=[fixed;addition];
    gap=inf(height(rows),1);
    for index=selected.'
        gap=min(gap,sum((features-features(index,:)).^2,2));
    end
    % Tails rank difficult modes; geometric gap prevents spending the entire
    % addition budget on nearly duplicate tests. Both are only indicators.
    priority=gap.*(1+difficulty/max(max(difficulty),eps));
    remaining=setdiff((1:height(rows)).',selected,'stable');
    [~,order]=sortrows([-priority(remaining),remaining],[1 2]);
    addition(end+1,1)=remaining(order(1)); %#ok<AGROW>
end
selection=struct(fixed=fixed,targeted=[fixed;addition],additions=addition,anchors=anchors,pageDifficulty=pageDifficulty,fixedBudget=24,additionBudget=12);
end
