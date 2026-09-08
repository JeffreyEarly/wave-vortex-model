function [state,assessment] = freeSurfaceCoefficientTransfer(source,target,options)
% Match resolved identities and their normalization, without replacing modes.
arguments (Input)
    source WVTransform
    target WVTransform
    options.modeTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 2*max(source.Nz,target.Nz)+1
end
if ~strcmp(class(source),class(target)) || ~ismember(string(class(source)),["WVTransformFreeSurfaceQG","WVTransformFreeSurfaceBoussinesq"])
    error('WV:TransferIncompatible','Transfer requires the same free-surface model class.')
end
for name=["Lx","Ly","Lz","g","rho0","latitude","rotationRate","planetaryRadius","g0","gd"]
    if ~isequal(source.(name),target.(name))
        error('WV:TransferIncompatible','Resolution transfer requires identical %s.',name)
    end
end
if ~isequal(source.activeEndpoint,target.activeEndpoint)
    error('WV:TransferIncompatible','Keep the same active endpoints for resolution transfer.')
end
if options.quadratureCount<2*max(source.Nz,target.Nz)+1
    error('WV:TransferQuadrature','Use at least 2*max(source.Nz,target.Nz)+1 quadrature points.')
end
if source.Nz>=target.Nz, grid=source.z; else, grid=target.z; end
rule=WVInternal.qgVerticalOperators(grid,options.quadratureCount);
z=rule.zQuadrature; weights=rule.quadratureWeights;
Ps=WVInternal.qgVerticalInterpolation(source.z,z); Pt=WVInternal.qgVerticalInterpolation(target.z,z);
N2s=source.N2Function(z); N2t=target.N2Function(z);
if max(abs(N2s-N2t)./max(abs(N2s),realmin))>1e-10
    error('WV:TransferIncompatible','Source and target stratifications differ on the comparison quadrature.')
end
metric=[weights;weights;weights;weights.*N2s(:);source.g];
sourceState=source.coefficientState(); state=target.coefficientState();
for name=string(fieldnames(state)).', state.(name)=complex(zeros(size(state.(name)))); end
state.Amda=real(state.Amda);
sourceKeys=[source.kMode_wv(source.klNonzero),source.lMode_wv(source.klNonzero)];
targetKeys=[target.kMode_wv(target.klNonzero),target.lMode_wv(target.klNonzero)];
[common,targetColumn]=ismember(sourceKeys,targetKeys,'rows');
sourceEnergy=0; targetEnergy=0; errorEnergy=0; discardedEnergy=0; retainedErrorEnergy=0;
familyDiscardedEnergy=struct(); familyMatched=struct(); maxModeError=0;
for family=string(fieldnames(state)).'
    familyDiscardedEnergy.(family)=0; familyMatched.(family)=0;
end
% Include the horizontal mean as the final column, with its real-field factor.
for column=0:length(source.klNonzero)
    isMean=column==0; tc=0; present=true;
    if isMean
        families=intersect(string(fieldnames(state)),["Aio","Amda"],'stable'); factor=.5;
    else
        families=setdiff(string(fieldnames(state)),["Aio","Amda"],'stable'); factor=1;
        present=common(column); if present, tc=targetColumn(column); end
    end
    S=complex(zeros(length(metric),1)); T=S; lost=S; retained=S;
    for family=families.'
        [Ms,sourceLabels]=WVInternal.freeSurfaceTransferModes(source,family,column,Ps,source.t);
        if present
            [Mt,targetLabels]=WVInternal.freeSurfaceTransferModes(target,family,tc,Pt,source.t);
            [matched,targetRow]=ismember(sourceLabels,targetLabels);
        else
            matched=false(size(sourceLabels)); targetRow=zeros(size(sourceLabels)); Mt=zeros(length(metric),0);
        end
        if isMean, a=sourceState.(family); else, a=sourceState.(family)(:,column); end
        b=complex(zeros(size(Mt,2),1));
        for j=find(matched).'
            % A scalar shape alignment cannot detect a changed APV inversion
            % eigenvalue or reference-time wave frequency. Check those too.
            if ismember(family,["Ag_q","Aw_p","Aw_m"])
                sp=source.klNonzeroKhUniqueIndex(column); tp=target.klNonzeroKhUniqueIndex(tc);
                parameter="apvMu"; if family~="Ag_q", parameter="waveFrequency"; end
                sv=source.(parameter)(j,sp); tv=target.(parameter)(targetRow(j),tp);
                if abs(sv-tv)>options.modeTolerance*max(abs(sv),realmin)
                    error('WV:TransferModeMismatch','%s physical mode %g has an incompatible %s. Refine the scientific representation.',family,sourceLabels(j),parameter)
                end
            end
            sr=Ms(:,j); tr=Mt(:,targetRow(j));
            normTarget=real(tr'*(metric.*tr)); normSource=real(sr'*(metric.*sr));
            if normTarget<=0 || normSource<=0
                error('WV:TransferNullMode','Matched physical modes must have positive energy.')
            end
            scale=(tr'*(metric.*sr))/normTarget;
            residual=sr-scale*tr;
            modeError=sqrt(real(residual'*(metric.*residual))/normSource);
            maxModeError=max(maxModeError,modeError);
            if modeError>options.modeTolerance
                error('WV:TransferModeMismatch','%s physical mode %g at Fourier column %d differs by %.3g (tolerance %.3g). Refine the scientific representation or sampling grid.',family,sourceLabels(j),column,modeError,options.modeTolerance)
            end
            b(targetRow(j))=scale*a(j);
        end
        if family=="Amda", b=real(b); end
        if present
            if isMean, state.(family)=b; else, state.(family)(:,tc)=b; end
        end
        full=Ms*a(:);
        missing=Ms(:,~matched)*reshape(a(~matched),[],1);
        kept=Ms(:,matched)*reshape(a(matched),[],1); transferred=Mt*b;
        if family=="Aio"
            full=2*real(full); missing=2*real(missing); kept=2*real(kept); transferred=2*real(transferred);
        end
        S=S+full; T=T+transferred; lost=lost+missing; retained=retained+kept;
        familyDiscardedEnergy.(family)=familyDiscardedEnergy.(family)+factor*real(missing'*(metric.*missing));
        familyMatched.(family)=familyMatched.(family)+nnz(matched);
    end
    sourceEnergy=sourceEnergy+factor*real(S'*(metric.*S));
    targetEnergy=targetEnergy+factor*real(T'*(metric.*T));
    errorEnergy=errorEnergy+factor*real((S-T)'*(metric.*(S-T)));
    discardedEnergy=discardedEnergy+factor*real(lost'*(metric.*lost));
    retainedErrorEnergy=retainedErrorEnergy+factor*real((retained-T)'*(metric.*(retained-T)));
end
assessment=struct(sourceTime=source.t,targetReferenceTime=target.t0,quadratureCount=options.quadratureCount,maximumModeShapeError=maxModeError,sourceEnergy=sourceEnergy,targetEnergy=targetEnergy,errorEnergy=errorEnergy,relativeFieldError=sqrt(errorEnergy/max(sourceEnergy,realmin)),discardedEnergy=discardedEnergy,relativeDiscardedFieldNorm=sqrt(discardedEnergy/max(sourceEnergy,realmin)),retainedRepresentationError=sqrt(retainedErrorEnergy/max(sourceEnergy,realmin)),familyDiscardedEnergy=familyDiscardedEnergy,familyMatched=familyMatched);
end
