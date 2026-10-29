function F = assembleLoadVector(model)
%ASSEMBLELOADVECTOR Global equivalent nodal load vector (nodal + element loads).
%   F = ASSEMBLELOADVECTOR(MODEL) returns the 2NN-by-1 vector
%       F = F_nodal + sum_e A_e' * f_e0
%   where F_nodal comes from ASSEMBLENODALLOADVECTOR and f_e0 are the
%   consistent load vectors of the element loads (ELEMENTLOADVECTORS).
%   Forces [N] are positive upward and couples [N*m] counterclockwise.
%
%   See also ASSEMBLENODALLOADVECTOR, ELEMENTLOADVECTORS, SOLVESTATICMODEL.

F = assembleNodalLoadVector(model);
f0 = elementLoadVectors(model);
dofMap = elementDofs(model.elements.conn);
for e = find(any(f0 ~= 0, 2)).'
    F(dofMap(e, :)) = F(dofMap(e, :)) + f0(e, :).';
end
end
