function wvt = makeToleranceBoussinesq()
% Reuse the documented nonlinear mixed-family initial state.
wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 129],N2Function=@(z)1e-4+0*z,apvModeCount=4,mdaModeCount=4,inertialModeCount=4,waveModeCount=6,nEVP=256,shouldAntialias=true,quadraticDealiasing="fixedFraction");
state=wvt.coefficientState();
column=find(wvt.kNonzero>0 & wvt.lNonzero==0,1); index=wvt.klNonzero(column);
for mode=1:2
    unit=wvt.coefficientState(); unit.Aw_p(mode,column)=1;
    polarization=wvt.reconstructSpectralState(state=unit);
    height=[2 .15]; phase=[.37 1.1];
    state.Aw_p(mode,column)=height(mode)*exp(1i*phase(mode))/(2*polarization.ssh(end,index));
end
state.Ag_q(1,column)=5e-9*exp(.83i);
state.Aio(1)=.02*exp(.33i)/(2*wvt.inertialF(end,1));
% Prescribe small active endpoint anomalies independently of the APV term.
fields=wvt.reconstructSpectralState(state=state);
existing=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
response=zeros(2);
for mode=1:2
    unit=wvt.coefficientState(); unit.Ag_0(mode,column)=1;
    fields=wvt.reconstructSpectralState(state=unit);
    response(:,mode)=[fields.eta(end,index)-fields.ssh(end,index);fields.eta(1,index)];
end
state.Ag_0(:,column)=response\([.2*exp(.7i);.1*exp(1.3i)]/2-existing);
% Inward mean label offsets keep parcels inside the reference density domain.
state.Amda(1:2)=wvt.mdaG([end 1],1:2)\[2;-2];
yColumn=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
state.Aw_p(1,yColumn)=.3*exp(.41i)*state.Aw_p(1,column);
state.Aw_m=.2*exp(.63i)*state.Aw_p;
for name=string(fieldnames(state)).', wvt.(name)=state.(name); end
wvt.t0=-17;
wvt.addForcing(WVNonlinearAdvection(wvt));
end
