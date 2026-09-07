classdef TestFreeSurfaceQGConservation < matlab.unittest.TestCase
    % Unforced f-plane controls separate spatial and temporal errors.
    properties
        study
    end
    methods (TestClassSetup)
        function runControls(testCase)
            testCase.study = TestFreeSurfaceQGConservation.runStudy();
        end
    end
    methods (Test, TestTags="full")
        function instantaneousBudgetsConverge(testCase)
            r = testCase.study.rates;
            testCase.verifyGreaterThan(min(r.rhsMagnitude),0)
            for scale = [Inf 700]
                rows = r(r.stratificationScale==scale,:);
                testCase.verifyLessThan(abs(rows.energyRate(end)),.01*abs(rows.energyRate(1))+1e-9)
                testCase.verifyLessThan(abs(rows.generalizedRate(end)),.01*abs(rows.generalizedRate(1))+1e-9)
                testCase.verifyLessThan(abs(rows.enstrophyRate(end)),1e-8)
                testCase.verifyLessThan(abs(rows.enstrophyRate(end)),.01*abs(rows.enstrophyRate(1))+1e-10)
                testCase.verifyLessThan(max(abs(rows.surfaceRate)),1e-12)
                testCase.verifyLessThan(max(abs(rows.bottomRate)),1e-12)
                testCase.verifyLessThan(max(rows.roundTripError),1e-6)
                testCase.verifyLessThan(max(rows.endpointResidual),1e-12)
                testCase.verifyLessThan(rows.qgpvConsistency(end),1e-6)
            end
        end
        function timeRefinementResolvesTheSameModalTrajectory(testCase)
            r = testCase.study.time;
            testCase.verifyLessThan(r.stateError(2),r.stateError(1)/8)
            testCase.verifyLessThan(r.stateError(3),r.stateError(2)/8)
            testCase.verifyLessThan(r.stateError(3),1e-9)
            testCase.verifyLessThan(abs(r.surfaceDrift(end)),abs(r.surfaceDrift(1))/8)
            testCase.verifyLessThan(abs(r.bottomDrift(end)),abs(r.bottomDrift(1))/8)
            testCase.verifyLessThan(abs(r.enstrophyDrift(end)),abs(r.enstrophyDrift(1))/8)
        end
        function spatialRefinementControlsInvariantDriftAndTruncation(testCase)
            v = testCase.study.vertical;
            testCase.verifyLessThan(abs(v.energyDrift(end)),.01*abs(v.energyDrift(1))+1e-10)
            testCase.verifyLessThan(abs(v.generalizedDrift(end)),.01*abs(v.generalizedDrift(1))+1e-10)
            testCase.verifyLessThan(max(abs(v.enstrophyDrift)),1e-8)
            testCase.verifyLessThan(max(abs(v.surfaceDrift)),1e-10)
            testCase.verifyLessThan(max(abs(v.bottomDrift)),1e-10)
            h = testCase.study.horizontal;
            testCase.verifyLessThan(h.stateError(2),h.stateError(1)/2)
            testCase.verifyLessThan(h.stateError(3),h.stateError(2)/2)
            testCase.verifyLessThan(max(abs(h.energyDrift)),1e-7)
            testCase.verifyLessThan(max(abs(h.generalizedDrift)),1e-7)
            testCase.verifyLessThan(max(abs(h.enstrophyDrift)),1e-8)
            testCase.verifyLessThan(max(abs(h.surfaceDrift)),1e-10)
            testCase.verifyLessThan(max(abs(h.bottomDrift)),1e-10)
        end
    end
    methods (Static)
        function study = runStudy()
            % Reproduce fixed-physics unforced controls and error estimates.
            arguments (Output)
                study (1,1) struct
            end
            rateRows = cell(8,1); index = 0;
            for scale = [Inf 700]
                for nz = [17 33 65 129]
                    w = TestFreeSurfaceQGConservation.controlledState(12,nz,scale);
                    tendency = w.coefficientTendency();
                    d = w.quadraticDiagnostics(tendency=tendency);
                    normalized = rates(d)*w.Lx/w.uvMax;
                    [roundTrip,endpointResidual,consistency] = reconstructionErrors(w);
                    rhsMagnitude = norm(tendency.Ag_q,'fro')+norm(tendency.Ag_0,'fro');
                    index = index+1;
                    rateRows{index} = array2table([scale,nz,w.apvModeCount,normalized,rhsMagnitude,roundTrip,endpointResidual,consistency], ...
                        VariableNames={'stratificationScale','Nz','APVModes','energyRate','generalizedRate','enstrophyRate','surfaceRate','bottomRate','rhsMagnitude','roundTripError','endpointResidual','qgpvConsistency'});
                end
            end
            study.rates = vertcat(rateRows{:});
            steps = [8 16 32 64];
            saved = cell(1,4); timeRows = zeros(4,7);
            for j = 1:4
                [w,initial,final] = TestFreeSurfaceQGConservation.trajectory(12,65,steps(j));
                saved{j} = state(w);
                timeRows(j,1:6) = [steps(j),drift(initial,final)];
            end
            for j = 1:4
                timeRows(j,7) = stateError(w,saved{j},saved{4});
            end
            names = {'steps','energyDrift','generalizedDrift','enstrophyDrift','surfaceDrift','bottomDrift','stateError'};
            study.time = array2table(timeRows,VariableNames=names);
            verticalRows = zeros(4,7); counts = [17 33 65 129];
            for j = 1:4
                if counts(j)==65
                    verticalRows(j,:) = [65,w.apvModeCount,timeRows(4,2:6)];
                else
                    [v,initial,final] = TestFreeSurfaceQGConservation.trajectory(12,counts(j),64);
                    verticalRows(j,:) = [counts(j),v.apvModeCount,drift(initial,final)];
                end
            end
            study.vertical = array2table(verticalRows,VariableNames=[{'Nz','APVModes'},names(2:6)]);
            counts = [8 12 16 24]; horizontalRows = zeros(4,7);
            horizontalStates = cell(1,4); geometries = cell(1,4); bases = cell(1,4);
            for j = 1:4
                if counts(j)==12
                    h = w;
                    horizontalRows(j,1:6) = [12,timeRows(4,2:6)];
                else
                    [h,initial,final] = TestFreeSurfaceQGConservation.trajectory(counts(j),65,64);
                    horizontalRows(j,1:6) = [counts(j),drift(initial,final)];
                end
                horizontalStates{j} = state(h);
                geometries{j} = [h.kNonzero(:),h.lNonzero(:)];
                bases{j} = {h.apvF,h.apvG,h.mdaG};
            end
            reference = horizontalStates{4};
            for j = 1:4
                assert(isequal(bases{j},bases{4}),'Horizontal comparisons require identical resolved vertical bases.');
                projected = reference;
                projected.Ag_q(:) = 0; projected.Ag_0(:) = 0;
                [present,indices] = ismember(geometries{j},geometries{4},'rows');
                assert(all(present),'Reference must contain every candidate horizontal wavenumber.');
                projected.Ag_q(:,indices) = horizontalStates{j}.Ag_q;
                projected.Ag_0(:,indices) = horizontalStates{j}.Ag_0;
                projected.Amda = horizontalStates{j}.Amda;
                horizontalRows(j,7) = stateError(h,projected,reference);
            end
            study.horizontal = array2table(horizontalRows,VariableNames=[{'Nxy'},names(2:end)]);
        end

        function w = controlledState(nh,nz,scale)
            arguments (Input)
                nh (1,1) double {mustBeInteger,mustBePositive}
                nz (1,1) double {mustBeInteger,mustBePositive}
                scale (1,1) double {mustBePositive} = 700
            end
            arguments (Output)
                w (1,1) WVTransformFreeSurfaceQG
            end
            w = WVTransformFreeSurfaceQG([100e3 100e3 1000],[nh nh nz],N2Function=@(z)1e-4*exp(2*z/scale),latitude=30,g0=-.1,gd=.1);
            x = 2*pi*w.X/w.Lx; y = 2*pi*w.Y/w.Ly;
            q = 1e-7*((1+.2*cos(pi*w.Z/w.Lz)).*cos(x)+.8*(1+.4*w.Z/w.Lz).*sin(y)+.5*cos(2*pi*w.Z/w.Lz).*cos(x+y+.3));
            b0 = .1*(cos(x(:,:,1))+.7*sin(y(:,:,1))+.5*cos(x(:,:,1)+y(:,:,1)+.7));
            bd = .06*(sin(x(:,:,1)+.2)-.8*cos(y(:,:,1)+.4));
            geometry = WVGeometryDoublyPeriodic([w.Lx w.Ly],[nh nh],Nz=2);
            qHat = w.transformFromSpatialDomainWithFourier(q);
            bHat = geometry.transformFromSpatialDomainWithFourier(cat(3,b0,bd));
            [w.Ag_q,w.Ag_0] = w.transformStateForward(qHat(:,w.klNonzero),bHat(:,w.klNonzero));
            w.Amda = w.transformMDAForward(.01*cos(pi*w.z/w.Lz));
        end

        function [w,initial,final] = trajectory(nh,nz,steps)
            arguments (Input)
                nh (1,1) double
                nz (1,1) double
                steps (1,1) double
            end
            arguments (Output)
                w (1,1) WVTransformFreeSurfaceQG
                initial (1,1) struct
                final (1,1) struct
            end
            w = TestFreeSurfaceQGConservation.controlledState(nh,nz);
            initial = w.quadraticDiagnostics();
            model = WVModel(w,shouldUseLinearDynamics=false);
            model.setupIntegrator(integratorType="fixed",deltaT=2e6/steps);
            model.integrateToTime(2e6,shouldShowIntegrationDiagnostics=false);
            final = w.quadraticDiagnostics();
        end
    end
