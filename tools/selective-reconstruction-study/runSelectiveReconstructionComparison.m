function table = runSelectiveReconstructionComparison(outputFolder)
% Compare cold direct reconstruction with the frozen 1353067a implementation.
arguments
    outputFolder (1,1) string
end
if ~isfolder(outputFolder), mkdir(outputFolder); end
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
originalPath=path; cleanup=onCleanup(@()path(originalPath));
addpath(fullfile(root,'UnitTests','ReferenceImplementations'));
requests={"ssh",["ssu","ssv"],"eta",["u","v"],["u","v","w","eta","p","ssh"]};
rows=cell(15,10); index=0;
for Z=[33 65 129]
    w=WVTransformFreeSurfaceBoussinesq.fromStratification([1e5 1e5 1000],[8 8 Z],N2Function=@(z)1e-4*exp(z/650),apvModeCount=3,mdaModeCount=2,inertialModeCount=3,waveModeCount=4,shouldAntialias=true);
    coefficients=w.coefficientState();
    for name=string(fieldnames(coefficients)).'
        ordinal=reshape(1:numel(coefficients.(name)),size(coefficients.(name)));
        if name=="Ag_q" || name=="Ag_0", scale=1e-8; else, scale=.002; end
        if name=="Amda", value=scale*cos(ordinal); else, value=scale*exp(1i*ordinal)./(1+ordinal); end
        coefficients.(name)=value; w.(name)=value;
    end
    scientific=w.scientificState();
    save(fullfile(outputFolder,sprintf('state-%d.mat',Z)),'scientific','coefficients');
    w.t=327; w.t0=-17;
    old=WVTransformFreeSurfaceBoussinesq(scientific);
    for name=string(fieldnames(coefficients)).', old.(name)=coefficients.(name); end
    old.t=w.t; old.t0=w.t0;
    old.addOperation(fullBoussinesqReferenceOperation(old),shouldOverwriteExisting=true,shouldSuppressWarning=true);
    for request=1:numel(requests)
        names=requests{request};
        expected=fullBoussinesqFieldReference(w,names);
        actual=cold(w,names); difference=0;
        for name=names
            delta=actual.(name)-expected.(name);
            difference=max(difference,norm(delta(:))/max(norm(expected.(name)(:)),realmin));
        end
        assert(difference<1e-10,'Selective reconstruction differs from the frozen reference.');
        reference=@()fullBoussinesqFieldReference(w,names);
        selected=@()cold(w,names);
        reference(); selected();
        measurements=zeros(3,2);
        for repeat=1:3
            if mod(repeat,2)
                measurements(repeat,:)=[timeit(reference),timeit(selected)];
            else
                b=timeit(selected); a=timeit(reference); measurements(repeat,:)=[a,b];
            end
        end
        args=cellstr(names);
        registeredCold=timeit(@()registered(old,args));
        cold(w,names);
        warmSeconds=timeit(@()w.variableWithName(args{:}));
        successiveSeconds=timeit(@()successive(w,names));
        info=whos('actual');
        cacheBytes=0;
        for key=w.variableCache.keys.'
            value=w.variableCache{key}; entry=whos('value'); cacheBytes=cacheBytes+entry.bytes;
        end
        index=index+1;
        rows(index,:)={Z,join(names,','),median(measurements(:,1)),median(measurements(:,2)),warmSeconds,successiveSeconds,difference,info.bytes,registeredCold,cacheBytes};
        fprintf('Z=%d %s: reference %.4g cold %.4g warm %.4g s\n',Z,join(names,','),rows{index,3:5});
    end
end
table=cell2table(rows,VariableNames={'Z','request','referenceSeconds','coldSeconds','warmSeconds','successiveStateSeconds','relativeDifference','outputBytes','oldRegisteredColdSeconds','cachedArrayBytes'});
writetable(table,fullfile(outputFolder,'comparison.csv'));
end
function fields=cold(w,names)
w.clearVariableCacheOfApAmA0DependentVariables();
fields=w.reconstructFields(names);
end
function fields=successive(w,names)
w.t=w.t+1;
fields=w.reconstructFields(names);
end

function value=registered(w,args)
w.clearVariableCacheOfApAmA0DependentVariables();
value=w.variableWithName(args{:});
end
