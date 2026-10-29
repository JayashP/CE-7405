%TESTPOINTLOADSINELEMENTS Point loads inside elements: forces, jumps and deflection between nodes.
%   Script-based test file (see runAllTests). Analytical references are
%   closed-form statics and elastic-curve results, fixed in the test:
%     Simple span, load P (down) at a, b = L - a:
%       v(x) = -P*b*x*(L^2 - b^2 - x^2)/(6EI L)                 for x <= a
%       v(x) = -P*a*(L - x)*(L^2 - a^2 - (L - x)^2)/(6EI L)     for x >= a
%     Propped cantilever (fixed at x = 0, roller at L), load P (down) at a:
%       R_B = P*a^2*(3L - a)/(2L^3), R_A = P - R_B, M_A = R_B*L - P*a,
%       M(a) = R_B*(L - a), v(x <= a) = (M_A*x^2/2 + R_A*x^3/6)/EI
%     Simple span, uniform q (down): v(x) = -q*x*(L^3 - 2L*x^2 + x^3)/(24EI)
%     Fixed-fixed, uniform q (down): v(x) = -q*x^2*(L - x)^2/(24EI)
L = 10;            % [m]
EI = 200e9 * 0.01; % [N*m^2]
tol = 0.1;         % [%]
vSS = @(x, a, P) -P .* ((x <= a) .* (L - a) .* x .* (L^2 - (L - a)^2 - x.^2) ...
    + (x > a) .* a .* (L - x) .* (L^2 - a^2 - (L - x).^2)) / (6*EI*L);

%% Two loads inside ONE simply supported element are not moved to the nodes
P1 = 50e3; a1 = 3;
P2 = 80e3; a2 = 7;
model = createBeamModel([0; L], EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 2, 'roller');
model = addPointLoad(model, a1, -P1);
model = addPointLoad(model, a2, -P2);
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 10);
RA = (P1*(L - a1) + P2*(L - a2)) / L;
RB = P1 + P2 - RA;
MRef = RA*s.x - P1*max(s.x - a1, 0) - P2*max(s.x - a2, 0);
at1 = abs(s.x - a1) < 1e-12;
at2 = abs(s.x - a2) < 1e-12;
xq = linspace(0, L, 41)';
vq = evaluateDeflection(model, res.U, xq);
vRef = vSS(xq, a1, P1) + vSS(xq, a2, P2);
fprintf('  samples at the loads: V(3-) = %.6g, V(3+) = %.6g, V(7-) = %.6g, V(7+) = %.6g kN\n', ...
    s.V(find(at1, 1))/1e3, s.V(find(at1, 1, 'last'))/1e3, s.V(find(at2, 1))/1e3, s.V(find(at2, 1, 'last'))/1e3);
reportComparisons('One-element simple span, 50 kN at 3 m and 80 kN at 7 m', [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, RA/1e3, tol), ...
    compareToReference('R_B [kN]', res.R(3)/1e3, RB/1e3, tol), ...
    compareToReference('M(3 m) [kN*m]', max(s.M(at1))/1e3, RA*a1/1e3, tol), ...
    compareToReference('M(7 m) [kN*m]', max(s.M(at2))/1e3, RB*(L - a2)/1e3, tol), ...
    compareToReference('V(3-) [kN]', s.V(find(at1, 1))/1e3, RA/1e3, tol), ...
    compareToReference('V(3+) [kN]', s.V(find(at1, 1, 'last'))/1e3, (RA - P1)/1e3, tol), ...
    compareToReference('V(7+) [kN]', s.V(find(at2, 1, 'last'))/1e3, -RB/1e3, tol), ...
    compareToReference('max|M - M_exact| / max M [-] (all samples)', max(abs(s.M - MRef)) / (RB*(L - a2)), 0, [], 1e-3), ...
    compareToReference('v(3 m) [mm]', vq(13)*1e3, vRef(13)*1e3, tol), ...
    compareToReference('v(7 m) [mm]', vq(29)*1e3, vRef(29)*1e3, tol), ...
    compareToReference('max|v - v_exact| / max|v_exact| [-] (41 points)', max(abs(vq - vRef)) / max(abs(vRef)), 0, [], 1e-3)]);

%% Propped cantilever with a load inside an element (indeterminate)
P = 100e3;
a = 3.7;                          % inside element 2 of 4 (2.5 m elements)
RBp = P * a^2 * (3*L - a) / (2*L^3);
RAp = P - RBp;
MAp = RBp*L - P*a;
model = createBeamModel(generateUniformMesh(L, 4), EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 5, 'roller');
model = addPointLoad(model, a, -P);
res = solveStaticModel(model);
s = sampleInternalForces(model, res.U, 5);
atLoad = abs(s.x - a) < 1e-12;
xq = linspace(0, a, 12)';
vRefP = (MAp*xq.^2/2 + RAp*xq.^3/6) / EI;
assert(res.pointLoads.element == 2 && abs(res.pointLoads.a - 1.2) < 1e-12, 'load should be inside element 2 at a = 1.2 m');
reportComparisons(sprintf('Propped cantilever, P = %g kN at x = %g m (inside element 2), 4 elements', P/1e3, a), [ ...
    compareToReference('R_B = P*a^2*(3L - a)/(2L^3) [kN]', res.R(9)/1e3, RBp/1e3, tol), ...
    compareToReference('R_A [kN]', res.R(1)/1e3, RAp/1e3, tol), ...
    compareToReference('M_A = R_B*L - P*a [kN*m]', res.elementForces.moment(1, 1)/1e3, MAp/1e3, tol), ...
    compareToReference('M(a) = R_B*(L - a) [kN*m]', max(s.M(atLoad))/1e3, RBp*(L - a)/1e3, tol), ...
    compareToReference('shear jump under the load [kN]', (max(s.V(atLoad)) - min(s.V(atLoad)))/1e3, P/1e3, tol), ...
    compareToReference('v(a) [mm]', evaluateDeflection(model, res.U, a)*1e3, vRefP(end)*1e3, tol), ...
    compareToReference('max|v - v_exact| / |v(a)| [-] (12 points on 0..a)', max(abs(evaluateDeflection(model, res.U, xq) - vRefP)) / abs(vRefP(end)), 0, [], 1e-3)]);

