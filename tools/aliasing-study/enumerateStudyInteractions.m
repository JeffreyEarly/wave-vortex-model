function inventory = enumerateStudyInteractions(Lxy,Nxy)
% Enumerate ordered nonzero inputs and retained vector-closed outputs.
arguments (Input)
    Lxy (1,2) double {mustBePositive}
    Nxy (1,2) double {mustBeInteger,mustBePositive}
end
geometry = WVGeometryDoublyPeriodic(Lxy,Nxy,shouldAntialias=true,Nz=1,shouldExcludeNyquist=true,shouldExcludeConjugates=false);
vectors = round([geometry.k(:)*Lxy(1)/(2*pi),geometry.l(:)*Lxy(2)/(2*pi)]);
[~,order] = sortrows(vectors); vectors = vectors(order,:);
physicalVectors = vectors.*(2*pi./Lxy);
magnitudes = hypot(physicalVectors(:,1),physicalVectors(:,2));
% Quantize only roundoff when grouping equal magnitudes, never vector closure.
[pages,~,pageIndex] = uniquetol(magnitudes,1e-12,DataScale=max(magnitudes));
nonzero = find(magnitudes>0);
rows = zeros(length(nonzero)^2,9); count=0;
for a = nonzero.'
    for b = nonzero.'
        [retained,c] = ismember(vectors(a,:)+vectors(b,:),vectors,'rows');
        if ~retained, continue; end
        count=count+1;
        rows(count,:) = [vectors(a,:) vectors(b,:) vectors(c,:) pageIndex(a) pageIndex(b) pageIndex(c)];
    end
end
rows = rows(1:count,:);
[pairs,representative,group] = unique(rows(:,7:9),'rows','stable');
inventory = struct(vectors=vectors,physicalVectors=physicalVectors,magnitudes=pages,interactions=array2table(rows,VariableNames=["k1x","k1y","k2x","k2y","k3x","k3y","page1","page2","page3"]),pageTriples=pairs,representative=representative,group=group);
end
