function filter=horizontalVanishingFilter(kh,cutoff,maximum)
% Evaluate the common horizontal spectral-vanishing filter.
% Physical cutoff and maximum are supplied by the owning closure policy.
% - Topic: Developer utilities
filter=exp(-((abs(kh)-maximum)./(abs(kh)-cutoff)).^2);
filter(abs(kh)<=cutoff)=0;
filter(abs(kh)>maximum)=1;
end
