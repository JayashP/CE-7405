function results = solveStaticModel(model)
%SOLVESTATICMODEL Linear static solution of a bending-beam model.
%   RESULTS = SOLVESTATICMODEL(MODEL) assembles K and the equivalent nodal
%   load vector F (nodal loads plus consistent element loads), partitions the DOFs
%   (zero prescribed displacement at restrained DOFs), solves
%       Kff * Uf = Ff
%   with MATLAB backslash (never inv), and recovers reactions and element
%   end forces. Units are SI (DECISIONS.md D-002); signs follow D-003.
%   An under-restrained model throws 'BridgeFE:underRestrained' (see
%   PARTITIONDOFS); an ill-conditioned Kff (rcond < 1e-12) issues the
%   warning 'BridgeFE:illConditioned'.
%
%   RESULTS fields:
%     U               2NN-by-1 displacements [v1 theta1 v2 theta2 ...] [m, rad]
%     v, theta        NN-by-1 nodal v [m] (+ up) and theta [rad] (+ CCW)
%     F               2NN-by-1 equivalent nodal loads [N, N*m] (nodal +
%                     consistent element loads; see ASSEMBLELOADVECTOR)
%     elementLoads    NE-by-4 consistent load vectors f_e0 of the element loads
%     pointLoads      where each point load was applied (LOCATEPOINTLOADS)
%     K               sparse unrestrained global stiffness matrix
%     ke              4-by-4-by-NE element stiffness matrices
%     freeDofs        free DOF indices
%     restrainedDofs  restrained DOF indices
%     R               2NN-by-1 reactions (0 at free DOFs) [N, N*m]
%     reactions       struct with per-support columns node, Fv [N] (+ up), Mz [N*m] (+ CCW)
%     elementForces   output of RECOVERELEMENTFORCES
%     diagnostics     rcondKff, maxResidual (max |Kff*Uf - Ff|), and
%                     sumVerticalForce [N] and sumMomentAboutOrigin [N*m]
%                     (loads + reactions; both should vanish; the consistent
%                     vector of a uniform load has the same resultant force
%                     and moment as the load itself)
%     units           model.units
%
%   Example:
%     model = createBeamModel(generateUniformMesh(20, 20), 2e9);
%     model = addSupport(model, 1, 'pin');
%     model = addSupport(model, 21, 'roller');
%     model = addNodalLoad(model, 11, -100e3);
%     res = solveStaticModel(model);
%     res.v(11)          % midspan deflection [m], negative = downward
%
%   See also ASSEMBLEGLOBALK, ASSEMBLELOADVECTOR, PARTITIONDOFS,
%   RECOVERREACTIONS, RECOVERELEMENTFORCES.

validateModel(model);
[K, ke] = assembleGlobalK(model);
F = assembleLoadVector(model);
[freeDofs, restrainedDofs] = partitionDofs(model);

nDof = numel(F);
U = zeros(nDof, 1);
rcondKff = Inf;
maxResidual = 0;
if ~isempty(freeDofs)
    Kff = K(freeDofs, freeDofs);
    Ff = F(freeDofs);
    rcondKff = rcond(full(Kff));
    if rcondKff < 1e-12
        warning('BridgeFE:illConditioned', ...
            'Reduced stiffness matrix is ill-conditioned (rcond = %.3e); results may be inaccurate.', ...
            rcondKff);
    end
    U(freeDofs) = Kff \ Ff;
    maxResidual = full(max(abs(Kff * U(freeDofs) - Ff)));
end
R = recoverReactions(K, U, F, restrainedDofs);

% Whole-structure equilibrium of applied loads plus reactions.
x = model.nodes.x;
totalFv = F(1:2:end) + R(1:2:end);
totalMz = F(2:2:end) + R(2:2:end);
diagnostics.rcondKff = rcondKff;
diagnostics.maxResidual = maxResidual;
diagnostics.sumVerticalForce = sum(totalFv);
diagnostics.sumMomentAboutOrigin = sum(totalFv .* x) + sum(totalMz);   % CCW positive about x = 0

sn = model.supports.node;
results.U = U;
results.v = U(1:2:end);
results.theta = U(2:2:end);
results.F = F;
results.elementLoads = elementLoadVectors(model);
results.pointLoads = locatePointLoads(model);
results.K = K;
results.ke = ke;
results.freeDofs = freeDofs;
results.restrainedDofs = restrainedDofs;
results.R = R;
results.reactions = struct('node', sn, 'Fv', R(2*sn - 1), 'Mz', R(2*sn));
results.elementForces = recoverElementForces(model, U);
results.diagnostics = diagnostics;
results.units = model.units;
end
