classdef TestFreeSurfaceMappedTendency < matlab.unittest.TestCase
    methods (Test, TestTags="full")
        function mappedRatesSatisfyPhysicalMaterialEquations(testCase)
            [hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative] = manufacturedState();
            tendency = WVInternal.freeSurfaceMappedTendency(hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative);
            testCase.verifyLessThan(max(abs(derivative.x(hatted.u)+derivative.y(hatted.v)+derivative.xi(hatted.w)),[],'all'),2e-14)
            testCase.verifyEqual(hatted.w(:,:,1),zeros(size(hatted.ssh)),AbsTol=0)
            testCase.verifyEqual(tendency.ssh,hatted.w(:,:,end),AbsTol=0)
            testCase.verifyGreaterThan(max(abs(tendency.ssh),[],'all'),1e-3)

            % Differentiate the inverse velocity map in time numerically.
            % Then use fixed-physical-depth chain rules and the Cartesian
            % advective equations, independently of the conservative RHS.
            dt = 0.002;
            plus = hatted;
            minus = hatted;
            for name = ["u","v","w","eta","ssh"]
                plus.(name) = hatted.(name)+dt*tendency.(name);
                minus.(name) = hatted.(name)-dt*tendency.(name);
            end
            physical = inverseMap(hatted,xi,Lz,derivative);
            physicalPlus = inverseMap(plus,xi,Lz,derivative);
            physicalMinus = inverseMap(minus,xi,Lz,derivative);
            gamma = 1+hatted.ssh/Lz;
            s = reshape(1+xi/Lz,1,1,[]);
            xiAtFixedZTime = -s.*tendency.ssh./gamma;
            xiAtFixedZX = -s.*derivative.x(hatted.ssh)./gamma;
            xiAtFixedZY = -s.*derivative.y(hatted.ssh)./gamma;
            for name = ["u","v","w","eta"]
                field = physical.(name);
                fieldXi = derivative.xi(field);
                fixedZTime = (physicalPlus.(name)-physicalMinus.(name))/(2*dt)+xiAtFixedZTime.*fieldXi;
                fixedZX = derivative.x(field)+xiAtFixedZX.*fieldXi;
                fixedZY = derivative.y(field)+xiAtFixedZY.*fieldXi;
                fixedZZ = fieldXi./gamma;
                material.(name) = fixedZTime+physical.u.*fixedZX+physical.v.*fixedZY+physical.w.*fixedZZ;
            end
            pressureXi = derivative.xi(pressure);
            pressureX = derivative.x(pressure)+xiAtFixedZX.*pressureXi;
            pressureY = derivative.y(pressure)+xiAtFixedZY.*pressureXi;
            testCase.verifyEqual(material.u,f*physical.v-pressureX/rho0,AbsTol=2e-10)
            testCase.verifyEqual(material.v,-f*physical.u-pressureY/rho0,AbsTol=2e-10)
            testCase.verifyEqual(material.w,-pressureXi./(rho0*gamma)+buoyancy,AbsTol=2e-10)
            testCase.verifyEqual(material.eta,physical.w,AbsTol=2e-10)
        end

        function slopingSurfacePressureEntersTheVerticalVelocityMap(testCase)
            [hatted,~,~,xi,Lz,f,rho0,derivative,x,y] = manufacturedState();
            zero = zeros(size(hatted.u));
            for name = ["u","v","w","eta"], hatted.(name)=zero; end
            [X,~,~] = ndgrid(x,y,xi);
            pressure = 30*sin(2*pi*X/(x(end)+x(2)));
            tendency = WVInternal.freeSurfaceMappedTendency(hatted,pressure,zero,xi,Lz,f,rho0,derivative);
            % A pressure field independent of depth causes no physical
            % vertical acceleration at rest. Hatted w_t must cancel the
            % pressure-driven change of the sloping-coordinate velocity map.
            expected = reshape(1+xi/Lz,1,1,[]).*derivative.x(hatted.ssh).*derivative.x(pressure)/rho0;
            testCase.verifyEqual(tendency.w,expected,AbsTol=2e-14)
            testCase.verifyGreaterThan(max(abs(expected),[],'all'),1e-6)
            gamma = 1+hatted.ssh/Lz;
            physicalWTime = tendency.w+reshape(1+xi/Lz,1,1,[]).*(tendency.u.*derivative.x(hatted.ssh)+tendency.v.*derivative.y(hatted.ssh))./gamma;
            testCase.verifyEqual(physicalWTime,zero,AbsTol=2e-14)
        end

        function uniformInertialFlowHasTheExactFlatSurfaceLimit(testCase)
            [hatted,~,~,xi,Lz,f,rho0,derivative] = manufacturedState();
            shape = size(hatted.u);
            hatted.u = 0.3*ones(shape);
            hatted.v = -0.2*ones(shape);
            hatted.w = zeros(shape);
            hatted.eta = 0.07*ones(shape);
            hatted.ssh(:) = 0;
            buoyancy = -1e-4*hatted.eta;
            pressure = rho0*buoyancy.*reshape(xi,1,1,[]);
            tendency = WVInternal.freeSurfaceMappedTendency(hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative);
            testCase.verifyEqual(tendency.u,f*hatted.v,AbsTol=2e-14)
            testCase.verifyEqual(tendency.v,-f*hatted.u,AbsTol=2e-14)
            testCase.verifyEqual(tendency.w,zeros(shape),AbsTol=2e-14)
            testCase.verifyEqual(tendency.eta,zeros(shape),AbsTol=2e-14)
            testCase.verifyEqual(tendency.ssh,zeros(size(hatted.ssh)),AbsTol=0)
        end
    end
