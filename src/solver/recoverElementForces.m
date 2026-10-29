function ef = recoverElementForces(model, U)
%RECOVERELEMENTFORCES Element end actions and end shear / bending moment.
%   EF = RECOVERELEMENTFORCES(MODEL, U) computes, for every element e,
%       f_e = k_e * q_e - f_e0,      q_e = U(ELEMENTDOFS(e)),
%   from the full global displacement vector U. f_e0 is the consistent
%   (equivalent nodal) load vector of the loads acting inside element e
%   (ELEMENTLOADVECTORS); it is zero for an element without member loads.
%   Member loads: uniform load per element (model.loads.elementUDL) and
%   point loads strictly inside elements (model.loads.point).
%
%   EF fields (SI units):
%     endActions  NE-by-4 [F_i M_i F_j M_j], the forces [N] and couples [N*m]
%                 exerted ON the element BY its end nodes, global DOF signs
%                 (force + up, couple + counterclockwise)
%     shear       NE-by-2 internal shear [V(x_i+) V(x_j-)] [N]
%     moment      NE-by-2 internal bending moment [M(x_i+) M(x_j-)] [N*m]
%     x           NE-by-2 coordinates of the element ends [x_i x_j] [m]
%   Internal force convention (DECISIONS.md D-003): M positive sagging;
%   V(x) = sum of upward forces to the left of the section, so dM/dx = V:
%       V_i = F_i,   M_i = -M_i(end action),   V_j = -F_j,   M_j = M_j(end action).
%   Between the ends, V is linear under a uniform load and jumps at interior
%   point loads, and M is parabolic / piecewise; use SAMPLEINTERNALFORCES.
%   V_j and M_j are the limits just left of node j (x_j-), so they include
%   every load inside the element but not a load applied at node j itself.
%
%   See also SOLVESTATICMODEL, ELEMENTLOADVECTORS, SAMPLEINTERNALFORCES.

validateModel(model);
x = model.nodes.x;
conn = model.elements.conn;
EI = model.elements.EI;
ne = size(conn, 1);
if ~(isnumeric(U) && isvector(U) && numel(U) == 2 * numel(x))
    error('BridgeFE:invalidInput', 'U must be a vector with %d entries.', 2 * numel(x));
end
U = U(:);
dofMap = elementDofs(conn);
f0 = elementLoadVectors(model);

endActions = zeros(ne, 4);
for e = 1:ne
    Le = x(conn(e, 2)) - x(conn(e, 1));
    endActions(e, :) = (beamElementStiffness(EI(e), Le) * U(dofMap(e, :))).' - f0(e, :);
end

ef.endActions = endActions;
ef.shear = [endActions(:, 1), -endActions(:, 3)];
ef.moment = [-endActions(:, 2), endActions(:, 4)];
ef.x = [x(conn(:, 1)), x(conn(:, 2))];
end
