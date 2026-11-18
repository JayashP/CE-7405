%TESTGUIHELPERS Input parsing, model/vehicle building and table data used by the app.
%   Script-based test file (see runAllTests). The app only calls these
%   helpers and the verified engine, so checking them here (in MATLAB and in
%   GNU Octave) covers the app's input conversion and displayed numbers.
%   Display units: m, kN, kN/m, GPa, m^4; engine units: SI.
in = struct('spans', '20 20', 'elementsPerSpan', 16, 'supports', 'pin roller roller', ...
    'materialType', 'steel', 'E_GPa', 200, 'I_m4', 0.01, 'materialName', '', 'materialBasis', '', ...
    'udlDown_kNpm', 20);                                 % two-span Benchmark D inputs
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);   % spec 3-axle example

%% Numbers typed in text fields are parsed without evaluating code
assert(isequal(parseNumberList('20 20', 'spans'), [20 20]), 'spaces');
assert(isequal(parseNumberList('80, 120,120', 'loads'), [80 120 120]), 'commas');
assert(isequal(parseNumberList(' 4.2;1.4 ', 'spacings'), [4.2 1.4]), 'semicolons and padding');
assert(isequal(parseNumberList([12 15], 'spans'), [12 15]), 'numeric input');
assert(isequal(parseNumberList('1e3 2.5E-1', 'x'), [1000 0.25]), 'exponents');
fprintf('  PASS parsed ''20 20'', ''80, 120,120'', '' 4.2;1.4 '', [12 15], ''1e3 2.5E-1''\n');
assertThrows(@() parseNumberList('', 'spans'), 'BridgeFE:invalidInput');
assertThrows(@() parseNumberList('20 abc', 'spans'), 'BridgeFE:invalidInput');
assertThrows(@() parseNumberList('Inf', 'spans'), 'BridgeFE:invalidInput');
assertThrows(@() parseNumberList('2i', 'spans'), 'BridgeFE:invalidInput');
assertThrows(@() parseNumberList('exit', 'spans'), 'BridgeFE:invalidInput');

%% App model inputs build exactly the model built directly with the engine (Benchmark D)
[model, info] = buildModelFromInputs(in);
[x, xs] = meshSpans([20 20], 16);
direct = createBeamModel(x, defineMaterial('steel', 200e9, 0.01));
direct = addSupport(direct, findNodeAtX(direct, xs(1)), 'pin');
direct = addSupport(direct, findNodeAtX(direct, xs(2)), 'roller');
direct = addSupport(direct, findNodeAtX(direct, xs(3)), 'roller');
direct = addUniformLoad(direct, -20e3);
assert(isequal(model, direct), 'GUI-built model must equal the directly built model');
res = solveStaticModel(model);
B = findNodeAtX(model, 20);
fprintf('  %s\n', info.summary{:});
assert(isempty(info.warnings) && isequal(info.supportX, [0; 20; 40]), 'info fields');
reportComparisons('Model from app inputs (two 20 m spans, q = 20 kN/m down): Benchmark D', [ ...
    compareToReference('M_B [kN*m] = -qL^2/8', res.elementForces.moment(B, 1)/1e3, -1000, 0.5), ...
    compareToReference('R_B [kN] = 5qL/4', res.R(2*B - 1)/1e3, 500, 0.5)]);

%% Support entries, RCC material and unit warnings are converted correctly
cant = struct('spans', '8', 'elementsPerSpan', 4, 'supports', 'free FIXED', 'materialType', 'rcc', ...
    'E_GPa', 32, 'I_m4', 0.0625, 'materialName', 'Deck', 'materialBasis', 'test Ieff');
[model, ~] = buildModelFromInputs(cant);
assert(isequal(model.supports.node, 5) && strcmp(model.supports.type{1}, 'fixed'), 'free end + fixed end');
assert(strcmp(model.materials(1).type, 'rcc') && model.materials(1).EI == 2e9 && strcmp(model.materials(1).name, 'Deck'), 'RCC material');
assert(all(model.loads.elementUDL == 0), 'no uniform load when the field is absent');
slip = in;
slip.E_GPa = 200e9;                       % Pa typed into the GPa field
[~, info] = buildModelFromInputs(slip);
fprintf('  unit-slip warning reported to the app: %s\n', info.warnings{1});
assert(numel(info.warnings) == 1 && ~isempty(strfind(info.warnings{1}, 'outside the usual')), 'unit warning must be reported');
fprintf('  PASS ''free FIXED'' -> cantilever fixed at the right end; RCC EI = 2e9; unit slip reported\n');

