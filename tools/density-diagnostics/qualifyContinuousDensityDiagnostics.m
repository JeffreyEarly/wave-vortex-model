function report = qualifyContinuousDensityDiagnostics(outputPath)
% Qualify the default pipeline against an analytic volume-preserving twist.
% Configure package dependencies before calling this authoring tool. The
% independent geometry reference lives in UnitTests/DensityDiagnosticReference.
arguments (Input)
    outputPath (1,1) string = ""
end
arguments (Output)
    report (1,1) struct
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath = path;
pathCleanup = onCleanup(@()path(originalPath));
addpath(fullfile(root,'UnitTests'));
report = struct(schema="wave-vortex-default-continuous-twist-qualification-v1");
report.cases = cell(0,1);
report.interpretation = "Continuous area-preserving polar twist with analytic inverse and APE/APV truth, then public spectral state initialization. Finite grids approximate the continuous density distribution; spectral initialization error is reported separately. No rho_nm or eta_true cache injection.";
for n = [16,32,64]
    wvt = WVTransformConstantStratification([2 2 2],[n n n+1],N0=.2,shouldAntialias=false);
    X = wvt.X;
    Y = wvt.Y;
    Z = wvt.Z;
    u = .03*sin(pi*Y).*cos(pi*Z/2);
    v = .02*sin(pi*X).*cos(pi*Z/2);
    radius = .7;
    angle = 3;
    dx = X-1;
    dz = Z+1;
    q = max(0,1-(dx.^2+dz.^2)/radius^2);
    theta = angle*q.^3;
    thetaX = -6*angle*dx.*q.^2/radius^2;
    thetaZ = -6*angle*dz.*q.^2/radius^2;
    horizontalArm = cos(theta).*dx+sin(theta).*dz;
    gradientX = -sin(theta)-horizontalArm.*thetaX;
    gradientZ = cos(theta)-horizontalArm.*thetaZ;
    [~,materialHeight] = DensityDiagnosticReference.inversePolarTwist(X,Z,[1 -1],radius,angle);
    etaTruth = Z-materialHeight;
    densityTruth = wvt.rho0*(1-.04*materialHeight/wvt.g);
    wvt.initWithUVEta(u,v,etaTruth);
    density = wvt.rho_total;
    original = wvt.rho_nm0(:);
    target = WVNoMotionProfileOperation.moments_from_rho_tot(density,original(end),original(1),wvt.z_int,wvt.Lz);
    initial = WVNoMotionProfileOperation.rho_to_u(original,original(end),original(1));
    initialResidual = WVNoMotionProfileOperation.residual(initial,flip(wvt.z_int/wvt.Lz),target);
    row = struct(grid=[n,n,n+1],status="not-run",actualReferenceDefault=wvt.shouldUseTrueNoMotionProfile, ...
        densityMagnitude=max(abs(density),[],"all"), ...
        spectralDensityMaximumError=max(abs(density-densityTruth),[],"all"), ...
        spectralDensityRMSError=sqrt(mean((density-densityTruth).^2,"all")), ...
        initialProfileMaximumMomentResidual=max(abs(initialResidual)),firstFourInitialMomentResiduals=initialResidual(1:4));
    operation = wvt.operationWithName('rho_nm');
    started = tic;
    try
        rho = wvt.rho_nm;
        eta = wvt.eta_true;
        ape = wvt.ape;
        apv = wvt.apv;
        zetaX = .02*(pi/2)*sin(pi*X).*sin(pi*Z/2);
        zetaZ = pi*(.02*cos(pi*X)-.03*cos(pi*Y)).*cos(pi*Z/2);
        apvTruth = zetaX.*gradientX+(zetaZ+wvt.f).*gradientZ-wvt.f;
        apeTruth = .04*etaTruth.^2/2;
        row.status = "returned";
        row.rhoProfileMaximumError = max(abs(rho(:)-original));
        row.etaRMSError = sqrt(mean((eta-etaTruth).^2,"all"));
        row.apeRMSError = sqrt(mean((ape-apeTruth).^2,"all"));
        row.apvRMSError = sqrt(mean((apv-apvTruth).^2,"all"));
        row.apvRelativeRMSError = row.apvRMSError/sqrt(mean(apvTruth.^2,"all"));
        row.minimumAPE = min(ape,[],"all");
        row.apvAllFinite = all(isfinite(apv),"all");
        row.meanDisplacement = sum(squeeze(mean(eta,[1,2])).*wvt.z_int(:))/wvt.Lz;
        profile = WVNoMotionProfile(wvt.z,rho);
        row.densityClosureMaximum = max(abs(profile.density(Z-eta)-density),[],"all");
    catch exception
        row.status = "rejected";
        row.errorIdentifier = string(exception.identifier);
        row.errorMessage = string(exception.message);
    end
    row.seconds = toc(started);
    row.solver = operation.lastSolverOutput;
    report.cases{end+1} = row;
    fprintf('CONTINUOUS_DEFAULT n=%g status=%s residual=%.6g spectralRhoError=%.6g\n', ...
        n,row.status,row.solver.maximumResidual,row.spectralDensityMaximumError);
end
report.matlabRelease = string(version('-release'));
sourcePaths = ["Operations/WVNoMotionProfileOperation.m","Operations/EtaTrueOperation.m", ...
    "Operations/APEOperation.m","Operations/APVOperation.m", ...
    "Operations/@WVNoMotionProfile/WVNoMotionProfile.m", ...
    "@WVTransformConstantStratification/WVTransformConstantStratification.m", ...
    "UnitTests/DensityDiagnosticReference.m","UnitTests/TestDensityDiagnosticReference.m", ...
    "tools/density-diagnostics/qualifyContinuousDensityDiagnostics.m"];
report.sources = cell(size(sourcePaths));
for index = 1:numel(sourcePaths)
    sourcePath = fullfile(root,sourcePaths(index));
    quote = string(char(39));
    quotedPath = quote+replace(sourcePath,quote,string(char([39,34,39,34,39])))+quote;
    [status,digest] = system("shasum -a 256 "+quotedPath);
    assert(status==0,'Cannot hash the continuous qualification source.');
    report.sources{index} = struct(path=sourcePaths(index),sha256=string(extractBefore(digest,' ')));
end
report.platform = string(computer);
if outputPath ~= ""
    folder = fileparts(outputPath);
    if folder ~= "" && ~isfolder(folder)
        mkdir(folder);
    end
    fid = fopen(outputPath,'w');
    assert(fid>=0,'Cannot create the continuous density report.');
    outputCleanup = onCleanup(@()fclose(fid));
    fprintf(fid,'%s\n',jsonencode(report,PrettyPrint=true));
end
end
