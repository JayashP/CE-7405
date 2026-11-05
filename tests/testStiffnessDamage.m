%TESTSTIFFNESSDAMAGE Stage 2: prescribed EI loss, healthy vs damaged response, sensitivity sweep.
%   Script-based test file (see runAllTests). The damage model is
%   EI_D = (1 - d) EI in chosen elements (PROJECT_SPEC.md section 6). With
%   g = d/(1 - d), so that 1/EI_D = (1 + g)/EI, the fixed references are:
%   * Simple span L, central load P, damage on [a, b] within the left half.
%     Virtual work with M = P*x/2 and m = x/2:
%       delta_mid = P*L^3/(48EI) + g*P*(b^3 - a^3)/(12EI)
%     Reactions and moments are unchanged (statically determinate).
%   * Propped cantilever (fixed at 0, roller at L), uniform q, damage on [a, b].
%     Compatibility of the released cantilever (M0 = -q(L-x)^2/2, m = L-x):
%       R_B = (q/2) * I3 / I2, with
%       I3 = L^4/4 + g*((L-a)^4 - (L-b)^4)/4 and
%       I2 = L^3/3 + g*((L-a)^3 - (L-b)^3)/3
%     (d = 0 gives 3qL/8), and M_A = R_B*L - q*L^2/2.
%   * Two spans L1, L2, uniform q, span 1 damaged (three-moment equation):
%       M_B = -q*(L1^3/EI1 + L2^3/EI2) / (8*(L1/EI1 + L2/EI2)), with EI1 = (1-d)*EI.
EI = 200e9 * 0.01;   % [N*m^2]
tol = 0.1;           % [%]

%% Zero loss reproduces the healthy model and results exactly
model = createBeamModel(generateUniformMesh(20, 8), defineMaterial('steel', 200e9, 0.01));
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
model = addPointLoad(model, 7.3, -100e3);
zero = applyStiffnessDamage(model, 3:5, 0);
assert(isequal(zero, model), 'd = 0 must leave the model unchanged');
back = applyStiffnessDamage(applyStiffnessDamage(model, 4, 0.4), 4, 0);
assert(isequal(back, model), 'setting d = 0 again must restore the healthy model');
assert(isequal(solveStaticModel(zero).U, solveStaticModel(model).U), 'd = 0 must give identical displacements');
fprintf('  PASS d = 0 leaves the model and its solution bit-identical; re-applying d = 0 restores it\n');

%% Only the chosen element changes: K_D - K_H = -d * A_j'' k_j A_j
model = createBeamModel(generateUniformMesh(10, 5), EI);
d = 0.35;
damaged = applyStiffnessDamage(model, 3, d);
KH = full(assembleGlobalK(model));
KD = full(assembleGlobalK(damaged));
dofs = elementDofs(model.elements.conn(3, :));
expected = zeros(size(KH));
expected(dofs, dofs) = -d * beamElementStiffness(EI, 2);
eiH = effectiveEI(model);
eiD = effectiveEI(damaged);
reportComparisons('Stiffness loss d = 0.35 in element 3 of 5', [ ...
    compareToReference('max|(K_D - K_H) - (-d A3'' k3 A3)| / max|K_H| [-]', max(max(abs((KD - KH) - expected))) / max(abs(KH(:))), 0, [], 1e-14), ...
    compareToReference('EI_eff of element 3 [N*m^2] = (1 - d) EI', eiD(3), (1 - d) * EI, 1e-10), ...
    compareToReference('max|EI_eff change| outside element 3 [N*m^2]', max(abs(eiD([1 2 4 5]) - eiH([1 2 4 5]))), 0, [], 1e-9), ...
    compareToReference('material EI of element 3 unchanged [N*m^2]', damaged.elements.EI(3), EI, 1e-10)]);

