classdef (Sealed) WVSpatialDerivativeDispatch
    % Encode benchmarked spatial-derivative implementation choices.
    %
    % Records are intentionally exact. Horizontal and all-derivative paths
    % are selected only for grid shapes measured by `derivative-dispatch-v1`;
    % no performance result is extrapolated to an untested shape, derivative
    % order, backend, or hydrostatic configuration.
    %
    % ```matlab
    % id = WVSpatialDerivativeDispatch.implementation( ...
    %     "fftw","diffX",[256 256 65],1,false);
    % ```
    %
    % - Topic: Developer internals
    % - Declaration: classdef (Sealed) WVSpatialDerivativeDispatch

    methods (Static)
        function id = implementation(backend,operation,Nxyz,derivativeOrder,isHydrostatic)
            % Return the measured implementation for one exact configuration.
            %
            % - Topic: Developer internals
            % - Parameter backend: active backend, `"builtin"` or `"fftw"`
            % - Parameter operation: `"diffX"`, `"diffY"`, `"diffZF"`, `"diffZG"`, `"F-all"`, or `"G-all"`
            % - Parameter Nxyz: exact spatial grid shape `[Nx Ny Nz]`
            % - Parameter derivativeOrder: derivative order from 1 through 4
            % - Parameter isHydrostatic: whether the constant-stratification model is hydrostatic
            % - Returns id: selected implementation identifier
            % - Developer: true
            arguments
                backend (1,1) string {mustBeMember(backend,["builtin","fftw"])}
                operation (1,1) string {mustBeMember(operation,["diffX","diffY","diffZF","diffZG","F-all","G-all"])}
                Nxyz (1,3) double {mustBeInteger,mustBePositive}
                derivativeOrder (1,1) double {mustBeMember(derivativeOrder,1:4)} = 1
                isHydrostatic (1,1) logical = false
            end
            id = WVSpatialDerivativeDispatch.baseline(operation);
            records = WVSpatialDerivativeDispatch.records();
            for record = records
                if record.backend == backend && record.operation == operation && isequal(record.Nxyz,Nxyz) && ismember(derivativeOrder,record.derivativeOrders) && (record.isHydrostatic < 0 || logical(record.isHydrostatic) == isHydrostatic)
                    id = record.implementation;
                    return
                end
            end
        end

        function value = allRecords()
            % Return the immutable derivative-dispatch records.
            %
            % - Topic: Developer internals
            % - Returns value: JSON-safe exact dispatch records
            % - Developer: true
            value = WVSpatialDerivativeDispatch.records();
        end
    end

    methods (Static, Access=private)
        function id = baseline(operation)
            if operation == "diffX" || operation == "diffY"
                id = "matlab-1d";
            elseif operation == "diffZF" || operation == "diffZG"
                id = "dense-matrix";
            else
                id = "composed-current";
            end
        end

        function value = records()
            value = [ ...
                WVSpatialDerivativeDispatch.record("fftw","diffX",[128 128 129],[2 3],-1,"fftw-1d"), ...
                WVSpatialDerivativeDispatch.record("fftw","diffX",[128 128 257],1:4,-1,"fftw-1d"), ...
                WVSpatialDerivativeDispatch.record("fftw","diffY",[128 128 257],1:3,-1,"fftw-1d"), ...
                WVSpatialDerivativeDispatch.record("fftw","F-all",[128 128 33],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("builtin","G-all",[128 128 257],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[64 64 65],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[128 128 33],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[128 128 65],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[128 128 129],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[128 128 257],1,0,"modal-direct"), ...
                WVSpatialDerivativeDispatch.record("fftw","G-all",[256 256 65],1,-1,"modal-direct")];
        end

        function value = record(backend,operation,Nxyz,orders,isHydrostatic,implementation)
            value = struct("backend",backend,"operation",operation,"Nxyz",Nxyz,"derivativeOrders",orders,"isHydrostatic",isHydrostatic,"implementation",implementation,"sourceSuite","derivative-dispatch-v1","speedThreshold",1.10,"relativeErrorTolerance",1e-12);
        end
    end
end
