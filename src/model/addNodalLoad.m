function model = addNodalLoad(model, node, Fv, Mz)
%ADDNODALLOAD Add a concentrated vertical force and/or couple at a node.
%   MODEL = ADDNODALLOAD(MODEL, NODE, FV, MZ) adds a vertical force FV [N]
%   and a couple MZ [N*m] at node NODE, using the global DOF signs
%   (DECISIONS.md D-003):
%     FV  positive UPWARD; a downward gravity or axle load is NEGATIVE.
%     MZ  positive counterclockwise. Optional, default 0.
%   Several loads at the same node are superposed. A load at a restrained
%   DOF is carried directly by the support reaction.
%
%   Example (100 kN downward at the node at x = 10 m):
%     model = addNodalLoad(model, findNodeAtX(model, 10), -100e3);
%
%   See also ASSEMBLENODALLOADVECTOR, FINDNODEATX.

if nargin < 4
    Mz = 0;
end
validateModel(model);
nn = numel(model.nodes.x);
assertIntegerScalarInRange(node, 'node', 1, nn);
assertFiniteRealScalar(Fv, 'Fv');
assertFiniteRealScalar(Mz, 'Mz');

model.loads.nodal(end+1, :) = [node, double(Fv), double(Mz)];
end
