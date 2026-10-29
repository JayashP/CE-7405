%TESTCANTILEVERTIPLOAD Fixed-end restraint check: cantilever with a downward tip load.
%   Script-based test file (see runAllTests). Extra determinate check, not
%   one of the spec's numbered benchmarks, that exercises the rotational
%   restraint and the hogging-moment sign. Analytical references
%   (Euler-Bernoulli, constant EI, load P downward at the free end):
%     R_A = +P (up), reaction couple at A = +P*L (counterclockwise)
%     M(x) = -P*(L - x) (hogging), V(x) = +P
%     v_tip = -P*L^3/(3EI), theta_tip = -P*L^2/(2EI)
L = 10;            % [m]
P = 50e3;          % tip load magnitude [N], acts downward
EI = 200e9 * 0.01; % [N*m^2]
ne = 10;
relTolPct = 0.1;
MA_ref = P * L;                 % [N*m]
vtip_ref = -P * L^3 / (3*EI);   % [m]
thetatip_ref = -P * L^2 / (2*EI);  % [rad]

%% Cantilever with a tip load and 10 elements
model = createBeamModel(generateUniformMesh(L, ne), EI);
model = addSupport(model, findNodeAtX(model, 0), 'fixed');
tip = findNodeAtX(model, L);
model = addNodalLoad(model, tip, -P, 0);
res = solveStaticModel(model);
ef = res.elementForces;
Mref = -P * (L - ef.x);                       % analytical M at every element end [N*m]
maxMomentError = max(abs(ef.moment(:) - Mref(:)));
reportComparisons(sprintf('Cantilever: L = %g m, P = %g kN down at tip, EI = %g N*m^2, %d elements', ...
    L, P/1e3, EI, ne), [ ...
    compareToReference('R_A [kN] (+ up)', res.R(1)/1e3, P/1e3, relTolPct), ...
    compareToReference('reaction couple at A [kN*m] (+ CCW)', res.R(2)/1e3, MA_ref/1e3, relTolPct), ...
    compareToReference('M(x = 0) [kN*m] (+ sagging)', ef.moment(1, 1)/1e3, -MA_ref/1e3, relTolPct), ...
    compareToReference('M(x = L) [kN*m]', ef.moment(end, 2)/1e3, 0, [], 1e-6 * MA_ref/1e3), ...
    compareToReference('max|M - M_ref| over element ends [kN*m]', maxMomentError/1e3, 0, [], 1e-6 * MA_ref/1e3), ...
    compareToReference('min V over element ends [kN]', min(ef.shear(:))/1e3, P/1e3, relTolPct), ...
    compareToReference('max V over element ends [kN]', max(ef.shear(:))/1e3, P/1e3, relTolPct), ...
    compareToReference('v_tip [mm] (+ up)', res.v(tip) * 1e3, vtip_ref * 1e3, relTolPct), ...
    compareToReference('theta_tip [rad] (+ CCW)', res.theta(tip), thetatip_ref, relTolPct), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6 * P/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6 * MA_ref/1e3)]);
assert(res.v(1) == 0 && res.theta(1) == 0, 'Fixed-end DOFs must be exactly zero');
fprintf('  PASS v_A = theta_A = 0 exactly at the fixed end\n');
