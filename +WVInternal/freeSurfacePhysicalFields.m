function physical = freeSurfacePhysicalFields(hatted,xi,Lz,sshX,sshY)
% Map projection variables to physical and material-coordinate fields.
%
% The input velocities are the manuscript's hatted variables on the fixed
% reference column. With s=1+xi/Lz and gamma=1+ssh/Lz, physical depth is
% xi+s*ssh, horizontal velocity is (u_hat,v_hat)/gamma, and physical w is
% w_hat+s*(u_hat*ssh_x+v_hat*ssh_y)/gamma. The material reference-coordinate
% velocity is (w_hat-s*w_hat(surface))/gamma when ssh_t=w_hat(surface).
% Eta is total material displacement; eta_i=eta-s*ssh. These definitions
% follow eq:projection-ready-geometric-identities of the free-surface notes.
%
% This map does not compute pressure, an equation tendency, or a density
% anomaly, and it does not assert that a projected tendency obeys the
% surface kinematic constraint. Geometry is always that of the total state.
%
% - Topic: Developer utilities
% - Declaration: physical = freeSurfacePhysicalFields(hatted,xi,Lz,sshX,sshY)
% - Parameter hatted: real grid fields u,v,w,eta and two-dimensional ssh
% - Parameter xi: increasing bottom-to-surface reference coordinate
% - Parameter Lz: positive reference depth
% - Parameter sshX: reference horizontal derivative of surface height
% - Parameter sshY: reference horizontal derivative of surface height
% - Returns physical: u,v,w,eta,eta_i,ssh,z,gamma and material xi velocity w_i
% - Developer: true
arguments (Input)
    hatted (1,1) struct
    xi (:,1) double
    Lz (1,1) double {mustBePositive}
    sshX (:,:) double
    sshY (:,:) double
end
arguments (Output)
    physical (1,1) struct
end
gamma=1+hatted.ssh/Lz;
if any(~isfinite(gamma) | gamma<=0,'all')
    error('WV:InvalidFreeSurfaceGeometry','Surface height must be finite and greater than minus the reference depth everywhere.')
end
s=reshape(1+xi/Lz,1,1,[]);
physical=struct();
physical.u=hatted.u./gamma;
physical.v=hatted.v./gamma;
physical.w=hatted.w+s.*(physical.u.*sshX+physical.v.*sshY);
physical.w_i=(hatted.w-s.*hatted.w(:,:,end))./gamma;
physical.z=reshape(xi,1,1,[])+s.*hatted.ssh;
physical.gamma=gamma;
physical.eta=hatted.eta;
physical.eta_i=hatted.eta-s.*hatted.ssh;
physical.ssh=hatted.ssh;
end
