function elements = elementsBetween(model, x1, x2)
%ELEMENTSBETWEEN Indices of the elements lying between two node coordinates.
%   ELEMENTS = ELEMENTSBETWEEN(MODEL, X1, X2) returns the column vector of
%   element indices covering [X1, X2] [m], where X1 < X2 and both are node
%   coordinates (FINDNODEATX; an off-node coordinate throws
%   'BridgeFE:notOnNode'). Use it to load or modify one span at a time.
%
%   Example (elements of the second span of two 10 m spans):
%     e2 = elementsBetween(model, 10, 20);
%
%   See also FINDNODEATX, MESHSPANS, ADDUNIFORMLOAD.

n1 = findNodeAtX(model, x1);
n2 = findNodeAtX(model, x2);
if n2 <= n1
    error('BridgeFE:invalidInput', 'x2 (%g m) must be greater than x1 (%g m).', x2, x1);
end
elements = (n1:n2-1)';
end
