%TESTMOVINGLOADENVELOPES Envelopes, critical vehicle positions and step refinement.
%   Script-based test file (see runAllTests). Analytical references (fixed;
%   never edit them to make a test pass). The three marked * were also
%   confirmed by an independent brute-force sweep outside MATLAB on
%   2026-10-29 (see VERIFICATION_LOG V-007):
%   Single load P on a simple span L (influence lines):
%     Mmax(x) = P*x*(L-x)/L, Vmax(x) = P*(L-x)/L, Vmin(x) = -P*x/L,
%     vmin(L/2) = -P*L^3/(48EI), max M = P*L/4 at x = L/2 with the load there.
%   * Two equal axles P at spacing d on a simple span (absolute maximum
%     moment, d <= 0.586L): M = P*(2L - d)^2/(8L) under an axle at
%     x = L/2 -/+ d/4.
%   * Spec 3-axle truck (80/120/120 kN, 4.2 m + 1.4 m) on a 20 m simple span:
%     max M = 1349.1025 kN*m under the middle axle at x = 9.7375 m, front axle
%     at x_v = 13.9375 m (resultant rule).
%     Max reactions: R_A = 289.2 kN at x_v = 5.6 m, R_B = 261.2 kN at x_v = 20 m.
%   * Two equal spans L, single load P: M_B(a) = -P*a*(L^2 - a^2)/(4L^2) for a
%     load at a in span 1, so min M_B = -P*L/(6*sqrt(3)) at a = L/sqrt(3).
%     Uplift R_A,min = -P/(6*sqrt(3)) for the load at the same distance from C.
%   Acceptance: moving-load target 0.5 % (spec Benchmark B). Critical
%   locations within one refined step.
EI = 200e9 * 0.01; % [N*m^2]
tol = 0.5;         % [%]

%% Single moving load envelopes on a simple span equal the influence-line maxima
L = 20;
P = 100e3;
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
ml = runMovingLoad(model, createVehicle(P, [], 'single axle'), 'Step', 0.125, 'Refine', false);
xs = ml.stations;
inner = xs > 0 & xs < L;
env = ml.envelope;
mid = find(abs(xs - L/2) < 1e-9);
cM = ml.critical(1);
fprintf('  %d positions, %d stations (every %.3f m)\n', numel(ml.positions), numel(xs), xs(2) - xs(1));
reportComparisons('Single 100 kN load, 20 m simple span, 8 elements: envelopes at all interior stations', [ ...
    compareToReference('max|Mmax - Px(L-x)/L| / (PL/4) [-]', max(abs(env.Mmax(inner) - P*xs(inner).*(L - xs(inner))/L)) / (P*L/4), 0, [], 5e-3), ...
    compareToReference('max|Vmax - P(L-x)/L| / P [-]', max(abs(env.Vmax(inner) - P*(L - xs(inner))/L)) / P, 0, [], 5e-3), ...
    compareToReference('max|Vmin + Px/L| / P [-]', max(abs(env.Vmin(inner) + P*xs(inner)/L)) / P, 0, [], 5e-3), ...
    compareToReference('min over stations of Mmin [kN*m] (no hogging)', min(env.Mmin)/1e3, 0, [], 1e-6*P*L/1e3), ...
    compareToReference('vmin(L/2) [mm] = -PL^3/(48EI)', env.vmin(mid)*1e3, -P*L^3/(48*EI)*1e3, tol), ...
    compareToReference('critical max M [kN*m] = PL/4', cM.value/1e3, P*L/4/1e3, tol), ...
    compareToReference('critical max M at x [m]', cM.x, L/2, tol), ...
    compareToReference('critical max M for x_v [m]', cM.xv, L/2, tol), ...
    compareToReference('R_A max [kN] (load on A)', ml.reactions.Rmax(1)/1e3, P/1e3, tol), ...
    compareToReference('R_A max at x_v [m]', ml.reactions.RmaxXv(1), 0, [], 1e-9), ...
    compareToReference('R_B max [kN] (load on B)', ml.reactions.Rmax(2)/1e3, P/1e3, tol), ...
    compareToReference('R_A min [kN]', ml.reactions.Rmin(1)/1e3, 0, [], 1e-6*P/1e3)]);

%% Two equal axles reach the absolute maximum moment of the resultant rule
L = 20;
P = 100e3;
d = 4.2;
Mref = P * (2*L - d)^2 / (8*L);
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
twoAxle = createVehicle([P P], d, 'two equal axles');
ml = runMovingLoad(model, twoAxle, 'Step', 0.55, 'RefineFactor', 10);
c = ml.critical(1);
fprintf('  coarse step %.4g m: max M %.6f kN*m at x_v = %.4f; refined (%d extra positions): %.6f kN*m at x = %.4f, x_v = %.4f, axles %s\n', ...
    ml.step, c.coarseValue/1e3, c.coarseXv, ml.nRefined, c.value/1e3, c.x, c.xv, mat2str(c.axleX, 6));
