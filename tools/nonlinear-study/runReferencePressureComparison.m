function [results,quadrature] = runReferencePressureComparison()
% Compare exact pressure references with independently integrated energy.
% This manufactured-state study does not test a discretized evolution law.
% Parcel labels remain in [-D,0]; only the physical-height reference is
% explicitly continued. Run with this folder on the MATLAB path.
D = 1000;
g = 9.81;
N2 = 1e-4;
scale = 700;
x = (0:15)*2*pi/16;
zeta = 5*cos(x)+1.5*sin(2*x);
zetaRate = .02*sin(x);
profiles = ["constant","exponential","exponentialC1"];
rows = cell(1,numel(profiles));
for iProfile = 1:numel(profiles)
    profile = profiles(iProfile);
    if profile == "constant"
        q = @(z)-N2*z;
        H = @(z)N2*z.^2/2;
        parcelN2 = @(r)N2+zeros(size(r));
    else
        % Explicit analytic reference continuation, used only on [-D,10].
        q = @(z)-N2*scale*expm1(z/scale);
        H = @(z)N2*scale^2*(expm1(z/scale)-z/scale);
        parcelN2 = @(r)N2*exp(r/scale);
        if profile == "exponentialC1"
            % Keep the column unchanged; continue its surface N2 as a
            % constant above zero. Density is C1, pressure is C2.
            q = @(z)-N2*scale*expm1(min(z,0)/scale)-N2*max(z,0);
            H = @(z)N2*scale^2*(expm1(min(z,0)/scale)-min(z,0)/scale)+N2*max(z,0).^2/2;
        end
    end
    qPlus = @(z)q(min(z,0));
    HPlus = @(z)H(min(z,0));
    parcelDensity = @(r)checkedParcelAnomaly(r,q,D);
    accelerationError = 0;
    pressureBoundaryError = 0;
    volumeSurfaceError = 0;
    volumeCoordinateError = 0;
    primitiveEnergyError = 0;
    energyRateError = 0;
    missingSurfaceEnergy = 0;
    missingPressure = 0;
    labelMinimum = inf;
    labelMaximum = -inf;
    constantBuoyancyError = 0;
    constantAPEError = 0;
    constantSurfaceEnergyError = 0;
    apeGradientError = 0;
    for ix = 1:numel(x)
        crest = zeta(ix);
        gamma = 1+crest/D;
        label = @(xi)-D/2+(D/2-30)*(2*xi/D+1)+5*sin(x(ix))*sin(pi*(xi+D)/D);
        height = @(xi)xi+(1+xi/D)*crest;
        xi = linspace(-D,0,101);
        r = label(xi);
        z = height(xi);
        labelMinimum = min(labelMinimum,min(r));
        labelMaximum = max(labelMaximum,max(r));
        qr = parcelDensity(r);
        % A total pressure satisfying p_tot(zeta)=0, in physical coordinates.
        P = @(s)(g+.01*cos(x(ix)))*(crest-s);
        pressure = @(s)P(s)+g*s-H(s);
        pressurePlus = @(s)P(s)+g*s-HPlus(s);
        h = 1e-3;
        % Keep the independent pressure difference stencil off the kink.
        selected = abs(z)>2*h;
        zCheck = z(selected);
        exactAcceleration = .01*cos(x(ix))-qr(selected);
        smoothAcceleration = -(pressure(zCheck+h)-pressure(zCheck-h))/(2*h)+q(zCheck)-qr(selected);
        upperAcceleration = -(pressurePlus(zCheck+h)-pressurePlus(zCheck-h))/(2*h)+qPlus(zCheck)-qr(selected);
        accelerationError = max([accelerationError,max(abs(smoothAcceleration-exactAcceleration)),max(abs(upperAcceleration-exactAcceleration))]);
        pressureBoundaryError = max([pressureBoundaryError,abs(pressure(crest)-(g*crest-H(crest))),abs(pressurePlus(crest)-(g*crest-HPlus(crest)))]);
        A = @(xi)(height(xi)-label(xi)).*parcelDensity(label(xi))-H(label(xi))+H(height(xi));
        APlus = @(xi)(height(xi)-label(xi)).*parcelDensity(label(xi))-H(label(xi))+HPlus(height(xi));
        ape = @(z,eta)eta.*parcelDensity(z-eta)-H(z-eta)+H(z);
        eta = z-r;
        derivativeEta = (ape(z,eta+h)-ape(z,eta-h))/(2*h);
        derivativeZ = (ape(z+h,eta)-ape(z-h,eta))/(2*h);
        apeGradientError = max([apeGradientError,max(abs(derivativeEta-eta.*parcelN2(r))),max(abs(derivativeZ+eta.*parcelN2(r)+q(z)-qr))]);
        % Split the upper-constant integrand at physical z=0, if present.
        cuts = unique(sort([-D,0,min(0,-crest/gamma)]));
        volumeSmooth = piecewiseIntegral(@(xi)gamma*A(xi),cuts);
        volumeUpper = piecewiseIntegral(@(xi)gamma*APlus(xi),cuts);
        surfaceSmooth = g*crest^2/2-integral(H,0,crest,AbsTol=1e-12,RelTol=1e-12);
        surfaceUpper = g*crest^2/2-integral(HPlus,0,crest,AbsTol=1e-12,RelTol=1e-12);
        volumeSurfaceError = max(volumeSurfaceError,abs((volumeSmooth+surfaceSmooth)-(volumeUpper+surfaceUpper)));
        % A second volume calculation uses physical height directly.
        inverse = @(s)(s-crest)/gamma;
        physicalVolume = piecewiseIntegral(@(s)A(inverse(s)),unique(sort([-D,min(0,crest),crest])));
        volumeCoordinateError = max(volumeCoordinateError,abs(physicalVolume-volumeSmooth));
        % Pointwise A is also evaluated by density quadrature, without H.
        for j = [1,51,101]
            independentA = splitDensityIntegral(qr(j),q,r(j),z(j));
            independentUpper = splitDensityIntegral(qr(j),qPlus,r(j),z(j));
            primitiveEnergyError = max([primitiveEnergyError,abs(independentA-A(xi(j))),abs(independentUpper-APlus(xi(j)))]);
        end
        % Reynolds transport of the reference-only volume change; no PDE
        % trajectory is assumed. This tests the matched surface derivative.
        volumeReferenceRate = (H(crest)-HPlus(crest))*zetaRate(ix);
        delta = 1e-3;
        surfaceDifference = @(s)-integral(@(v)H(v)-HPlus(v),0,s,AbsTol=1e-12,RelTol=1e-12);
        surfaceReferenceRate = (surfaceDifference(crest+delta)-surfaceDifference(crest-delta))/(2*delta)*zetaRate(ix);
        energyRateError = max(energyRateError,abs(volumeReferenceRate+surfaceReferenceRate));
        missingSurfaceEnergy = max(missingSurfaceEnergy,abs(surfaceSmooth-g*crest^2/2));
        missingPressure = max(missingPressure,abs(H(crest)));
        if profile == "constant"
            constantBuoyancyError = max(constantBuoyancyError,max(abs(q(z)-qr+N2*(z-r))));
            constantAPEError = max(constantAPEError,max(abs(A(xi)-N2*(z-r).^2/2)));
            constantSurfaceEnergyError = max([constantSurfaceEnergyError,abs(surfaceSmooth-(g*crest^2/2-N2*crest^3/6)),abs(surfaceUpper-(g*crest^2/2-N2*min(crest,0)^3/6))]);
        end
    end
    assert(labelMinimum>=-D && labelMaximum<=0);
    assert(accelerationError<5e-8);
    assert(pressureBoundaryError<1e-12);
    assert(volumeSurfaceError<1e-8);
    assert(volumeCoordinateError<1e-8);
    assert(primitiveEnergyError<1e-10);
    assert(energyRateError<1e-10);
    assert(apeGradientError<5e-10);
    assert(constantBuoyancyError<1e-14 && constantAPEError<1e-10 && constantSurfaceEnergyError<1e-12);
    rows{iProfile} = table(profile,labelMinimum,labelMaximum,accelerationError,pressureBoundaryError,volumeSurfaceError,volumeCoordinateError,primitiveEnergyError,energyRateError,missingPressure,missingSurfaceEnergy,constantBuoyancyError,constantAPEError,constantSurfaceEnergyError,apeGradientError);
