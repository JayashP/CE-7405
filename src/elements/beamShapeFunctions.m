function N = beamShapeFunctions(r, Le)
%BEAMSHAPEFUNCTIONS Cubic Hermite shape functions of a 2-node Euler-Bernoulli beam element.
%   N = BEAMSHAPEFUNCTIONS(R, LE) returns a numel(R)-by-4 matrix whose row k
%   is [N1 N2 N3 N4] evaluated at the normalized position R(k) = s/LE in
%   [0, 1], where s [m] is measured from the element's left node and LE [m]
%   is the element length (PROJECT_SPEC.md section 5.2):
%       N1 = 1 - 3r^2 + 2r^3          (multiplies v1     [m])
%       N2 = LE*(r - 2r^2 + r^3)      (multiplies theta1 [rad]; units m)
%       N3 = 3r^2 - 2r^3              (multiplies v2     [m])
%       N4 = LE*(-r^2 + r^3)          (multiplies theta2 [rad]; units m)
%   so v(s) = N*[v1; theta1; v2; theta2] for an element without member loads.
%   The same functions give the consistent load vector of a point load
%   (EQUIVALENTPOINTLOAD).
%
%   Example:
%     N = beamShapeFunctions([0; 0.5; 1], 2.5);
%
%   See also EQUIVALENTPOINTLOAD, EVALUATEDEFLECTION.

assertPositiveFiniteScalar(Le, 'Le');
if ~(isnumeric(r) && isreal(r) && isvector(r) && all(isfinite(r)) && all(r >= 0) && all(r <= 1))
    error('BridgeFE:invalidInput', 'r must be a real vector of normalized positions in [0, 1].');
end
r = double(r(:));

N = [1 - 3*r.^2 + 2*r.^3, ...
     Le * (r - 2*r.^2 + r.^3), ...
     3*r.^2 - 2*r.^3, ...
     Le * (-r.^2 + r.^3)];
end
