function [state,assessment]=invertThermodynamicCoefficientMap(w,profile,target,time)
% Local fixed-point inverse of the near-identity finite coefficient map.
% No inverse is claimed outside the tested neighborhood.
state=target; residualHistory=zeros(30,1); scale=max(coefficientNorm(w,target),1e-12);
for iteration=1:30
    mapped=thermodynamicCoefficientMap(w,profile,state,time);
    residualState=target;
    for name=string(fieldnames(target)).'
        residual=target.(name)-mapped.(name);
        residualState.(name)=residual;
        state.(name)=state.(name)+residual;
    end
    error=coefficientNorm(w,residualState)/scale;
    residualHistory(iteration)=error;
    if error<2e-11, break; end
end
assert(error<2e-11,'Local coefficient conversion inverse did not converge.');
assessment=struct(iterations=iteration,residual=error,residualHistory=residualHistory(1:iteration));
end

function value=coefficientNorm(w,state)
f=w.reconstructSpectralState(state=state);
columnWeights=2*ones(1,numel(w.k)); columnWeights(w.k==0 & w.l==0)=1;
energy=0;
for name=["u","v","w","eta"]
    weight=w.verticalQuadratureWeights;
    if name=="eta", weight=weight.*w.N2; end
    energy=energy+sum(weight.*columnWeights.*abs(f.(name)).^2,'all');
end
energy=energy+w.g*sum(columnWeights.*abs(f.ssh(end,:)).^2);
value=sqrt(energy);
end
