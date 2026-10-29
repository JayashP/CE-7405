function F = assembleLoadVector(model)
%ASSEMBLELOADVECTOR Global equivalent nodal load vector (nodal + element loads).
%   F = ASSEMBLELOADVECTOR(MODEL) returns the 2NN-by-1 vector
%       F = F_nodal + F_pointAtNodes + sum_e A_e' * f_e0
%   where F_nodal comes from ASSEMBLENODALLOADVECTOR, F_pointAtNodes holds
%   the point loads (model.loads.point) that sit on a node, and f_e0 are the
%   consistent load vectors of the loads inside elements (uniform loads and
%   interior point loads, ELEMENTLOADVECTORS).
%   Forces [N] are positive upward and couples [N*m] counterclockwise.
%
%   See also ASSEMBLENODALLOADVECTOR, ELEMENTLOADVECTORS, LOCATEPOINTLOADS,
%   SOLVESTATICMODEL.

F = assembleNodalLoadVector(model);
f0 = elementLoadVectors(model);
dofMap = elementDofs(model.elements.conn);
for e = find(any(f0 ~= 0, 2)).'
    F(dofMap(e, :)) = F(dofMap(e, :)) + f0(e, :).';
end
loc = locatePointLoads(model);
for k = find(loc.node > 0).'
    n = loc.node(k);
    F(2*n - 1) = F(2*n - 1) + loc.P(k);
end
end
