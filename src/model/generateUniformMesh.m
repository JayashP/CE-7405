function x = generateUniformMesh(L, ne)
%GENERATEUNIFORMMESH Node coordinates of a uniform mesh on [0, L].
%   X = GENERATEUNIFORMMESH(L, NE) returns the (NE+1)-by-1 vector of node
%   coordinates [m] that divides a beam of total length L [m] into NE equal
%   elements of length L/NE. X(1) = 0 and X(end) = L exactly; when NE is
%   even, X(NE/2+1) = L/2 exactly.
%
%   Example (spec section 4.1: 30 m, 20 elements, Le = 1.5 m, 21 nodes):
%     x = generateUniformMesh(30, 20);
%
%   See also CREATEBEAMMODEL.

assertPositiveFiniteScalar(L, 'L');
assertIntegerScalarInRange(ne, 'ne', 1, Inf);

x = L * ((0:ne)' / ne);
end
