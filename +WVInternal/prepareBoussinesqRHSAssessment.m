function prepared = prepareBoussinesqRHSAssessment(w)
% Freeze one modal state and its continuous volume/endpoint source functionals.
% This offline snapshot neither changes the runtime activation gate nor caches
% data on the caller. Its sampled modal representation must be resolved first.
arguments
    w (1,1) WVTransformFreeSurfaceBoussinesq
end
snapshot=WVTransformFreeSurfaceBoussinesq(w.scientificState());
state=w.coefficientState();
for name=string(fieldnames(state)).', snapshot.(name)=state.(name); end
snapshot.t=w.t; snapshot.t0=w.t0;
prepared=struct(kind="boussinesqRHSSnapshot-v1",transform=snapshot,spectral=snapshot.reconstructSpectralState(),thermodynamics=WVInternal.freeSurfaceThermodynamics(snapshot));
prepared.pairings.apvF=split(w.apvFSourcePairing,w.apvF,ones(w.Nz,1));
prepared.pairings.apvG=split(w.apvGSourcePairing,w.apvG,w.N2);
prepared.pairings.inertial=split(w.inertialFForward,w.inertialF,ones(w.Nz,1));
prepared.pairings.mda=split(w.mdaGForward,w.mdaG,w.N2);
for p=1:numel(w.khUnique)
    prepared.pairings.zeroF{p}=split(w.zeroAPVFPairing(:,:,p),w.zeroAPVF(:,:,p),ones(w.Nz,1));
    prepared.pairings.zeroG{p}=split(w.zeroAPVGPairing(:,:,p),w.zeroAPVG(:,:,p),w.N2);
end
    function part=split(pair,basis,weight)
        % Recover the fixed modal normalization from interior samples only.
        % Endpoint delta functionals must never be interpolated as densities.
        interior=2:w.Nz-1;
        if isempty(pair)
            part=struct(mix=zeros(0,size(basis,2)),basis=basis,endpoint=zeros(0,2),stratified=~all(weight==1)); return
        end
        density=basis.'.*weight.';
        mix=(pair(:,interior)./w.verticalQuadratureWeights(interior).')/density(:,interior);
        volume=(mix*density).*w.verticalQuadratureWeights.';
        residual=pair-volume;
        if norm(residual(:,interior),'fro')>1e-10*max(norm(pair(:,interior),'fro'),realmin)
            error('WV:UnsupportedSourcePairing','The stored pairing is not a volume density plus endpoint functionals.')
        end
        part=struct(mix=mix,basis=basis,endpoint=residual(:,[1 end]),stratified=~all(weight==1));
    end
end
