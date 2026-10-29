%TESTPROPPEDCANTILEVER Benchmark C and a point-load check on a propped cantilever.
%   Script-based test file (see runAllTests). Fixed at A (x = 0), roller at
%   B (x = L), constant EI. This is statically indeterminate to degree one.
%   Analytical references (fixed; never edit them to make a test pass):
%   Central point load P (downward) at L/2:
%     R_A = 11P/16, R_B = 5P/16, M_A = -3PL/16, M(L/2) = +5PL/32,
%     v(L/2) = -7PL^3/(768EI)
%   Benchmark C, uniform load q (downward) over the span (PROJECT_SPEC.md §10):
%     R_A = 5qL/8, R_B = 3qL/8, M_A = -qL^2/8,
%     M(x) = -qL^2/8 + 5qLx/8 - qx^2/2, max sagging 9qL^2/128 at x = 5L/8,
%     theta_B = +qL^3/(48EI),
%     v(x) = (-qL^2*x^2/16 + 5qL*x^3/48 - q*x^4/24)/EI
%   Benchmark C acceptance: < 0.5 % (spec). Point-load check: < 0.1 %.
%   Zero references: absolute tolerance 1e-6 x characteristic magnitude.
L = 10;            % [m]
P = 100e3;         % [N], downward
q = 20e3;          % [N/m], downward
EI = 200e9 * 0.01; % [N*m^2]
tolC = 0.5;        % Benchmark C target [%]
tolP = 0.1;        % point-load check target [%]
ne = 16;           % Le = 0.625 m, so L/2 and 5L/8 are nodes

%% Propped cantilever with a central point load at a node
model = createBeamModel(generateUniformMesh(L, ne), EI);
model = addSupport(model, findNodeAtX(model, 0), 'fixed');
B = findNodeAtX(model, L);
model = addSupport(model, B, 'roller');
mid = findNodeAtX(model, L/2);
model = addNodalLoad(model, mid, -P);
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 4);
xm = (model.nodes.x(s.element) + model.nodes.x(s.element + 1)) / 2;   % element midpoints
leftOfLoad = xm < L/2;
MRef = leftOfLoad .* (-3*P*L/16 + 11*P*s.x/16) + ~leftOfLoad .* (5*P*(L - s.x)/16);
VRef = leftOfLoad * (11*P/16) - ~leftOfLoad * (5*P/16);
reportComparisons(sprintf('Propped cantilever, P = %g kN at L/2, L = %g m, %d elements', P/1e3, L, ne), [ ...
    compareToReference('R_A [kN] (+ up)', res.R(1)/1e3, 11*P/16/1e3, tolP), ...
    compareToReference('R_B [kN] (+ up)', res.R(2*B - 1)/1e3, 5*P/16/1e3, tolP), ...
    compareToReference('reaction couple at A [kN*m] (+ CCW)', res.R(2)/1e3, 3*P*L/16/1e3, tolP), ...
    compareToReference('M_A = M(0) [kN*m] (+ sagging)', ef.moment(1, 1)/1e3, -3*P*L/16/1e3, tolP), ...
    compareToReference('M(L/2) [kN*m]', ef.moment(mid - 1, 2)/1e3, 5*P*L/32/1e3, tolP), ...
    compareToReference('v(L/2) [mm]', res.v(mid)*1e3, -7*P*L^3/(768*EI)*1e3, tolP), ...
    compareToReference('max|M - M_exact| / (3PL/16) [-]', max(abs(s.M - MRef)) / (3*P*L/16), 0, [], 1e-3), ...
    compareToReference('max|V - V_exact| / P [-]', max(abs(s.V - VRef)) / P, 0, [], 1e-3), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*P/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*P*L/1e3)]);
assert(res.v(1) == 0 && res.theta(1) == 0 && res.v(B) == 0, 'restrained DOFs must be exactly zero');
fprintf('  PASS v_A = theta_A = v_B = 0 exactly\n');

