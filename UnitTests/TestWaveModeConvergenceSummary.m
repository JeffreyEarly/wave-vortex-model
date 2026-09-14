classdef TestWaveModeConvergenceSummary < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function reorderedReportsMatchScalarTablePolicy(testCase)
            [candidate,z,w] = preparedModes(4);
            candidate = reorder(candidate,[3 1 4 2]);
            reference = reorder(candidate,[2 4 1 3]);
            report = assessModeConvergence(candidate,reference,z,w);
            report.measurements = report.measurements([2:2:height(report.measurements),1:2:height(report.measurements)],:);
            verifyScalarSummary(testCase,report,4,1e-6)
        end

        function providerLabelFailuresMatchScalarTablePolicy(testCase)
            [candidate,z,w] = preparedModes(4);
            reports = cell(3,1);

            reports{1} = assessModeConvergence(candidate,reorder(candidate,[1 3 4]),z,w);

            duplicateReference = candidate;
            duplicateReference.identity.columnLabels(3) = duplicateReference.identity.columnLabels(2);
            reports{2} = assessModeConvergence(candidate,duplicateReference,z,w);

            duplicateCandidate = candidate;
            duplicateCandidate.identity.columnLabels(2) = duplicateCandidate.identity.columnLabels(1);
            reports{3} = assessModeConvergence(duplicateCandidate,candidate,z,w);

            for iReport = 1:numel(reports)
                actual = verifyScalarSummary(testCase,reports{iReport},4,1e-6);
                testCase.verifyFalse(actual.complete)
            end
            testCase.verifyEqual(reports{1}.matches.status,["matched";"inconclusive";"matched";"matched"])
            testCase.verifyEqual(reports{2}.matches.status,["matched";"inconclusive";"inconclusive";"matched"])
            testCase.verifyEqual(reports{3}.matches.status,["inconclusive";"inconclusive";"matched";"matched"])

            candidateSubset = reorder(candidate,[1 3 4]);
            actual = verifyScalarSummary(testCase,assessModeConvergence(candidateSubset,candidate,z,w),3,1e-6);
            testCase.verifyTrue(actual.complete)
            testCase.verifyEqual(actual.acceptedCount,3)
        end

        function lateInconclusiveModeSurvivesEarlierFailure(testCase)
            [reference,z,w] = preparedModes(3);
            candidate = reference;
            candidate.values.F(:,2) = 1.2*candidate.values.F(:,2);
            candidate.derivatives.F(:,2) = 1.2*candidate.derivatives.F(:,2);
            report = assessModeConvergence(candidate,reorder(reference,[1 2]),z,w);
            actual = verifyScalarSummary(testCase,report,3,0.1);
            testCase.verifyEqual(actual.passed,[true;false;false])
            testCase.verifyEqual(actual.acceptedCount,1)
            testCase.verifyFalse(actual.complete)
            testCase.verifyEqual(actual.prefixError(3),actual.prefixError(2))

            withoutRequestedEvidence = candidate;
            withoutRequestedEvidence = rmfield(withoutRequestedEvidence,["derivatives","equivalentDepths"]);
            report = assessModeConvergence(withoutRequestedEvidence,withoutRequestedEvidence,z,w);
            actual = verifyScalarSummary(testCase,report,3,0.1);
            testCase.verifyEqual(actual.passed,false(3,1))
            testCase.verifyFalse(actual.complete)
        end

        function toleranceAndExceptionalScalarsPreserveLegacyMax(testCase)
            [candidate,z,w] = preparedModes(5);
            candidate.equivalentDepths = [realmin 0 realmin Inf NaN];
            reference = candidate;
            reference.equivalentDepths = [2*realmin 0 0 Inf 1];
            report = assessModeConvergence(candidate,reference,z,w);
            actual = verifyScalarSummary(testCase,report,5,0.5);
            testCase.verifyEqual(actual.passed,[true;true;false;true;false])
            testCase.verifyEqual(actual.acceptedCount,2)
            testCase.verifyEqual(actual.prefixError(1:4),[0.5;0.5;Inf;Inf])
            testCase.verifyEqual(report.measurements.status(report.measurements.quantity=="equivalentDepth"),["measured";"measured";"measured";"measured";"inconclusive"])

            report = assessModeConvergence(candidate,reorder(candidate,2:5),z,w);
            actual = verifyScalarSummary(testCase,report,5,0.5);
            testCase.verifyTrue(isnan(actual.prefixError(1)))
            testCase.verifyEqual(actual.prefixError(2),0)
            testCase.verifyFalse(actual.complete)
        end

        function zeroCountIsAnEmptyCompletePrefix(testCase)
            [candidate,z,w] = preparedModes(2);
            report = assessModeConvergence(candidate,candidate,z,w);
            actual = verifyScalarSummary(testCase,report,0,1e-6);
            testCase.verifyEqual(actual.passed,false(0,1))
            testCase.verifyEqual(actual.prefixError,zeros(0,1))
            testCase.verifyEqual(actual.acceptedCount,0)
            testCase.verifyTrue(actual.complete)
        end
    end
end

function summary = verifyScalarSummary(testCase,report,n,tolerance)
expected = scalarTableSummary(report,n,tolerance);
summary = WVInternal.summarizeModeConvergence(report,n,tolerance);
testCase.verifyEqual(summary,expected)
end

function summary = scalarTableSummary(report,n,tolerance)
passed = false(n,1);
prefixError = zeros(n,1);
complete = true;
for j = 1:n
    rows = report.measurements.columnLabel==report.identity.columnLabels(j) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
    if any(report.measurements.status(rows)~="measured")
        complete = false;
    else
        passed(j) = all(report.measurements.value(rows)<=tolerance);
    end
    selected = ismember(report.measurements.columnLabel,report.identity.columnLabels(1:j)) & ismember(report.measurements.quantity,["equivalentDepth","h1"]);
    prefixError(j) = max(report.measurements.value(selected));
end
summary = struct(passed=passed,complete=complete,acceptedCount=sum(cumprod(passed)),prefixError=prefixError);
end

function [prepared,z,w] = preparedModes(n)
z = linspace(-1,0,17).';
w = [0.5;ones(15,1);0.5]/16;
modes = 1:n;
values = struct(F=cos(pi*z*modes),G=sin(pi*z*modes));
derivatives = struct(F=-pi*sin(pi*z*modes).*modes,G=pi*cos(pi*z*modes).*modes);
identity = struct(family="waves",columnLabels=string(modes),normalization="test",zDomain=[-1 0],kappa=1e-4);
prepared = struct(identity=identity,values=values,derivatives=derivatives,equivalentDepths=1./modes,provenance=struct(source="prepared regression"));
end

function prepared = reorder(prepared,order)
prepared.identity.columnLabels = prepared.identity.columnLabels(order);
prepared.equivalentDepths = prepared.equivalentDepths(order);
for group = ["values","derivatives"]
    for field = string(fieldnames(prepared.(group))).'
        prepared.(group).(field) = prepared.(group).(field)(:,order);
    end
end
end
