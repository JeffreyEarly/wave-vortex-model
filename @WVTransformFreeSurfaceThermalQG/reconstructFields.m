function fields = reconstructFields(self,variableNames,options)
% Reconstruct selected physical fields without changing canonical state.
% Buoyancy is -N2*eta_i; endpoint anomalies are surface then bottom displacement.
% - Topic: Evaluate physical fields
% - Parameter variableNames: names from namesOfTransformVariables
% - Parameter options.flowComponent: optional family-mask selection
% - Returns fields: named real physical arrays
arguments
    self (1,1) WVTransformFreeSurfaceThermalQG
    variableNames (1,:) string
    options.flowComponent WVFlowComponent = WVFlowComponent.empty(0,0)
end
if isempty(variableNames) || any(~ismember(variableNames,string(self.namesOfTransformVariables())))
    error('WV:ThermalField','Request supported thermal fields from namesOfTransformVariables.');
end
state=self.coefficientState(flowComponent=options.flowComponent);
endpointOnly=all(ismember(variableNames,["ssh","ssu","ssv","endpointAnomalies"]));
if endpointOnly
    C=complex(zeros(self.thermalModeCount,numel(self.klNonzero)));
    for p=1:numel(self.khUnique)
        columns=self.klNonzeroKhUniqueIndex==p;
        C(:,columns)=self.thermalToPolynomial(:,:,p)*state.Ath(:,columns);
    end
    r=WVInternal.thermalPolynomialFields([0;-self.Lz],self.thermalModeCount,self.Lz,self.N20,self.inverseScale,0,self.f,self.g);
    geometry=self.endpointGeometry();
else
    [r,C]=self.polynomialState(state); geometry=self;
end
meanIndex=find(hypot(self.k,self.l)==0,1);
fields=struct();
for name=variableNames
    switch name
        case "endpointAnomalies"
            if endpointOnly, values=r.eta_i*C; else, values=r.eta_i([end 1],:)*C; end
            hat=complex(zeros(2,self.Nkl)); hat(:,self.klNonzero)=values;
            hat(:,meanIndex)=self.mdaG([end 1],:)*state.Amda;
            fields.(name)=self.endpointGeometry().transformToSpatialDomainWithFourier(hat);
        case {"ssh","ssu","ssv"}
            row=r.ssh*C;
            if name=="ssu", row=(-1i*self.l(self.klNonzero).') .*(row*self.g/self.f); end
            if name=="ssv", row=(1i*self.k(self.klNonzero).') .*(row*self.g/self.f); end
            hat=complex(zeros(2,self.Nkl)); hat(:,self.klNonzero)=repmat(row,2,1);
            physical=self.endpointGeometry().transformToSpatialDomainWithFourier(hat);
            fields.(name)=physical(:,:,1);
        case "uvMax"
            if isfield(fields,'u') && isfield(fields,'v')
                fields.(name)=max(hypot(fields.u,fields.v),[],"all");
            else
                hat=complex(zeros(self.Nz,self.Nkl));
                hat(:,self.klNonzero)=(-1i*self.l(self.klNonzero).').*(r.psi*C);
                u=geometry.transformToSpatialDomainWithFourier(hat);
                hat(:,self.klNonzero)=(1i*self.k(self.klNonzero).').*(r.psi*C);
                v=geometry.transformToSpatialDomainWithFourier(hat);
                fields.(name)=max(hypot(u,v),[],"all");
            end
        otherwise
            switch name
                case "psi", values=r.psi*C; meanValue=zeros(self.Nz,1);
                case "u", values=(-1i*self.l(self.klNonzero).').*(r.psi*C); meanValue=zeros(self.Nz,1);
                case "v", values=(1i*self.k(self.klNonzero).').*(r.psi*C); meanValue=zeros(self.Nz,1);
                case "eta", values=r.eta*C; meanValue=self.mdaG*state.Amda;
                case "eta_i", values=r.eta_i*C; meanValue=self.mdaG*state.Amda;
                case "buoyancy", values=r.buoyancy*C; meanValue=-self.N2.*(self.mdaG*state.Amda);
                case "qgpv", values=r.qgpv*C-(hypot(self.k(self.klNonzero),self.l(self.klNonzero)).'.^2).*(r.psi*C); meanValue=-self.f*self.mdaGZ*state.Amda;
            end
            hat=complex(zeros(self.Nz,self.Nkl)); hat(:,self.klNonzero)=values; hat(:,meanIndex)=meanValue;
            fields.(name)=geometry.transformToSpatialDomainWithFourier(hat);
    end
end
end
