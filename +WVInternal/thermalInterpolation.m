function matrix = thermalInterpolation(nodes,targets)
% Barycentric interpolation from increasing Chebyshev-Lobatto coordinates.
% - Topic: Developer utilities
n=numel(nodes); weights=(-1).^(0:n-1)'; weights([1 end])=weights([1 end])/2;
difference=targets(:)-nodes(:).';
matrix=weights.'./difference;
exact=difference==0;
regular=~any(exact,2);
matrix(regular,:)=matrix(regular,:)./sum(matrix(regular,:),2);
for row=find(~regular).'
    matrix(row,:)=double(exact(row,:));
end
end
