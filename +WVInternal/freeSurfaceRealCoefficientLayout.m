function layout = freeSurfaceRealCoefficientLayout(wvt)
% Describe independent real coordinates without inactive wave padding.
%
% Packing is an isometry for the real Euclidean coefficient/covector
% pairing, not for physical energy. MDA has only real coordinates. This
% ephemeral layout snapshots shapes and active prefixes, not model values;
% it neither changes the transform nor supplies another prognostic state.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
families = ["Ag_q","Ag_0","Aw_p","Aw_m","Aio","Amda"];
template = wvt.coefficientState();
active = struct();
positions = struct();
count = 0;
for name = families
    template.(name) = zeros(size(template.(name)));
    mask = true(size(template.(name)));
    if ismember(name,["Aw_p","Aw_m"]), mask=wvt.activeWaveModes; end
    active.(name) = mask;
    number = nnz(mask);
    positions.(name).real = count+(1:number);
    count = count+number;
    positions.(name).imaginary = zeros(1,0);
    if name~="Amda"
        positions.(name).imaginary = count+(1:number);
        count = count+number;
    end
end
layout = struct(dimension=count,pack=@pack,unpack=@unpack,validate=@validate);

    function validate(state)
        if ~isstruct(state) || ~isscalar(state) || ~isequal(sort(string(fieldnames(state))),sort(families.'))
            error('WV:RealCoefficientLayout','Supply exactly the six canonical coefficient families.');
        end
        for family = families
            value = state.(family);
            if ~isa(value,'double') || ~isequal(size(value),size(template.(family))) || any(~isfinite(value),'all') || (family=="Amda" && ~isreal(value))
                error('WV:RealCoefficientLayout','%s has an invalid coefficient shape or value.',family);
            end
            if any(value(~active.(family))~=0)
                error('WV:RealCoefficientLayout','Inactive wave coefficients must remain zero.');
            end
        end
    end

    function vector = pack(state)
        validate(state);
        vector = zeros(count,1);
        for family = families
            value = state.(family)(active.(family));
            vector(positions.(family).real) = real(value);
            if family~="Amda", vector(positions.(family).imaginary)=imag(value); end
        end
    end

    function state = unpack(vector)
        if ~isa(vector,'double') || ~isreal(vector) || ~isequal(size(vector),[count,1]) || any(~isfinite(vector))
            error('WV:RealCoefficientLayout','Supply a finite real column with %d entries.',count);
        end
        state = template;
        for family = families
            value = vector(positions.(family).real);
            if family~="Amda", value=complex(value,vector(positions.(family).imaginary)); end
            state.(family)(active.(family)) = value;
        end
    end
end
