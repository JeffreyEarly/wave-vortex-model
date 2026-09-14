function [state,assessment]=coefficientStateForTransform(self,target,options)
% Fit a compatible thermal target to physical QGPV, endpoints and mean density.
% Both transforms remain unchanged. Fourier integer pairs identify horizontal
% content; thermal eigenvalue ordering never identifies vertical directions.
% Nonzero QGPV is fitted in positive physical-depth least squares with exact
% endpoint constraints. Mean displacement is independently fitted with exact
% endpoint and integrated buoyancy constraints; an inadequate target mean
% space rejects the transfer.
% Residuals include discarded Fourier content and vertical fit error, retaining
% all cross terms. They are errors of the reconstructed difference, never a
% subtraction of two large energies. Refine quadrature to assess fit convergence.
% - Topic: Transfer resolution
% - Parameter target: thermal target with identical physics and diffusion
% - Parameter options.quadratureCount: common physical-depth Gauss count
% - Returns state: target-shaped Ath and Amda without modifying either object
% - Returns assessment: positive physical error norms, energies and endpoint loss
arguments (Input)
    self (1,1) WVTransformFreeSurfaceThermalQG
    target (1,1) WVTransform
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 2*max(self.Nz,target.Nz)+1
end
arguments (Output)
    state (1,1) struct
    assessment (1,1) struct
end
if ~isa(target,'WVTransformFreeSurfaceThermalQG')
    error('WV:TransferIncompatible','Thermal physical transfer requires a thermal target.');
end
for name=["domainSize","N20","inverseScale","latitude","g","rho0","activeEndpoint","kappa_z"]
    if ~isequal(self.(name),target.(name))
        error('WV:TransferIncompatible','Thermal transfer requires identical %s.',name);
    end
end
if options.quadratureCount<2*max([self.Nz,target.Nz,self.thermalModeCount,target.thermalModeCount])+1
    error('WV:TransferQuadrature','Use at least twice the larger native sample or thermal count plus one quadrature points.');