underAxle = min(abs(c.axleX - c.x));
reportComparisons(sprintf('Two 100 kN axles at %.1f m on a 20 m span: absolute maximum moment', d), [ ...
    compareToReference('refined max M [kN*m] = P(2L-d)^2/(8L)', c.value/1e3, Mref/1e3, tol), ...
    compareToReference('|x - L/2| [m] = d/4', abs(c.x - L/2), d/4, 100 * 0.06 / (d/4)), ...
    compareToReference('distance from max to nearest axle [m]', underAxle, 0, [], 1e-9), ...
    compareToReference('refined error <= coarse error [-] (1 = yes)', double(abs(c.value - Mref) <= abs(c.coarseValue - Mref)), 1, 1e-9)]);

%% Step convergence of the maximum moment for the two-axle vehicle
% Near the optimum, M under the governing axle is exactly quadratic in x_v:
% M = M* - (2P/L)*(x_v - x_v*)^2 while both axles are on the span. So a grid
% of step h misses M* by at most (2P/L)*(h/2)^2.
L = 20;
P = 100e3;
d = 4.2;
Mref = P * (2*L - d)^2 / (8*L);
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
twoAxle = createVehicle([P P], d, 'two equal axles');
steps = [2.42 1.21 0.605 0.3025];             % 24.2 m of travel / 10, 20, 40, 80
rows = [];
errors = zeros(size(steps));
for k = 1:numel(steps)
    mlc = runMovingLoad(model, twoAxle, 'Step', steps(k), 'Refine', false);
    errors(k) = Mref - mlc.critical(1).value;
    bound = (2*P/L) * (steps(k)/2)^2;
    fprintf('  step %.4f m: max M %.6f kN*m, error %.6f kN*m, bound (2P/L)(h/2)^2 = %.6f kN*m\n', ...
        steps(k), mlc.critical(1).value/1e3, errors(k)/1e3, bound/1e3);
    rows = [rows, compareToReference(sprintf('step %.4f m: error / bound [-] (<= 1)', steps(k)), ...
        errors(k) / bound, 0, [], 1 + 1e-9)]; %#ok<AGROW>
end
mlr = runMovingLoad(model, twoAxle, 'Step', 2.42, 'RefineFactor', 20);
fprintf('  step 2.42 m + refinement x20 (%d extra positions): max M %.6f kN*m\n', mlr.nRefined, mlr.critical(1).value/1e3);
rows = [rows, ...
    compareToReference('step 2.42 m + refinement x20: max M [kN*m]', mlr.critical(1).value/1e3, Mref/1e3, 0.01), ...
    compareToReference('all coarse errors >= 0, i.e. no overshoot (1 = yes) [-]', double(min(errors) >= -1e-9 * Mref), 1, 1e-9)];
reportComparisons('Step convergence, two-axle vehicle (no refinement unless stated)', rows);

%% Spec 3-axle truck on a 20 m simple span matches the resultant rule
L = 20;
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');
ml = runMovingLoad(model, truck, 'Step', 0.1);
c = ml.critical(1);
fprintf('  max M %.4f kN*m at x = %.4f, x_v = %.4f, axles %s (coarse %.4f at x_v = %.2f)\n', ...
    c.value/1e3, c.x, c.xv, mat2str(c.axleX, 6), c.coarseValue/1e3, c.coarseXv);
reportComparisons('Spec 3-axle truck on a 20 m simple span (positions every 0.1 m, refined to 0.01 m)', [ ...
    compareToReference('max M [kN*m]', c.value/1e3, 1349.1025, tol), ...
    compareToReference('x of max M [m] (under the middle axle)', c.x, 9.7375, 100 * 0.01 / 9.7375), ...
    compareToReference('x_v for max M [m]', c.xv, 13.9375, 100 * 0.01 / 13.9375), ...
    compareToReference('R_A max [kN]', ml.reactions.Rmax(1)/1e3, 289.2, tol), ...
    compareToReference('R_A max at x_v [m]', ml.reactions.RmaxXv(1), 5.6, tol), ...
    compareToReference('R_B max [kN]', ml.reactions.Rmax(2)/1e3, 261.2, tol), ...
    compareToReference('R_B max at x_v [m]', ml.reactions.RmaxXv(2), 20, tol), ...
    compareToReference('max upward deflection [mm] (none expected)', ml.critical(5).value*1e3, 0, [], 1e-9)]);

%% Two-span continuous beam: negative moment over the support and uplift
L = 20;
P = 100e3;
[x, xsup] = meshSpans([L L], 16);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, 0), 'pin');
model = addSupport(model, findNodeAtX(model, L), 'roller');
model = addSupport(model, findNodeAtX(model, 2*L), 'roller');
ml = runMovingLoad(model, createVehicle(P, [], 'single axle'), 'Step', 0.1);
B = find(abs(ml.stations - L) < 1e-9);
cMin = ml.critical(2);
aStar = L / sqrt(3);
fprintf('  most negative M %.4f kN*m at x = %.3f m for x_v = %.4f m; R_A min %.4f kN at x_v = %.4f m\n', ...
    cMin.value/1e3, cMin.x, cMin.xv, ml.reactions.Rmin(1)/1e3, ml.reactions.RminXv(1));
