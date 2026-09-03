function annotations = classDefinedPropertyAnnotations()
% Declare actual modal arrays and selectable physical diagnostics.
% - Topic: Create and restore a transform
annotations=cat(2,WVGeometryDoublyPeriodic.propertyAnnotationsForGeometry(),WVTransform.propertyAnnotationsForTransform());
for name=["totalEnergy" "totalEnergySpatiallyIntegrated"]
    i=find(string({annotations.name})==name,1);
    annotations(i)=WVVariableAnnotation(char(name),{},'m3 s-2','horizontally averaged depth-integrated reconstructed physical energy per unit density');
end
annotations(end+1)=CADimensionProperty('z','m','physical vertical coordinate, bottom to surface');
annotations(end+1)=CADimensionProperty('thermalMode','1','complete ordinal diffusion-mode coordinate');
annotations(end+1)=CADimensionProperty('thermalState','1','scaled independent data: interior QGPV, then surface displacement');
annotations(end+1)=CADimensionProperty('klNonzero','1','original one-based full-kl indices at positive wavenumber');
annotations(end+1)=CADimensionProperty('khUnique','rad m-1','distinct positive horizontal-wavenumber pages');
annotations(end+1)=CADimensionProperty('activeEndpoint','1','surface endpoint code, one');
annotations(end+1)=WVTransformFreeSurfaceQGDiffusion.thermalCoefficientAnnotation();
annotations(end+1)=CANumericProperty('N2',{'z'},'s-2','squared buoyancy frequency');
annotations(end+1)=CANumericProperty('verticalQuadratureWeights',{'z'},'m','positive physical quadrature weights');
annotations(end+1)=CANumericProperty('verticalDerivativeMatrix',{'z','z'},'m-1','physical spectral first derivative');
annotations(end+1)=CAObjectProperty('verticalNumerics','persisted vertical product quadrature and QGPV polynomial transforms');
annotations(end+1)=CANumericProperty('shouldDealiasVertical',{},'1','whether nonlinear QGPV advection uses vertical over-integration');
annotations(end+1)=CANumericProperty('thermalDecayRate',{'thermalMode','khUnique'},'s-1','signed decay rates, with null directions kept',isComplex=true);
annotations(end+1)=CANumericProperty('scaledStateFromModes',{'thermalState','thermalMode','khUnique'},'1','unit Euclidean right modes in scaled independent-data coordinates',isComplex=true);
annotations(end+1)=CANumericProperty('modesFromScaledState',{'thermalMode','thermalState','khUnique'},'1','left projection inverse to scaledStateFromModes',isComplex=true);
annotations(end+1)=CANumericProperty('phiModes',{'z','thermalMode','khUnique'},'m s-1','streamfunction per meter of thermal amplitude',isComplex=true);
annotations(end+1)=CANumericProperty('etaModes',{'z','thermalMode','khUnique'},'1','displacement per meter of thermal amplitude',isComplex=true);
annotations(end+1)=CANumericProperty('qModes',{'z','thermalMode','khUnique'},'m-1 s-1','full-grid reconstructed QGPV per meter of amplitude',isComplex=true);
annotations(end+1)=CANumericProperty('klNonzeroKhUniqueIndex',{'klNonzero'},'1','one-based wavenumber page map');
for name=["kNonzero" "lNonzero" "khNonzero"]
    annotations(end+1)=CANumericProperty(char(name),{'klNonzero'},'rad m-1','horizontal wavenumber coordinate');
end
for name=["eigenResidual" "eigenvectorCondition"]
    annotations(end+1)=CANumericProperty(char(name),{'khUnique'},'1',char(name));
end
names={'Lz','kappaT','latitude','rotationRate','planetaryRadius','g','f','beta','inertialPeriod'};
units={'m','m2 s-1','degrees_north','rad s-1','m','m s-2','s-1','m-1 s-1','s'};
descriptions={'depth','fixed homogeneous buoyancy diffusivity','latitude','planetary rotation rate','planetary radius','gravity','Coriolis frequency','meridional Coriolis gradient','inertial period'};
for i=1:length(names), annotations(end+1)=CANumericProperty(names{i},{},units{i},descriptions{i}); end
names={'psi','u','v','eta','qgpv','buoyancy','surfaceAnomaly','ssh','uvMax','potentialEnstrophy'};
units={'m2 s-1','m s-1','m s-1','m','s-1','m s-2','m','m','m s-1','m s-2'};
descriptions={'geostrophic streamfunction','zonal velocity','meridional velocity','isopycnal displacement','full-grid reconstructed QGPV','physical buoyancy anomaly','surface endpoint displacement anomaly','sea-surface height','maximum horizontal speed','horizontally averaged depth-integrated ordinary potential enstrophy'};
for i=1:length(names)
    if i<=6, dims={'x','y','z'}; elseif i<=8, dims={'x','y'}; else, dims={}; end
    annotations(end+1)=WVVariableAnnotation(names{i},dims,units{i},descriptions{i});
end
end
