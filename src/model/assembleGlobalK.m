function [K, ke] = assembleGlobalK(model)
%ASSEMBLEGLOBALK Assemble the global bending stiffness matrix by DOF connectivity.
%   K = ASSEMBLEGLOBALK(MODEL) returns the sparse 2NN-by-2NN global
%   stiffness matrix
%       K = sum_e A_e' * k_e * A_e,
%   where A_e maps the global DOFs to the element DOFs
%   [v_i theta_i v_j theta_j] (ELEMENTDOFS) and k_e = BEAMELEMENTSTIFFNESS(EI_e, L_e).
%   Global DOF order is [v1 theta1 v2 theta2 ... ]. Supports are NOT
%   applied here, so K is singular with two rigid-body modes.
%
%   [K, KE] = ASSEMBLEGLOBALK(MODEL) also returns the element matrices as a
%   4-by-4-by-NE array for inspection.
%
%   See also BEAMELEMENTSTIFFNESS, ELEMENTDOFS, PARTITIONDOFS.

validateModel(model);
x = model.nodes.x;
conn = model.elements.conn;
EI = effectiveEI(model);          % (1 - d) * material EI (Stage 2 damage)
ne = size(conn, 1);
nDof = 2 * numel(x);
dofMap = elementDofs(conn);

% Triplet (row, col, value) assembly; sparse() sums the overlapping entries.
ke = zeros(4, 4, ne);
rows = zeros(16 * ne, 1);
cols = zeros(16 * ne, 1);
vals = zeros(16 * ne, 1);
for e = 1:ne
    Le = x(conn(e, 2)) - x(conn(e, 1));
    ke(:, :, e) = beamElementStiffness(EI(e), Le);
    d = dofMap(e, :);
    r = repmat(d(:), 1, 4);     % r(a,b) = d(a)
    c = repmat(d, 4, 1);        % c(a,b) = d(b)
    idx = 16 * (e - 1) + (1:16);
    rows(idx) = r(:);
    cols(idx) = c(:);
    vals(idx) = reshape(ke(:, :, e), [], 1);
end
K = sparse(rows, cols, vals, nDof, nDof);
end
