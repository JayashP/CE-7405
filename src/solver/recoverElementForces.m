function ef = recoverElementForces(model, U)
%RECOVERELEMENTFORCES Element end actions and end shear / bending moment.
%   EF = RECOVERELEMENTFORCES(MODEL, U) computes, for every element e,
%       f_e = k_e * q_e,      q_e = U(ELEMENTDOFS(e)),
%   from the full global displacement vector U.
%
%   LIMITATION (milestone M1): the model has nodal loads only, so no load
%   acts inside an element and the formula above is complete. Once in-element
%   loads exist (DEVELOPMENT_PLAN.md M2/M3) this must become
%   f_e = k_e*q_e - f_e0 (f_e0 = consistent load vector of the member loads),
%   and diagrams must include the in-element loads between the ends.
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
%   Without member loads, V is constant and M is linear along an element.
%
%   See also SOLVESTATICMODEL, BEAMELEMENTSTIFFNESS.

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

endActions = zeros(ne, 4);
for e = 1:ne
    Le = x(conn(e, 2)) - x(conn(e, 1));
    endActions(e, :) = (beamElementStiffness(EI(e), Le) * U(dofMap(e, :))).';
end

ef.endActions = endActions;
ef.shear = [endActions(:, 1), -endActions(:, 3)];
ef.moment = [-endActions(:, 2), endActions(:, 4)];
ef.x = [x(conn(:, 1)), x(conn(:, 2))];
end
