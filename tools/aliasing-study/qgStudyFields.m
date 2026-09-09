function fields = qgStudyFields(data,page,setName)
% Evaluate resolved QG streamfunction coordinates and physical observations.
% Columns are APV modes followed by the fixed surface and bottom responses.
arguments (Input)
    data (1,1) struct
    page (1,1) double {mustBeInteger,mustBePositive}
    setName (1,1) string {mustBeMember(setName,["S","R","Q","H"])}
end
kappa=data.inventory.magnitudes(page);
if kappa==0, error('WVStudy:InvalidQGPage','QG input modes require positive kappa.'); end
A=data.apv; B=data.boundary{page};
h=A.basis.h(:); endpointName="E";
if setName=="H", h=A.checkh; endpointName="J"; end
mu=kappa^2+(data.config.f^2/data.config.g)./h;
F=[A.(setName).F B.(setName).F]; G=[A.(setName).G B.(setName).G];
Fe=[A.(endpointName).F B.(endpointName).F];
Ge=[A.(endpointName).G B.(endpointName).G];
fOverG=data.config.f/data.config.g;
b=fOverG*[Ge(2,:)-Fe(2,:);Ge(1,:)];
% Boundary-normalized coordinates prescribe these observations exactly.
% Measure the sampled endpoint identity separately instead of advecting its
% floating-point residual as a spurious anomaly at the opposite endpoint.
b(:,end-1:end)=fOverG*eye(2);
fields=struct(psi=F,eta=fOverG*G,q=[-A.(setName).F.*mu.' zeros(size(B.(setName).F))],b=b,psiEndpoint=flipud(Fe),mu=mu,canonicalScale=[-mu;-kappa^2;-kappa^2]);
fields.apvEndpointResponse=-b(:,1:numel(mu))./mu.';
fields.labels=["apv:"+string(A.labels),"surface","bottom"];
end