%% Invalid model inputs give clear errors instead of a model
bad = in;
bad.supports = 'pin roller';                          % 2 entries for 3 span ends
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:invalidInput');
bad.supports = 'pin hinge roller';
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:invalidSupportType');
bad.supports = 'none none none';
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:underRestrained');
bad = in;
bad.spans = '20';
bad.supports = 'pin none';
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:underRestrained');
bad = in;
bad.udlDown_kNpm = -5;
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:invalidInput');
bad = in;
bad.E_GPa = 0;
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:invalidInput');
bad = in;
bad.elementsPerSpan = 2.5;
assertThrows(@() buildModelFromInputs(bad), 'BridgeFE:invalidInput');

%% Vehicle inputs in kN and m build the engine vehicle
v = vehicleFromInputs('80 120 120', '4.2 1.4', 'spec truck');
ref = createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec truck');
assert(isequal(v, ref), 'vehicle from app inputs must equal createVehicle in SI');
single = vehicleFromInputs('100', '', '');
assert(isequal(single.axleLoads, 100e3) && isempty(single.axleSpacings), 'single axle with empty spacing field');
fprintf('  PASS ''80 120 120'' kN / ''4.2 1.4'' m -> createVehicle([80e3 120e3 120e3], [4.2 1.4]); single axle accepted\n');
assertThrows(@() vehicleFromInputs('80 120', '4.2 1.4', ''), 'BridgeFE:invalidVehicle');
assertThrows(@() vehicleFromInputs('80 -120', '4.2', ''), 'BridgeFE:invalidVehicle');

%% The static path used by the Matrices tab reproduces the moving-load position
[x, xs] = meshSpans([12 15], [8 10]);
model = createBeamModel(x, 2e9);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
model = addUniformLoad(model, -10e3);
prep = prepareMovingLoad(model, defaultEnvelopeStations(x, 4));
worst = 0;
for xv = [0 3 12 16.4 29.9 32.6]
    res = analyzeVehiclePosition(prep, truck, xv, 1);
    st = solveStaticModel(modelWithVehicle(model, truck, xv, 1));
    worst = max([worst, max(abs(st.U - res.U)) / max(abs(st.U)), max(abs(st.R - res.R)) / max(abs(st.R))]);
end
reportComparisons('modelWithVehicle + solveStaticModel vs analyzeVehiclePosition (6 positions)', ...
    compareToReference('max normalized difference in U and R [-]', worst, 0, [], 1e-9));