%% Simply supported beam: damage changes deflection only (statically determinate)
L = 20;
P = 100e3;
a = 3;
b = 7;
d = 0.3;
g = d / (1 - d);
model = buildSimplySupportedCentralLoad(L, 20, EI, P);
damaged = applyStiffnessDamage(model, elementsBetween(model, a, b), d);
rh = solveStaticModel(model);
rd = solveStaticModel(damaged);
mid = findNodeAtX(model, L/2);
deltaRef = P*L^3/(48*EI) + g * P * (b^3 - a^3) / (12*EI);
reportComparisons(sprintf('Simple span, P = %g kN at midspan, d = %g on %g..%g m', P/1e3, d, a, b), [ ...
    compareToReference('max|R_D - R_H| / P [-]', max(abs(rd.R - rh.R)) / P, 0, [], 1e-9), ...
    compareToReference('max|M_D - M_H| / (PL/4) [-] (element ends)', max(abs(rd.elementForces.moment(:) - rh.elementForces.moment(:))) / (P*L/4), 0, [], 1e-9), ...
    compareToReference('healthy |delta_mid| [mm] = PL^3/(48EI)', -rh.v(mid)*1e3, P*L^3/(48*EI)*1e3, tol), ...
    compareToReference('damaged |delta_mid| [mm] (virtual work)', -rd.v(mid)*1e3, deltaRef*1e3, tol), ...
    compareToReference('increase of |delta_mid| [mm]', (rh.v(mid) - rd.v(mid))*1e3, g*P*(b^3 - a^3)/(12*EI)*1e3, tol)]);

%% Propped cantilever: damage redistributes the reactions (statically indeterminate)
L = 10;
q = 20e3;
model = createBeamModel(generateUniformMesh(L, 20), EI);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 21, 'roller');
model = addUniformLoad(model, -q);
rows = [];
regions = [0 2 0.5; 6 8 0.5; 3 5 0.2];
for k = 1:size(regions, 1)
    a = regions(k, 1);
    b = regions(k, 2);
    d = regions(k, 3);
    g = d / (1 - d);
    I3 = L^4/4 + g * ((L - a)^4 - (L - b)^4) / 4;
    I2 = L^3/3 + g * ((L - a)^3 - (L - b)^3) / 3;
    RB = q/2 * I3 / I2;
    res = solveStaticModel(applyStiffnessDamage(model, elementsBetween(model, a, b), d));
    rows = [rows, ...
        compareToReference(sprintf('d = %.1f on %g..%g m: R_B [kN]', d, a, b), res.R(41)/1e3, RB/1e3, tol), ...
        compareToReference(sprintf('d = %.1f on %g..%g m: M_A [kN*m]', d, a, b), res.elementForces.moment(1, 1)/1e3, (RB*L - q*L^2/2)/1e3, tol)]; %#ok<AGROW>
end
healthyRB = solveStaticModel(model).R(41);
rows = [rows, compareToReference('healthy R_B [kN] = 3qL/8', healthyRB/1e3, 3*q*L/8/1e3, tol)];
reportComparisons('Propped cantilever, q = 20 kN/m: R_B redistributes with the damaged region', rows);
fprintf('  R_B healthy %.4f kN; damage near the fixed end lowers the fixed-end restraint, so R_B rises\n', healthyRB/1e3);

