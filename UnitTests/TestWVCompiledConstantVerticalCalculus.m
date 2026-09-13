classdef TestWVCompiledConstantVerticalCalculus < matlab.unittest.TestCase
    % Focused public parity for tiled constant-stratification vertical calculus.
    methods (Test,TestTags="optional")
        function volumesMatchMatlabAcrossTileBoundary(testCase)
            gridSizes = {[8 6 9],[18 16 17]};
            for isHydrostatic = [true false]
                for shouldAntialias = [true false]
                    for iGrid = 1:numel(gridSizes)
                        Nxyz = gridSizes{iGrid};
                        [matlabWVT,compiledWVT] = makeTransforms(Nxyz,isHydrostatic,shouldAntialias);
                        cleanup = onCleanup(@()deleteTransforms(matlabWVT,compiledWVT));
                        diagnostic = configurationName(Nxyz,isHydrostatic,shouldAntialias);
                        horizontalRows = prod(Nxyz(1:2));
                        if iGrid == 1
                            testCase.verifyLessThan(horizontalRows,256,diagnostic+" tile-boundary precondition");
                        else
                            testCase.verifyGreaterThan(horizontalRows,256,diagnostic+" tile-boundary precondition");
                        end
                        [F,G,expectedDzF,expectedDzG] = analyticVolumes(matlabWVT);

                        testCase.verifyGreaterThan(norm(expectedDzF(:)),0,diagnostic+" analytic diffZF nonzero");
                        testCase.verifyGreaterThan(norm(expectedDzG(:)),0,diagnostic+" analytic diffZG nonzero");
                        verifyNear(testCase,matlabWVT.diffZF(F),expectedDzF,2e-11,diagnostic+" analytic diffZF");
                        verifyNear(testCase,matlabWVT.diffZG(G),expectedDzG,2e-11,diagnostic+" analytic diffZG");

                        broadband = broadbandVolume(matlabWVT);
                        realF = F+broadband;
                        realG = G-0.3*broadband;
                        valuesF = {realF,complex(realF,0.25*G-0.4*broadband)};
                        valuesG = {realG,complex(realG,-0.25*F+0.2*broadband)};
                        kinds = ["real" "complex"];
                        for iKind = 1:2
                            for order = 1:4
                                verifyDerivative(testCase,matlabWVT,compiledWVT,"diffZF",valuesF{iKind},order,diagnostic+" "+kinds(iKind));
                                verifyDerivative(testCase,matlabWVT,compiledWVT,"diffZG",valuesG{iKind},order,diagnostic+" "+kinds(iKind));
                            end
                            verifyIntegral(testCase,matlabWVT,compiledWVT,"intZF",valuesF{iKind},diagnostic+" "+kinds(iKind)+" volume");
                            verifyIntegral(testCase,matlabWVT,compiledWVT,"intZG",valuesG{iKind},diagnostic+" "+kinds(iKind)+" volume");
                        end
                        clear cleanup
                    end
                end
            end
        end

        function matrixIntegralsMatchMatlabAtTileTails(testCase)
            columnCounts = [0 1 255 256 257];
            gridSizes = {[8 6 9],[18 16 17]};
            for isHydrostatic = [true false]
                for shouldAntialias = [true false]
                    for iGrid = 1:numel(gridSizes)
                        Nxyz = gridSizes{iGrid};
                        [matlabWVT,compiledWVT] = makeTransforms(Nxyz,isHydrostatic,shouldAntialias);
                        cleanup = onCleanup(@()deleteTransforms(matlabWVT,compiledWVT));
                        diagnostic = configurationName(Nxyz,isHydrostatic,shouldAntialias);
                        for columnCount = columnCounts
                            realMatrix = deterministicMatrix(matlabWVT.Nz,columnCount);
                            complexMatrix = complex(realMatrix,0.5*flip(realMatrix,1));
                            for method = ["intZF" "intZG"]
                                verifyIntegral(testCase,matlabWVT,compiledWVT,method,realMatrix,diagnostic+" real matrix columns="+columnCount);
                                verifyIntegral(testCase,matlabWVT,compiledWVT,method,complexMatrix,diagnostic+" complex matrix columns="+columnCount);
                            end
                        end
                        clear cleanup
                    end
                end
            end
        end
    end