end

function [hatted,pressure,buoyancy,xi,Lz,f,rho0,derivative,x,y] = manufacturedState()
Lz = 100;
Lx = 800;
Ly = 600;
nx = 64;
ny = 48;
nz = 11;
x = (0:nx-1).'*Lx/nx;
y = (0:ny-1).'*Ly/ny;
xi = -Lz*(1+cos(pi*(0:nz-1).'/(nz-1)))/2;
[X,Y,R] = ndgrid(x,y,1+xi/Lz);
k = 2*pi/Lx;
l = 2*pi/Ly;
a = 0.25;
b = 0.1;
hatted.u = 0.3+a*cos(k*X).*cos(l*Y).*(1+R+R.^2);
hatted.v = -0.2+b*sin(k*X).*sin(l*Y).*(1+2*R);
hatted.w = Lz*sin(k*X).*cos(l*Y).*(a*k*(R+R.^2/2+R.^3/3)-b*l*(R+R.^2));
hatted.eta = 0.4*sin(k*X).*cos(l*Y).*(R+0.3*R.^2)+0.07*(1-R+R.^2);
hatted.ssh = 12*cos(k*X(:,:,1))+8*sin(l*Y(:,:,1));
pressure = 30*cos(2*k*X).*sin(l*Y).*(1+R+R.^3)+12*sin(k*X).*(R-R.^2);
buoyancy = -1e-4*hatted.eta+2e-5*cos(k*X).*sin(l*Y).*R.^2;
f = -1e-4;
rho0 = 1025;
derivative.x = @(field) fourierDerivative(field,Lx,1);
derivative.y = @(field) fourierDerivative(field,Ly,2);
% Barycentric differentiation is exact on the degree-ten polynomial space;
% this test does not use the WVM WKB or modal derivative implementation.
weights = (-1).^(0:nz-1).';
weights([1 end]) = weights([1 end])/2;
distance = xi-xi.';
distance(1:nz+1:end) = 1;
matrix = (weights.'./weights)./distance;
matrix(1:nz+1:end) = 0;
matrix(1:nz+1:end) = -sum(matrix,2);
derivative.xi = @(field) reshape(reshape(field,[],nz)*matrix.',size(field));
end

function result = fourierDerivative(field,L,dimension)
n = size(field,dimension);
wavenumber = (2*pi/L)*[0:n/2-1 0 -n/2+1:-1];
shape = ones(1,ndims(field));
shape(dimension) = n;
result = real(ifft(1i*reshape(wavenumber,shape).*fft(field,[],dimension),[],dimension));
end

function physical = inverseMap(hatted,xi,Lz,derivative)
% Independent inverse map used only to construct the physical-equation oracle.
stretch = 1+hatted.ssh/Lz;
surfaceFraction = reshape(1+xi/Lz,1,1,[]);
physical.u = hatted.u./stretch;
physical.v = hatted.v./stretch;
physical.w = hatted.w+surfaceFraction.*(physical.u.*derivative.x(hatted.ssh)+physical.v.*derivative.y(hatted.ssh));
physical.eta = hatted.eta;
end
