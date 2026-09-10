function boundary = freeSurfaceBoundaryOperator(wvt)
% Apply retained SSH and active endpoint traces and their real adjoint.
%
% Nonzero compact Fourier coefficients use sqrt(2) real/imaginary weights;
% only endpoint anomalies include horizontal means. The Euclidean trace
% norm is their horizontally averaged physical L2 norm. Endpoint anomalies
% are surface eta-SSH and bottom eta. A target's discarded RMS includes
% Fourier content outside this inventory and its unsupported mean SSH.
%
% The factory snapshots stored modes/counts and reads current phase clocks
% when applied. No global reconstruction matrix or new modes are formed.
% It does not assert that every retained trace can be independently driven;
% the coupled solver must check the small constraint Schur blocks for rank.
arguments (Input)
    wvt (1,1) WVTransformFreeSurfaceBoussinesq
end
coefficientLayout = WVInternal.freeSurfaceRealCoefficientLayout(wvt);
template = coefficientLayout.unpack(zeros(coefficientLayout.dimension,1));
selected = [1,1+wvt.activeEndpoint];
allNames = ["ssh","surface","bottom"];
names = allNames(selected);
nTrace = length(selected);
nColumn = length(wvt.klNonzero);
nq = size(template.Ag_q,1);
n0 = size(template.Ag_0,1);
blocks = cell(length(wvt.khUnique),1);
for page = 1:length(blocks)
    mu = wvt.apvMu(:,page).';
    qSSH = -(wvt.f/wvt.g)*wvt.apvF(end,:)./mu;
    qEta = -(wvt.f/wvt.g)*wvt.apvG([end,1],:)./mu;
    zeroSSH = -(wvt.f/wvt.g)*wvt.zeroAPVF(end,:,page)/wvt.khUnique(page)^2;
    zeroEta = -(wvt.f/wvt.g)*wvt.zeroAPVG([end,1],:,page)/wvt.khUnique(page)^2;
    block = [qSSH,zeroSSH;qEta(1,:)-qSSH,zeroEta(1,:)-zeroSSH;qEta(2,:),zeroEta(2,:)];
    count = wvt.waveModeCountByKh(page);
    if count>0
        modes = 1:count;
        wave = WVInternal.freeSurfaceWavePolarization(wvt.waveF(:,modes,page),wvt.waveG(:,modes,page),wvt.waveEquivalentDepth(modes,page),wvt.khUnique(page),0,f=wvt.f,g=wvt.g,rho0=wvt.rho0);
        waveSSH = reshape(wave.ssh,1,[]);
        waveEta = reshape(wave.eta([end,1],:,:),2,[]);
        block = [block,[waveSSH;waveEta(1,:)-waveSSH;waveEta(2,:)]];
    end
    blocks{page} = block(selected,:);
end
meanSSH = wvt.mdaPressureMode(end,:)/wvt.g;
if any(meanSSH~=0)
    error('WV:BoundaryMeanGauge','The stored MDA pressure must use the zero-mean SSH gauge.');
end
meanBlock = wvt.mdaG([wvt.Nz,1],:);
meanBlock = meanBlock(wvt.activeEndpoint,:);
dimension = 2*nTrace*nColumn+length(wvt.activeEndpoint);
fourier = WVFourierStorageLayout(wvt,"full-complex");
meanIndex = find(wvt.k==0 & wvt.l==0,1);
boundary = struct(dimension=dimension,names=names,apply=@apply,adjoint=@adjoint,projectTarget=@projectTarget,blocks={blocks},meanBlock=meanBlock);

    function vector = apply(state)
        coefficientLayout.validate(state);
        spectral = complex(zeros(nTrace,nColumn));
        for pageIndex = 1:length(blocks)
            columns = find(wvt.klNonzeroKhUniqueIndex==pageIndex);
            count = wvt.waveModeCountByKh(pageIndex);
            phase = exp(1i*wvt.waveFrequency(1:count,pageIndex)*(wvt.t-wvt.t0));
            values = [state.Ag_q(:,columns);state.Ag_0(:,columns);phase.*state.Aw_p(1:count,columns);conj(phase).*state.Aw_m(1:count,columns)];
            spectral(:,columns) = blocks{pageIndex}*values;
        end
        vector = packTrace(spectral,meanBlock*state.Amda);
    end

    function state = adjoint(vector)
        [spectral,means] = unpackTrace(vector);
        state = template;
        for pageIndex = 1:length(blocks)
            columns = find(wvt.klNonzeroKhUniqueIndex==pageIndex);
            count = wvt.waveModeCountByKh(pageIndex);
            % unpackTrace divides by sqrt(2); the real coefficient adjoint
            % needs sqrt(2), hence the additional factor two here.
            values = 2*blocks{pageIndex}'*spectral(:,columns);
            phase = exp(1i*wvt.waveFrequency(1:count,pageIndex)*(wvt.t-wvt.t0));
            state.Ag_q(:,columns) = values(1:nq,:);
            state.Ag_0(:,columns) = values(nq+(1:n0),:);
            state.Aw_p(1:count,columns) = conj(phase).*values(nq+n0+(1:count),:);
            state.Aw_m(1:count,columns) = phase.*values(nq+n0+count+(1:count),:);
        end
        state.Amda = real(meanBlock'*means);
    end

    function [vector,discardedRMS] = projectTarget(fields)
        samples = zeros(wvt.Nx,wvt.Ny,nTrace);
        for trace = 1:nTrace
            name = names(trace);
            if ~isfield(fields,name) || ~isa(fields.(name),'double') || ~isreal(fields.(name)) || ~isequal(size(fields.(name)),[wvt.Nx,wvt.Ny]) || any(~isfinite(fields.(name)),'all')
                error('WV:BoundaryTarget','%s must be a finite real horizontal field.',name);
            end
            samples(:,:,trace) = fields.(name);
        end
        storage = fft(fft(samples,[],1),[],2)/(wvt.Nx*wvt.Ny);
        spectral = fourier.transformFromFourierStorageToWVGrid(reshape(storage,[],nTrace));
        vector = packTrace(spectral(:,wvt.klNonzero),real(spectral(2:end,meanIndex)));
        if nargout>1
            retained = complex(zeros(nTrace,wvt.Nkl));
            retained(:,wvt.klNonzero) = spectral(:,wvt.klNonzero);
            retained(2:end,meanIndex) = real(spectral(2:end,meanIndex));
            storage = fourier.transformFromWVGridToFourierStorage(fourier.allocateFourierStorage(nTrace),retained);
            storage = fourier.reshapeFourierRowsToStorage(storage);
            projected = real(ifft(ifft(storage,[],1),[],2))*(wvt.Nx*wvt.Ny);
            discardedRMS = sqrt(mean((samples-projected).^2,'all'));
        end
    end

    function vector = packTrace(spectral,means)
        vector = [sqrt(2)*real(spectral(:));sqrt(2)*imag(spectral(:));means];
    end

    function [spectral,means] = unpackTrace(vector)
        if ~isa(vector,'double') || ~isreal(vector) || ~isequal(size(vector),[dimension,1]) || any(~isfinite(vector))
            error('WV:BoundaryCoordinates','Supply a finite real column with %d entries.',dimension);
        end
        number = nTrace*nColumn;
        spectral = reshape(complex(vector(1:number),vector(number+(1:number)))/sqrt(2),nTrace,nColumn);
        means = vector(2*number+1:end);
    end
end
