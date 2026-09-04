classdef TestExponentialTimeFunctions < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function referencePath(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(fileparts(mfilename('fullpath')),'Fixtures')));
        end
    end
    methods (Test, TestTags="full")
        function weightsMatchExpandedOriginalIncludingNullAndStiffRates(testCase)
            rates=[0 -1e-16 -0.99; -1 -1.01 -1e3; -0.1+0.2i -1+2i -100+3i];
            % Nonmonotone repeated pages exercise expansion, not sorting.
            map=[3 1 2 1 3 2 2];
            for h=[0 1e-6 1 86400]
                expected=referenceExponentialRK4Coefficients(rates(:,map),h);
                actual=WVInternal.exponentialRK4Coefficients(rates,h,map);
                testCase.verifyEqual(actual,expected)
                testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates,h,map.'),expected)
                testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates(:,map),h),expected)
            end
        end

        function weightsPreserveScalarAndColumnShapes(testCase)
            for rates={0,-0.1,[0;-1e-9;-1]}
                for h=[1 86400]
                    expected=referenceExponentialRK4Coefficients(rates{1},h);
                    testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates{1},h),expected)
                    % The original helper only accepted scalars/matrices or
                    % columns, not a multi-entry row of small rates.
                    for name=string(fieldnames(expected)).'
                        expected.(name)=expected.(name)(:,[1 1]);
                    end
                    testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates{1},h,[1 1]),expected)
                end
            end
        end

    end
end
