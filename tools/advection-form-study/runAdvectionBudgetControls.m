function runAdvectionBudgetControls
% Integrate analytic inventory rates alongside each discrete RHS, without repair.
folder=fileparts(mfilename('fullpath')); rows=struct([]);
for profile=["constant","exponential"]
    for spec=[8 33 3 4 2 3;16 65 6 8 4 6].'
        w=makeAdvectionStudyTransform(profile,spec.');
        for scenario=["waves","mixed"]
            seed=manuscriptEvolutionOperators(w,profile,padding=1); initial=seed.seed(scenario,.1);
            for form=["divergence","advective","split","compatible"]
                op=advectionStudyOperators(w,profile,form);
                for dt=[10 5]
                    state=initial; integral=zeros(3,1); first=op.observe(327,state);
                    for t=327:dt:367-dt
                        k1=op.rhs(t,state); b1=thermodynamicBudgetRate(w,profile,"displacement",state,t,k1);
                        s=add(state,k1,dt/2); k2=op.rhs(t+dt/2,s); b2=thermodynamicBudgetRate(w,profile,"displacement",s,t+dt/2,k2);
                        s=add(state,k2,dt/2); k3=op.rhs(t+dt/2,s); b3=thermodynamicBudgetRate(w,profile,"displacement",s,t+dt/2,k3);
                        s=add(state,k3,dt); k4=op.rhs(t+dt,s); b4=thermodynamicBudgetRate(w,profile,"displacement",s,t+dt,k4);
                        for family=string(fieldnames(state)).', state.(family)=state.(family)+dt*(k1.(family)+2*k2.(family)+2*k3.(family)+k4.(family))/6; end
                        integral=integral+dt*(b1+2*b2+2*b3+b4)/6;
                    end
                    last=op.observe(367,state); change=[last.energy-first.energy;last.densityMoment-first.densityMoment;last.densitySquaredMoment-first.densitySquaredMoment];
                    row=struct(profile=profile,nx=w.Nx,nz=w.Nz,scenario=scenario,form=form,deltaT=dt,energyChange=change(1),energyDefectIntegral=integral(1),energyBudgetError=change(1)-integral(1),densityChange=change(2),densityDefectIntegral=integral(2),densityBudgetError=change(2)-integral(2),secondDensityChange=change(3),secondDensityDefectIntegral=integral(3),secondDensityBudgetError=change(3)-integral(3),externalWork=0);
                    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
                end
            end
        end
    end
end
writetable(struct2table(rows),fullfile(folder,'results','budgets.csv'));
end
function state=add(state,rate,scale)
for family=string(fieldnames(state)).', state.(family)=state.(family)+scale*rate.(family); end
end
