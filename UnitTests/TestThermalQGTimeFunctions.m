classdef TestThermalQGTimeFunctions < matlab.unittest.TestCase
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
                expected=thermalQGOriginalRK4Coefficients(rates(:,map),h);
                actual=WVInternal.exponentialRK4Coefficients(rates,h,map);
                testCase.verifyEqual(actual,expected)
                testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates,h,map.'),expected)
                testCase.verifyEqual(WVInternal.exponentialRK4Coefficients(rates(:,map),h),expected)
            end
        end

        function weightsPreserveScalarAndColumnShapes(testCase)
            for rates={0,-0.1,[0;-1e-9;-1]}
                for h=[1 86400]
                    expected=thermalQGOriginalRK4Coefficients(rates{1},h);
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

        function seasonalResponseMatchesExpandedOriginal(testCase)
            for diffusivity=[0 1e-5]
                w=TestWVTransformFreeSurfaceQGDiffusion.transform(diffusivity);
                pattern=sin(2*pi*w.Y(:,:,1)/w.Ly)+0.3*cos(2*pi*(w.X(:,:,1)/w.Lx+w.Y(:,:,1)/w.Ly));
                for phase=[0 0.43 pi/2]
                    force=WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=2e-8,phase=phase);
                    for t=[0 1e-6 86400 20.5*force.period]
                        expected=TestThermalQGTimeFunctions.originalSeasonalResponse(w,force,t);
                        testCase.verifyEqual(force.exactThermalResponse(w,t),expected)
                    end
                end
                force=WVSeasonalSurfaceAnomalyForcing(w,pattern=pattern,amplitude=0);
                testCase.verifyFalse(any(force.exactThermalResponse(w,force.period),'all'))
            end
        end
    end
    methods (Static)
        function amplitudes=originalSeasonalResponse(w,force,t)
            % The old expression expands rates before evaluating both signs.
            b=w.spectralField(force.amplitude*force.pattern);
            source=w.transformStateForward(zeros(w.Nz-2,length(w.klNonzero)),b);
            rates=w.coefficientLinearRates(); omega=2*pi/force.period;
            plus=integral(omega); minus=integral(-omega);
            amplitudes=source.*(exp(1i*force.phase)*plus-exp(-1i*force.phase)*minus)/(2i);
            function value=integral(frequency)
                z=(rates-1i*frequency)*t;
                ratio=ones(size(z)); nonzero=z~=0;
                ratio(nonzero)=expm1(z(nonzero))./z(nonzero);
                value=t*exp(1i*frequency*t).*ratio;
            end
        end
    end
end
