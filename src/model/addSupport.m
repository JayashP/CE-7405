function model = addSupport(model, node, type)
%ADDSUPPORT Add an idealized support at a node of a bending-beam model.
%   MODEL = ADDSUPPORT(MODEL, NODE, TYPE) restrains the DOFs of node NODE
%   according to TYPE (case-insensitive, see SUPPORTRESTRAINT):
%     'pin'     v restrained, theta free
%     'roller'  v restrained, theta free (same as 'pin' in this model)
%     'fixed'   v and theta restrained
%   Restrained DOFs have zero prescribed displacement. A node may carry at
%   most one support; a second support at the same node throws
%   'BridgeFE:duplicateSupport'. Use FINDNODEATX to get NODE from a
%   coordinate so supports never snap silently to a nearby node.
%
%   Example:
%     model = addSupport(model, findNodeAtX(model, 0), 'fixed');
%
%   See also SUPPORTRESTRAINT, FINDNODEATX, PARTITIONDOFS.

validateModel(model);
nn = numel(model.nodes.x);
assertIntegerScalarInRange(node, 'node', 1, nn);
restraint = supportRestraint(type);

if any(model.supports.node == node)
    error('BridgeFE:duplicateSupport', ...
        'Node %d already has a support; a node may carry at most one support.', node);
end

model.supports.node(end+1, 1) = node;
model.supports.type{end+1, 1} = lower(char(type));
model.supports.restraint(end+1, :) = restraint;
end
