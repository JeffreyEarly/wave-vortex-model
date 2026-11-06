function reference = balancedDensityDiffusionReference(N2,dLnN2,depth,kh,f,g,kappaZ,dimension,assemblyCount,z)
% Assemble a balanced diffusion reference in physical-depth Legendre polynomials.
% The same energy coordinates are used for assembly, traces, and output fields.
[nodes,weights] = legpts(assemblyCount);
zAssembly = depth*(nodes-1)/2;
weights = depth*weights(:)/2;
[phi,eta,etaZ,~,buoyancyZ,ssh] = fieldsAt(zAssembly);
energyFields = [sqrt(weights)*kh.*phi; sqrt(weights.*N2(zAssembly)).*eta; sqrt(g)*ssh];
[~,R] = qr(energyFields,0);
coordinates = eye(dimension)/R;
mass = (energyFields*coordinates)'*(energyFields*coordinates);
diffusion = (etaZ*coordinates)'*(kappaZ*weights.*(buoyancyZ*coordinates));

[phi,~,etaZ,buoyancy,~,ssh] = fieldsAt(z);
[~,etaTrace] = fieldsAt([0;-depth]);
endpointDisplacement = etaTrace-[ssh;zeros(1,dimension)];
reference = struct(generator=mass\diffusion,boundaryLoad=-(mass\(etaTrace*coordinates)'), ...
    streamfunction=phi*coordinates,buoyancy=buoyancy*coordinates, ...
    qgpv=(-kh^2*phi-f*etaZ)*coordinates,ssh=ssh*coordinates, ...
    endpoints=endpointDisplacement*coordinates,polynomialCoefficients=coordinates);

    function [psi,eta,etaZ,b,bZ,surface] = fieldsAt(depthPoints)
        [psi,psiZ,psiZZ] = polynomials(depthPoints,depth,dimension);
        stratification = N2(depthPoints);
        logGradient = dLnN2(depthPoints);
        stretching = 1+depthPoints/depth;
        surface = (f/g)*ones(1,dimension);
        eta = -f./stratification.*psiZ;
        etaZ = -f./stratification.*(psiZZ-logGradient.*psiZ);
        b = -stratification.*(eta-stretching.*surface);
        bZ = f*psiZZ+stratification.*(1/depth+logGradient.*stretching).*surface;
    end
end

function [P,Pz,Pzz] = polynomials(z,depth,dimension)
x = 1+2*z(:)/depth;
P = zeros(numel(x),dimension);
Pz = P;
Pzz = P;
P(:,1) = 1;
if dimension>1
    P(:,2) = x;
    Pz(:,2) = 1;
end
for k = 2:dimension-1
    P(:,k+1) = ((2*k-1)*x.*P(:,k)-(k-1)*P(:,k-1))/k;
    Pz(:,k+1) = ((2*k-1)*(x.*Pz(:,k)+P(:,k))-(k-1)*Pz(:,k-1))/k;
    Pzz(:,k+1) = ((2*k-1)*(x.*Pzz(:,k)+2*Pz(:,k))-(k-1)*Pzz(:,k-1))/k;
end
Pz = (2/depth)*Pz;
Pzz = (2/depth)^2*Pzz;
end