end

function [matlabWVT,compiledWVT] = makeTransforms(Nxyz,isHydrostatic,shouldAntialias)
matlabWVT = WVTransformConstantStratification([6000 4000 1000],Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=isHydrostatic,shouldAntialias=shouldAntialias,computationalBackend="matlab");
compiledWVT = WVTransformConstantStratification([6000 4000 1000],Nxyz,N0=sqrt(2e-5),latitude=45,isHydrostatic=isHydrostatic,shouldAntialias=shouldAntialias,computationalBackend="compiled");
end

function [F,G,expectedDzF,expectedDzG] = analyticVolumes(wvt)
[X,Y,Z] = wvt.xyzGrid;
horizontal = 1+0.2*cos(2*pi*X/wvt.Lx)+0.1*sin(2*pi*Y/wvt.Ly);
mode = 2;
m = mode*pi/wvt.Lz;
theta = m*(Z+wvt.Lz);
F = horizontal.*cos(theta);
G = horizontal.*sin(theta);
expectedDzF = -m*horizontal.*sin(theta);
expectedDzG = m*horizontal.*cos(theta);
end

function value = broadbandVolume(wvt)
[x,y,z] = ndgrid(0:wvt.Nx-1,0:wvt.Ny-1,0:wvt.Nz-1);
value = 0.013*sin(2*pi*(3*x/wvt.Nx+2*y/wvt.Ny)).*cos(3*pi*z/(wvt.Nz-1));
value = value+0.007*cos(2*pi*(x/wvt.Nx-3*y/wvt.Ny)).*sin(4*pi*z/(wvt.Nz-1));
end

function value = deterministicMatrix(rows,columns)
if columns == 0
    value = zeros(rows,0);
    return
end
[row,column] = ndgrid(0:rows-1,0:columns-1);
value = 0.25+cos(pi*row/max(rows-1,1))+0.1*sin(2*pi*(column+1)/max(columns,2));
end

function verifyDerivative(testCase,matlabWVT,compiledWVT,method,input,order,diagnostic)
original = input;
expected = feval(method,matlabWVT,input,n=order);
actual = feval(method,compiledWVT,input,n=order);
testCase.verifyEqual(input,original,diagnostic+" "+method+" order "+order+" input unchanged");
verifyNear(testCase,actual,expected,1e-12,diagnostic+" "+method+" order "+order);
end

function verifyIntegral(testCase,matlabWVT,compiledWVT,method,input,diagnostic)
original = input;
expected = feval(method,matlabWVT,input);
actual = feval(method,compiledWVT,input);
testCase.verifyEqual(input,original,diagnostic+" "+method+" input unchanged");
verifyNear(testCase,actual,expected,1e-12,diagnostic+" "+method);
end

function verifyNear(testCase,actual,expected,tolerance,diagnostic)
testCase.verifySize(actual,size(expected),diagnostic);
testCase.assertTrue(all(isfinite(actual(:))) && all(isfinite(expected(:))),diagnostic+" finite output");
relativeError = norm(actual(:)-expected(:))/max(norm(expected(:)),realmin);
testCase.verifyLessThanOrEqual(relativeError,tolerance,diagnostic);
end

function value = configurationName(Nxyz,isHydrostatic,shouldAntialias)
value = "grid="+join(string(Nxyz),"x")+", hydrostatic="+string(isHydrostatic)+", antialias="+string(shouldAntialias);
end

function deleteTransforms(varargin)
for transform = varargin
    if isvalid(transform{1}), delete(transform{1}), end
end
end
