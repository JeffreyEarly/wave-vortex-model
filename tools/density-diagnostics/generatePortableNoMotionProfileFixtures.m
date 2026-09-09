function paths = generatePortableNoMotionProfileFixtures(outputDirectory)
% Create compact supplied-profile fixtures from retained actual-density fits.
% This does not load snapshots or qualify a new no-motion solver execution.
arguments (Input)
    outputDirectory (1,1) string = ""
end
arguments (Output)
    paths (1,:) string
end
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
if outputDirectory=="", outputDirectory=fullfile(root,"UnitTests","fixtures"); end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
paths = strings(1,2);
days = ["3000","3250"];
for index = 1:numel(days)
    day = days(index);
    profilePath = ".github/ci-evidence/issue-391-density/final-production-day"+day+".json";
    gridPath = "UnitTests/fixtures/density-run18-day"+day+".json";
    saved = jsondecode(fileread(fullfile(root,profilePath)));
    grid = jsondecode(fileread(fullfile(root,gridPath)));
    assert(saved.status=="passed" && saved.actualReferenceDefault && saved.selectedSolver=="dampedLeastSquares");
    assert(string(saved.input.sha256)==string(grid.source.sha256));
    z = grid.z(:);
    rho = saved.noMotionProfile(:);
    assert(numel(z)==numel(rho));
    profile = WVNoMotionProfile(z,rho);
    midpoint = (z(1:end-1)+z(2:end))/2;
    query = [z;midpoint;linspace(z(1),z(end),97).'];
    material = flipud(query);
    % Exact rest, within-interval tiny moves and full-depth moves accompany
    % the mirrored queries, which cross many irregular vertical intervals.
    center = midpoint(round(numel(midpoint)/2));
    query = [query;z(1);z(end);center;center;center]; %#ok<AGROW>
    material = [material;z(1);z(end);center;center+8*eps(abs(center));center-8*eps(abs(center))]; %#ok<AGROW>
    target = profile.density(material);
    g = 9.81;
    rho0 = 1025;
    request = struct(z=z,rho=rho,queryHeights=query,targetDensity=target,materialHeights=material,g=g,rho0=rho0);
    expected = struct(density=profile.density(query),inverse=profile.inverse(target), ...
        ape=profile.availablePotentialEnergy(query,material,g,rho0));
    fixture = struct(schema="wave-vortex-supplied-no-motion-profile-fixture-v1", ...
        scope="Historical actual-default fitted JAMES profile with deterministic synthetic queries; supplied-profile calculus only, no new fit or full-state diagnostic qualification.", ...
        sourceSnapshot=saved.input,sourceSHA256=[provenance(root,profilePath),provenance(root,gridPath)], ...
        generator=provenance(root,"tools/density-diagnostics/generatePortableNoMotionProfileFixtures.m"), ...
        matlabReference=provenance(root,"Operations/@WVNoMotionProfile/WVNoMotionProfile.m"), ...
        matlabRelease=string(version('-release')),request=request,expected=expected);
    paths(index) = fullfile(outputDirectory,"portable-no-motion-profile-day"+day+".json");
    stream = fopen(paths(index),'w');
    assert(stream>=0,"Cannot write the supplied-profile fixture.");
    cleanup = onCleanup(@()fclose(stream));
    fprintf(stream,"%s\n",jsonencode(fixture,PrettyPrint=true));
    clear cleanup
    fprintf("NO_MOTION_PROFILE_FIXTURE day=%s nodes=%d queries=%d\n",day,numel(z),numel(query));
end
end

function value = provenance(root,path)
quote = string(char(39));
quotedPath = quote+replace(fullfile(root,path),quote,string(char([39,34,39,34,39])))+quote;
[status,digest] = system("shasum -a 256 "+quotedPath);
assert(status==0,"Cannot hash the supplied-profile fixture source.");
value = struct(path=path,sha256=string(extractBefore(digest," ")));
end
