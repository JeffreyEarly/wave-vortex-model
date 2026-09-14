function result = thermalChebyshev(values,action,options)
% Apply FFT-backed polynomial calculus on increasing WKB Lobatto points.
% Values are sample-by-column arrays; coefficients are in ascending degree.
% Repeated physical derivatives apply the variable Jacobian at each step.
% - Topic: Developer utilities
arguments
    values (:,:) double {mustBeFinite}
    action (1,1) string {mustBeMember(action,["coefficients","values","derivative","resample"])}
    options.depth (1,1) double {mustBePositive} = 1
    options.inverseScale (1,1) double {mustBeReal,mustBeFinite} = 0
    options.order (1,1) double {mustBeInteger,mustBeMember(options.order,[1 2])} = 1
    options.count (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.count,3)} = size(values,1)
end
n=size(values,1);
if n<3, error('WV:ThermalCalculusSize','Supply at least three polynomial samples.'); end
switch action
    case "coefficients"
        result=chebtech2.vals2coeffs(values);
    case "values"
        result=chebtech2.coeffs2vals(values);
    case "resample"
        c=chebtech2.vals2coeffs(values);
        result=zeros(options.count,size(c,2),'like',c);
        retained=min(n,options.count); result(1:retained,:)=c(1:retained,:);
        result=chebtech2.coeffs2vals(result);
    case "derivative"
        s=-cos(pi*(0:n-1)'/(n-1));
        a=options.inverseScale;
        if a==0
            jacobian=2/options.depth*ones(n,1);
        else
            jacobian=2*a/(-expm1(-options.depth*a))*(1+(s-1)*(-expm1(-options.depth*a))/2);
        end
        result=values;
        for j=1:options.order
            c=chebtech2.vals2coeffs(result); d=zeros(size(c),'like',c);
            d(n-1,:)=2*(n-1)*c(n,:);
            for k=n-2:-1:1, d(k,:)=d(k+2,:)+2*k*c(k+1,:); end
            d(1,:)=d(1,:)/2;
            result=jacobian.*chebtech2.coeffs2vals(d);
        end
end
end
