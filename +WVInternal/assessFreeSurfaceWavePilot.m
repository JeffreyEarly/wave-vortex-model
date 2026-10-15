function cost = assessFreeSurfaceWavePilot(state,options)
% A conclusive sampled failure may reject only the first resolution pair.
% Passing or inconclusive samples cannot qualify the complete inventory.
cost = struct(waveEigensolves=0,pages=0,rejected=false,quadraticDealiasingSeconds=0);
active = find(state.waveModeCountByKh>0);
if ~isempty(options.referenceNEVP) || numel(active)<32, return; end
positions = active(unique(round(linspace(1,numel(active),7))));
state.nEVP = options.nEVP;
state.khUnique = state.khUnique(positions);
state.waveModeCountByKh = state.waveModeCountByKh(positions);
[state,bases] = WVInternal.buildFreeSurfaceWaveState(state,options);
referenceNEVP = max(options.nEVP+16,ceil(1.5*options.nEVP));
assessment = WVInternal.assessWaveModeConstruction(state,bases,(1:numel(positions)).',referenceNEVP,options.modeConvergenceTolerance,options);
values = [assessment.pages.convergedCount;assessment.inertial.convergedCount];
limits = [assessment.pages.gridSupportedCount;assessment.inertial.gridSupportedCount];
complete = [assessment.pages.status~="reference-inconclusive";~isnan(assessment.inertial.usableCount)];
cost.pages = numel(positions)+1;
cost.waveEigensolves = 2*cost.pages;
cost.quadraticDealiasingSeconds = assessment.quadraticDealiasingSeconds;
cost.rejected = any(complete & isfinite(values) & values<limits);
% Both sampled collections are discarded. Only the complete path accepts
% modes and supplies references for subsequent candidate reuse.
end