reportComparisons('Single 100 kN load on two 20 m spans (16 elements each), positions every 0.1 m, refined', [ ...
    compareToReference('envelope Mmin at B [kN*m] = -PL/(6*sqrt3)', ml.envelope.Mmin(B)/1e3, -P*L/(6*sqrt(3))/1e3, tol), ...
    compareToReference('critical min M [kN*m]', cMin.value/1e3, -P*L/(6*sqrt(3))/1e3, tol), ...
    compareToReference('critical min M at x [m] (support B)', cMin.x, L, tol), ...
    compareToReference('distance of x_v from L/sqrt3 or 2L - L/sqrt3 [m]', min(abs(cMin.xv - [aStar, 2*L - aStar])), 0, [], 0.02), ...
    compareToReference('R_A min [kN] = -P/(6*sqrt3) (uplift)', ml.reactions.Rmin(1)/1e3, -P/(6*sqrt(3))/1e3, tol), ...
    compareToReference('R_A min at x_v [m] = 2L - L/sqrt3', ml.reactions.RminXv(1), 2*L - aStar, 100 * 0.02 / (2*L - aStar)), ...
    compareToReference('R_B max [kN] (load on B)', ml.reactions.Rmax(2)/1e3, P/1e3, tol), ...
    compareToReference('R_A max [kN] (load on A)', ml.reactions.Rmax(1)/1e3, P/1e3, tol)]);

%% Permanent uniform load adds its static response to every envelope
L = 20;
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');
live = runMovingLoad(model, truck, 'Step', 0.2, 'Refine', false);
modelQ = addUniformLoad(model, -20e3);
both = runMovingLoad(modelQ, truck, 'Step', 0.2, 'Refine', false);
st = analyzeVehiclePosition(prepareMovingLoad(modelQ, live.stations), truck, -100, 1);   % truck off the bridge
fields = {'Mmax', 'Mmin', 'Vmax', 'Vmin', 'vmax', 'vmin'};
statics = {max(st.stations.ML, st.stations.MR), min(st.stations.ML, st.stations.MR), ...
    max(st.stations.VL, st.stations.VR), min(st.stations.VL, st.stations.VR), st.stations.v, st.stations.v};
rows = [];
for k = 1:numel(fields)
    f = fields{k};
    diffNorm = max(abs(both.envelope.(f) - (live.envelope.(f) + statics{k}))) / max(abs(both.envelope.(f)));
    rows = [rows, compareToReference(sprintf('max|%s(q + truck) - %s(q) - %s(truck)| / max [-]', f, f, f), diffNorm, 0, [], 1e-9)]; %#ok<AGROW>
end
rows = [rows, compareToReference('R_A max: (q + truck) - truck [kN] = qL/2', (both.reactions.Rmax(1) - live.reactions.Rmax(1))/1e3, 200, 0.1)];
reportComparisons('Superposition: 20 kN/m permanent load + spec truck (same positions)', rows);

%% Reversed travel direction gives the mirror-image envelopes on a symmetric span
L = 20;
model = createBeamModel(generateUniformMesh(L, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec 3-axle example');
fwd = runMovingLoad(model, truck, 'Step', 0.1, 'Direction', 1, 'Refine', false);
bwd = runMovingLoad(model, truck, 'Step', 0.1, 'Direction', -1, 'Refine', false);
assert(max(abs(flipud(L - fwd.stations) - fwd.stations)) < 1e-12, 'stations must be symmetric');
ef = fwd.envelope;
eb = bwd.envelope;
scaleM = max(abs(ef.Mmax));
scaleV = max(abs([ef.Vmax; ef.Vmin]));
scalev = max(abs(ef.vmin));
reportComparisons('Travel toward -x vs toward +x on a symmetric 20 m span (spec truck)', [ ...
    compareToReference('max|Mmax(-x)(x) - Mmax(+x)(L-x)| / max [-]', max(abs(eb.Mmax - flipud(ef.Mmax))) / scaleM, 0, [], 1e-9), ...
    compareToReference('max|vmin(-x)(x) - vmin(+x)(L-x)| / max [-]', max(abs(eb.vmin - flipud(ef.vmin))) / scalev, 0, [], 1e-9), ...
    compareToReference('max|Vmax(-x)(x) + Vmin(+x)(L-x)| / max [-]', max(abs(eb.Vmax + flipud(ef.Vmin))) / scaleV, 0, [], 1e-9), ...
    compareToReference('max|Vmin(-x)(x) + Vmax(+x)(L-x)| / max [-]', max(abs(eb.Vmin + flipud(ef.Vmax))) / scaleV, 0, [], 1e-9), ...
    compareToReference('R_A max (-x) - R_B max (+x) [kN]', (bwd.reactions.Rmax(1) - fwd.reactions.Rmax(2))/1e3, 0, [], 1e-9), ...
    compareToReference('critical max M (-x) - (+x) [kN*m]', (bwd.critical(1).value - fwd.critical(1).value)/1e3, 0, [], 1e-9)]);
