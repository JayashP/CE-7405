function s = sampleInternalForces(model, U, nPerElement)
%SAMPLEINTERNALFORCES Shear and bending moment sampled along every element.
%   S = SAMPLEINTERNALFORCES(MODEL, U, NPERELEMENT) evaluates the internal
%   shear V [N] and bending moment M [N*m] at NPERELEMENT+1 equally spaced
%   points of every element, both ends included, plus the position of every
%   point load inside the element, from the full displacement vector U.
%   NPERELEMENT defaults to 10.
%
%   Inside element e, with s measured from its left node, end values V_i
%   and M_i from RECOVERELEMENTFORCES (which already include f_e0), uniform
%   load w_e (+ up) and interior point loads P_k (+ up) at a_k:
%       V(s) = V_i + w_e*s + sum_{a_k < s} P_k
%       M(s) = M_i + V_i*s + w_e*s^2/2 + sum_{a_k < s} P_k*(s - a_k)
%   This is exact element equilibrium. Each interior point load is sampled
%   twice at s = a_k: first the limit from the left (load excluded), then
%   from the right (load included), so the shear jump of size P_k is shown
%   and M has its kink there. Every node also appears twice (end of element
%   e, start of element e+1), keeping jumps from nodal forces and supports.
%
%   S fields (column vectors of equal length):
%     x        sample coordinate [m]
%     V        internal shear [N], V(x) = sum of upward forces left of x
%     M        internal bending moment [N*m], positive sagging
%     element  index of the element each sample belongs to
%
%   See also RECOVERELEMENTFORCES, EVALUATEDEFLECTION, SOLVESTATICMODEL.

if nargin < 3
    nPerElement = 10;
end
assertIntegerScalarInRange(nPerElement, 'nPerElement', 1, Inf);
ef = recoverElementForces(model, U);
w = model.loads.elementUDL;
loc = locatePointLoads(model);
ne = size(model.elements.conn, 1);

xs = cell(ne, 1);
Vs = cell(ne, 1);
Ms = cell(ne, 1);
es = cell(ne, 1);
for e = 1:ne
    Le = ef.x(e, 2) - ef.x(e, 1);
    k = find(loc.element == e);
    aK = loc.a(k);
    PK = loc.P(k);
    t = unique([Le * ((0:nPerElement)' / nPerElement); aK]);
    % One row per t (left limit), plus a right-limit row at each load position.
    isLoadPoint = ismember(t, aK);
    tRows = [t; t(isLoadPoint)];
    rightLimit = [false(size(t)); true(nnz(isLoadPoint), 1)];
    [tRows, order] = sort(tRows);
    rightLimit = rightLimit(order);
    Vi = ef.shear(e, 1);
    Mi = ef.moment(e, 1);
    V = Vi + w(e) * tRows;
    M = Mi + Vi * tRows + w(e) * tRows.^2 / 2;
    for j = 1:numel(aK)
        acts = tRows > aK(j) | (tRows == aK(j) & rightLimit);
        V = V + PK(j) * acts;
        M = M + PK(j) * max(tRows - aK(j), 0) .* acts;
    end
    xe = ef.x(e, 1) + tRows;
    xe(tRows == Le) = ef.x(e, 2);
    xs{e} = xe;
    Vs{e} = V;
    Ms{e} = M;
    es{e} = repmat(e, numel(tRows), 1);
end
s.x = vertcat(xs{:});
s.V = vertcat(Vs{:});
s.M = vertcat(Ms{:});
s.element = vertcat(es{:});
end
