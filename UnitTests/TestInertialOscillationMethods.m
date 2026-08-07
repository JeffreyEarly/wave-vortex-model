classdef TestInertialOscillationMethods < matlab.unittest.TestCase
    properties
        wvt
        solutionGroup
    end

    properties (ClassSetupParameter)
        Lxyz = struct('Lxyz',[15e3, 15e3, 1300]);
        Nxyz = struct('Nx8Ny8Nz5',[8 8 30]);
        transform = {'hydrostatic'};
    end

    methods (TestClassSetup)
        function classSetup(testCase,Lxyz,Nxyz,transform)
            switch transform
                case 'constant'
                    testCase.wvt = WVTransformConstantStratification(Lxyz, Nxyz);
                case 'hydrostatic'
                    testCase.wvt = WVTransformHydrostatic(Lxyz, Nxyz, N2=@(z) (5.2e-3)*(5.2e-3)*ones(size(z)),shouldAntialias=0);
                case 'boussinesq'
                    testCase.wvt = WVTransformBoussinesq(Lxyz, Nxyz, N2=@(z) (5.2e-3)*(5.2e-3)*ones(size(z)),shouldAntialias=0);
            end
            % testCase.wvt.addOperation(testCase.wvt.operationForDynamicalVariable('u','v','eta','w',flowComponent=testCase.wvt.flowComponent('inertial')));
            testCase.solutionGroup = WVInertialOscillationComponent(testCase.wvt);
        end
    end

    methods (TestMethodSetup)
        function resetTransform(self)
            self.wvt.removeAll();
            self.wvt.t = 0;
        end
    end

    methods (Test, TestTags = "full")
        function testRemoveAllInertialMotions(self)
            seedRandomNumberGenerator(self,21517);
            % In this test we intialize with a random flow state, confirm
            % that both total energy and inertial energy are present,
            % remove all the inertial energy, and then confirm that there
            % is no inertial energy remaining, and that the total energy is
            % the same as the initial total, minus the initial inertial.
            self.wvt.initWithRandomFlow(uvMax=0.02);

            initialTotalEnergy = self.wvt.totalEnergy;
            initialInertialEnergy = self.wvt.inertialEnergy;
            self.verifyGreaterThan(initialTotalEnergy,0.0);
            self.verifyGreaterThan(initialInertialEnergy,0.0);

            self.wvt.removeAllInertialMotions();
            finalTotalEnergy = self.wvt.totalEnergy;
            finalInertialEnergy = self.wvt.inertialEnergy;

            self.verifyEqual(finalInertialEnergy,0.0);
            self.verifyEqual(finalTotalEnergy,initialTotalEnergy-initialInertialEnergy, "AbsTol",1e-7,"RelTol",1e-7);
        end

        function testInitWithInertialMotions(self)
            seedRandomNumberGenerator(self,37547);
            % In this test we expect all existing motions to be removed
            % when we initialize.
            %
            % VERY IMPORTANT: We do *not* get back exactly what we put in
            % because we are de-aliasing the signal. Hence, this experiment
            % was designed assuming Nz=30 (and thus Nj=20).
            U_io = 0.2;
            Ld = self.wvt.Lz/2;
            theta = pi/3;
            u_NIO = @(z) U_io*cos(theta)*exp((z/Ld));
            v_NIO = @(z) U_io*sin(theta)*exp((z/Ld));

            % Populate the flow field with junk...
            self.wvt.initWithRandomFlow(uvMax=0.02);

            % call our initWithInertialMotions method
            self.wvt.initWithInertialMotions(u_NIO,v_NIO);

            % now verify that only inertial oscillations are part of the
            % solution.
            self.verifyThat(u_NIO(self.wvt.Z),IsSameSolutionAs(self.wvt.u,relTol=1e-3),'u_tot');
            self.verifyThat(v_NIO(self.wvt.Z),IsSameSolutionAs(self.wvt.v,relTol=1e-3),'v_tot');
        end

        function testSetInertialMotions(self)
            seedRandomNumberGenerator(self,58451);
            U_io = 0.2;
            Ld = self.wvt.Lz/2;
            theta = 0;
            u_NIO = @(z) U_io*cos(theta)*exp((z/Ld));
            v_NIO = @(z) U_io*sin(theta)*exp((z/Ld));

            % Populate the flow field with junk...
            self.wvt.initWithRandomFlow(uvMax=0.02);

            initialTotalEnergy = self.wvt.totalEnergy;
            initialInertialEnergy = self.wvt.inertialEnergy;

            % Now overwrite *only* the inertial stuff, other stuff should
            % remain.
            self.wvt.setInertialMotions(u_NIO,v_NIO);

            finalTotalEnergy = self.wvt.totalEnergy;
            finalInertialEnergy = self.wvt.inertialEnergy;

            % Now confirm that the inertial solution matches AND that the
            % original non-inertial energy stayed the same.
            self.verifyThat(u_NIO(self.wvt.Z),IsSameSolutionAs(self.wvt.u_io,relTol=1e-3),'u_io');
            self.verifyThat(v_NIO(self.wvt.Z),IsSameSolutionAs(self.wvt.v_io,relTol=1e-3),'v_io');
            self.verifyEqual(finalTotalEnergy-finalInertialEnergy,initialTotalEnergy-initialInertialEnergy, "AbsTol",1e-7,"RelTol",1e-7);
        end

    end

end
