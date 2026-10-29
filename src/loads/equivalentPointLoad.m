function fe0 = equivalentPointLoad(P, a, Le)
%EQUIVALENTPOINTLOAD Consistent nodal load vector of a point load inside an element.
%   FE0 = EQUIVALENTPOINTLOAD(P, A, LE) returns the 4-by-1 consistent load
%   vector, in element DOF order [v1 theta1 v2 theta2], of a vertical point
%   load P [N] acting at distance A [m] from the element's left node,
%   0 <= A <= LE:
%       FE0 = P * [N1; N2; N3; N4]  evaluated at r = A/LE   [N; N*m; N; N*m]
%   (BEAMSHAPEFUNCTIONS, PROJECT_SPEC.md section 5.2). P is positive UPWARD
%   (DECISIONS.md D-003), so a downward axle load of magnitude Q is P = -Q.
%   The load is NOT moved to the nearest node. FE0 is assembled into the
%   global load vector and subtracted in force recovery (f_e = k_e*q_e - f_e0).
%
%   Example (100 kN downward at 1.2 m in a 2.5 m element):
%     fe0 = equivalentPointLoad(-100e3, 1.2, 2.5);
%
%   See also BEAMSHAPEFUNCTIONS, ELEMENTLOADVECTORS, ADDPOINTLOAD.

assertFiniteRealScalar(P, 'P');
assertPositiveFiniteScalar(Le, 'Le');
assertFiniteRealScalar(a, 'a');
if a < 0 || a > Le
    error('BridgeFE:invalidInput', 'a (%g m) must lie within the element, 0 <= a <= Le = %g m.', a, Le);
end

fe0 = P * beamShapeFunctions(a / Le, Le).';
end