%% Diagram data list both limits at every point, sorted along the beam
[x, xs] = meshSpans([12 15], [8 10]);
model = createBeamModel(x, 2e9);
model = addSupport(model, findNodeAtX(model, xs(1)), 'pin');
model = addSupport(model, findNodeAtX(model, xs(2)), 'roller');
model = addSupport(model, findNodeAtX(model, xs(3)), 'roller');
prep = prepareMovingLoad(model, defaultEnvelopeStations(x, 4));
res = analyzeVehiclePosition(prep, truck, 16.4, 1);
d = responseDiagramData(res);
n = numel(res.stations.x) + numel(res.axlePoints.x);
assert(numel(d.x) == 2*n && all(diff(d.x) >= 0), 'two rows per point, sorted by x');
k = find(abs(d.x - 12.2) < 1e-9);                       % the axle at 16.4 - 4.2 = 12.2 m
fprintf('  rows at the axle x = 12.2 m: V = %s kN\n', mat2str(d.V(k).'/1e3, 6));
reportComparisons('Shear jump under the 120 kN axle at x = 12.2 m in the diagram data', ...
    compareToReference('V(x+) - V(x-) [kN]', (d.V(k(end)) - d.V(k(1)))/1e3, -120, 0.1));

%% Table data match the moving-load results they display
model = createBeamModel(generateUniformMesh(20, 8), 2e9);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 9, 'roller');
ml = runMovingLoad(model, truck, 'Step', 0.5);
[data, cols] = criticalTableData(ml);
assert(isequal(size(data), [6 7]) && numel(cols) == 7, 'critical table is 6 x 7');
assert(abs(str2double(data{1, 3}) - ml.critical(1).value/1e3) < 1e-3 && abs(str2double(data{5, 3}) - ml.critical(5).value*1e3) < 1e-3, ...
    'critical values shown in kN*m and mm');
[rdata, rcols] = reactionEnvelopeTableData(ml, model.nodes.x);
assert(isequal(size(rdata), [3 7]) && strcmp(rdata{2, 3}, 'couple [kN*m]') && numel(rcols) == 7, 'fixed support gives a couple row');
assert(abs(str2double(rdata{1, 4}) - ml.reactions.Rmax(1)/1e3) < 1e-3, 'reaction maxima in kN');
res = analyzeVehiclePosition(prepareMovingLoad(model, defaultEnvelopeStations(model.nodes.x, 4)), truck, 12, 1);
[cdata, ~] = currentReactionTableData(res, model);
assert(strcmp(cdata{1, 3}, 'fixed') && ~strcmp(cdata{1, 5}, '-') && strcmp(cdata{2, 5}, '-'), 'couple only at the fixed support');
assert(abs(str2double(cdata{1, 4}) + str2double(cdata{2, 4}) - 320) < 1e-3, 'reactions add up to the 320 kN truck');
labels = dofLabels(2);
theta = 'theta';                                     % Octave: single-byte characters
if ~exist('OCTAVE_VERSION', 'builtin')
    theta = char(952);                               % MATLAB: Greek theta
end
assert(isequal(labels, {'v1', [theta '1'], 'v2', [theta '2']}), 'DOF labels');
cells = formatMatrixCells([0 2e9; -1.5 0.000123456], '%.4g');
assert(isequal(cells, {'0', '2e+09'; '-1.5', '0.0001235'}), 'formatted matrix cells');
fprintf('  PASS critical (6x7), reaction envelope (3x7) and current reaction tables; DOF labels; matrix cells\n');

%% Damage-tab inputs and tables match the Stage 2 engine
model = createBeamModel(generateUniformMesh(20, 8), 2e9);      % propped cantilever, 2.5 m elements
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 9, 'roller');
[damaged, els, info] = damageModelFromInputs(model, 5, 10, 30);
assert(isequal(els(:)', [3 4]) && isequal(damaged, applyStiffnessDamage(model, [3 4], 0.30)), ...
    '5-10 m, 30 %: elements 3-4 with factor 0.70');
assert(~isempty(strfind(info.summary, 'Elements 3-4')) && ~isempty(strfind(info.summary, '0.7 EI')), 'damage summary text');
same = damageModelFromInputs(model, 5, 10, 0);
assert(isequal(same.elements.stiffnessFactor, ones(8, 1)), 'd = 0 % leaves the model healthy');
assertThrows(@() damageModelFromInputs(model, 5, 10, 100), 'BridgeFE:invalidInput');
assertThrows(@() damageModelFromInputs(model, 5, 10, -1), 'BridgeFE:invalidInput');
assertThrows(@() damageModelFromInputs(model, 5, 11, 30), 'BridgeFE:notOnNode');
cmp = compareHealthyDamaged(model, damaged, truck, 'Step', 0.5);
[data, cols] = damageComparisonTableData(cmp);
assert(numel(cols) == 5 && isequal(size(data), [6 + 2*2, 5]), '6 extremes + max/min of 2 vertical reactions (no couple rows)');
r5 = find(strcmp(data(:, 1), 'Deflection v min [mm]'));
c5 = cmp.critical(strcmp({cmp.critical.quantity}, 'v') & strcmp({cmp.critical.extreme}, 'min'));
assert(numel(r5) == 1 && abs(str2double(data{r5, 2}) - c5.healthy*1e3) < 1e-3 ...
    && abs(str2double(data{r5, 4}) - c5.change*1e3) < 1e-3 ...
    && abs(str2double(data{r5, 5}) - c5.pctChange) < 1e-2, 'v min row: mm, change and signed %');
assert(c5.change < 0 && str2double(data{r5, 5}) < 0, 'larger downward deflection: negative change and %');
cmpSame = compareHealthyDamaged(model, model, truck, 'Step', 0.5);
cmpSame.critical(1).healthy = 0;  cmpSame.critical(1).pctChange = NaN;   % a zero healthy value
dataSame = damageComparisonTableData(cmpSame);
assert(strcmp(dataSame{1, 5}, 'n/a (healthy = 0)') && strcmp(dataSame{2, 4}, '0.000') && strcmp(dataSame{2, 5}, '0.00'), ...
    'zero healthy value shown as n/a; zero change shown without a sign');
[code, items] = sensitivityQuantityCode();
assert(isempty(code) && numel(items) == 6, '6 sensitivity quantities');
assert(strcmp(sensitivityQuantityCode(items{1}), 'vmin') && strcmp(sensitivityQuantityCode(items{6}), 'Rmax'), 'labels map to codes');
assertThrows(@() sensitivityQuantityCode('deflection'), 'BridgeFE:invalidInput');
s = damageSensitivity(model, truck, 0.30, 'vmin', 'Step', 1, 'Refine', false);
[sdata, scols] = sensitivityTableData(s, model);
assert(isequal(size(sdata), [8 6]) && strcmp(scols{4}, 'vmin [mm]'), 'one row per element, vmin in mm');
top = s.rank(1);
assert(strcmp(sdata{1, 1}, '1') && strcmp(sdata{1, 2}, sprintf('%d', top)) ...
    && abs(str2double(sdata{1, 5}) - s.change(top)*1e3) < 1e-4, 'rank 1 is the largest |change|');
assert(all(diff(abs(cellfun(@str2double, sdata(:, 5)))) <= 1e-4), 'rows sorted by |change|, largest first');
q = quantityDisplay('M');
assert(strcmp(q.unit, 'kN*m') && q.scale == 1e-3, 'moment display unit');
q = quantityDisplay('v');
assert(strcmp(q.unit, 'mm') && q.scale == 1e3, 'deflection display unit');
fprintf('  PASS damage inputs (elements 3-4, factor 0.70), comparison table (10 rows), sensitivity ranking (8 rows)\n');

%% Table numbers never show a negative zero, and the findings name the determinacy
assert(strcmp(formatNumber(-2.3e-12, 3), '0.000') && strcmp(formatNumber(-0.0004, 3, true), '0.000'), 'round-off is 0.000');
assert(strcmp(formatNumber(-0.0006, 3), '-0.001') && strcmp(formatNumber(5.9136, 3, true), '+5.914') ...
    && strcmp(formatNumber(-23.7349, 2, true), '-23.73') && strcmp(formatNumber(1349.1024, 3), '1349.102'), 'rounding and sign');
assert(strcmp(formatNumber(NaN, 2), 'n/a'), 'NaN shown as n/a');
simple = createBeamModel(generateUniformMesh(20, 8), 2e9);              % 2.5 m elements
simple = addSupport(simple, 1, 'pin');
simple = addSupport(simple, 9, 'roller');
cmp = compareHealthyDamaged(simple, applyStiffnessDamage(simple, 3:4, 0.3), truck, 'Step', 0.5);
lines = damageComparisonSummary(cmp, simple);
iv = strcmp({cmp.critical.quantity}, 'v') & strcmp({cmp.critical.extreme}, 'min');
assert(numel(lines) == 3 && ~isempty(strfind(lines{1}, 'Statically determinate')), 'simple span: determinate');
assert(~isempty(strfind(lines{2}, 'Deflection v min')) && ~isempty(strfind(lines{2}, 'larger magnitude')) ...
    && ~isempty(strfind(lines{2}, formatNumber(cmp.critical(iv).pctChange, 2, true))), 'largest change: downward deflection');
assert(strcmp(lines{3}, 'Vertical reactions: unchanged (to 0.001 kN).'), 'simple span: reactions unchanged');
propped = createBeamModel(generateUniformMesh(20, 8), 2e9);
propped = addSupport(propped, 1, 'fixed');
propped = addSupport(propped, 9, 'roller');
cmp = compareHealthyDamaged(propped, applyStiffnessDamage(propped, 1:2, 0.5), truck, 'Step', 0.5);
lines = damageComparisonSummary(cmp, propped);
assert(~isempty(strfind(lines{1}, 'indeterminate beam (degree 1)')) && ~isempty(strfind(lines{3}, 'Largest reaction change')), ...
    'propped cantilever: degree 1, reactions redistribute');
both = addSupport(createBeamModel(generateUniformMesh(20, 8), 2e9), 1, 'fixed');
both = addSupport(both, 9, 'fixed');
lines = damageComparisonSummary(compareHealthyDamaged(both, both, truck, 'Step', 1), both);
assert(~isempty(strfind(lines{1}, '(degree 2)')) && strcmp(lines{2}, 'Largest change of an extreme: none (to the decimals shown).'), ...
    'fixed-fixed: degree 2; no damage gives no change');
crit = criticalTableData(runMovingLoad(simple, truck, 'Step', 0.5));
reac = reactionEnvelopeTableData(runMovingLoad(simple, truck, 'Step', 0.5), simple.nodes.x);
assert(~any(strcmp([crit(:); reac(:)], '-0.000')), 'Envelopes tables: round-off is 0.000, never -0.000');
fprintf('  PASS formatNumber (no -0.000, also in the Envelopes tables); findings: simple span determinate, propped degree 1, fixed-fixed degree 2\n');

%% Theme colours are valid RGB triplets
th = appTheme();
names = fieldnames(th);
for k = 1:numel(names)
    c = th.(names{k});
    assert(isnumeric(c) && isequal(size(c), [1 3]) && all(c >= 0 & c <= 1), 'colour %s invalid', names{k});
end
fprintf('  PASS %d theme colours are RGB triplets in [0, 1]\n', numel(names));