%% Two-span beam with span 1 damaged follows the three-moment equation
L1 = 10;
L2 = 15;
q = 20e3;
d = 0.3;
[x, xs] = meshSpans([L1 L2], [8 12]);
model = createBeamModel(x, defineMaterial('steel', 200e9, 0.01));
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
B = findNodeAtX(model, xs(2));
model = addSupport(model, B, 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
model = addUniformLoad(model, -q);
damaged = applyStiffnessDamage(model, elementsBetween(model, xs(1), xs(2)), d);
EI1 = (1 - d) * EI;
MB = -q * (L1^3/EI1 + L2^3/EI) / (8 * (L1/EI1 + L2/EI));
MBh = -q * (L1^3 + L2^3) / (8 * (L1 + L2));
res = solveStaticModel(damaged);
reportComparisons(sprintf('Spans %g + %g m, q = %g kN/m, span 1 with d = %g', L1, L2, q/1e3, d), [ ...
    compareToReference('M_B [kN*m] (three-moment, EI1 = 0.7 EI)', res.elementForces.moment(B, 1)/1e3, MB/1e3, tol), ...
    compareToReference('change of M_B vs healthy [kN*m]', (res.elementForces.moment(B, 1) - solveStaticModel(model).elementForces.moment(B, 1))/1e3, (MB - MBh)/1e3, tol), ...
    compareToReference('R_A [kN] = qL1/2 + M_B/L1', res.R(1)/1e3, (q*L1/2 + MB/L1)/1e3, tol)]);
assert(isequal(damaged.elements.EI, model.elements.EI) && all(damaged.elements.materialId == 1), 'material record unchanged by damage');
fprintf('  PASS material EI and material record unchanged; only stiffnessFactor carries the loss\n');

%% Moving-load comparison: determinate beam keeps forces, continuous beam redistributes
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
model = createBeamModel(generateUniformMesh(20, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
cmpS = compareHealthyDamaged(model, applyStiffnessDamage(model, 4:5, 0.3), truck, 'Step', 0.2, 'Refine', false);
[x, xs] = meshSpans([12 15], [8 10]);
cont = createBeamModel(x, EI);
cont = addSupport(cont, findNodeAtX(cont, xs(1)), 'pin');
cont = addSupport(cont, findNodeAtX(cont, xs(2)), 'roller');
cont = addSupport(cont, findNodeAtX(cont, xs(3)), 'roller');
contD = applyStiffnessDamage(cont, elementsBetween(cont, 6, 12), 0.4);
cmpC = compareHealthyDamaged(cont, contD, truck, 'Step', 0.2, 'Refine', false);
direct = runMovingLoad(contD, truck, 'Step', 0.2, 'Refine', false);
c = cmpS.critical;
fprintf('  simple span: Mmax %.3f -> %.3f kN*m, vmin %.3f -> %.3f mm (%+.2f %%), Mmin pct = %g (healthy ~0)\n', ...
    c(1).healthy/1e3, c(1).damaged/1e3, c(6).healthy*1e3, c(6).damaged*1e3, c(6).pctChange, c(2).pctChange);
fprintf('  continuous: M_B min %.3f -> %.3f kN*m (%+.2f %%), R_B max %.3f -> %.3f kN (%+.2f %%)\n', ...
    cmpC.critical(2).healthy/1e3, cmpC.critical(2).damaged/1e3, cmpC.critical(2).pctChange, ...
    cmpC.reactions(2).healthyMax/1e3, cmpC.reactions(2).damagedMax/1e3, cmpC.reactions(2).pctChangeMax);
reportComparisons('Healthy vs damaged under the spec truck (positions every 0.2 m)', [ ...
    compareToReference('simple span: max |R change| over supports [kN]', max(abs([cmpS.reactions.changeMax, cmpS.reactions.changeMin]))/1e3, 0, [], 1e-6), ...
    compareToReference('simple span: max |Mmax envelope change| [kN*m]', max(abs(cmpS.envelopeChange.Mmax))/1e3, 0, [], 1e-6), ...
    compareToReference('simple span: downward deflection grows, signed pct < 0 (1 = yes)', double(c(6).damaged < c(6).healthy && c(6).pctChange < 0), 1, 1e-9), ...
    compareToReference('simple span: zero healthy Mmin gives NaN percent (1 = yes)', double(isnan(c(2).pctChange)), 1, 1e-9), ...
    compareToReference('continuous: R_B max changes (|change| > 1 kN) (1 = yes)', double(abs(cmpC.reactions(2).changeMax) > 1e3), 1, 1e-9), ...
    compareToReference('continuous: damaged critical M min = direct runMovingLoad [kN*m]', cmpC.critical(2).damaged/1e3, direct.critical(2).value/1e3, 1e-10), ...
    compareToReference('continuous: pct change = 100*(D-H)/|H| [%]', cmpC.critical(2).pctChange, ...
        100*(cmpC.critical(2).damaged - cmpC.critical(2).healthy)/abs(cmpC.critical(2).healthy), 1e-10)]);

%% Moving-load fast path equals the static engine on a damaged model
[x, xs] = meshSpans([12 15], [8 10]);
model = createBeamModel(x, EI);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
model = addUniformLoad(model, -10e3);
damaged = applyStiffnessDamage(model, [3 4 12], [0.5 0.3 0.6]);
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
prep = prepareMovingLoad(damaged, defaultEnvelopeStations(x, 4));
worst = 0;
for xv = [5.3 9.1 19.7]                               % axles inside the damaged elements 3, 4 and 12
    res = analyzeVehiclePosition(prep, truck, xv, 1);
    ref = modelWithVehicle(damaged, truck, xv, 1);
    st = solveStaticModel(ref);
    pts = [res.stations.x; res.axlePoints.x];
    vRef = evaluateDeflection(ref, st.U, pts);
    worst = max([worst, max(abs(res.U - st.U)) / max(abs(st.U)), ...
        max(abs([res.stations.v; res.axlePoints.v] - vRef)) / max(abs(vRef))]);
end
reportComparisons('Damaged two-span model: analyzeVehiclePosition vs static engine (3 positions, axles in damaged elements)', ...
    compareToReference('max normalized difference in U and in v at stations and under axles [-]', worst, 0, [], 1e-9));

%% Sensitivity sweep ranks the midspan elements first for deflection and finds no change in moment
truck = createVehicle(100e3, [], 'single axle');
model = createBeamModel(generateUniformMesh(20, 8), EI);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
sv = damageSensitivity(model, truck, 0.3, 'vmin', 'Step', 0.25, 'Refine', false);
sm = damageSensitivity(model, truck, 0.3, 'Mmax', 'Step', 0.25, 'Refine', false);
sr = damageSensitivity(model, truck, 0.3, 'Rmax', 'Node', 1, 'Step', 0.25, 'Refine', false);
check = runMovingLoad(applyStiffnessDamage(model, 3, 0.3), truck, 'Step', 0.25, 'Refine', false);
fprintf('  vmin per damaged element [mm]: %s (healthy %.4f)\n', mat2str(sv.values.'*1e3, 6), sv.healthy*1e3);
fprintf('  ranking for vmin: %s\n', mat2str(sv.rank.'));
reportComparisons('Sensitivity sweep, d = 0.3 moved over 8 elements, single 100 kN load', [ ...
    compareToReference('vmin: two most influential elements are the middle two (4, 5) (1 = yes)', double(isequal(sort(sv.rank(1:2)).', [4 5])), 1, 1e-9), ...
    compareToReference('vmin: symmetric (max|value(e) - value(9-e)| / |healthy|) [-]', max(abs(sv.values - flipud(sv.values))) / abs(sv.healthy), 0, [], 1e-9), ...
    compareToReference('vmin: every location increases deflection (1 = yes)', double(all(sv.change < 0)), 1, 1e-9), ...
    compareToReference('vmin of element 3 = direct runMovingLoad [mm]', sv.values(3)*1e3, check.critical(6).value*1e3, 1e-10), ...
    compareToReference('Mmax: max |change| over locations [kN*m] (determinate)', max(abs(sm.change))/1e3, 0, [], 1e-6), ...
    compareToReference('R_A max: max |change| over locations [kN] (determinate)', max(abs(sr.change))/1e3, 0, [], 1e-6)]);

%% Invalid damage input is rejected and material reassignment keeps the loss
model = createBeamModel(generateUniformMesh(10, 5), defineMaterial('steel', 200e9, 0.01));
assertThrows(@() applyStiffnessDamage(model, 2, 1), 'BridgeFE:invalidInput');
assertThrows(@() applyStiffnessDamage(model, 2, -0.1), 'BridgeFE:invalidInput');
assertThrows(@() applyStiffnessDamage(model, 6, 0.2), 'BridgeFE:invalidInput');
assertThrows(@() applyStiffnessDamage(model, [1 2], [0.1 0.2 0.3]), 'BridgeFE:invalidInput');
broken = model;
broken.elements.stiffnessFactor(2) = 0;
assertThrows(@() assembleGlobalK(broken), 'BridgeFE:invalidModel');
assertThrows(@() damageSensitivity(model, createVehicle(1e3, []), 0, 'vmin'), 'BridgeFE:invalidInput');
assertThrows(@() damageSensitivity(model, createVehicle(1e3, []), 0.2, 'Rmax'), 'BridgeFE:invalidInput');
damaged = applyStiffnessDamage(model, [2 4], [0.1 0.25]);
damaged = assignMaterial(damaged, defineMaterial('rcc', 32e9, 0.0625), 4);
eff = effectiveEI(damaged);
assert(abs(eff(2) - 0.9*2e9) < 1e-3 && abs(eff(4) - 0.75*2e9) < 1e-3, 'loss is kept when a material is reassigned');
fprintf('  PASS per-element losses 0.1 / 0.25; RCC reassignment of element 4 keeps its 25 %% loss (EI_eff = 1.5e9)\n');