%% Deflection between nodes is exact for uniform and point loads
q = 20e3;
model = createBeamModel(generateUniformMesh(L, 2), EI);           % only 2 elements
model = addSupport(model, 1, 'pin');
model = addSupport(model, 3, 'roller');
model = addUniformLoad(model, -q);
res = solveStaticModel(model);
xq = linspace(0, L, 41)';
vq = evaluateDeflection(model, res.U, xq);
vRefU = -q * xq .* (L^3 - 2*L*xq.^2 + xq.^3) / (24*EI);
P = 100e3;
a = 7.3;
modelP = createBeamModel(generateUniformMesh(L, 4), EI);
modelP = addSupport(modelP, 1, 'pin');
modelP = addSupport(modelP, 5, 'roller');
modelP = addPointLoad(modelP, a, -P);
resP = solveStaticModel(modelP);
vqP = evaluateDeflection(modelP, resP.U, xq);
modelF = createBeamModel([0; L], EI);                              % one fixed-fixed element: U = 0
modelF = addSupport(modelF, 1, 'fixed');
modelF = addSupport(modelF, 2, 'fixed');
modelF = addUniformLoad(modelF, -q);
resF = solveStaticModel(modelF);
reportComparisons('Deflection between nodes (Hermite part + fixed-fixed particular solution)', [ ...
    compareToReference('UDL, 2 elements: max|v - v_exact| / v_mid [-] (41 points)', max(abs(vq - vRefU)) / (5*q*L^4/(384*EI)), 0, [], 1e-3), ...
    compareToReference('UDL, 2 elements: v(L/4) [mm]', vq(11)*1e3, vRefU(11)*1e3, tol), ...
    compareToReference('P at 7.3 m, 4 elements: max|v - v_exact| / max|v| [-]', max(abs(vqP - vSS(xq, a, P))) / max(abs(vSS(xq, a, P))), 0, [], 1e-3), ...
    compareToReference('P at 7.3 m: v(7.3 m) [mm]', evaluateDeflection(modelP, resP.U, a)*1e3, vSS(a, a, P)*1e3, tol), ...
    compareToReference('fixed-fixed 1 element: v(L/2) [mm]', evaluateDeflection(modelF, resF.U, L/2)*1e3, -q*L^4/(384*EI)*1e3, tol), ...
    compareToReference('fixed-fixed 1 element: v(L/4) [mm]', evaluateDeflection(modelF, resF.U, L/4)*1e3, -q*(L/4)^2*(3*L/4)^2/(24*EI)*1e3, tol)]);
assertThrows(@() evaluateDeflection(modelP, resP.U, L + 1), 'BridgeFE:offBeam');

%% Mixed loads close element equilibrium and show a jump of P at each interior load
model = createBeamModel(generateUniformMesh(L, 5), EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 6, 'roller');
model = addUniformLoad(model, -15e3, 2:4);
model = addPointLoad(model, 4.5, -60e3);
model = addPointLoad(model, 5.2, 25e3);           % upward load in the same element
model = addPointLoad(model, 8, -40e3);            % at a node
model = addNodalLoad(model, 4, 0, 30e3);
res = solveStaticModel(model);
ef = res.elementForces;
s = sampleInternalForces(model, res.U, 4);
lastRow = arrayfun(@(e) find(s.element == e, 1, 'last'), (1:5)');
jumpA = diff(s.V(abs(s.x - 4.5) < 1e-12));
jumpB = diff(s.V(abs(s.x - 5.2) < 1e-12));
reportComparisons('Fixed + roller, UDL on elements 2-4, interior loads at 4.5 m (down) and 5.2 m (up), load at node 5, couple at node 4', [ ...
    compareToReference('max|V(x_j-) - V_j| / 60 kN [-]', max(abs(s.V(lastRow) - ef.shear(:, 2))) / 60e3, 0, [], 1e-12), ...
    compareToReference('max|M(x_j-) - M_j| / (60 kN * L) [-]', max(abs(s.M(lastRow) - ef.moment(:, 2))) / (60e3*L), 0, [], 1e-12), ...
    compareToReference('shear jump at 4.5 m [kN]', jumpA/1e3, -60, tol), ...
    compareToReference('shear jump at 5.2 m [kN]', jumpB/1e3, 25, tol), ...
    compareToReference('sum Fv, loads + reactions [kN]', res.diagnostics.sumVerticalForce/1e3, 0, [], 1e-6*60), ...
    compareToReference('sum M about x = 0 [kN*m]', res.diagnostics.sumMomentAboutOrigin/1e3, 0, [], 1e-6*600)]);

%% A point load on a support goes straight into that reaction
model = createBeamModel(generateUniformMesh(L, 4), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 5, 'roller');
res = solveStaticModel(addPointLoad(model, 0, -50e3));
assert(all(res.U == 0), 'a load on the pinned support must not deform the beam');
reportComparisons('50 kN downward point load exactly at the pin (x = 0)', [ ...
    compareToReference('R_A [kN]', res.R(1)/1e3, 50, tol), ...
    compareToReference('R_B [kN]', res.R(9)/1e3, 0, [], 1e-9)]);
