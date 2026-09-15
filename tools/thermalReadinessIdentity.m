function hash = thermalReadinessIdentity(value)
% Fingerprint an authoring manifest and its exact named canonical arrays.
% Numeric parts use their exact column-major little-endian representation,
% with class and shape headers; real and imaginary parts are separate. Field order
% does not affect a struct identity. Function handles and objects are rejected.
arguments (Input)
    value
end
arguments (Output)
    hash (1,1) string
end
digest = java.security.MessageDigest.getInstance('SHA-256');
appendValue(digest,value);
hash = string(lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
end
function appendValue(digest,value)
header = string(class(value))+":"+join(string(size(value)),",")+";";
digest.update(unicode2native(char(header),'UTF-8'));
if isstruct(value)
    names = sort(string(fieldnames(value)));
    for j = 1:numel(value)
        for name = names.'
            digest.update(unicode2native(jsonencode(name),'UTF-8'));
            appendValue(digest,value(j).(name));
        end
    end
elseif iscell(value)
    for j = 1:numel(value), appendValue(digest,value{j}); end
elseif isnumeric(value) || islogical(value)
    [~,~,endian] = computer;
    if islogical(value), value=uint8(value); end
    for part = {real(value),imag(value)}
        numbers = part{1};
        if endian == 'B', numbers = swapbytes(numbers); end
        digest.update(typecast(numbers(:),'uint8'));
    end
elseif isstring(value) || ischar(value)
    digest.update(unicode2native(jsonencode(value),'UTF-8'));
else
    error('WV:ReadinessIdentityType','Readiness identities require data-only arrays and manifests, not %s.',class(value));
end
end
