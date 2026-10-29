function F = assembleNodalLoadVector(model)
%ASSEMBLENODALLOADVECTOR Global load vector from concentrated nodal loads.
%   F = ASSEMBLENODALLOADVECTOR(MODEL) returns the 2NN-by-1 vector
%   [F1 M1 F2 M2 ...] built from model.loads.nodal, with forces [N]
%   positive upward and couples [N*m] positive counterclockwise. Loads at
%   the same node are summed. Loads applied inside elements are not part
%   of this milestone.
%
%   See also ADDNODALLOAD, SOLVESTATICMODEL.

validateModel(model);
F = zeros(2 * numel(model.nodes.x), 1);
loads = model.loads.nodal;
for k = 1:size(loads, 1)
    n = loads(k, 1);
    F(2*n - 1) = F(2*n - 1) + loads(k, 2);
    F(2*n)     = F(2*n)     + loads(k, 3);
end
end
