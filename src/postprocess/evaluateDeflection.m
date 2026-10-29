function v = evaluateDeflection(model, U, xq)
%EVALUATEDEFLECTION Vertical deflection at arbitrary coordinates along the beam.
%   V = EVALUATEDEFLECTION(MODEL, U, XQ) returns the deflection v [m]
%   (+ up) at the query coordinates XQ [m], e.g. sensor locations, from the
%   full displacement vector U. Inside element e (left node at x_e, length
%   L_e, s = x - x_e):
%       v(s) = N(s)*q_e + v_p(s)
%   where N are the cubic Hermite functions (BEAMSHAPEFUNCTIONS) and v_p is
%   the exact fixed-fixed (clamped-clamped) solution of the loads acting
%   inside that element. v_p vanishes with its slope at both element ends,
%   so nodal values are unchanged and the sum is the exact Euler-Bernoulli
%   deflection:
%     uniform load w (+ up):  v_p = w*s^2*(L_e - s)^2 / (24 EI)
%     point load P (+ up) at a, b = L_e - a:
%       s <= a:  v_p = P*b^2*s^2*(3a*L_e - (3a + b)*s) / (6 EI L_e^3)
%       s >= a:  v_p = P*a^2*t^2*(3b*L_e - (3b + a)*t) / (6 EI L_e^3), t = L_e - s
%   Without v_p, Hermite interpolation alone is NOT exact inside a loaded
%   element (DECISIONS.md D-009). A query outside the beam throws
%   'BridgeFE:offBeam'.
%
%   Example (deflection at quarter points of a 20 m span):
%     v = evaluateDeflection(model, res.U, [5 10 15]);
%
%   See also BEAMSHAPEFUNCTIONS, SOLVESTATICMODEL, SAMPLEINTERNALFORCES.

validateModel(model);
x = model.nodes.x;
conn = model.elements.conn;
EI = model.elements.EI;
w = model.loads.elementUDL;
ne = size(conn, 1);
if ~(isnumeric(U) && isvector(U) && numel(U) == 2 * numel(x))
    error('BridgeFE:invalidInput', 'U must be a vector with %d entries.', 2 * numel(x));
end
if ~(isnumeric(xq) && isreal(xq) && isvector(xq) && all(isfinite(xq)))
    error('BridgeFE:invalidInput', 'xq must be a real, finite vector of coordinates [m].');
end
U = U(:);
xq = double(xq(:));
tol = 1e-9 * (x(end) - x(1));
if any(xq < x(1) - tol | xq > x(end) + tol)
    error('BridgeFE:offBeam', 'Query coordinates must lie within the beam [%g, %g] m.', x(1), x(end));
end
dofMap = elementDofs(conn);
loc = locatePointLoads(model);

v = zeros(numel(xq), 1);
for k = 1:numel(xq)
    xp = min(max(xq(k), x(1)), x(end));
    e = min(find(x(1:end-1) <= xp, 1, 'last'), ne);
    Le = x(conn(e, 2)) - x(conn(e, 1));
    s = min(max(xp - x(e), 0), Le);
    vk = beamShapeFunctions(s / Le, Le) * U(dofMap(e, :));
    vk = vk + w(e) * s^2 * (Le - s)^2 / (24 * EI(e));
    for j = find(loc.element == e).'
        a = loc.a(j);
        b = Le - a;
        if s <= a
            vk = vk + loc.P(j) * b^2 * s^2 * (3*a*Le - (3*a + b)*s) / (6 * EI(e) * Le^3);
        else
            t = Le - s;
            vk = vk + loc.P(j) * a^2 * t^2 * (3*b*Le - (3*b + a)*t) / (6 * EI(e) * Le^3);
        end
    end
    v(k) = vk;
end
end
