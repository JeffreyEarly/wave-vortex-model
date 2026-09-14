function tendency=projectThermalWeak(w,moments,endpoints)
% Apply the common physical weak dual to nonzero compact Fourier columns.
% - Topic: Developer utilities
Ath=complex(zeros(size(w.Ath)));
for p=1:numel(w.khUnique)
    columns=w.klNonzeroKhUniqueIndex==p;
    Ath(:,columns)=-w.sourceDual(:,:,p)*moments(:,columns)+w.sourceEndpoint(:,:,p)*endpoints(:,columns);
end
tendency=struct(Ath=Ath,Amda=zeros(size(w.Amda)));
end
