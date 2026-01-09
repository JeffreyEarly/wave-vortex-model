classdef NoMotionProfileOperation < WVOperation
    properties (GetAccess=public, SetAccess=protected)
        spline
        toleranceZ
    end

    methods

        function self = NoMotionProfileOperation(options)
            arguments
                options.toleranceZ = 1e-2 % centimeter accuracy
            end
            outputVariables(1) = WVVariableAnnotation('rho_nm',{'z'},'kg m^{-3}', 'no-motion density profile');
            % outputVariables(1).isVariableWithLinearTimeStep = false;
            self@WVOperation('rho_nm',outputVariables,@disp);

            self.toleranceZ = options.toleranceZ;
        end

        function varargout = compute(self,wvt,varargin)
            % Using K=3, we get really good convergence, really fast, with no
            % appreciable change for K=4. K=2 does not appear to have great behavior at
            % the boundaries.
            %
            % rms z deviation 16.297 m.
            % rms density deviation 0.012472 kg m^{-3}.
            % rms z deviation 0.35489 m.
            % rms density deviation 0.00011936 kg m^{-3}.
            % rms z deviation 0.00066169 m.
            % rms density deviation 6.1183e-08 kg m^{-3}.
            % rms z deviation 2.003e-08 m.
            % rms density deviation 1.6825e-11 kg m^{-3}.
            if isempty(self.spline)
                % We create an initial 'guess' for the no-motion state based on
                % the profile the simulation was initialized with, before
                % initial conditions were added and forcing applied.
                K = 3;
                self.spline = BSpline(K,BSpline.knotPointsForDataPoints(wvt.z,K=K));
                self.spline.x_mean = mean(wvt.rho_nm0);
                self.spline.x_std = std(wvt.rho_nm0);
                Z = BSpline.matrix( wvt.z, self.spline.tKnot, self.spline.K );
                self.spline.xi = Z\((wvt.rho_nm0 - self.spline.x_mean)/self.spline.x_std);
            end

            rho = sort(wvt.rho_total(:),'descend');
            z_i = wvt.Z(:);
            DeltaZ_i = (rho - self.spline(z_i))./self.spline(z_i,1);

            disp("rms z deviation " + std(DeltaZ_i) + " m.")
            disp("rms density deviation " + std(rho - self.spline(z_i)) + " kg m^{-3}.")

            MaxIteration = 10;
            iteration = 0;
            while std(DeltaZ_i) > self.toleranceZ & iteration < MaxIteration
                z_i = z_i + DeltaZ_i;
                z_i(z_i<wvt.z(1)) = wvt.z(1);
                z_i(z_i>wvt.z(end)) = wvt.z(end);

                % the spline regression requires this sort order
                [z_i,I] = sort(z_i);
                rho = rho(I);

                rho_bar = (rho - self.spline.x_mean)/self.spline.x_std;
                Z = BSpline.matrix( z_i, self.spline.tKnot, self.spline.K );
                self.spline.xi = Z\rho_bar;

                DeltaZ_i = (rho - self.spline(z_i))./self.spline(z_i,1);

                disp("rms z deviation " + std(DeltaZ_i) + " m.")
                disp("rms density deviation " + std(rho - self.spline(z_i)) + " kg m^{-3}.")
                iteration = iteration + 1;
            end
            varargout = {self.spline};
        end
  
    end

end