%TESTUNIFORMLOADBEAMS Uniform load on a simple span and on a fixed-fixed beam.
%   Script-based test file (see runAllTests). Checks the consistent load
%   vector, the member-load term in force recovery (f_e = k_e*q_e - f_e0) and
%   the sampled parabolic moment. Analytical references (constant EI,
%   downward load of intensity q, entered as w = -q):
%     Simple span:  R = qL/2, M(x) = q*x*(L-x)/2, M_mid = qL^2/8,
%                   v(x) = -q*x*(L^3 - 2L*x^2 + x^3)/(24EI), theta_A = -qL^3/(24EI)
%     Fixed-fixed:  R = qL/2, M(0) = M(L) = -qL^2/12, M_mid = +qL^2/24,
%                   reaction couples +qL^2/12 at A and -qL^2/12 at B,
%                   v(x) = -q*x^2*(L-x)^2/(24EI)
L = 10;            % [m]
q = 20e3;          % downward load intensity [N/m]
EI = 200e9 * 0.01; % [N*m^2]
relTolPct = 0.1;

%% Simply supported beam under uniform load, 10 elements
model = createBeamModel(generateUniformMesh(L, 10), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 11, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 8);
x = model.nodes.x;
vRef = -q * x .* (L^3 - 2*L*x.^2 + x.^3) / (24*EI);
MRef = q * s.x .* (L - s.x) / 2;
VRef = q * (L/2 - s.x);
[Mmax, iMax] = max(s.M);
reportComparisons(sprintf('Simple span, q = %g kN/m down, L = %g m, EI = %g N*m^2, 10 elements', q/1e3, L, EI), [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, q*L/2/1e3, relTolPct), ...
    compareToReference('R_B [kN]', res.R(21)/1e3, q*L/2/1e3, relTolPct), ...
    compareToReference('M_max from samples [kN*m]', Mmax/1e3, q*L^2/8/1e3, relTolPct), ...
    compareToReference('x of M_max [m]', s.x(iMax), L/2, relTolPct), ...
    compareToReference('v_mid [mm]', res.v(6)*1e3, -5*q*L^4/(384*EI)*1e3, relTolPct), ...
    compareToReference('theta_A [rad]', res.theta(1), -q*L^3/(24*EI), relTolPct), ...
    compareToReference('max|v - v_exact| / |v_mid| [-] (11 nodes)', max(abs(res.v - vRef)) / (5*q*L^4/(384*EI)), 0, [], 1e-3), ...
    compareToReference('max|M - M_exact| / (qL^2/8) [-] (88 samples)', max(abs(s.M - MRef)) / (q*L^2/8), 0, [], 1e-3), ...
    compareToReference('max|V - V_exact| / (qL/2) [-] (88 samples)', max(abs(s.V - VRef)) / (q*L/2), 0, [], 1e-3), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*q*L/1e3), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*q*L^2/1e3)]);

%% Fixed-fixed single element has no free DOF and its forces come only from -f_e0
model = createBeamModel([0; L], EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 2, 'fixed');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 10);
assert(isempty(res.freeDofs) && all(res.U == 0), 'a single fixed-fixed element must have no free DOFs and U = 0');
reportComparisons('Fixed-fixed beam as ONE element, uniform load (empty free-DOF set)', [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, q*L/2/1e3, relTolPct), ...
    compareToReference('reaction couple at A [kN*m] (+ CCW)', res.R(2)/1e3, q*L^2/12/1e3, relTolPct), ...
    compareToReference('R_B [kN]', res.R(3)/1e3, q*L/2/1e3, relTolPct), ...
    compareToReference('reaction couple at B [kN*m] (+ CCW)', res.R(4)/1e3, -q*L^2/12/1e3, relTolPct), ...
    compareToReference('M(0) [kN*m]', res.elementForces.moment(1, 1)/1e3, -q*L^2/12/1e3, relTolPct), ...
    compareToReference('M(L) [kN*m]', res.elementForces.moment(1, 2)/1e3, -q*L^2/12/1e3, relTolPct), ...
    compareToReference('M(L/2) from samples [kN*m]', s.M(6)/1e3, q*L^2/24/1e3, relTolPct)]);

%% Fixed-fixed beam with 16 elements matches the exact moment and deflection
model = createBeamModel(generateUniformMesh(L, 16), EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 17, 'fixed');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 8);
x = model.nodes.x;
vRef = -q * x.^2 .* (L - x).^2 / (24*EI);
MRef = q * (-L^2/12 + L*s.x/2 - s.x.^2/2);
reportComparisons('Fixed-fixed beam, 16 elements, uniform load', [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, q*L/2/1e3, relTolPct), ...
    compareToReference('M(0) [kN*m]', res.elementForces.moment(1, 1)/1e3, -q*L^2/12/1e3, relTolPct), ...
    compareToReference('M(L/2) [kN*m]', res.elementForces.moment(8, 2)/1e3, q*L^2/24/1e3, relTolPct), ...
    compareToReference('v_mid [mm]', res.v(9)*1e3, -q*L^4/(384*EI)*1e3, relTolPct), ...
    compareToReference('max|v - v_exact| / |v_mid| [-] (17 nodes)', max(abs(res.v - vRef)) / (q*L^4/(384*EI)), 0, [], 1e-3), ...
    compareToReference('max|M - M_exact| / (qL^2/12) [-] (144 samples)', max(abs(s.M - MRef)) / (q*L^2/12), 0, [], 1e-3)]);

%% Sampled diagrams close element equilibrium at both element ends
model = createBeamModel(generateUniformMesh(L, 7), EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 8, 'roller');
model = addUniformLoad(model, -q, 2:5);
model = addNodalLoad(model, 4, -30e3, 5e3);
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 4);
lastOfElement = (1:7) * 5;
reportComparisons('Sampled V and M at element right ends vs recovered end forces (mixed loads)', [ ...
    compareToReference('max|V(L_e) - V_j| / (qL) [-]', max(abs(s.V(lastOfElement) - ef.shear(:, 2))) / (q*L), 0, [], 1e-12), ...
    compareToReference('max|M(L_e) - M_j| / (qL^2) [-]', max(abs(s.M(lastOfElement) - ef.moment(:, 2))) / (q*L^2), 0, [], 1e-12)]);
