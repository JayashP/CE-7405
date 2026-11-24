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
% Matrices tab: MATLAB's solver returned U = -0 for theta1 with the truck at the start (V-031); '%.6g' printed "-0".
res = solveStaticModel(simple);
res.F(2) = -0; res.U(2) = -0; res.R(3) = -0;            % negative zeros as the solver can return them
dofRows = dofTableData(simple.nodes.x, res);
assert(isequal(size(dofRows), [18 7]) && ~any(strcmp(dofRows(:), '-0')) ...
    && strcmp(dofRows{2, 5}, '0') && strcmp(dofRows{2, 6}, '0') && strcmp(dofRows{3, 7}, '0'), ...
    'Matrices tab DOF table: a negative zero in F, U or R is shown as 0, never -0');
assert(strcmp(dofRows{1, 4}, 'restrained') && strcmp(dofRows{3, 4}, 'free') && strcmp(dofRows{17, 3}, '20') ...
    && strcmp(dofRows{1, 7}, sprintf('%.6g', res.R(1))) && strcmp(dofRows{5, 6}, sprintf('%.6g', res.U(5))), ...
    'Matrices tab DOF table: status, node x and nonzero F, U, R as before (%.6g)');
fprintf('  PASS formatNumber (no -0.000, also in the Envelopes tables); no -0 in the Matrices tab DOF table; findings: simple span determinate, propped degree 1, fixed-fixed degree 2\n');

