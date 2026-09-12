function runThermodynamicBudgetControls
folder=fileparts(mfilename('fullpath')); rows=struct([]);
for profile=["constant","exponential"]
    if profile=="constant", N2=@(z)1e-4+zeros(size(z)); else, N2=@(z)1e-4*exp(z/650); end
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 33],N2Function=N2,apvModeCount=3,waveModeCount=4,mdaModeCount=2,inertialModeCount=3,nEVP=256,shouldAntialias=false);
    for scenario=["waves","mixed"]
        w.removeAll(); study=manuscriptEvolutionOperators(w,profile,padding=1); a=study.seed(scenario,.1);
        for variant=["displacement","density"]
            op=thermodynamicComparisonOperators(w,profile,variant); initial=a;
            if variant=="density", initial=thermodynamicCoefficientMap(w,profile,a,327); end
            names=string(fieldnames(initial)).';
            for dt=[10 5]
                state=initial; integral=zeros(3,1); first=op.observe(327,state);
                for t=327:dt:367-dt
                    k1=op.rhs(t,state); b1=thermodynamicBudgetRate(w,profile,variant,state,t,k1);
                    s=add(state,k1,dt/2); k2=op.rhs(t+dt/2,s); b2=thermodynamicBudgetRate(w,profile,variant,s,t+dt/2,k2);
                    s=add(state,k2,dt/2); k3=op.rhs(t+dt/2,s); b3=thermodynamicBudgetRate(w,profile,variant,s,t+dt/2,k3);
                    s=add(state,k3,dt); k4=op.rhs(t+dt,s); b4=thermodynamicBudgetRate(w,profile,variant,s,t+dt,k4);
                    for name=names, state.(name)=state.(name)+dt*(k1.(name)+2*k2.(name)+2*k3.(name)+k4.(name))/6; end
                    integral=integral+dt*(b1+2*b2+2*b3+b4)/6;
                end
                last=op.observe(367,state); change=[last.energy-first.energy;last.densityMoment-first.densityMoment;last.densitySquaredMoment-first.densitySquaredMoment];
                row=struct(profile=profile,scenario=scenario,variant=variant,deltaT=dt,energyChange=change(1),energyDefectIntegral=integral(1),energyBudgetError=change(1)-integral(1),densityBudgetError=change(2)-integral(2),secondDensityBudgetError=change(3)-integral(3),externalWork=0);
                if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
            end
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','budget-controls.csv'));
    function s=add(s,k,dt)
        for name=names, s.(name)=s.(name)+dt*k.(name); end
    end
end
