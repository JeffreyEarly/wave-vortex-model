classdef TestBuoyancyIntervalRecurrence < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function agreesWithIndependentHighPrecisionPolynomials(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            oracle=readtable(fullfile(root,'UnitTests','ReferenceImplementations','data','buoyancy-oracle.csv'));
            for degree=unique(oracle.degree).'
                coefficients=zeros(degree+1,1); coefficients(1)=1e-4;
                coefficients(end)=coefficients(end)+2e-5;
                polynomial=chebfun(coefficients,[-1000 0],'coeffs');
                context=WVInternal.freeSurfaceThermodynamicContext(@(z)polynomial(z),1000,9.81,1025);
                cases=oracle(oracle.degree==degree,:);
                z=reshape(cases.z,1,1,[]); eta=reshape(cases.eta,1,1,[]);
                actual=context.evaluateNonlinear(z,eta,0,cases.referenceN2);
                % Representation and evaluation roundoff scale with interval,
                % not with the vanishing nonlinear remainder itself.
                buoyancyBound=256*eps(1e-4)*abs(cases.eta)+3e-11*abs(cases.buoyancy);
                energyBound=3e-10*abs(cases.ape)+1e-30;
                profileError=abs(actual.N2AtLabel(:)-cases.labelN2);
                testCase.verifyLessThanOrEqual(profileError,3e-16*ones(size(profileError)))
                remainderBound=(profileError+256*eps(1e-4)).*abs(cases.eta)+3e-11*abs(cases.remainder);
                testCase.verifyLessThanOrEqual(abs(actual.buoyancy(:)-cases.buoyancy),buoyancyBound)
                testCase.verifyLessThanOrEqual(abs(actual.ape(:)-cases.ape),energyBound)
                testCase.verifyLessThanOrEqual(abs(actual.buoyancyRemainder(:)-cases.remainder),remainderBound)
                fprintf('Degree %d: max buoyancy/APE/remainder error %.3g %.3g %.3g\n',degree,max(abs(actual.buoyancy(:)-cases.buoyancy)),max(abs(actual.ape(:)-cases.ape)),max(abs(actual.buoyancyRemainder(:)-cases.remainder)))
            end
        end
    end
end
