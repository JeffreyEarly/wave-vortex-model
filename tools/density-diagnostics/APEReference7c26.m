classdef APEReference7c26
    % Frozen benchmark reference from commit 7c26eca05561e1fda4e99f641080efc5f6a7a449.
    % Only the class and constructor names differ from the original source.
    % Evaluate a monotone density profile and its displacement energetics.
    %
    % A shape-preserving cubic interpolant supplies the density, its inverse,
    % and the exact polynomial integral used by APE. Density plateaus do not
    % have a unique inverse and are rejected explicitly.
    %
    % - Topic: Internal
    % - Developer: true
    properties (SetAccess=private)
        z
        rho
    end
    properties (Access=private)
        densityOffset
        densityScale
        coefficients
        normalizedDensity
    end
    methods
        function self = APEReference7c26(z,rho)
            arguments
                z (:,1) double {mustBeFinite,mustBeReal}
                rho (:,1) double {mustBeFinite,mustBeReal}
            end
            if numel(z) < 2 || numel(z) ~= numel(rho) || any(diff(z) <= 0)
                error('WVNoMotionProfile:InvalidGrid','Use matching density and strictly increasing height vectors with at least two entries.');
            end
            if any(diff(rho) >= 0)
                error('WVNoMotionProfile:NonInvertibleDensity','Density must strictly decrease with height; plateaus have no unique inverse material height.');
            end
            self.z = z;
            self.rho = rho;
            self.densityOffset = rho(end);
            self.densityScale = rho(1)-rho(end);
            self.normalizedDensity = (rho-self.densityOffset)/self.densityScale;
            pp = pchip(z,self.normalizedDensity);
            self.coefficients = [zeros(pp.pieces,4-pp.order),pp.coefs];
        end

        function rho = density(self,z)
            arguments
                self
                z double {mustBeFinite,mustBeReal}
            end
            self.validateHeight(z);
            rho = self.densityOffset + self.densityScale * ppval(mkpp(self.z,self.coefficients),z);
        end

        function z = inverse(self,rho)
            arguments
                self
                rho double {mustBeFinite,mustBeReal}
            end
            shape = size(rho);
            tolerance = 8*eps(max(abs(self.rho)));
            if any(rho(:) < self.rho(end)-tolerance | rho(:) > self.rho(1)+tolerance)
                error('WVNoMotionProfile:DensityOutsideProfile','Total density lies outside the no-motion profile range; recompute a profile that spans the current density distribution.');
            end
            target = (min(max(rho(:),self.rho(end)),self.rho(1))-self.densityOffset)/self.densityScale;
            interval = discretize(-target,-self.normalizedDensity);
            c = self.coefficients(interval,:);
            lower = zeros(size(target));
            upper = self.z(interval+1)-self.z(interval);
            height = upper .* (self.normalizedDensity(interval)-target) ./ (self.normalizedDensity(interval)-self.normalizedDensity(interval+1));
            heightTolerance = 8*eps(max(abs(self.z))+diff(self.z([1 end])));
            active = true(size(target));
            for iteration = 1:64
                residual = ((c(:,1).*height+c(:,2)).*height+c(:,3)).*height+c(:,4)-target;
                lower(residual > 0) = height(residual > 0);
                upper(residual < 0) = height(residual < 0);
                derivative = (3*c(:,1).*height+2*c(:,2)).*height+c(:,3);
                next = height-residual./derivative;
                useMidpoint = ~isfinite(next) | next <= lower | next >= upper;
                next(useMidpoint) = (lower(useMidpoint)+upper(useMidpoint))/2;
                converged = residual == 0 | upper-lower <= heightTolerance;
                active = active & ~converged;
                if ~any(active)
                    break
                end
                height(active) = next(active);
            end
            if any(active)
                error('WVNoMotionProfile:InverseDidNotConverge','Density inversion failed to reach the height tolerance.');
            end
            z = reshape(self.z(interval)+height,shape);
        end

        function ape = availablePotentialEnergy(self,z,materialHeight,g,rho0)
            arguments
                self
                z double {mustBeFinite,mustBeReal}
                materialHeight double {mustBeFinite,mustBeReal}
                g (1,1) double {mustBeFinite,mustBeReal,mustBePositive}
                rho0 (1,1) double {mustBeFinite,mustBeReal,mustBePositive}
            end
            if ~isequal(size(z),size(materialHeight))
                error('WVNoMotionProfile:ShapeMismatch','Height and material height must have the same shape.');
            end
            self.validateHeight(z);
            self.validateHeight(materialHeight);
            % Exchange the two integrals to evaluate (r-z)*rho'(r)
            % from material height s to z. This uses density derivatives
            % directly, avoiding cancellation even for sub-ulp density
            % changes associated with small representable displacements.
            low = min(z,materialHeight);
            high = max(z,materialHeight);
            integral = zeros(size(z));
            for index = 1:numel(self.z)-1
                a = max(low,self.z(index));
                b = min(high,self.z(index+1));
                selected = b > a;
                t = a(selected)-self.z(index);
                d = b(selected)-a(selected);
                c = self.coefficients(index,:);
                A = (3*c(1)*t+2*c(2)).*t+c(3);
                B = 6*c(1)*t+2*c(2);
                C = 3*c(1);
                D = z(selected)-a(selected);
                piece = -D.*A.*d + (A-D.*B).*d.^2/2 + (B-D*C).*d.^3/3 + C*d.^4/4;
                integral(selected) = integral(selected)+piece;
            end
            ape = (g*self.densityScale/rho0)*sign(z-materialHeight).*integral;
        end
    end
    methods (Access=private)
        function validateHeight(self,z)
            if any(z(:) < self.z(1) | z(:) > self.z(end))
                error('WVNoMotionProfile:HeightOutsideProfile','Height must lie inside the no-motion profile domain.');
            end
        end
    end
end
