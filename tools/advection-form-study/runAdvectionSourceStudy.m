function runAdvectionSourceStudy
% Independent sampled-source and modal projection refinement, fixed inventories.
folder=fileparts(mfilename('fullpath')); rows=struct([]); familyRows=struct([]); metricRows=struct([]);
specs=[8 17;8 33;16 33;16 65;32 129;48 129;32 257];
for profile=["constant","exponential"]
    objects=cell(1,size(specs,1));
    for j=1:numel(objects)
        objects{j}=makeAdvectionStudyTransform(profile,[specs(j,:) 3 4 2 3]);
        fprintf("source setup %s %d/%d done\n",profile,j,numel(objects));
    end
    for amplitude=[1e-4 .1 .4]
        for time=[327 901]
            rates=cell(numel(objects),4); sources=cell(numel(objects),4);
            for config=1:numel(objects)
                w=objects{config}; seed=manuscriptEvolutionOperators(w,profile,padding=1); state=seed.seed("mixed",amplitude);
                formIndex=0;
                for form=["divergence","advective","split","compatible"]
                    formIndex=formIndex+1; op=advectionStudyOperators(w,profile,form);
                    [rates{config,formIndex},sources{config,formIndex},terms]=op.rhs(time,state);
                end
                h=w.reconstructFields(["u_hat","v_hat","w_hat"]);
                continuity=w.diffX(h.u_hat)+w.diffY(h.v_hat)+w.diffZ(h.w_hat);
                W=diag(w.verticalQuadratureWeights); B=zeros(w.Nz); B(1,1)=-1; B(end,end)=1;
                defect=W*w.verticalDerivativeMatrix+w.verticalDerivativeMatrix'*W-B;
                row=struct(profile=profile,amplitude=amplitude,time=time,config=config,continuityMax=max(abs(continuity),[],'all'),sbpMatrixNorm=norm(defect,2),transportBottomMax=max(abs(terms.transportW(:,:,1)),[],'all'));
                if isempty(metricRows), metricRows=row; else, metricRows(end+1)=row; end %#ok<AGROW>
            end
            for config=1:numel(objects)
                w=objects{config}; reference=objects{7};
                for formIndex=1:4
                    forms=["divergence","advective","split","compatible"]; form=forms(formIndex);
                    for field=["u","v","w","eta"]
                        target=sample(sources{7,1}.(field),reference,w,profile);
                        value=sources{config,formIndex}.(field);
                        row=struct(profile=profile,amplitude=amplitude,time=time,config=config,form=form,field=field,rmsError=sqrt(mean((value-target).^2,'all')),maxError=max(abs(value-target),[],'all'),referenceRMS=sqrt(mean(target.^2,'all')));
                        if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
                    end
                    % Each object independently projects its sampled sources.
                    rate=rates{config,formIndex}; target=rates{7,1};
                    for family=string(fieldnames(rate)).'
                        actual=rate.(family); expected=target.(family);
                        if size(actual,2)==numel(w.klNonzero)
                            keys=round([w.kNonzero(:)*w.Lx,w.lNonzero(:)*w.Ly]/(2*pi));
                            referenceKeys=round([reference.kNonzero(:)*reference.Lx,reference.lNonzero(:)*reference.Ly]/(2*pi));
                            [ok,indices]=ismember(keys,referenceKeys,'rows');
                            actual=actual(:,ok); expected=expected(:,indices(ok));
                        end
                        row=struct(profile=profile,amplitude=amplitude,time=time,config=config,form=form,family=family,rmsError=sqrt(mean(abs(actual-expected).^2,'all')),referenceRMS=sqrt(mean(abs(expected).^2,'all')));
                        if isempty(familyRows), familyRows=row; else, familyRows(end+1)=row; end %#ok<AGROW>
                    end
                end
            end
            fprintf('sources %s amplitude %g time %g done\n',profile,amplitude,time);
            writetable(struct2table(rows),fullfile(folder,'results','sources.csv'));
            writetable(struct2table(familyRows),fullfile(folder,'results','families.csv'));
            writetable(struct2table(metricRows),fullfile(folder,'results','metrics.csv'));
        end
    end
end
end
function out=sample(value,from,to,profile)
% Interpolate the independently refined source, without re-evaluating it.
if profile=="constant", nodes=from.z/from.Lz; x=to.z/to.Lz;
else, nodes=expm1((from.z+from.Lz)/1300); x=expm1((to.z+to.Lz)/1300); end
n=numel(nodes); bw=(-1).^(0:n-1)'; bw([1 end])=bw([1 end])/2; M=zeros(numel(x),n);
for j=1:numel(x)
    [distance,k]=min(abs(x(j)-nodes));
    if distance<1e-13, M(j,k)=1; else, row=bw./(x(j)-nodes); M(j,:)=row'/sum(row); end
end
value=real(interpft(interpft(value,to.Nx,1),to.Ny,2));
out=reshape(reshape(value,[],from.Nz)*M.',to.Nx,to.Ny,to.Nz);
end
