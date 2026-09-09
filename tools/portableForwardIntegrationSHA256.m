function value = portableForwardIntegrationSHA256(path)
% Hash exact source or qualification artifact bytes.
arguments
    path (1,1) string
end
fid = fopen(path,"rb");
if fid < 0
    error("WaveVortexModel:InvalidForwardIntegrationQualification","Missing source or artifact: %s",path);
end
cleanup = onCleanup(@()fclose(fid));
bytes = fread(fid,Inf,"*uint8");
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
value = lower(join(string(dec2hex(typecast(digest.digest(),'uint8'),2)),""));
end