end
results = vertcat(rows{:});
disp(results)
% Constant N, valid r=xi: smooth A is quadratic; upper-constant A has a
% piecewise quadratic correction confined to the physical crest layer.
counts = [16;32;64;128];
smoothError = zeros(size(counts));
upperError = zeros(size(counts));
crest = 5;
gamma = 1+crest/D;
exactSmooth = gamma*N2*crest^2*D/6;
exactUpper = exactSmooth-N2*crest^3/6;
for j = 1:numel(counts)
    n = counts(j);
    offDiagonal = (1:n-1)./sqrt(4*(1:n-1).^2-1);
    [vectors,nodes] = eig(diag(offDiagonal,1)+diag(offDiagonal,-1),'vector');
    weights = D*vectors(1,:).^2;
    xi = D*(nodes.'-1)/2;
    z = xi+(1+xi/D)*crest;
    smooth = N2*((1+xi/D)*crest).^2/2;
    upper = smooth-N2*max(z,0).^2/2;
    smoothError(j) = abs(gamma*sum(weights.*smooth)-exactSmooth);
    upperError(j) = abs(gamma*sum(weights.*upper)-exactUpper);
end
assert(all(smoothError<1e-11));
assert(upperError(1)>1e-3);
quadrature = table(counts,smoothError,upperError);
disp(quadrature)
end

function values = checkedParcelAnomaly(r,q,D)
assert(all(r>=-D & r<=0,'all'),'ReferencePressureStudy:InvalidParcelLabel','Parcel density is defined only on [-D,0].');
values = q(r);
end

function result = piecewiseIntegral(f,cuts)
result = 0;
for j = 1:numel(cuts)-1
    result = result+integral(f,cuts(j),cuts(j+1),AbsTol=1e-11,RelTol=1e-12);
end
end

function result = splitDensityIntegral(qr,qReference,r,z)
orientation = sign(z-r);
cuts = unique(sort([r,z,max(min(0,max(r,z)),min(r,z))]));
result = orientation*piecewiseIntegral(@(s)qr-qReference(s),cuts);
end
