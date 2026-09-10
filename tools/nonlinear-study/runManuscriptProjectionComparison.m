function results = runManuscriptProjectionComparison(outputPath,options)
% Compare literal Appendix C projection with matched-physics weak evolution.
%
% This instantaneous authoring experiment does not replace the runtime.
% Pressure is reconstructed from modes; the reference density is constant
% above zero and the surface condition is the manuscript approximation.
% Horizontal padding evaluates products before restriction to the same
% retained transform. Separate rows vary the vertical inventory/grid.
arguments (Input)
    outputPath (1,1) string
    options.profiles (1,:) string {mustBeMember(options.profiles,["constant","exponential"])} = ["constant","exponential"]
    options.levels (1,:) double {mustBeMember(options.levels,[1 2 3])} = [1 2]
    options.amplitudes (1,:) double {mustBePositive} = [1 .5 .25 .125]
    options.padding (1,:) double {mustBeMember(options.padding,[1 2 4])} = [1 2]
    options.scenarios (1,:) string = "mixed"
    options.shouldCompareDiagnosticPressure (1,1) logical = false
    options.fixedModeCounts (1,:) double {mustBeInteger,mustBePositive} = []
    options.shouldCheckEnergyDerivative (1,1) logical = false
end
configuration = [65 2 3;129 4 6;257 8 12];
rows = cell(0,1);
helper = freeSurfaceWeakStudyHelpers();
for profile = options.profiles
    profileFunction = @(z)1e-4+zeros(size(z));
    if profile=="exponential", profileFunction=@(z)1e-4*exp(z/650); end
    for level = options.levels
        Nz=configuration(level,1); count=configuration(level,2); waveCount=configuration(level,3);
        if ~isempty(options.fixedModeCounts)
            assert(numel(options.fixedModeCounts)==2,'Supply [balancedCount waveCount].');
            count=options.fixedModeCounts(1); waveCount=options.fixedModeCounts(2);
        end
        wvt = WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 Nz],N2Function=profileFunction,apvModeCount=count,mdaModeCount=count,inertialModeCount=count,waveModeCount=waveCount,nEVP=256,shouldAntialias=true,shouldCheckQuadraticAliasing=true);
        wvt.t0=-17; wvt.t=327;
        seed=helper.seedState(wvt);
        column=find(wvt.kNonzero==0 & wvt.lNonzero>0,1);
        unit=wvt.coefficientState(); unit.Aw_m(1,column)=1;
        spectral=wvt.reconstructSpectralState(state=unit);
        seed.Aw_m(1,column)=.7*exp(.43i)/(2*spectral.ssh(end,wvt.klNonzero(column)));
        weak=WVInternal.freeSurfaceWeakSolver(wvt);
        if options.shouldCompareDiagnosticPressure, pressureSolver=WVInternal.freeSurfacePressureSolver(wvt); end
        derivative=derivatives(wvt,helper);
        for scenario = options.scenarios
            initial=seed;
            if scenario=="waves"
                initial.Ag_q(:)=0; initial.Ag_0(:)=0; initial.Aio(:)=0;
            elseif scenario=="balanced"
                initial.Aw_p(:)=0; initial.Aw_m(:)=0; initial.Aio(:)=0;
            elseif scenario~="mixed"
                error('WVStudy:Scenario','Use mixed, waves or balanced.')
            end
            for amplitude = options.amplitudes
                state=structfun(@(value)amplitude*value,initial,UniformOutput=false);
                hatted=sample(wvt,state,1);
                [integratedN2,thermal]=referenceThermodynamics(hatted,wvt,profile);
                base=evaluateManuscriptNonlinearTerms(hatted,hatted.p,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,integratedN2,derivative);
                zero=zeros(size(hatted.u));
                pressureFree=evaluateManuscriptNonlinearTerms(hatted,zero,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,integratedN2,derivative);
                alpha=reshape(1+wvt.z/wvt.Lz,1,1,[]);
                gamma=base.physical.gamma;
                metric=struct(gamma=gamma,betaX=alpha.*derivative.x(hatted.ssh)./gamma,betaY=alpha.*derivative.y(hatted.ssh)./gamma,displacementWeight=gamma.*thermal.N2AtLabel);
                [covector,target,weakRHSReport]=WVInternal.freeSurfaceWeakRHS(wvt,hatted,metric,-integratedN2,wvt.g*hatted.ssh,derivative,weak.boundary,tendency=pressureFree.total);
                clock=tic;
                [weakTotalRate,weakReport]=weak.solve(covector,target,metric);
                weakSolveSeconds=toc(clock);
                linearRate=phaseRate(wvt,state);
                weakRate=subtract(weakTotalRate,linearRate);
                weakFields=sample(wvt,weakTotalRate,1);
                weakRateFields=sample(wvt,weakRate,1);
                diagnosticPressure=[];
                pressureDifferenceNorm=NaN; pressureSolverResidual=NaN;
                if options.shouldCompareDiagnosticPressure
                    [piDiagnostic,pressureReport]=pressureSolver.solve(hatted.ssh,pressureFree.total,wvt.g*hatted.ssh,tolerance=1e-12);
                    diagnosticPressure=wvt.rho0*piDiagnostic;
                    pressureDifferenceNorm=sqrt(sum(reshape(wvt.verticalQuadratureWeights,1,1,[]).*(piDiagnostic-hatted.p/wvt.rho0).^2,'all')/(wvt.Nx*wvt.Ny));
                    pressureSolverResidual=pressureReport.scaledRelativeResidual;
                end
                nativeRateFields=[];
                for padding = options.padding
                    padded=sample(wvt,state,padding);
                    [paddedIntegral,~]=referenceThermodynamics(padded,wvt,profile);
                    clock=tic;
                    terms=evaluateManuscriptNonlinearTerms(padded,padded.p,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,paddedIntegral,derivative);
                    sources=struct();
                    for name=["u","v","w","eta"], sources.(name)=restrict(terms.source.(name),wvt.Nx,wvt.Ny); end
                    rate=wvt.projectSources(sources);
                    directAssemblyProjectionSeconds=toc(clock);
                    pressureSubstitutionRateDifference=NaN;
                    if options.shouldCompareDiagnosticPressure
                        p=diagnosticPressure;
                        if padding~=1, p=real(interpft(interpft(p,padding*wvt.Nx,1),padding*wvt.Ny,2)); end
                        corrected=evaluateManuscriptNonlinearTerms(padded,p,wvt.z,wvt.Lz,wvt.f,wvt.rho0,wvt.N2,paddedIntegral,derivative);
                        for name=["u","v","w","eta"], correctedSources.(name)=restrict(corrected.source.(name),wvt.Nx,wvt.Ny); end
                        correctedRate=wvt.projectSources(correctedSources);
                        pressureSubstitutionRateDifference=fieldNorm(sample(wvt,subtract(correctedRate,rate),1),reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny),wvt.N2,wvt.g);
                    end
                    totalRate=rate;
                    for name=string(fieldnames(rate)).', totalRate.(name)=rate.(name)+linearRate.(name); end
                    totalFields=sample(wvt,totalRate,1);
                    rateFields=sample(wvt,rate,1);
                    horizontalPaddingDifference=NaN;
                    if padding==1, nativeRateFields=rateFields; end
                    if ~isempty(nativeRateFields)
                        horizontalPaddingDifference=fieldNorm(subtract(rateFields,nativeRateFields),reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny),wvt.N2,wvt.g);
                    end
                    % The strong residual deliberately uses the fixed
                    % native-grid equation reference in every padding row.
                    difference=subtract(totalFields,base.total);
                    weights=reshape(wvt.verticalQuadratureWeights,1,1,[])/(wvt.Nx*wvt.Ny);
                    directNonlinearNorm=fieldNorm(rateFields,weights,wvt.N2,wvt.g);
                    weakNonlinearNorm=fieldNorm(weakRateFields,weights,wvt.N2,wvt.g);
                    directWeakDifference=fieldNorm(subtract(rateFields,weakRateFields),weights,wvt.N2,wvt.g);
                    strongResidual=fieldNorm(difference,weights,wvt.N2,wvt.g);
                    sshResidual=max(abs(totalFields.ssh-hatted.w(:,:,end)),[],'all');
                    sshPhaseResidual=max(abs(sampleSSH(wvt,linearRate)-hatted.w(:,:,end)),[],'all');
                    endpointTarget=weakRHSReport.boundaryTargetFields;
                    surfaceRate=totalFields.eta(:,:,end)-totalFields.ssh;
                    bottomRate=totalFields.eta(:,:,1);
                    surfaceResidual=max(abs(surfaceRate-endpointTarget.surface),[],'all');
                    bottomResidual=max(abs(bottomRate-endpointTarget.bottom),[],'all');
                    retainedResidual=norm(weak.boundary.apply(totalRate)-target);
                    weakRetainedResidual=norm(weak.boundary.apply(weakTotalRate)-target);
                    pressureSurfaceResidual=max(abs(hatted.p(:,:,end)/wvt.rho0-wvt.g*hatted.ssh),[],'all');
                    divergence=derivative.x(totalFields.u)+derivative.y(totalFields.v)+derivative.xi(totalFields.w);
                    divergenceResidual=max(abs(divergence),[],'all');
                    % A same-pressure mapped-equation check is distinct from
                    % the independent Cartesian manufactured equation tests.
                    mapped=WVInternal.freeSurfaceMappedTendency(hatted,hatted.p,-integratedN2,wvt.z,wvt.Lz,wvt.f,wvt.rho0,derivative);
                    transcriptionError=maxFieldDifference(base.total,mapped);
                    reactionWork=-weak.boundary.apply(state).'*weakReport.multiplier;
                    directEnergyRate=energyRate(hatted,totalFields,base.physical,thermal,derivative,wvt,weights);
                    weakEnergyRate=energyRate(hatted,weakFields,base.physical,thermal,derivative,wvt,weights);
                    energyDerivativeError=NaN;
                    if options.shouldCheckEnergyDerivative
                        errors=zeros(1,3); steps=[1 .1 .01];
                        for iStep=1:numel(steps)
                            plus=hatted; minus=hatted;
                            for name=["u","v","w","eta","ssh"]
                                plus.(name)=hatted.(name)+steps(iStep)*totalFields.(name);
                                minus.(name)=hatted.(name)-steps(iStep)*totalFields.(name);
                            end
                            finiteDifference=(energyValue(plus,wvt,profile,derivative,weights)-energyValue(minus,wvt,profile,derivative,weights))/(2*steps(iStep));
                            errors(iStep)=abs(finiteDifference-directEnergyRate);
                        end
                        energyDerivativeError=min(errors);
                        fprintf('Energy derivative absolute errors at steps [1,.1,.01]: %.6g %.6g %.6g\n',errors);
                        assert(energyDerivativeError<1e-9,'The energy directional derivative failed its independent finite-difference control.');
                    end
                    sourceMagnitude=max(abs(sources.w),[],'all');
                    minimumLabel=min(thermal.label,[],'all'); maximumLabel=max(thermal.label,[],'all');
                    row=table(profile,level,Nz,count,waveCount,scenario,amplitude,padding,directNonlinearNorm,weakNonlinearNorm,directWeakDifference,strongResidual,sshResidual,sshPhaseResidual,surfaceResidual,bottomResidual,retainedResidual,weakRetainedResidual,pressureSurfaceResidual,divergenceResidual,transcriptionError,reactionWork,directEnergyRate,weakEnergyRate,sourceMagnitude,minimumLabel,maximumLabel,directAssemblyProjectionSeconds,weakSolveSeconds,pressureDifferenceNorm,pressureSolverResidual,pressureSubstitutionRateDifference,horizontalPaddingDifference,energyDerivativeError);
                    rows{end+1,1}=row; %#ok<AGROW>
                    fprintf('%s level%d %s a=%g pad%d: SSH %.3g, surface %.3g, bottom %.3g, direct/weak %.3g\n',profile,level,scenario,amplitude,padding,sshResidual,surfaceResidual,bottomResidual,directWeakDifference/max(directNonlinearNorm,realmin));
                    assert(transcriptionError<2e-11,'Appendix C transcription does not match supplied-pressure mapped equations.');
                    assert(sshPhaseResidual<2e-12 && pressureSurfaceResidual<2e-10);
                    assert(weakRetainedResidual<1e-12);
                end
            end
        end
    end
