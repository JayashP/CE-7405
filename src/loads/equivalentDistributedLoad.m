function fe0 = equivalentDistributedLoad(w, Le)
%EQUIVALENTDISTRIBUTEDLOAD Consistent nodal load vector of a uniform element load.
%   FE0 = EQUIVALENTDISTRIBUTEDLOAD(W, LE) returns the 4-by-1 consistent
%   (work-equivalent) load vector, in element DOF order [v1 theta1 v2 theta2],
%   of a uniform load of intensity W [N/m] acting over a whole element of
%   length LE [m]:
%       FE0 = W * [ LE/2;  LE^2/12;  LE/2;  -LE^2/12 ]     [N; N*m; N; N*m]
%   This is the integral of W times the cubic Hermite shape functions
%   N1..N4 over the element. W is positive UPWARD (DECISIONS.md D-003), so a
%   downward load of magnitude q is W = -q.
%
%   FE0 is used twice: assembled into the global load vector, and subtracted
%   from k_e*q_e when recovering element end forces (f_e = k_e*q_e - f_e0).
%
%   Example (20 kN/m downward on a 1.5 m element):
%     fe0 = equivalentDistributedLoad(-20e3, 1.5);
%
%   See also ELEMENTLOADVECTORS, ADDUNIFORMLOAD, RECOVERELEMENTFORCES.

assertFiniteRealScalar(w, 'w');
assertPositiveFiniteScalar(Le, 'Le');

fe0 = w * [Le/2; Le^2/12; Le/2; -Le^2/12];
end
