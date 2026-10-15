function [assessment,reference,convergence,entry]=assessInitializationWithFault(fault,varargin)
% Keep numerical assessment real; alter only the evidence seen by the test factory.
[assessment,reference,convergence]=WVInternal.assessWaveModeConstruction(varargin{:});
state=varargin{1};
converged=all(assessment.pages.convergedCount>=assessment.pages.gridSupportedCount) && assessment.inertial.convergedCount>=assessment.inertial.gridSupportedCount;
entry=struct(nPages=numel(state.khUnique),nEVP=state.nEVP,referenceNEVP=varargin{4},kappa=state.khUnique,faultApplied=false,convergedBeforeFault=converged);
if fault=="inconclusive" && entry.nPages==7
    assessment.pages.status(:)="reference-inconclusive";
    assessment.pages.convergedCount(:)=0;
    assessment.pages.usableCount(:)=NaN;
    assessment.inertial.convergedCount=0;
    assessment.inertial.usableCount=NaN;
    entry.faultApplied=true;
elseif fault=="unsampled-failure" && entry.nPages>7 && state.nEVP==64
    assessment.pages.convergedCount(2)=0;
    assessment.pages.usableCount(2)=0;
    assessment.pages.status(2)="rejected";
    entry.faultApplied=true;
end
end
