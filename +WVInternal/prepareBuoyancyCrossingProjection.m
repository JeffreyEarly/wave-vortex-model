function context = prepareBuoyancyCrossingProjection(N2Function,xi,weights,D,order)
% Prepare a volume-load correction on the native WKB Chebyshev grid.
% The polynomial continuation is an algebraic subtraction only: parcel and
% reference density conventions are unchanged. No coefficient state is cached.
arguments
    N2Function (1,1) function_handle
    xi (:,1) double
    weights (:,1) double {mustBePositive}
    D (1,1) double {mustBePositive}
    order (1,1) double {mustBeInteger,mustBePositive} = 8
end
profile=chebfun(N2Function,[-D 0],'splitting','off');
primitive=cumsum(profile); coefficients=chebcoeffs(primitive);
% Divided-difference recurrence accepts padded equal-length coefficient lists.
parameters=struct(coefficients=coefficients,N20=N2Function(0),D=D);
map=cumsum(chebfun(@(z)sqrt(N2Function(z)),[-D 0]));
span=map(0)-map(-D); map=2*(map-map(-D))/span-1;
n=numel(xi); nodes=-cos(pi*(0:n-1)/(n-1));
if numel(weights)~=n || max(abs(map(xi)-nodes.'))>1e-10
    error('WV:CrossingProjectionGrid','Crossing projection requires native WKB Chebyshev samples and their volume weights.')
end
b=(-1).^(0:n-1); b([1 end])=b([1 end])/2;
[g,q]=legpts(order,[0 1]);
context=struct(apply=@apply,load=@integrateLayer,order=order);
    function integratedLoad=integrateLayer(ssh)
        % Return a source load, not a pointwise physical acceleration.
        % For every interpolated test mode phi, sum(q*phi*load) equals the
        % Gauss integral of phi*J(z) on z>0.
        shape=[size(ssh,1),size(ssh,2),n];
        crest=max(ssh(:),0); active=find(crest>0);
        integratedLoad=zeros(numel(crest),n);
        if isempty(active), integratedLoad=reshape(integratedLoad,shape); return; end
        gamma=1+crest(active)/D; thickness=crest(active)./gamma;
        load=zeros(numel(active),n);
        positions=-thickness*(1-g.');
        locations=reshape(map(positions(:)),size(positions));
        integrands=continuedPrimitive(parameters,crest(active)*g.');
        for j=1:order
            difference=locations(:,j)-nodes;
            exact=abs(difference)<8*eps;
            difference(exact)=1;
            cardinal=b./difference; cardinal=cardinal./sum(cardinal,2);
            hit=any(exact,2); cardinal(hit,:)=double(exact(hit,:));
            load=load+(q(j)*thickness.*integrands(:,j)).*cardinal;
        end
        integratedLoad(active,:)=load./weights.';
        integratedLoad=reshape(integratedLoad,shape);
    end
    function correction=apply(ssh)
        % Diagnostic difference from native quadrature. Runtime candidates
        % use load with the directly evaluated smooth buoyancy remainder.
        integratedLoad=integrateLayer(ssh);
        height=xi.'+(1+xi.'/D).*max(ssh(:),0);
        sampled=continuedPrimitive(parameters,max(height,0));
        correction=integratedLoad-reshape(sampled,size(integratedLoad));
    end
end
function value=continuedPrimitive(p,z)
% J(z)=integral_0^z N2_polynomial(s) ds, with J(0)=0 exactly.
[variation,~]=WVInternal.chebyshevIntervalAverages(p.coefficients,zeros(size(p.coefficients)),zeros(size(z)),z,p.D);
value=z.*(p.N20+variation);
end
