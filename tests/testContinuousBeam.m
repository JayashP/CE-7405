%TESTCONTINUOUSBEAM Benchmark D and other two-span continuous-beam checks.
%   Script-based test file (see runAllTests). Supports: pin at A (x = 0),
%   rollers at B and C, constant EI. Each case is statically indeterminate
%   to degree one. Analytical references (fixed; never edit them to make a
%   test pass), downward loads P and q:
%   Two equal spans L, point load P at each midspan:
%     R_A = R_C = 5P/16, R_B = 11P/8, M_B = -3PL/16, v(L/2) = -7PL^3/(768EI)
%   Benchmark D, equal spans L, uniform q on both spans (PROJECT_SPEC.md §10):
%     R_A = R_C = 3qL/8, R_B = 5qL/4, M_B = -qL^2/8, theta_B = 0,
%     max sagging 9qL^2/128 at x = 3L/8 and x = 2L - 3L/8,
%     theta_A = -qL^3/(48EI); in span 1, with x' = L - x,
%     v = (-qL^2*x'^2/16 + 5qL*x'^3/48 - q*x'^4/24)/EI (mirrored in span 2)
%   Equal spans, uniform q on span AB only (three-moment equation):
%     M_B = -qL^2/16, R_A = 7qL/16, R_B = 5qL/8, R_C = -qL/16 (uplift)
%   Unequal spans L1, L2 with uniform q on both (three-moment equation):
%     M_B = -q(L1^3 + L2^3)/(8(L1 + L2)), R_A = qL1/2 + M_B/L1,
%     R_C = qL2/2 + M_B/L2, R_B = q(L1 + L2) - R_A - R_C
%   Acceptance: Benchmark D < 0.5 % (spec target used for C); other checks < 0.1 %.
L = 10;            % span [m]
P = 100e3;         % [N], downward
q = 20e3;          % [N/m], downward
EI = 200e9 * 0.01; % [N*m^2]
tolD = 0.5;
tol = 0.1;
nPerSpan = 16;     % Le = 0.625 m, so L/2 and 3L/8 are nodes

%% Two equal spans with a point load at each midspan
[x, xs] = meshSpans([L L], nPerSpan);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
C = findNodeAtX(model, xs(3));
model = addSupport(model, B, 'roller');
model = addSupport(model, C, 'roller');
m1 = findNodeAtX(model, L/2);
m2 = findNodeAtX(model, 3*L/2);
model = addNodalLoad(model, m1, -P);
model = addNodalLoad(model, m2, -P);
res = solveStaticModel(model);
ef = res.elementForces;
reportComparisons(sprintf('Two spans of %g m, P = %g kN at each midspan, %d elements per span', L, P/1e3, nPerSpan), [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, 5*P/16/1e3, tol), ...
    compareToReference('R_B [kN]', res.R(2*B - 1)/1e3, 11*P/8/1e3, tol), ...
    compareToReference('R_C [kN]', res.R(2*C - 1)/1e3, 5*P/16/1e3, tol), ...
    compareToReference('M_B from span 1 [kN*m]', ef.moment(B - 1, 2)/1e3, -3*P*L/16/1e3, tol), ...
    compareToReference('M_B from span 2 [kN*m]', ef.moment(B, 1)/1e3, -3*P*L/16/1e3, tol), ...
    compareToReference('M under load in span 1 [kN*m]', ef.moment(m1 - 1, 2)/1e3, 5*P*L/32/1e3, tol), ...
    compareToReference('v(L/2) [mm]', res.v(m1)*1e3, -7*P*L^3/(768*EI)*1e3, tol), ...
    compareToReference('theta_B [rad]', res.theta(B), 0, [], 1e-6*P*L^2/(16*EI)), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*P/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*P*L/1e3)]);

