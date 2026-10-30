function res = analyzeVehiclePosition(prep, vehicle, xv, direction)
%ANALYZEVEHICLEPOSITION Quasi-static response for one vehicle position.
%   RES = ANALYZEVEHICLEPOSITION(PREP, VEHICLE, XV, DIRECTION) applies the
%   axles of VEHICLE with its front axle at XV [m] (DIRECTION +1 or -1,
%   default +1) on top of the permanent loads stored in PREP
%   (PREPAREMOVINGLOAD) and solves with the stored Cholesky factor. It uses
%   the same rules as the static engine:
%     - axles off the beam (beyond 1e-9 times its length) are ignored;
%     - an axle at a node is a nodal force there (at a support it goes
%       straight into the reaction);
%     - an axle inside an element acts through its Hermite consistent load
%       vector (EQUIVALENTPOINTLOAD), not moved to a node.
%   End actions are f_e = k_e*q_e - f_e0. V and M at the stations and under
%   every axle on the beam use exact element equilibrium, with the left (x-)
%   and right (x+) limits (a load within 1e-9*L of an evaluation point counts
%   as at that point). Deflections use Hermite interpolation plus the
%   fixed-fixed particular solutions (same formulas as EVALUATEDEFLECTION).
%   This is a quasi-static analysis; no dynamic effects are included.
%
%   RES fields (SI units, signs of DECISIONS.md D-003):
%     xv, direction
%     axles      x, P (signed, + up), onBridge (logical) for every axle
%     U, R, F    full displacement, reaction (0 at free DOFs) and load vectors
%     endActions NE-by-4 element end actions
%     stations   x, VL, VR (shear at x- and x+), ML, MR, v at the stations
%     axlePoints the same fields evaluated under each axle on the beam
%
%   See also PREPAREMOVINGLOAD, RUNMOVINGLOAD, SOLVESTATICMODEL.

if nargin < 4
    direction = 1;
end
[xa, Pa] = vehicleAxlePositions(vehicle, xv, direction);
x = prep.x;
tol = prep.tol;
Le = prep.Le;
dofMap = prep.dofMap;

onBridge = xa >= x(1) - tol & xa <= x(end) + tol;
xOn = min(max(xa(onBridge), x(1)), x(end));
POn = Pa(onBridge);
axleMap = mapCoordinatesToElements(x, xOn, tol);

% Load vector and element load vectors: permanent loads + axles on the beam.
F = prep.Fbase;
f0 = prep.f0base;
pe = prep.basePoint.e;
pa = prep.basePoint.a;
pp = prep.basePoint.P;
for k = 1:numel(xOn)
    n = axleMap.node(k);
    if n > 0
        F(2*n - 1) = F(2*n - 1) + POn(k);
    else
        e = axleMap.eL(k);
        a = axleMap.sL(k);
        fe = equivalentPointLoad(POn(k), a, Le(e));
        F(dofMap(e, :)) = F(dofMap(e, :)) + fe;
        f0(e, :) = f0(e, :) + fe.';
        pe = [pe; e]; %#ok<AGROW>
        pa = [pa; a]; %#ok<AGROW>
        pp = [pp; POn(k)]; %#ok<AGROW>
    end
end

% Solve with the stored factorization Kff = Rc'*Rc.
U = zeros(numel(F), 1);
if ~isempty(prep.freeDofs)
    U(prep.freeDofs) = prep.Rc \ (prep.Rc' \ F(prep.freeDofs));
end
R = zeros(numel(F), 1);
R(prep.restrainedDofs) = full(prep.Kc * U - F(prep.restrainedDofs));

% End actions f_e = k_e*q_e - f_e0 for every element.
ne = size(dofMap, 1);
Q = reshape(U(dofMap), ne, 4);
endActions = zeros(ne, 4);
for e = 1:ne
    endActions(e, :) = (prep.ke(:, :, e) * Q(e, :).').' - f0(e, :);
end
Vi = endActions(:, 1);
Mi = -endActions(:, 2);

loads = struct('e', pe, 'a', pa, 'P', pp);
st = prep.stations;
[VL, ML] = shearMoment(st.eL, st.sL, false, Vi, Mi, prep.w, loads, tol);
[VR, MR] = shearMoment(st.eR, st.sR, true, Vi, Mi, prep.w, loads, tol);
res.stations = struct('x', st.x, 'VL', VL, 'VR', VR, 'ML', ML, 'MR', MR, ...
    'v', deflection(st.eL, st.sL, U, prep, loads));
[aVL, aML] = shearMoment(axleMap.eL, axleMap.sL, false, Vi, Mi, prep.w, loads, tol);
[aVR, aMR] = shearMoment(axleMap.eR, axleMap.sR, true, Vi, Mi, prep.w, loads, tol);
res.axlePoints = struct('x', xOn, 'VL', aVL, 'VR', aVR, 'ML', aML, 'MR', aMR, ...
    'v', deflection(axleMap.eL, axleMap.sL, U, prep, loads));

res.xv = xv;
res.direction = direction;
res.axles = struct('x', xa, 'P', Pa, 'onBridge', onBridge);
res.U = U;
res.R = R;
res.F = F;
res.endActions = endActions;
end

function [V, M] = shearMoment(e, s, rightLimit, Vi, Mi, w, loads, tol)
% Exact element equilibrium from the left-end values (as SAMPLEINTERNALFORCES).
V = Vi(e) + w(e) .* s;
M = Mi(e) + Vi(e) .* s + w(e) .* s.^2 / 2;
for k = 1:numel(loads.e)
    inElement = e == loads.e(k);
    if rightLimit
        acts = inElement & s >= loads.a(k) - tol;
    else
        acts = inElement & s > loads.a(k) + tol;
    end
    V = V + loads.P(k) * acts;
    M = M + loads.P(k) * max(s - loads.a(k), 0) .* inElement;
end
end

function v = deflection(e, s, U, prep, loads)
% Hermite interpolation plus fixed-fixed particular solutions (as EVALUATEDEFLECTION).
Le = prep.Le(e);
EI = prep.EI(e);
r = s ./ Le;
N = [1 - 3*r.^2 + 2*r.^3, Le .* (r - 2*r.^2 + r.^3), 3*r.^2 - 2*r.^3, Le .* (-r.^2 + r.^3)];
q = reshape(U(prep.dofMap(e, :)), numel(e), 4);
v = sum(N .* q, 2) + prep.w(e) .* s.^2 .* (Le - s).^2 ./ (24 * EI);
for k = 1:numel(loads.e)
    inElement = e == loads.e(k);
    a = loads.a(k);
    b = Le - a;
    t = Le - s;
    left = inElement & s <= a;
    right = inElement & s > a;
    vLeft = loads.P(k) * b.^2 .* s.^2 .* (3*a*Le - (3*a + b) .* s) ./ (6 * EI .* Le.^3);
    vRight = loads.P(k) * a^2 * t.^2 .* (3*b .* Le - (3*b + a) .* t) ./ (6 * EI .* Le.^3);
    v = v + vLeft .* left + vRight .* right;
end
end
