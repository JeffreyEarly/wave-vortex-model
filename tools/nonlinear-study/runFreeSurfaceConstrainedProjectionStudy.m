function results = runFreeSurfaceConstrainedProjectionStudy(outputFolder)
% Measure constrained finite-mode projection without claiming pressure closure.
%
% This diagnostic uses the unchanged WVM physics at 81987767956fae5aadcb53a9df16482221f5f3e4
% and configureCIEnvironment's InternalModes@2.0.0-beta.4 provider. It samples
% one nonzero Fourier column at t=t0. C contains SSH, surface eta-SSH, and
% bottom eta. With no surface mass source their target source rates are
% [0; Seta(surface); Seta(bottom)]. All rates below are complex Fourier
% amplitudes, not maxima of the corresponding real spatial harmonic.
%
% H includes every cross term in the positive physical quadratic energy.
% The study solves min (B-B0)'*H*(B-B0), subject to C*B=target, by whitening
% H and taking the small constraint Schur complement. This is a coefficient
% constraint reaction, not a physical pressure. Changes in physical source
% work and uncorrected endpoint rates assess its limitations as a model.
% Work is 2*real(a'*sourcePair), per reference density, for the real harmonic
% represented by this complex column. The deterministic mixed state has unit
% quadratic energy; it changes when the retained count changes. Work defects
% are normalized by 2*norm(a)_H*norm(sourcePair)_{H^-1}, not by a possibly
% cancelling signed work. No nonlinear invariant claim follows from H.
%
% Run after configureCIEnvironment(sourceRoot,oceanKitRoot), adding this
% directory to the path. This helper does not alter any transform state.
arguments (Input)
    outputFolder (1,1) string
end
arguments (Output)
    results table
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
rows = cell(0,1);
for profile = ["constant","exponential"]
    N2 = @(z) 1e-4+0*z;
    if profile=="exponential", N2=@(z)1e-4*exp(2*z/700); end
    for nWave = [4 8 16]
        wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=nWave,inertialModeCount=3,nEVP=128);
        wvt.t0=31; wvt.t=31;
        column = find(wvt.kNonzero>0 & wvt.lNonzero==0,1);
        index = wvt.klNonzero(column);
        [basis,template,families,counts] = columnBasis(wvt,column,index);
        weights = wvt.verticalQuadratureWeights;
        H = basis.u'*(weights.*basis.u)+basis.v'*(weights.*basis.v)+basis.w'*(weights.*basis.w);
        H = H+basis.eta'*((weights.*wvt.N2).*basis.eta)+wvt.g*(basis.ssh'*basis.ssh);
        H = (H+H')/2;
        C = [basis.ssh; basis.eta(end,:)-basis.ssh; basis.eta(1,:)];
        diagonalScale = sqrt(real(diag(H)));
        scaledH = H./(diagonalScale*diagonalScale.');
        R = chol(scaledH);
        T = diag(1./diagonalScale)/R;
        identity = eye(size(H));
        whiteningError = norm(T'*H*T-identity,2);
        ordinal = (1:size(H,1)).';
        mixedY = exp(1i*.37*ordinal)./(1+.1*ordinal);
        mixedY = mixedY/norm(mixedY);
        mixedState = T*mixedY;
        [X,~,Z] = ndgrid(wvt.x,wvt.y,wvt.z);
        k = wvt.kNonzero(column);
        s = 1+Z/wvt.Lz;
        zero = zeros(size(X));
        for sourceKind = ["displacement","transverseAcceleration","mixed"]
            source = struct(u=zero,v=zero,w=zero,eta=zero);
            switch sourceKind
                case "displacement"
                    source.eta = 1e-5*cos(k*X).*s.^2;
                case "transverseAcceleration"
                    source.v = 1e-7*cos(k*X).*s.^2;
                case "mixed"
                    source.u = 2e-7*sin(k*X).*(1+s);
                    source.v = 1e-7*cos(k*X).*s.^2;
                    source.w = 3e-8*cos(k*X).*s;
                    source.eta = 1e-5*cos(k*X).*(.3+s.^2);
            end
            projected = wvt.projectSources(source);
            B0 = columnVector(projected,column,families,counts);
            y0 = R*(diagonalScale.*B0);
            pair = complex(zeros(size(H,1),1));
            for name = ["u","v","w","eta"]
                transformed = wvt.transformFromSpatialDomainWithFourier(source.(name));
                spectral.(name) = transformed(:,index);
                metric = weights;
                if name=="eta", metric=weights.*wvt.N2; end
                pair = pair+basis.(name)'*(metric.*spectral.(name));
            end
            target = [0;spectral.eta(end);spectral.eta(1)];
            uncorrectedResidual = C*B0-target;
            physicalSourceWork = 2*real(mixedState'*pair);
            rawEnergyRate = 2*real(mixedState'*H*B0);
            workScale = 2*norm(mixedY)*norm(T'*pair);
            for constraintSet = ["ssh","sshAndEndpoints"]
                selected = 1;
                if constraintSet=="sshAndEndpoints", selected=1:3; end
                A = C(selected,:)*T;
                rowScale = vecnorm(A,2,2);
                A = A./rowScale;
                desired = target(selected)./rowScale;
                singularValues = svd(A);
                rankTolerance = max(size(A))*eps(max(singularValues));
                constraintRank = sum(singularValues>rankTolerance);
                if constraintRank~=length(selected)
                    error('WV:ConstrainedStudyRank','The %s constraint matrix has rank %d of %d.',constraintSet,constraintRank,length(selected));
                end
                multiplier = (A*A')\(desired-A*y0);
                y = y0+A'*multiplier;
                B = T*y;
                residual = C*B-target;
                correction = B-B0;
                energyRate = 2*real(mixedState'*H*B);
                Q = identity-A'*((A*A')\A);
                admissibleY = Q*mixedY;
                preservedY = admissibleY-A'*((A*A')\(A*admissibleY));
                preservationError = norm(preservedY-admissibleY)/max(norm(admissibleY),realmin);
                [resolvedError,resolvedConstraint] = resolvedSourceProbe(wvt,T*admissibleY,template,column,index,families,counts,C,selected,R,diagonalScale);
                row = struct(inputWVMRevision="81987767956fae5aadcb53a9df16482221f5f3e4",provider="InternalModes@2.0.0-beta.4",matlabRelease=string(version('-release')),profile=profile,waveModeCount=nWave,apvModeCount=3,nz=wvt.Nz,coefficientCount=size(H,1),source=sourceKind,constraints=constraintSet,constraintRank=constraintRank,minimumConstraintSingularValue=min(singularValues),scaledGramRcond=rcond(scaledH),whiteningError=whiteningError,rawSSHRate=abs(uncorrectedResidual(1)),correctedSSHRate=abs(residual(1)),rawSurfaceDensityRateResidual=abs(uncorrectedResidual(2)),correctedSurfaceDensityRateResidual=abs(residual(2)),rawBottomDensityRateResidual=abs(uncorrectedResidual(3)),correctedBottomDensityRateResidual=abs(residual(3)),relativeHCorrection=norm(y-y0)/max(norm(y0),realmin),admissiblePreservationError=preservationError,resolvedSourceProjectionError=resolvedError,resolvedSourceConstraintResidual=resolvedConstraint,physicalSourceWork=physicalSourceWork,rawProjectedEnergyRate=rawEnergyRate,correctedProjectedEnergyRate=energyRate,correctionToEnergyRate=energyRate-rawEnergyRate,rawWorkDefectScaled=(rawEnergyRate-physicalSourceWork)/max(workScale,realmin),correctedWorkDefectScaled=(energyRate-physicalSourceWork)/max(workScale,realmin),maximumUnitEnergyWorkChange=2*sqrt(max(real(correction'*H*correction),0)));
                row.g0 = wvt.g0;
                row.gd = wvt.gd;
                row.f = wvt.f;
                row.g = wvt.g;
                row.horizontalWavenumber = k;
                row.nEVP = 128;
                row.referenceTime = wvt.t0;
                rows{end+1}=row; %#ok<AGROW>
                fprintf('%s waves=%d %s %s: SSH %.3g -> %.3g, endpoints %.3g/%.3g -> %.3g/%.3g, work defect %.3g -> %.3g\n',profile,nWave,sourceKind,constraintSet,row.rawSSHRate,row.correctedSSHRate,row.rawSurfaceDensityRateResidual,row.rawBottomDensityRateResidual,row.correctedSurfaceDensityRateResidual,row.correctedBottomDensityRateResidual,row.rawWorkDefectScaled,row.correctedWorkDefectScaled);
            end
        end
    end
end
results = struct2table(vertcat(rows{:}));
writetable(results,fullfile(outputFolder,'constrained-source-projection-study.csv'));
end

function [basis,template,families,counts] = columnBasis(wvt,column,index)
families = ["Ag_q","Ag_0","Aw_p","Aw_m"];
template = wvt.coefficientState();
counts = zeros(size(families));
for j = 1:length(families), counts(j)=size(template.(families(j)),1); end
for name = ["u","v","w","eta"], basis.(name)=complex(zeros(wvt.Nz,sum(counts))); end
basis.ssh = complex(zeros(1,sum(counts)));
offset = 0;
for j = 1:length(families)
    for mode = 1:counts(j)
        state = template;
        state.(families(j))(mode,column)=1;
        fields = wvt.reconstructSpectralState(state=state);
        for name = ["u","v","w","eta"], basis.(name)(:,offset+mode)=fields.(name)(:,index); end
        basis.ssh(offset+mode)=fields.ssh(end,index);
    end
    offset = offset+counts(j);
end
end

function vector = columnVector(state,column,families,counts)
vector = complex(zeros(sum(counts),1));
offset = 0;
for j = 1:length(families)
    vector(offset+(1:counts(j)))=state.(families(j))(:,column);
    offset = offset+counts(j);
end
end

function [errorValue,constraintResidual] = resolvedSourceProbe(wvt,vector,template,column,index,families,counts,C,selected,R,diagonalScale)
state = template;
offset = 0;
for j = 1:length(families)
    state.(families(j))(:,column)=vector(offset+(1:counts(j)));
    offset = offset+counts(j);
end
fields = wvt.reconstructSpectralState(state=state);
for name = ["u","v","w","eta"]
    source.(name)=wvt.transformToSpatialDomainWithFourier(fields.(name));
end
projected = columnVector(wvt.projectSources(source),column,families,counts);
errorValue = norm(R*(diagonalScale.*(projected-vector)))/max(norm(R*(diagonalScale.*vector)),realmin);
target = [0;fields.eta(end,index);fields.eta(1,index)];
constraintResidual = norm(C(selected,:)*projected-target(selected));
end
