function [q,u,v,b,ub,vb,phiHat]=quasigeostrophicSpatialState(self)
% Return interior and two-endpoint fields in the shared QG spatial convention.
% - Topic: Evaluate physical fields
% - Returns q: full QGPV including its mean
% - Returns u: zonal velocity
% - Returns v: meridional velocity
% - Returns b: surface and bottom displacement anomalies
% - Returns ub: endpoint zonal velocity
% - Returns vb: endpoint meridional velocity
% - Returns phiHat: nonzero compact streamfunction samples
fields=self.reconstructFields(["qgpv","u","v","endpointAnomalies"]);
q=fields.qgpv; u=fields.u; v=fields.v; b=fields.endpointAnomalies;
ub=u(:,:,[end 1]); vb=v(:,:,[end 1]);
if nargout>6
    [r,C]=self.polynomialState(self.coefficientState()); phiHat=r.psi*C;
end
end