%% Drawing and diagram labels are clipped to the axes, and peak labels face the inside of the plot
% MATLAB draws text outside the axes unless Clipping is on, so after a zoom the labels of the hidden part
% were left beside the axes (user's MATLAB screenshot, 2026-11-19).
opt = @(t, name) t.options{find(strcmp(t.options, name), 1) + 1};
ax = RecordingAxes();
renderDrawing(ax, bridgeDrawing(buildModelFromInputs(in), struct('ShowNumbers', true)));
objs = recorded(ax).Objects;
texts = objs(strcmp({objs.kind}, 'text'));
clipped = arrayfun(@(t) any(strcmp(t.options, 'Clipping')) && strcmp(opt(t, 'Clipping'), 'on'), texts);
assert(numel(texts) > 20 && all(clipped), 'every drawing label is clipped to the axes (%d of %d)', ...
    nnz(clipped), numel(texts));
ax = RecordingAxes();
plotDiagram(ax, [0; 5; 10], [0; 1; 4], [0 0 1], 'v [mm]', 'first diagram, cleared by the next call');
plotDiagram(ax, [0; 5; 10], [-3; 0; 2], [0 0 1], 'M [kN*m]', 'minimum at the left end, maximum at the right end');
objs = recorded(ax).Objects;
labels = objs(strcmp({objs.kind}, 'text'));
assert(numel(labels) == 2, 'plotDiagram clears the axes and labels both extremes of the last diagram');
assert(strcmp(opt(labels(1), 'String'), '2 ') && strcmp(opt(labels(1), 'HorizontalAlignment'), 'right') ...
    && strcmp(opt(labels(1), 'VerticalAlignment'), 'bottom'), 'a peak in the right half is labelled on its left');
assert(strcmp(opt(labels(2), 'String'), ' -3') && strcmp(opt(labels(2), 'HorizontalAlignment'), 'left') ...
    && strcmp(opt(labels(2), 'VerticalAlignment'), 'top'), 'a peak in the left half is labelled on its right');
assert(all(arrayfun(@(t) strcmp(opt(t, 'Clipping'), 'on'), labels)), 'diagram peak labels are clipped to the axes');
% Round-off is not a peak: the user's MATLAB Vehicle tab labelled M = -1.164e-13 kN*m at the pinned end (V-030).
ax = RecordingAxes();
plotDiagram(ax, [0; 3.3; 20], [0; 219.2; -1.164e-13], [0 0 1], 'M [kN*m]', 'round-off at the pinned end');
objs = recorded(ax).Objects;
labels = objs(strcmp({objs.kind}, 'text'));
assert(numel(labels) == 1 && strcmp(opt(labels(1), 'String'), ' 219.2'), ...
    'a round-off minimum (-1.164e-13 against 219.2) gets no label; the maximum keeps its label');
ax = RecordingAxes();
plotDiagram(ax, [0; 10; 20], [3e-15; -24.925; 0], [0 0 1], 'v [mm]', 'round-off above zero at a support');
objs = recorded(ax).Objects;
labels = objs(strcmp({objs.kind}, 'text'));
assert(numel(labels) == 1 && strcmp(opt(labels(1), 'VerticalAlignment'), 'top'), ...
    'a round-off maximum (3e-15 against -24.925) gets no label; the minimum keeps its label');
ax = RecordingAxes();
plotDiagram(ax, [0; 3.3; 20], [0; 2.192e-10; -1.164e-22], [0 0 1], 'M [kN*m]', 'the same diagram scaled by 1e-12');
objs = recorded(ax).Objects;
labels = objs(strcmp({objs.kind}, 'text'));
assert(numel(labels) == 1 && strcmp(opt(labels(1), 'String'), ' 2.192e-10'), ...
    'the round-off bound is relative: the diagram scaled by 1e-12 keeps its maximum label and drops the round-off one');
ax = RecordingAxes();
plotDiagram(ax, [0; 3.3; 20], [0; 219.2; -1e-6], [0 0 1], 'M [kN*m]', 'a small but real minimum');
objs = recorded(ax).Objects;
labels = objs(strcmp({objs.kind}, 'text'));
assert(numel(labels) == 2 && strcmp(opt(labels(2), 'String'), '-1e-06 '), ...
    'a small real minimum (-1e-6 against 219.2, above the 1e-9 round-off bound) is still labelled');
fprintf('  PASS %d drawing labels and the diagram peak labels are clipped to the axes; peak labels face inwards; no label for round-off\n', numel(texts));

%% Information boxes: formatted HTML keeps the engine's words, highlights numbers and colours flags
h = htmlPanel(struct('title', 'T & <x>', 'items', {{'Spans: 20 m (total 40 m)', ...
    'S1 HL-93 2D 3-axle x_v 5-6.25 m; -7.5 mm; 1e-05 m; +11.4 %; seed 1.', {'warn', 'FIT CHECK FAILED: S = 39.5 > 22.4'}, ...
    {'ok', 'Fit check passed: S = 10.6 <= 22.4'}, '[warn] Truck', 'element 5, node 7, Elements 7-10, section 7, element(s) 4'}}, ...
    'kind', 'list'));
assert(~isempty(strfind(h, '<h4>T &amp; &lt;x&gt;</h4>')), 'headings are escaped');
assert(~isempty(strfind(h, '<b>Spans</b>: <span class="num">20 m</span> (total <span class="num">40 m</span>)')), ...
    'short label in bold, numbers with their unit highlighted');
assert(~isempty(strfind(h, 'S1 HL-93 2D 3-axle x_v <span class="num">5-6.25 m</span>; <span class="num">-7.5 mm</span>; ')) ...
    && ~isempty(strfind(h, '<span class="num">1e-05 m</span>; <span class="num">+11.4 %</span>; seed 1.')), ...
    'names (S1, HL-93, 2D, 3-axle, x_v) and the seed left alone; ranges, both signs, exponents highlighted');
assert(~isempty(strfind(h, '<li>element 5, node 7, Elements 7-10, section 7, element(s) 4</li>')), ...
    'element, node and section numbers are identifiers, not results');
assert(~isempty(strfind(h, '<li class="warn">&#9888;&#65038; <b>FIT CHECK FAILED</b>: S = <span class="num">39.5</span> &gt; ')) ...
    && ~isempty(strfind(h, '<li class="ok">&#10004;&#65038; <b>Fit check passed</b>')), ...
    'warning and pass items coloured, with text (not emoji) signs');
assert(~isempty(strfind(h, '<li>[warn] Truck</li>')), 'typed text cannot set a colour: the class comes with the item');
assert(~isempty(strfind(h, 'li.warn,li.ok{list-style:none;')) && ~isempty(strfind(h, 'overflow-wrap:anywhere')), ...
    'signs replace the bullets; long words wrap');
assertThrows(@() htmlPanel(struct('title', '', 'items', {{{'red', 'x'}}}, 'kind', 'list')), 'BridgeFE:invalidInput');
assert(~isempty(strfind(infoPanelHtml('message', {'1. Check the sensors'}), '<p>1. Check the sensors</p>')), ...
    'a step number is not a result');
summary = {'Spans: 12 + 15 m (total 27 m)'; 'Mesh: 8 + 8 elements per span'; ...
    'Supports: A Pin (x = 0 m), B Roller (x = 12 m), C Roller (x = 27 m)'; 'Material: RCC (rcc): E = 32 GPa'; ...
    'Basis: EI = Ec*Ieff'; 'Permanent uniform load: 10 kN/m downward'};
m = infoPanelHtml('model', summary);
plain = regexprep(regexprep(m, '<style>.*</style>', ''), '<[^>]*>', '');
assert(~isempty(strfind(m, '<h4>Supports</h4><ul><li>A Pin (x = <span class="num">0 m</span>)</li><li>B Roller')), ...
    'one bullet per support');
assert(~isempty(strfind(plain, 'Not a load rating or design check.')) && ~isempty(strfind(m, 'class="note"')), ...
    'modelling notes in grey');
assert(~isempty(strfind(m, 'column-count:2')) && isempty(strfind(infoPanelHtml('findings', {'a'; 'b'}), 'column-count')), ...
    'the wide model summary flows into two columns, other boxes do not');
for k = [1 2 4 5 6]
    assert(~isempty(strfind(plain, regexprep(summary{k}, '^[^:]*: ', ''))), 'summary line %d kept word for word', k);
end
lines = {'Method: noise-based region'; 'Best fit (smallest noise-weighted misfit S): element 5'; ...
    'No damage cannot be ruled out: the healthy model is also inside the region.'; 'Fit check passed: S = 9.8 <= 22.4'; ...
    'Synthetic test case (hidden from the search): NO damage'; 'Self-generated readings: algorithm check.'};
flagsIn = lines(3);
r = infoPanelHtml('identSummary', lines, flagsIn);
order = cellfun(@(t) strfind(r, t), {'<b>Method</b>', '<h4>Result</h4>', '<h4>Checks and flags</h4>', ...
    '<h4>Test case</h4>', '<h4>Notes</h4>'});
assert(all(diff(order) > 0) && isempty(strfind(r, '<h4>Method</h4>')), 'Summary sections in order, no repeated heading');
assert(~isempty(strfind(r, '<li class="warn">&#9888;&#65038; <b>No damage cannot be ruled out</b>')) ...
    && ~isempty(strfind(r, '<li class="ok">&#10004;&#65038; <b>Fit check passed</b>')), 'flag orange, passed check green');
ratioFlag = 'No noise level stated: the listed candidates are NOT a confidence region.';
rr = infoPanelHtml('identSummary', {'Method: no noise level stated, so ...'; 'Best fit (smallest RMSE): element 5'}, {ratioFlag});
assert(~isempty(strfind(rr, ['<li class="warn">&#9888;&#65038; <b>No noise level stated</b>: the listed candidates are ' ...
    'NOT a confidence region.</li>'])), 'a flag that is not one of the lines (ratio method) is shown with the checks');
b = infoPanelHtml('identBox', [lines(2); flagsIn; {'Full result: "Summary" tab.'}], flagsIn);
assert(numel(strfind(b, 'class="warn"')) == 1 && ~isempty(strfind(b, '<li class="note"><b>Full result</b>')) ...
    && strfind(b, 'class="warn"') < strfind(b, 'Best fit (smallest') && isempty(strfind(b, '<h4>')), ...
    'left box: flags first (orange), then the best fit, pointer grey, no heading');
assert(isempty(strfind(infoPanelHtml('message', {'Press a button.'}), '<h4>')), 'messages have no heading');
assertThrows(@() infoPanelHtml('unknown', {'x'}), 'BridgeFE:invalidInput');
fprintf('  PASS formatted boxes: words kept, names untouched, numbers and flags highlighted, sections in order\n');

%% Sensor and truck-position tables are read row by row, with errors that name the row
SIu = unitSystem('SI');
USu = unitSystem('US');
assert(isequal(coordinatesFromTable({5; 10; 15}, 'Sensor', 'x', SIu), [5 10 15]), 'cell column in m');
assert(isequal(coordinatesFromTable([10 20], 'Sensor', 'x', USu), [10 20] * 0.3048), 'numeric column in ft');
cases = {@() coordinatesFromTable({5; NaN}, 'Sensor', 'x', SIu), 'Sensor 2: x must be a number (m).'; ...
    @() coordinatesFromTable({5; 'a'}, 'Sensor', 'x', SIu), 'Sensor 2: x must be a number (m).'; ...
    @() coordinatesFromTable({1; 2; Inf}, 'Truck position', 'x_v', USu), 'Truck position 3: x_v must be a number (ft).'; ...
    @() coordinatesFromTable(cell(0, 1), 'Sensor', 'x', SIu), 'Add at least one sensor.'};
for k = 1:size(cases, 1)
    [msg, id] = errorMessage(cases{k, 1});
    assert(strcmp(id, 'BridgeFE:invalidInput') && strcmp(msg, cases{k, 2}), 'case %d: %s', k, msg);
end
fprintf('  PASS coordinate tables: m and ft, row-named errors, empty table refused\n');

%% The unit-slip message uses the unit the user typed in
USu = unitSystem('US');                   % each section runs on its own in runAllTests
[~, infoUS] = buildModelFromTables(struct('spanLengths', 66, 'elementsPerSpan', 8, 'supportTypes', {{'Pin', 'Roller'}}, ...
    'materialType', 'steel', 'E', 200, 'I', 24000), USu);           % 200 typed as if GPa, in a ksi field
range = materialModulusRange('steel') / USu.modulus.toSI;
assert(numel(infoUS.warnings) == 1 && strcmp(infoUS.warnings{1}, sprintf(['Steel modulus E = 200 ksi is outside the ' ...
    'usual %g-%g ksi. Check the units; the model was still built.'], range(1), range(2))), 'ksi message');
slip = struct('spanLengths', 20, 'elementsPerSpan', 4, 'supportTypes', {{'Pin', 'Roller'}}, ...
    'materialType', 'rcc', 'E', 3e10, 'I', 0.01);   % 3e10 GPa: the engine would warn (in Pa)
before = warning('query', 'BridgeFE:unusualModulus');
warning('on', 'BridgeFE:unusualModulus');
printed = evalc('[~, slipInfo] = buildModelFromTables(slip);');   % what reaches the Command Window
after = warning('query', 'BridgeFE:unusualModulus');
warning(before.state, 'BridgeFE:unusualModulus');
% lastwarn cannot tell: MATLAB records a warning that is turned off, Octave does not.
assert(isempty(strfind(lower(printed), 'warning')) && numel(slipInfo.warnings) == 1, ...
    'no engine warning (in Pa) printed: the app shows its own message');
assert(strcmp(after.state, 'on'), 'the warning is turned on again after the build');
assert(isequal(materialModulusRange('rcc'), [10e9 70e9]) && isequal(materialModulusRange('Steel'), [150e9 250e9]), 'ranges');
assertThrows(@() materialModulusRange('timber'), 'BridgeFE:invalidMaterial');
fprintf('  PASS unit-slip message in ksi: %s\n', infoUS.warnings{1});

%% Healthy vs damaged envelopes: four solid curves, one colour each, healthy drawn on top
th = appTheme();
ax = RecordingAxes();
xs = [0; 5; 10];
plotEnvelopeComparison(ax, xs, [1; 3; 1], [-1; -2; -1], [1; 4; 1], [-1; -3; -1], [th.healthyMax; th.healthyMin], ...
    [th.damagedMax; th.damagedMin], 'M [kN*m]', 'Moment envelope');
rec = recorded(ax);
curves = rec.Objects(arrayfun(@(o) numel(o.x) == 3, rec.Objects));
opt = @(o, name) o.options{find(strcmp(o.options, name), 1) + 1};
cols = cell2mat(arrayfun(@(o) opt(o, 'Color'), curves(:), 'UniformOutput', false));
assert(numel(curves) == 4 && isequal(cols, [th.damagedMax; th.damagedMin; th.healthyMax; th.healthyMin]), ...
    'damaged drawn first, healthy on top, one colour per curve');
assert(~any(arrayfun(@(o) any(strcmp(o.options, 'LineStyle')), curves)), 'all solid: no dash styles');
assert(all(arrayfun(@(o) opt(o, 'LineWidth'), curves(1:2)) > arrayfun(@(o) opt(o, 'LineWidth'), curves(3:4))), ...
    'damaged thick, healthy thin');
assert(isequal(rec.Legend, {'damaged max', 'damaged min', 'healthy max', 'healthy min'}), 'legend');
assert(size(unique([th.healthyMax; th.healthyMin; th.damagedMax; th.damagedMin], 'rows'), 1) == 4, 'four distinct colours');
fprintf('  PASS healthy vs damaged: 4 solid curves in 4 colours, healthy thin on top\n');

%% Theme colours are valid RGB triplets
th = appTheme();
names = fieldnames(th);
for k = 1:numel(names)
    c = th.(names{k});
    assert(isnumeric(c) && isequal(size(c), [1 3]) && all(c >= 0 & c <= 1), 'colour %s invalid', names{k});
end
fprintf('  PASS %d theme colours are RGB triplets in [0, 1]\n', numel(names));
