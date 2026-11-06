function assessment = assessFreeSurfaceVerticalProducts(vertical,transform,waveBases)
% Compare representative retained vertical products with independent depth rules.
% Each probe uses the top two retained F modes as factors and the last
% retained F mode as test function. It isolates sampling and quadrature
% defects for those products. Full nonlinear interactions require a state.
grid = vertical.grid;
counts = [2*grid.nPoints+1 4*grid.nPoints+3];
[z,weights] = physicalDepthRule(counts(1),grid.zDomain);
[zFine,weightsFine] = physicalDepthRule(counts(2),grid.zDomain);
P = grid.calculus.interpolationMatrix(zFine);

probes = assess(vertical.apvBasis,numel(transform.apvMode),"APV",NaN);
if nargin==3
    inertialBasis = waveBases.bases{waveBases.basisIndex(1)};
    probes(end+1) = assess(inertialBasis,numel(transform.inertialMode),"inertial",0);
    active = find(transform.waveModeCountByKh>0);
    if ~isempty(active)
        [~,largestCount] = max(transform.waveModeCountByKh(active));
        [~,largestKh] = max(transform.khUnique(active));
        for p = unique([active(largestCount) active(largestKh)])
            kappa = transform.khUnique(p);
            page = find(waveBases.kappa==kappa,1);
            basis = waveBases.bases{waveBases.basisIndex(page)};
            probes(end+1) = assess(basis,transform.waveModeCountByKh(p),"wave",kappa); %#ok<AGROW>
        end
    end
end
assessment = struct(status="measured",probes=probes,referenceQuadratureCounts=counts, ...
    fullNonlinearInteractions="unassessed",coverage="Selected F-mode products tested against the highest retained F mode");

    function probe = assess(basis,count,family,kappa)
        columns = max(1,count-1):count;
        basis = basis.selectColumns(columns);
        native = basis.F(grid.z);
        reference = basis.F(z);
        fine = basis.F(zFine);
        product = native(:,1).*native(:,end);
        referenceProduct = reference(:,1).*reference(:,end);
        fineProduct = fine(:,1).*fine(:,end);
        nativeMoment = sum(grid.weights.*native(:,end).*product);
        referenceMoment = sum(weights.*reference(:,end).*referenceProduct);
        fineMoment = sum(weightsFine.*fine(:,end).*fineProduct);
        productNorm = norm(sqrt(weightsFine).*fineProduct);
        scale = max(productNorm*norm(sqrt(weightsFine).*fine(:,end)),realmin);
        probe = struct(family=family,kappa=kappa,modeNumber=basis.modeNumber(:), ...
            quadratureError=abs(nativeMoment-fineMoment)/scale, ...
            referenceQuadratureError=abs(referenceMoment-fineMoment)/scale, ...
            interpolationError=norm(sqrt(weightsFine).*(P*product-fineProduct))/max(productNorm,realmin));
    end
end

function [z,weights] = physicalDepthRule(count,zDomain)
[points,weights] = legpts(count);
halfDepth = diff(zDomain)/2;
z = mean(zDomain)+halfDepth*points(:);
weights = halfDepth*weights(:);
end
