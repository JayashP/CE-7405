function node = findNodeAtX(model, xq, tol)
%FINDNODEATX Index of the node located at coordinate XQ.
%   NODE = FINDNODEATX(MODEL, XQ) returns the node whose coordinate equals
%   XQ [m] within 1e-9 times the beam length. If no node lies there the
%   error 'BridgeFE:notOnNode' is thrown, so supports and nodal loads can
%   never be moved silently to a nearby node (refine or align the mesh
%   instead).
%   NODE = FINDNODEATX(MODEL, XQ, TOL) uses the absolute tolerance TOL [m].
%
%   See also GENERATEUNIFORMMESH, ADDSUPPORT, ADDNODALLOAD.

validateModel(model);
x = model.nodes.x;
assertFiniteRealScalar(xq, 'xq');
if nargin < 3
    tol = 1e-9 * (x(end) - x(1));
end
assertPositiveFiniteScalar(tol, 'tol');

[gap, node] = min(abs(x - xq));
if gap > tol
    error('BridgeFE:notOnNode', ...
        'No node at x = %.12g m (nearest node %d at x = %.12g m). Align the mesh with this coordinate.', ...
        xq, node, x(node));
end
end