end
results=vertcat(rows{:});
writetable(results,outputPath);
end

function hatted = sample(wvt,state,padding)
spectral=wvt.reconstructSpectralState(state=state);
for name=["u","v","w","eta","ssh","p"]
    value=wvt.transformToSpatialDomainWithFourier(spectral.(name));
    if padding~=1, value=real(interpft(interpft(value,padding*wvt.Nx,1),padding*wvt.Ny,2)); end
    if name=="ssh", value=value(:,:,end); end
    hatted.(name)=value;
end
end

function value = sampleSSH(wvt,state)
spectral=wvt.reconstructSpectralState(state=state);
value=wvt.transformToSpatialDomainWithFourier(spectral.ssh);
value=value(:,:,end);
end

function derivative = derivatives(wvt,helper)
derivative=struct(x=@(field)helper.fourierDerivative(field,wvt.Lx,1),y=@(field)helper.fourierDerivative(field,wvt.Ly,2),xi=@(field)reshape(reshape(field,[],wvt.Nz)*wvt.verticalDerivativeMatrix.',size(field)));
end

function value = restrict(field,Nx,Ny)
% Retain the original Fourier cells; no pointwise downsampling of products.
if size(field,1)==Nx && size(field,2)==Ny, value=field; return; end
spectrum=fft2(field)/(size(field,1)*size(field,2));
mx=[0:Nx/2-1,-Nx/2:-1]; my=[0:Ny/2-1,-Ny/2:-1];
coefficient=spectrum(mod(mx,size(field,1))+1,mod(my,size(field,2))+1,:);
% The antialiased transform excludes these Nyquist cells.
coefficient(Nx/2+1,:,:)=0; coefficient(:,Ny/2+1,:)=0;
value=real(ifft2(coefficient))*(Nx*Ny);
end

function [integralN2,thermal] = referenceThermodynamics(hatted,wvt,profile)
z=reshape(wvt.z,1,1,[])+reshape(1+wvt.z/wvt.Lz,1,1,[]).*hatted.ssh;
label=z-hatted.eta;
tolerance=32*eps(wvt.Lz);
assert(all(label>=-wvt.Lz-tolerance & label<=tolerance,'all'),'The study seed has unsupported parcel labels.');
r=min(0,max(-wvt.Lz,label)); upper=min(z,0); interval=upper-r;
if profile=="constant"
    integralN2=1e-4*interval;
    ILabel=1e-4*r; JLabel=.5e-4*r.^2; JUpper=.5e-4*upper.^2;
    N2AtLabel=1e-4+zeros(size(r));
else
    L=650;
    integralN2=1e-4*L*exp(r/L).*expm1(interval/L);
    ILabel=1e-4*L*expm1(r/L);
    JLabel=1e-4*L^2*(expm1(r/L)-r/L);
    JUpper=1e-4*L^2*(expm1(upper/L)-upper/L);
    N2AtLabel=1e-4*exp(r/L);
end
ape=-hatted.eta.*ILabel-JLabel+JUpper;
thermal=struct(label=label,N2AtLabel=N2AtLabel,ape=ape,apeEta=hatted.eta.*N2AtLabel,apeZ=-hatted.eta.*N2AtLabel+integralN2);
end

function rate = phaseRate(wvt,state)
rate=structfun(@(value)zeros(size(value)),state,UniformOutput=false);
omega=wvt.waveFrequency(:,wvt.klNonzeroKhUniqueIndex);
rate.Aw_p=1i*omega.*state.Aw_p; rate.Aw_m=-1i*omega.*state.Aw_m; rate.Aio=1i*wvt.f*state.Aio;
end

function result = subtract(a,b)
result=struct();
for name=string(fieldnames(b)).'
    result.(name)=a.(name)-b.(name);
end
end

function value = fieldNorm(fields,weights,N2,g)
value=sqrt(sum(weights.*(fields.u.^2+fields.v.^2+fields.w.^2+reshape(N2,1,1,[]).*fields.eta.^2),'all')+g*mean(fields.ssh.^2,'all'));
end

function value = maxFieldDifference(a,b)
value=0;
for name=string(fieldnames(b)).', value=max(value,max(abs(a.(name)-b.(name)),[],'all')); end
end

function value = energyRate(hatted,rate,physical,thermal,derivative,wvt,weights)
% Differentiate the actual upper-constant APE plus the manuscript's
% approximate g*SSH^2/2 surface energy. The same approximation in the
% pressure boundary condition preserves the matching continuum energy
% balance. Here we measure the finite projected/discretized rate.
alpha=reshape(1+wvt.z/wvt.Lz,1,1,[]);
gamma=physical.gamma; gammaT=rate.ssh/wvt.Lz;
uT=(rate.u-physical.u.*gammaT)./gamma;
vT=(rate.v-physical.v.*gammaT)./gamma;
wT=rate.w+alpha.*(uT.*derivative.x(hatted.ssh)+vT.*derivative.y(hatted.ssh)+physical.u.*derivative.x(rate.ssh)+physical.v.*derivative.y(rate.ssh));
zT=alpha.*rate.ssh;
kinetic=.5*(physical.u.^2+physical.v.^2+physical.w.^2);
value=sum(weights.*(gammaT.*(kinetic+thermal.ape)+gamma.*(physical.u.*uT+physical.v.*vT+physical.w.*wT+thermal.apeEta.*rate.eta+thermal.apeZ.*zT)),'all')+wvt.g*mean(hatted.ssh.*rate.ssh,'all');
end

function value = energyValue(hatted,wvt,profile,derivative,weights)
[~,thermal]=referenceThermodynamics(hatted,wvt,profile);
gamma=1+hatted.ssh/wvt.Lz;
alpha=reshape(1+wvt.z/wvt.Lz,1,1,[]);
u=hatted.u./gamma; v=hatted.v./gamma;
w=hatted.w+alpha.*(u.*derivative.x(hatted.ssh)+v.*derivative.y(hatted.ssh));
value=sum(weights.*gamma.*(.5*(u.^2+v.^2+w.^2)+thermal.ape),'all')+.5*wvt.g*mean(hatted.ssh.^2,'all');
end
