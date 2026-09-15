classdef OverriddenWaveModeBasis < IMInternalModesBasis
    methods
        function self = OverriddenWaveModeBasis(source)
            arguments
                source (1,1) IMInternalModesBasis
            end
            self@IMInternalModesBasis(solver=source.solver,evp=source.evp,nativeModes=source.nativeModes, ...
                eigenvalues=source.eigenvalues,modeNumber=source.modeNumber, ...
                modeSelectionDiagnostics=source.modeSelectionDiagnostics,normalization=source.normalization,metadata=source.metadata);
        end

        function values = F(self,z,varargin)
            values = 1.25*F@IMInternalModesBasis(self,z,varargin{:});
        end

        function values = G(self,z,varargin)
            values = 0.75*G@IMInternalModesBasis(self,z,varargin{:});
        end
    end
end
