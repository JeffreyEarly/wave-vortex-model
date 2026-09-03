function [next,maxSpeed] = exponentialRK4Step(state,t,h,c,rhs,initialRHS,initialSpeed)
% Propagate homogeneous decay exactly and integrate the nonthermal RHS.
if nargin<6, [initialRHS,initialSpeed]=rhs(state,t); end
a=c.E2.*state+c.Q.*initialRHS;
[Na,sa]=rhs(a,t+h/2);
b=c.E2.*state+c.Q.*Na;
[Nb,sb]=rhs(b,t+h/2);
d=c.E2.*a+c.Q.*(2*Nb-initialRHS);
[Nd,sd]=rhs(d,t+h);
next=c.E.*state+c.f1.*initialRHS+2*c.f2.*(Na+Nb)+c.f3.*Nd;
maxSpeed=max([initialSpeed sa sb sd]);
end