end

function s = state(w)
s = struct(Ag_q=w.Ag_q,Ag_0=w.Ag_0,Amda=w.Amda);
end
function error = stateError(w,a,b)
for name = ["Ag_q","Ag_0","Amda"], a.(name) = a.(name)-b.(name); end
d = w.quadraticDiagnostics(state=a);
reference = w.quadraticDiagnostics(state=b);
error = sqrt(d.totalEnergy/reference.totalEnergy);
end
function values = inventory(d)
values = [d.totalEnergy,d.generalizedEnergy,d.potentialEnstrophy,d.surfaceAnomalyVariance,d.bottomAnomalyVariance];
end
function scales = inventoryScales(d)
scales = abs(inventory(d));
% Both active endpoint weights have magnitude .1 in these controls.
scales(2) = d.totalEnergy+.1*(d.surfaceAnomalyVariance+d.bottomAnomalyVariance);
end
function values = rates(d)
values = [d.totalEnergyTendency,d.generalizedEnergyTendency,d.potentialEnstrophyTendency,d.surfaceAnomalyVarianceTendency,d.bottomAnomalyVarianceTendency]./inventoryScales(d);
end
function values = drift(a,b)
values = (inventory(b)-inventory(a))./inventoryScales(a);
end
function [roundTrip,endpointResidual,consistency] = reconstructionErrors(w)
[q,b] = w.transformStateBack(w.Ag_q,w.Ag_0);
[a,z] = w.transformStateForward(q,b);
m = w.transformMDAForward(w.transformMDABack(w.Amda));
roundTrip = stateError(w,struct(Ag_q=a,Ag_0=z,Amda=m),state(w));
[~,reconstructed] = w.transformStateBack(a,z);
endpointResidual = norm(reconstructed-b,'fro')/norm(b,'fro');
q = w.qgpv;
independent = w.diffX(w.v)-w.diffY(w.u)-w.f*w.diffZ(w.eta);
consistency = norm(q(:)-independent(:))/norm(q(:));
end
