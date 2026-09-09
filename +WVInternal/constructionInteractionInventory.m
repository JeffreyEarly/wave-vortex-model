function inventory = constructionInteractionInventory(state)
% Linear-size inventory: representative closed triads for every output kappa.
Lxy=state.Lxyz(1:2);
v=round([state.kNonzero,state.lNonzero].*(Lxy/(2*pi)));
vectors=unique([0 0;v;-v],'rows'); physicalVectors=vectors.*(2*pi./Lxy);
magnitudes=[0;state.khUnique]; pageIndex=zeros(size(vectors,1),1);
for j=1:numel(pageIndex)
    [~,pageIndex(j)]=min(abs(magnitudes-hypot(physicalVectors(j,1),physicalVectors(j,2))));
end
lookup=containers.Map('KeyType','char','ValueType','double');
for j=1:size(vectors,1), lookup(key(vectors(j,:)))=j; end
[~,order]=sort(vecnorm(physicalVectors,2,2));
anchors=unique([order(2:min(end,9));order(max(2,end-7):end)]);
rows=zeros(2*numel(magnitudes),9); used=0; structurallyZeroOutputs=false(numel(magnitudes),1);
for p=1:numel(magnitudes)
    output=find(pageIndex==p,1); c=vectors(output,:);
    choices=unique([vectors(anchors,:);floor(c/2);ceil(c/2);c+[1 0];c+[0 1]],'rows');
    candidates=zeros(0,9); scores=zeros(0,2);
    for j=1:size(choices,1)
        a=choices(j,:); b=c-a;
        if all(a==0) || all(b==0) || ~isKey(lookup,key(a)) || ~isKey(lookup,key(b)), continue; end
        ia=lookup(key(a)); ib=lookup(key(b));
        candidates(end+1,:)=[a b c pageIndex(ia) pageIndex(ib) p]; %#ok<AGROW>
        scores(end+1,:)=[-abs(det([a;b]))/(norm(a)*norm(b)),max(norm(a),norm(b))]; %#ok<AGROW>
    end
    if isempty(candidates)
        % Prove absence, rather than confusing an unsampled page with zero.
        for ia=1:size(vectors,1)
            a=vectors(ia,:); b=c-a;
            if all(a==0) || all(b==0) || ~isKey(lookup,key(b)), continue; end
            ib=lookup(key(b)); candidates=[a b c pageIndex(ia) pageIndex(ib) p];
            scores=[0 0]; break
        end
        if isempty(candidates), structurallyZeroOutputs(p)=true; continue; end
    end
    [~,indices]=sortrows(scores,[1 2]); chosen=indices(1);
    [~,high]=max(scores(:,2)); chosen=unique([chosen;high],'stable');
    rows(used+(1:numel(chosen)),:)=candidates(chosen,:); used=used+numel(chosen);
end
rows=rows(1:used,:);
[triples,representative,group]=unique(rows(:,7:9),'rows','stable');
inventory=struct(structurallyZeroOutputs=structurallyZeroOutputs,vectors=vectors,physicalVectors=physicalVectors,magnitudes=magnitudes,interactions=array2table(rows,VariableNames=["k1x","k1y","k2x","k2y","k3x","k3y","page1","page2","page3"]),pageTriples=triples,representative=representative,group=group);
end
function value=key(vector)
value=sprintf('%d,%d',vector(1),vector(2));
end
