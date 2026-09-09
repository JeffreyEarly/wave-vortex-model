function results = runFreeSurfaceKinematicProbe(outputFolder)
% Measure the SSH tendency induced by the existing volume-source projector.
%
% Canonical amplitudes already include exact linear evolution through their
% reconstruction phases. With no independent surface mass source, an added
% amplitude tendency B must reconstruct zero SSH: C_ssh(t)*B=0. This study
% measures that constraint for generic sources rather than assuming that
% divergence-free modal velocities imply surface kinematics.
arguments (Input)
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
rows = cell(0,1);
for profile = ["constant","exponential"]
    N2 = @(z) 1e-4+0*z;
    if profile=="exponential", N2=@(z)1e-4*exp(2*z/700); end
    for nWave = [4 8 16]
        wvt=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 65],N2Function=N2,apvModeCount=3,mdaModeCount=2,waveModeCount=nWave,inertialModeCount=3,nEVP=128);
        wvt.t0=31; wvt.t=127;
        [X,~,Z]=ndgrid(wvt.x,wvt.y,wvt.z);
        k=2*pi/wvt.Lx; s=1+Z/wvt.Lz;
        blank=zeros(size(X));
        for sourceKind=["displacement","transverseAcceleration","verticalAcceleration","zeroSurfacePressure","nonzeroSurfacePressure"]
            source=struct(u=blank,v=blank,w=blank,eta=blank);
            switch sourceKind
                case "displacement"
                    source.eta=1e-5*cos(k*X).*s.^2;
                case "transverseAcceleration"
                    source.v=1e-7*cos(k*X).*s.^2;
                case "verticalAcceleration"
                    source.w=1e-7*cos(k*X).*s.^2;
                case "zeroSurfacePressure"
                    % Negative gradient of p/rho0=1e-4*cos(k*x)*s*(1-s).
                    source.u=1e-4*k*sin(k*X).*s.*(1-s);
                    source.w=-1e-4*cos(k*X).*(1-2*s)/wvt.Lz;
                case "nonzeroSurfacePressure"
                    % Negative gradient of p/rho0=1e-4*cos(k*x)*s^2.
                    source.u=1e-4*k*sin(k*X).*s.^2;
                    source.w=-2e-4*cos(k*X).*s/wvt.Lz;
            end
            B=wvt.projectSources(source);
            mapped=wvt.reconstructSpectralState(state=B);
            sshRate=wvt.transformToSpatialDomainWithFourier(mapped.ssh);
            divergence=1i*wvt.k.'.*mapped.u+1i*wvt.l.'.*mapped.v+wvt.verticalDerivativeMatrix*mapped.w;
            % An individual projected source can have exactly zero divergent
            % velocity terms. Scale by the independently specified source,
            % not cancellation-sized reconstructed derivative terms.
            sourceScale=norm(source.u(:))+norm(source.v(:))+norm(source.w(:))+abs(wvt.f)*norm(source.eta(:));
            divergenceScale=hypot(k,1/wvt.Lz)*sourceScale;
            row=struct(profile=profile,waveModeCount=nWave,source=sourceKind,maximumSSHRate=max(abs(sshRate),[],'all'),maximumVelocityDivergence=max(abs(divergence),[],'all'),sourceScaledVelocityDivergence=norm(divergence,'fro')/max(divergenceScale,realmin),maximumBottomWRate=max(abs(mapped.w(1,:))),maximumWaveCoefficientRate=max([abs(B.Aw_p(:));abs(B.Aw_m(:))]));
            rows{end+1}=row; %#ok<AGROW>
            fprintf('%s waves=%d %s: max SSH rate %.8g m/s, source-scaled divergence %.3g\n',profile,nWave,sourceKind,row.maximumSSHRate,row.sourceScaledVelocityDivergence);
        end
    end
end
results=struct2table(vertcat(rows{:}));
writetable(results,fullfile(outputFolder,'source-kinematic-probe.csv'));
end
