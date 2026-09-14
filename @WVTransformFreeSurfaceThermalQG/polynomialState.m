function [r,C] = polynomialState(self,state)
% Reuse radius-independent polynomial fields and batch each radius once.
if isempty(self.polynomialFields_)
    self.polynomialFields_=WVInternal.thermalPolynomialFields(self.z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
end
r=self.polynomialFields_; C=complex(zeros(self.thermalModeCount,numel(self.klNonzero)));
for p=1:numel(self.khUnique)
    columns=self.klNonzeroKhUniqueIndex==p;
    C(:,columns)=self.thermalToPolynomial(:,:,p)*state.Ath(:,columns);
end
end
