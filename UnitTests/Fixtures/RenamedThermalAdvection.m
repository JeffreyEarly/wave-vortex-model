classdef RenamedThermalAdvection < WVNonlinearAdvection
    % Verify nonlinear selection follows the implementation, not its label.
    methods
        function self=RenamedThermalAdvection(w)
            self@WVNonlinearAdvection(w);
            self.name='renamed nonlinear transport';
        end
    end
end