end
[x,weights]=legpts(options.quadratureCount); z=(x-1)*self.Lz/2; weights=weights(:)*self.Lz/2;
rs=WVInternal.thermalPolynomialFields(z,self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
rt=WVInternal.thermalPolynomialFields(z,target.thermalModeCount,target.Lz,target.N20,target.inverseScale,0,target.f,target.g);
es=WVInternal.thermalPolynomialFields([0;-self.Lz],self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
et=WVInternal.thermalPolynomialFields([0;-target.Lz],target.thermalModeCount,target.Lz,target.N20,target.inverseScale,0,target.f,target.g);
[~,Cs]=self.polynomialState(self.coefficientState());
[common,index]=ismember([target.kMode_wv(target.klNonzero),target.lMode_wv(target.klNonzero)],[self.kMode_wv(self.klNonzero),self.lMode_wv(self.klNonzero)],'rows');
Ct=complex(zeros(target.thermalModeCount,numel(target.klNonzero)));
state=struct(Ath=complex(zeros(size(target.Ath))),Amda=zeros(size(target.Amda)));
for p=1:numel(target.khUnique)
    columns=find(common & target.klNonzeroKhUniqueIndex==p);
    if isempty(columns), continue; end
    kh2=target.khUnique(p)^2;
    sourceQ=(rs.qgpv-kh2*rs.psi)*Cs(:,index(columns));
    endpoints=es.eta_i*Cs(:,index(columns));
    Ct(:,columns)=WVInternal.thermalConstrainedFit(rt.qgpv-kh2*rt.psi,sourceQ,et.eta_i,endpoints,weights);
    state.Ath(:,columns)=target.polynomialToThermal(:,:,p)*Ct(:,columns);
end
Ps=WVInternal.thermalVerticalInterpolation(self.z,z,self.Lz,self.inverseScale);
Pt=WVInternal.thermalVerticalInterpolation(target.z,z,target.Lz,target.inverseScale);
Gs=Ps*self.mdaG; Gt=Pt*target.mdaG;
meanSource=Gs*self.Amda;
meanMetric=weights.*self.N2Function(z);
meanConstraints=[target.mdaG([end 1],:);meanMetric.'*Gt];
meanValues=[self.mdaG([end 1],:)*self.Amda;meanMetric.'*meanSource];
state.Amda=real(WVInternal.thermalConstrainedFit(Gt,meanSource,meanConstraints,meanValues,weights));
S=spectralFields(self,rs,es,Cs,self.Amda,z,Ps);
T=spectralFields(target,rt,et,Ct,state.Amda,z,Pt);
keys=union([self.kMode_wv,self.lMode_wv],[target.kMode_wv,target.lMode_wv],'rows');
[hasS,is]=ismember(keys,[self.kMode_wv,self.lMode_wv],'rows');
[hasT,it]=ismember(keys,[target.kMode_wv,target.lMode_wv],'rows');
factor=2*ones(1,size(keys,1)); factor(all(keys==0,2))=1;
errorNorm=struct(); sourceEnergy=0; targetEnergy=0; errorEnergy=0;
for name=string(fieldnames(S)).'
    source=complex(zeros(size(S.(name),1),size(keys,1))); actual=source;
    source(:,hasS)=S.(name)(:,is(hasS)); actual(:,hasT)=T.(name)(:,it(hasT));
    delta=source-actual;
    if ismember(name,["ssh","endpointAnomalies"])
        errorNorm.(name)=sqrt(sum(factor.*abs(delta).^2,2));
    else
        errorNorm.(name)=sqrt(sum((weights/self.Lz).*factor.*abs(delta).^2,'all'));
    end
    if ismember(name,["u","v","eta","ssh"])
        metric=weights.*factor/2;
        if name=="eta", metric=metric.*self.N2Function(z); end
        if name=="ssh", metric=self.g*factor/2; end
        sourceEnergy=sourceEnergy+sum(metric.*abs(source).^2,'all');
        targetEnergy=targetEnergy+sum(metric.*abs(actual).^2,'all');
        errorEnergy=errorEnergy+sum(metric.*abs(delta).^2,'all');
    end
end
assessment=struct(quadratureCount=options.quadratureCount,sourceEnergy=sourceEnergy,targetEnergy=targetEnergy,errorEnergy=errorEnergy,relativeFieldError=sqrt(errorEnergy/max(sourceEnergy,realmin)),qgpvRMS=errorNorm.qgpv,buoyancyRMS=errorNorm.buoyancy,velocityRMS=hypot(errorNorm.u,errorNorm.v),endpointRMS=errorNorm.endpointAnomalies,sshRMS=errorNorm.ssh,meanDisplacementRMS=sqrt(sum(weights.*abs(Gt*state.Amda-meanSource).^2)/self.Lz),meanBuoyancyInventoryError=abs(meanMetric.'*(Gt*state.Amda-meanSource)),matchedFourierCount=sum(common),discardedFourierCount=numel(self.klNonzero)-sum(common));
end

function fields=spectralFields(w,r,e,C,Amda,z,P)
meanIndex=find(hypot(w.k,w.l)==0,1); indices=w.klNonzero;
meanG=P*w.mdaG; meanGZ=P*w.mdaGZ;
fields=struct();
for name=["u","v","eta","qgpv","buoyancy"]
    values=complex(zeros(numel(z),w.Nkl));
    switch name
        case "u", values(:,indices)=(-1i*w.l(indices).').*(r.psi*C);
        case "v", values(:,indices)=(1i*w.k(indices).').*(r.psi*C);
        case "eta", values(:,indices)=r.eta*C; values(:,meanIndex)=meanG*Amda;
        case "qgpv", values(:,indices)=r.qgpv*C-(hypot(w.k(indices),w.l(indices)).'.^2).*(r.psi*C); values(:,meanIndex)=-w.f*meanGZ*Amda;
        case "buoyancy", values(:,indices)=r.buoyancy*C; values(:,meanIndex)=-w.N2Function(z).*(meanG*Amda);
    end
    fields.(name)=values;
end
fields.ssh=complex(zeros(1,w.Nkl)); fields.ssh(:,indices)=e.ssh*C;
fields.endpointAnomalies=complex(zeros(2,w.Nkl)); fields.endpointAnomalies(:,indices)=e.eta_i*C; fields.endpointAnomalies(:,meanIndex)=w.mdaG([end 1],:)*Amda;
end