%% Benchmark C propped cantilever under uniform load with 16 elements
model = createBeamModel(generateUniformMesh(L, ne), EI);
model = addSupport(model, findNodeAtX(model, 0), 'fixed');
B = findNodeAtX(model, L);
model = addSupport(model, B, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 8);
x = model.nodes.x;
vRef = (-q*L^2*x.^2/16 + 5*q*L*x.^3/48 - q*x.^4/24) / EI;
MRef = -q*L^2/8 + 5*q*L*s.x/8 - q*s.x.^2/2;
VRef = 5*q*L/8 - q*s.x;
[Mmax, iMax] = max(s.M);
fprintf('  rcond(Kff) = %.3e, max|Kff*Uf - Ff| = %.3e\n', res.diagnostics.rcondKff, res.diagnostics.maxResidual);
reportComparisons(sprintf('Benchmark C: q = %g kN/m, L = %g m, EI = %g N*m^2, %d elements', q/1e3, L, EI, ne), [ ...
    compareToReference('R_A [kN] (+ up)', res.R(1)/1e3, 5*q*L/8/1e3, tolC), ...
    compareToReference('R_B [kN] (+ up)', res.R(2*B - 1)/1e3, 3*q*L/8/1e3, tolC), ...
    compareToReference('M_A = M(0) [kN*m] (+ sagging)', ef.moment(1, 1)/1e3, -q*L^2/8/1e3, tolC), ...
    compareToReference('reaction couple at A [kN*m] (+ CCW)', res.R(2)/1e3, q*L^2/8/1e3, tolC), ...
    compareToReference('max sagging M from samples [kN*m]', Mmax/1e3, 9*q*L^2/128/1e3, tolC), ...
    compareToReference('x of max sagging M [m]', s.x(iMax), 5*L/8, tolC), ...
    compareToReference('M(L) at roller [kN*m]', ef.moment(end, 2)/1e3, 0, [], 1e-6*q*L^2/8/1e3), ...
    compareToReference('theta_B [rad] (+ CCW)', res.theta(B), q*L^3/(48*EI), tolC), ...
    compareToReference('v(L/2) [mm]', res.v(findNodeAtX(model, L/2))*1e3, -q*L^4/(192*EI)*1e3, tolC), ...
    compareToReference('max|v - v_exact| / (qL^4/192EI) [-] (17 nodes)', max(abs(res.v - vRef)) / (q*L^4/(192*EI)), 0, [], 5e-3), ...
    compareToReference('max|M - M_exact| / (qL^2/8) [-] (144 samples)', max(abs(s.M - MRef)) / (q*L^2/8), 0, [], 5e-3), ...
    compareToReference('max|V - V_exact| / (5qL/8) [-] (144 samples)', max(abs(s.V - VRef)) / (5*q*L/8), 0, [], 5e-3), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*q*L/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*q*L^2/1e3)]);
assert(res.v(1) == 0 && res.theta(1) == 0 && res.v(B) == 0, 'restrained DOFs must be exactly zero');
fprintf('  PASS v_A = theta_A = 0 at the fixed end and v_B = 0 at the prop, exactly\n');

%% Benchmark C mesh independence with 1, 2, 4 and 16 elements
rows = [];
for n = [1 2 4 16]
    model = createBeamModel(generateUniformMesh(L, n), EI);
    model = addSupport(model, 1, 'fixed');
    model = addSupport(model, n + 1, 'roller');
    model = addUniformLoad(model, -q);
    res = solveStaticModel(model);
    rows = [rows, ...
        compareToReference(sprintf('ne = %2d: R_A [kN]', n), res.R(1)/1e3, 5*q*L/8/1e3, tolC), ...
        compareToReference(sprintf('ne = %2d: R_B [kN]', n), res.R(2*n + 1)/1e3, 3*q*L/8/1e3, tolC), ...
        compareToReference(sprintf('ne = %2d: M_A [kN*m]', n), res.elementForces.moment(1, 1)/1e3, -q*L^2/8/1e3, tolC), ...
        compareToReference(sprintf('ne = %2d: theta_B [rad]', n), res.theta(n + 1), q*L^3/(48*EI), tolC)]; %#ok<AGROW>
end
reportComparisons('Benchmark C mesh independence', rows);
