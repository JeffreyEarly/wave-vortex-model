classdef SpatialForcingOperation < WVOperation
    % Computes spatial forcing contributions for a WVTransform.
    %
    % Free-surface Boussinesq outputs are pressure-free hatted increments.
    % Their names are a snapshot of the registry when this operation is
    % created. Same-name replacement uses the current forcing; a removed
    % forcing contributes zero. Recreate the operation to expose new names.

    properties
        Fpv
        forcingNames = strings(0,1)
    end

    methods

        function self = SpatialForcingOperation(wvt)
            arguments
                wvt WVTransform
            end
            outputVariables = WVVariableAnnotation.empty(0,0);
            for i=1:length(wvt.forcing)

                if isa(wvt,"WVTransformFreeSurfaceBoussinesq")
                    suffix=replace(replace(string(wvt.forcing(i).name)," ","_"),"-","_");
                    for j=1:4
                        variables=["u","v","w","eta"];
                        units='m s-2'; if j==4, units='m s-1'; end
                        outputVariables((i-1)*4+j)=WVVariableAnnotation(char("F"+variables(j)+"_"+suffix),wvt.spatialDimensionNames(),units,char("pressure-free hatted "+variables(j)+" source from "+string(wvt.forcing(i).name)));
                    end
                elseif isa(wvt,"WVTransformBarotropicQG") || isa(wvt,"WVTransformStratifiedQG")
                    name = replace(replace(join( ["Fqgpv_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables(i) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'s-2', join(['spatial representation of qgpv forcing',string(wvt.forcing(i).name)]));
                elseif isa(wvt,"WVTransformHydrostatic") || (isa(wvt,"WVTransformConstantStratification") && wvt.isHydrostatic == true)
                    name = replace(replace(join( ["Fu_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*3+1) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-2', join(['spatial representation of hydrostatic forcing on the x-momentum equation',string(wvt.forcing(i).name)]));

                    name = replace(replace(join( ["Fv_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*3+2) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-2', join(['spatial representation of hydrostatic forcing on the y-momentum equation',string(wvt.forcing(i).name)]));

                    name = replace(replace(join( ["Feta_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*3+3) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-1', join(['spatial representation of hydrostatic forcing on the scaled density perturbation equation',string(wvt.forcing(i).name)]));
                elseif isa(wvt,"WVTransformBoussinesq") || (isa(wvt,"WVTransformConstantStratification") && wvt.isHydrostatic == false)
                    name = replace(replace(join( ["Fu_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*4+1) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-2', join(['spatial representation of non-hydrostatic forcing on the x-momentum equation',string(wvt.forcing(i).name)]));

                    name = replace(replace(join( ["Fv_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*4+2) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-2', join(['spatial representation of non-hydrostatic forcing on the y-momentum equation',string(wvt.forcing(i).name)]));

                    name = replace(replace(join( ["Fw_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*4+3) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-2', join(['spatial representation of non-hydrostatic forcing on the z-momentum equation',string(wvt.forcing(i).name)]));

                    name = replace(replace(join( ["Feta_", string(wvt.forcing(i).name)],"")," ","_"),"-","_");
                    outputVariables((i-1)*4+4) = WVVariableAnnotation(name,wvt.spatialDimensionNames(),'m s-1', join(['spatial representation of non-hydrostatic forcing on the scaled density perturbation equation',string(wvt.forcing(i).name)]));
                end
            end
            self@WVOperation('spatial forcing',outputVariables,@disp);
            self.Fpv = zeros(wvt.spatialMatrixSize);
            if isa(wvt,"WVTransformFreeSurfaceBoussinesq")
                self.forcingNames=string({wvt.forcing.name});
                addlistener(wvt,'forcingDidChange',@(~,~)invalidateFields(wvt,outputVariables));
            end
        end

        function varargout = compute(self,wvt,varargin)
            varargout = cell(self.nVarOut,1);

            if isa(wvt,"WVTransformFreeSurfaceBoussinesq")
                for index=1:numel(self.forcingNames)
                    if ismember(self.forcingNames(index),string({wvt.forcing.name}))
                        [varargout{(index-1)*4+(1:4)}]=wvt.spatialFluxForForcingWithName(self.forcingNames(index));
                    else
                        varargout((index-1)*4+(1:4))=repmat({zeros(wvt.spatialMatrixSize)},1,4);
                    end
                end
            elseif isa(wvt,"WVTransformBarotropicQG") || isa(wvt,"WVTransformStratifiedQG")
                self.Fpv = 0*self.Fpv;
                iForce = 0;
                for i=1:length(wvt.spatialFluxForcing)
                    iForce = iForce + 1;
                    Fpv0 = self.Fpv;
                    self.Fpv = wvt.spatialFluxForcing(i).addPotentialVorticitySpatialForcing(wvt,self.Fpv);
                    varargout{iForce} = (self.Fpv-Fpv0);
                end
                F0 = wvt.transformFromSpatialDomainWithFourier(self.Fpv);
                for i=1:length(wvt.spectralFluxForcing)
                    iForce = iForce + 1;
                    F0_i = F0;
                    F0 = wvt.spectralFluxForcing(i).addPotentialVorticitySpectralForcing(wvt,F0);
                    varargout{iForce} = wvt.transformToSpatialDomainWithFourier(F0 - F0_i);
                end
                for i=1:length(wvt.spectralAmplitudeForcing)
                    iForce = iForce + 1;
                    F0_i = F0;
                    F0 = wvt.spectralAmplitudeForcing(i).setPotentialVorticitySpectralForcing(wvt,F0);
                    varargout{iForce} = wvt.transformToSpatialDomainWithFourier(F0 - F0_i);
                end
            elseif isa(wvt,"WVTransformHydrostatic") || (isa(wvt,"WVTransformConstantStratification") && wvt.isHydrostatic == true)
                Fu=0;Fv=0;Feta=0; % this isn't good, need to cached
                iForce = 0;
                for i=1:length(wvt.spatialFluxForcing)
                    Fu0=Fu;Fv0=Fv;Feta0=Feta;
                    [Fu, Fv, Feta] = wvt.spatialFluxForcing(i).addHydrostaticSpatialForcing(wvt, Fu, Fv, Feta);
                    iForce = iForce + 1; varargout{iForce} = Fu-Fu0;
                    iForce = iForce + 1; varargout{iForce} = Fv-Fv0;
                    iForce = iForce + 1; varargout{iForce} = Feta-Feta0;
                end
                [Fp,Fm,F0] = wvt.transformUVEtaToWaveVortex(Fu, Fv, Feta);
                for i=1:length(wvt.spectralFluxForcing)
                    Fp_i = Fp; Fm_i = Fm; F0_i = F0;
                    [Fp,Fm,F0] = wvt.spectralFluxForcing(i).addSpectralForcing(wvt,Fp, Fm, F0);
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.phase.*(Fp-Fp_i) + wvt.UAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.UA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.phase.*(Fp-Fp_i) + wvt.VAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.VA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.NAp.*wvt.phase.*(Fp-Fp_i) + wvt.NAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.NA0.*(F0-F0_i));
                end
                for i=1:length(wvt.spectralAmplitudeForcing)
                    Fp_i = Fp; Fm_i = Fm; F0_i = F0;
                    [Fp,Fm,F0] = wvt.spectralAmplitudeForcing(i).setSpectralForcing(wvt,Fp, Fm, F0);
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.phase.*(Fp-Fp_i) + wvt.UAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.UA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.phase.*(Fp-Fp_i) + wvt.VAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.VA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.NAp.*wvt.phase.*(Fp-Fp_i) + wvt.NAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.NA0.*(F0-F0_i));
                end
            elseif isa(wvt,"WVTransformBoussinesq") || (isa(wvt,"WVTransformConstantStratification") && wvt.isHydrostatic == false)
                Fu=0;Fv=0;Fw=0;Feta=0; % this isn't good, need to cached
                iForce = 0;
                for i=1:length(wvt.spatialFluxForcing)
                    Fu0=Fu;Fv0=Fv;Fw0=Fw;Feta0=Feta;
                    [Fu, Fv, Fw, Feta] = wvt.spatialFluxForcing(i).addNonhydrostaticSpatialForcing(wvt, Fu, Fv, Fw, Feta);
                    iForce = iForce + 1; varargout{iForce} = Fu-Fu0;
                    iForce = iForce + 1; varargout{iForce} = Fv-Fv0;
                    iForce = iForce + 1; varargout{iForce} = Fw-Fw0;
                    iForce = iForce + 1; varargout{iForce} = Feta-Feta0;
                end
                [Fp,Fm,F0] = wvt.transformUVWEtaToWaveVortex(Fu, Fv, Fw, Feta);
                for i=1:length(wvt.spectralFluxForcing)
                    Fp_i = Fp; Fm_i = Fm; F0_i = F0;
                    [Fp,Fm,F0] = wvt.spectralFluxForcing(i).addSpectralForcing(wvt,Fp, Fm, F0);
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.phase.*(Fp-Fp_i) + wvt.UAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.UA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.phase.*(Fp-Fp_i) + wvt.VAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.VA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.WAp.*wvt.phase.*(Fp-Fp_i) + wvt.WAm.*wvt.conjPhase.*(Fm-Fm_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.NAp.*wvt.phase.*(Fp-Fp_i) + wvt.NAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.NA0.*(F0-F0_i));
                end
                for i=1:length(wvt.spectralAmplitudeForcing)
                    Fp_i = Fp; Fm_i = Fm; F0_i = F0;
                    [Fp,Fm,F0] = wvt.spectralAmplitudeForcing(i).setSpectralForcing(wvt,Fp, Fm, F0);
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.UAp.*wvt.phase.*(Fp-Fp_i) + wvt.UAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.UA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithF(Apm=wvt.VAp.*wvt.phase.*(Fp-Fp_i) + wvt.VAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.VA0.*(F0-F0_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.WAp.*wvt.phase.*(Fp-Fp_i) + wvt.WAm.*wvt.conjPhase.*(Fm-Fm_i));
                    iForce = iForce + 1; varargout{iForce} = wvt.transformToSpatialDomainWithG(Apm=wvt.NAp.*wvt.phase.*(Fp-Fp_i) + wvt.NAm.*wvt.conjPhase.*(Fm-Fm_i),A0=wvt.NA0.*(F0-F0_i));
                end
            end
        end

    end

end

function invalidateFields(wvt,annotations)
for annotation=annotations
    wvt.removeFromVariableCache(annotation.name);
end
end
