function [state,assessment] = coefficientStateForTransform(self,target,options)
% Express compatible resolved content in a target transform's coefficient convention.
%
% Match Fourier integers, physical vertical mode labels and active endpoints.
% A scalar normalization/phase alignment is permitted for each matching mode;
% the resolved modes are never mixed or replaced. Incompatible mode shapes
% raise an error. Both objects remain unchanged. The returned state represents
% the source at source.t, using target.t0; set target.t accordingly on adoption.
% Assessment uses a common refined positive physical quadrature and includes
% balanced cross terms. Discarded-field energy is not source minus target energy.
%
% - Topic: Transfer resolution
% - Declaration: [state,assessment] = coefficientStateForTransform(target,options)
% - Parameter target: same model class and physical problem at target resolution
% - Parameter options.modeTolerance: maximum relative per-mode physical shape residual
% - Parameter options.quadratureCount: comparison quadrature count; default twice the larger Nz plus one
% - Returns state: target-shaped family structure with absent target content zero
% - Returns assessment: positive field error, discarded-field and per-family energies, retained mismatch and matched counts
arguments (Input)
    self (1,1) WVTransformFreeSurfaceQG
    target (1,1) WVTransform
    options.modeTolerance (1,1) double {mustBeReal,mustBeFinite,mustBePositive} = 1e-6
    options.quadratureCount (1,1) double {mustBeInteger,mustBePositive} = 2*max(self.Nz,target.Nz)+1
end
arguments (Output)
    state (1,1) struct
    assessment (1,1) struct
end
args=namedargs2cell(options);
[state,assessment]=WVInternal.freeSurfaceCoefficientTransfer(self,target,args{:});
end
