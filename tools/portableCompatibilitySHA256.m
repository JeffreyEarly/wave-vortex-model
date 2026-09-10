function value = portableCompatibilitySHA256(path)
% Hash an authoritative compatibility source without changing it.
arguments
    path (1,1) string
end
file=fopen(path,"rb");
if file<0, error("WaveVortexModel:InvalidCompatibilityMatrix","Missing source: %s",path); end
cleanup=onCleanup(@()fclose(file));
bytes=fread(file,Inf,"*uint8");
digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
value=string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[])));
end