%% Benchmark D two equal spans with uniform load on both spans
[x, xs] = meshSpans([L L], nPerSpan);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
C = findNodeAtX(model, xs(3));
model = addSupport(model, B, 'roller');
model = addSupport(model, C, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 8);
xm = (model.nodes.x(s.element) + model.nodes.x(s.element + 1)) / 2;
inSpan1 = xm < L;
MRef = inSpan1 .* (3*q*L*s.x/8 - q*s.x.^2/2) + ~inSpan1 .* (3*q*L*(2*L - s.x)/8 - q*(2*L - s.x).^2/2);
VRef = inSpan1 .* (3*q*L/8 - q*s.x) + ~inSpan1 .* (13*q*L/8 - q*s.x);
xp = abs(L - x);                                             % distance from the interior support
vRef = (-q*L^2*xp.^2/16 + 5*q*L*xp.^3/48 - q*xp.^4/24) / EI;
[MmaxLeft, iLeft] = max(s.M .* inSpan1 - 1e30 * ~inSpan1);
[MmaxRight, iRight] = max(s.M .* ~inSpan1 - 1e30 * inSpan1);
fprintf('  rcond(Kff) = %.3e, max|Kff*Uf - Ff| = %.3e\n', res.diagnostics.rcondKff, res.diagnostics.maxResidual);
reportComparisons(sprintf('Benchmark D: two %g m spans, q = %g kN/m on both, %d elements per span', L, q/1e3, nPerSpan), [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, 3*q*L/8/1e3, tolD), ...
    compareToReference('R_B [kN]', res.R(2*B - 1)/1e3, 5*q*L/4/1e3, tolD), ...
    compareToReference('R_C [kN]', res.R(2*C - 1)/1e3, 3*q*L/8/1e3, tolD), ...
    compareToReference('M_B from span 1 [kN*m]', ef.moment(B - 1, 2)/1e3, -q*L^2/8/1e3, tolD), ...
    compareToReference('M_B from span 2 [kN*m]', ef.moment(B, 1)/1e3, -q*L^2/8/1e3, tolD), ...
    compareToReference('max sagging M, span 1 [kN*m]', MmaxLeft/1e3, 9*q*L^2/128/1e3, tolD), ...
    compareToReference('x of max sagging M, span 1 [m]', s.x(iLeft), 3*L/8, tolD), ...
    compareToReference('max sagging M, span 2 [kN*m]', MmaxRight/1e3, 9*q*L^2/128/1e3, tolD), ...
    compareToReference('x of max sagging M, span 2 [m]', s.x(iRight), 2*L - 3*L/8, tolD), ...
    compareToReference('theta_A [rad] (+ CCW)', res.theta(1), -q*L^3/(48*EI), tolD), ...
    compareToReference('theta_B [rad]', res.theta(B), 0, [], 1e-6*q*L^3/(48*EI)), ...
    compareToReference('max|v - v_exact| / (qL^4/192EI) [-] (33 nodes)', max(abs(res.v - vRef)) / (q*L^4/(192*EI)), 0, [], 5e-3), ...
    compareToReference('max|M - M_exact| / (qL^2/8) [-] (288 samples)', max(abs(s.M - MRef)) / (q*L^2/8), 0, [], 5e-3), ...
    compareToReference('max|V - V_exact| / (5qL/8) [-] (288 samples)', max(abs(s.V - VRef)) / (5*q*L/8), 0, [], 5e-3), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*q*L/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*q*L^2/1e3)]);

%% Uniform load on one span only gives uplift at the far support
[x, xs] = meshSpans([L L], nPerSpan);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
C = findNodeAtX(model, xs(3));
model = addSupport(model, B, 'roller');
model = addSupport(model, C, 'roller');
model = addUniformLoad(model, -q, elementsBetween(model, xs(1), xs(2)));
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 8);
xm = (model.nodes.x(s.element) + model.nodes.x(s.element + 1)) / 2;
inSpan1 = xm < L;
MRef = inSpan1 .* (7*q*L*s.x/16 - q*s.x.^2/2) + ~inSpan1 .* (-q*L*(2*L - s.x)/16);
reportComparisons('Two equal spans, q on span AB only (pattern load)', [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, 7*q*L/16/1e3, tol), ...
    compareToReference('R_B [kN]', res.R(2*B - 1)/1e3, 5*q*L/8/1e3, tol), ...
    compareToReference('R_C [kN] (negative = uplift)', res.R(2*C - 1)/1e3, -q*L/16/1e3, tol), ...
    compareToReference('M_B [kN*m]', ef.moment(B, 1)/1e3, -q*L^2/16/1e3, tol), ...
    compareToReference('max|M - M_exact| / (qL^2/16) [-] (288 samples)', max(abs(s.M - MRef)) / (q*L^2/16), 0, [], 1e-3), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*q*L/1e3)]);

%% Unequal spans of 10 m and 15 m under uniform load (three-moment equation)
L1 = 10;
L2 = 15;
MB = -q * (L1^3 + L2^3) / (8 * (L1 + L2));
RA = q*L1/2 + MB/L1;
RC = q*L2/2 + MB/L2;
RB = q*(L1 + L2) - RA - RC;
[x, xs] = meshSpans([L1 L2], [8 12]);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
C = findNodeAtX(model, xs(3));
model = addSupport(model, B, 'roller');
model = addSupport(model, C, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
ef = res.elementForces;
reportComparisons(sprintf('Unequal spans %g m + %g m, q = %g kN/m, 8 + 12 elements', L1, L2, q/1e3), [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, RA/1e3, tol), ...
    compareToReference('R_B [kN]', res.R(2*B - 1)/1e3, RB/1e3, tol), ...
    compareToReference('R_C [kN]', res.R(2*C - 1)/1e3, RC/1e3, tol), ...
    compareToReference('M_B [kN*m]', ef.moment(B, 1)/1e3, MB/1e3, tol), ...
    compareToReference('M_B from span 1 [kN*m]', ef.moment(B - 1, 2)/1e3, MB/1e3, tol), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*q*L2^2/1e3)]);
