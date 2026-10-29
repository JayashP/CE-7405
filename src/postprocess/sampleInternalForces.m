function s = sampleInternalForces(model, U, nPerElement)
%SAMPLEINTERNALFORCES Shear and bending moment sampled along every element.
%   S = SAMPLEINTERNALFORCES(MODEL, U, NPERELEMENT) evaluates the internal
%   shear V [N] and bending moment M [N*m] at NPERELEMENT+1 equally spaced
%   points of every element, both ends included, from the full displacement
%   vector U. NPERELEMENT defaults to 10.
%
%   Inside element e, with s measured from its left node and the end values
%   V_i, M_i from RECOVERELEMENTFORCES (which already include f_e0):
%       V(s) = V_i + w_e*s
%       M(s) = M_i + V_i*s + w_e*s^2/2
%   where w_e is the element's uniform load intensity (+ up). This is exact
%   element equilibrium for nodal and uniform loads, so the diagram shows the
%   linear shear and parabolic moment of a uniform load. Every node appears
%   twice (end of element e and start of element e+1), so jumps caused by
%   nodal forces or supports are kept.
%
%   S fields (column vectors of equal length):
%     x        sample coordinate [m]
%     V        internal shear [N], V(x) = sum of upward forces left of x
%     M        internal bending moment [N*m], positive sagging
%     element  index of the element each sample belongs to
%
%   Not included yet: deflection between nodes, and point loads inside
%   elements (milestone M3).
%
%   See also RECOVERELEMENTFORCES, SOLVESTATICMODEL.

if nargin < 3
    nPerElement = 10;
end
assertIntegerScalarInRange(nPerElement, 'nPerElement', 1, Inf);
ef = recoverElementForces(model, U);
w = model.loads.elementUDL;
ne = size(model.elements.conn, 1);

nSamples = nPerElement + 1;
s.x = zeros(ne * nSamples, 1);
s.V = zeros(ne * nSamples, 1);
s.M = zeros(ne * nSamples, 1);
s.element = zeros(ne * nSamples, 1);
for e = 1:ne
    Le = ef.x(e, 2) - ef.x(e, 1);
    t = Le * ((0:nPerElement)' / nPerElement);
    idx = (e - 1) * nSamples + (1:nSamples);
    Vi = ef.shear(e, 1);
    Mi = ef.moment(e, 1);
    s.x(idx) = ef.x(e, 1) + t;
    s.x(idx(end)) = ef.x(e, 2);
    s.V(idx) = Vi + w(e) * t;
    s.M(idx) = Mi + Vi * t + w(e) * t.^2 / 2;
    s.element(idx) = e;
end
end
