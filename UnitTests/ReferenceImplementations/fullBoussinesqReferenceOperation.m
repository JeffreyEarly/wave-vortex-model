function operation = fullBoussinesqReferenceOperation(w)
% Frozen grouped-operation scheduling, with the pre-change reconstruction.
names=string(w.namesOfTransformVariables());
args=cellstr(names);
annotations=w.operationForKnownVariable(args{:}).outputVariables;
operation=WVOperation('boussinesqFields',annotations,@compute);
    function varargout=compute(wvt)
        fields=fullBoussinesqFieldReference(wvt,names);
        varargout=cell(1,numel(names));
        for index=1:numel(names), varargout{index}=fields.(names(index)); end
    end
end
