%TESTINPUTTABLES Table inputs, unit conversion, vehicle presets and drawing labels of the app (M9 part B).
%   Script-based test file (see runAllTests). The app's Bridge model and
%   Vehicle tabs pass their tables to buildModelFromTables and
%   vehicleFromTable in the chosen display units (unitSystem 'SI' or 'US');
%   the engine works in SI. These tests check the conversion against
%   independent constants (international foot 0.3048 m, inch 0.0254 m,
%   pound-force 4.4482216152605 N; NIST SP 811), that every invalid table
%   entry names its row, the vehicle presets, and the drawing labels.
SI = unitSystem('SI');
US = unitSystem('US');
ft = 0.3048;                       % m, exact
inch = 0.0254;                     % m, exact
kip = 1000 * 4.4482216152605;      % N, 1000 lbf
in = struct('spanLengths', [20 20], 'elementsPerSpan', [16 16], 'supportTypes', {{'Pin', 'Roller', 'Roller'}}, ...
    'materialType', 'steel', 'E', 200, 'I', 0.01, 'udlDown', 20);     % two-span Benchmark D as SI tables

%% Support letters run A to Z, then AA, AB, ...; support labels map to the engine types
assert(isequal(supportLetters(4), {'A', 'B', 'C', 'D'}), 'first letters');
letters = supportLetters(703);
assert(isequal(letters([26 27 28 52 53 702 703]), {'Z', 'AA', 'AB', 'AZ', 'BA', 'ZZ', 'AAA'}), 'letters beyond Z');
assert(isequal(size(supportLetters(0)), [1 0]), 'no span ends, no letters');
assertThrows(@() supportLetters(-1), 'BridgeFE:invalidInput');
assertThrows(@() supportLetters(2.5), 'BridgeFE:invalidInput');
[labels, types] = supportTypeList();
assert(isequal(labels, {'Pin', 'Roller', 'Fixed', 'Free'}) && isequal(types, {'pin', 'roller', 'fixed', 'none'}), ...
    'drop-down labels and engine types');
for k = 1:numel(types)
    supportSymbolGeometry(types{k}, 0, 0, 1, 'left', [0 0 0]);      % every engine type can be drawn
end
for k = 1:3
    supportRestraint(types{k});                                     % and pin, roller, fixed are engine supports
end
fprintf('  PASS A..Z, AA, AB, AZ, BA, ZZ, AAA; Pin/Roller/Fixed/Free -> pin/roller/fixed/none\n');

%% SI tables with equal element counts build exactly the model of buildModelFromInputs
old = struct('spans', '20 20', 'elementsPerSpan', 16, 'supports', 'pin roller roller', 'materialType', 'steel', ...
    'E_GPa', 200, 'I_m4', 0.01, 'udlDown_kNpm', 20);
[model, info] = buildModelFromTables(in);
assert(isequal(model, buildModelFromInputs(old)), 'SI tables must give the buildModelFromInputs model');
assert(isequal(buildModelFromTables(in, SI), model), 'U = SI is the default');
cells = in;
cells.spanLengths = {20, 20};                         % a uitable column may come as a cell array
cells.elementsPerSpan = {16; 16};
assert(isequal(buildModelFromTables(cells), model), 'cell-array table columns');
ints = in;
ints.E = int32(200);                                  % integer classes are read as double, not saturated
ints.elementsPerSpan = int32([16 16]);
ints.udlDown = uint8(20);
assert(isequal(buildModelFromTables(ints), model), 'integer-class inputs');
cant = struct('spanLengths', 8, 'elementsPerSpan', 4, 'supportTypes', {{'free', 'FIXED'}}, 'materialType', 'rcc', ...
    'E', 32, 'I', 0.0625, 'materialName', 'Deck', 'materialBasis', 'test Ieff');
oldCant = struct('spans', '8', 'elementsPerSpan', 4, 'supports', 'free FIXED', 'materialType', 'rcc', ...
    'E_GPa', 32, 'I_m4', 0.0625, 'materialName', 'Deck', 'materialBasis', 'test Ieff');
[cantModel, cantInfo] = buildModelFromTables(cant);
assert(isequal(cantModel, buildModelFromInputs(oldCant)), 'Free/Fixed cantilever, RCC, no load field');
assert(isequal(cantInfo.supportTypes, {'Free'; 'Fixed'}), 'labels in their drop-down spelling');
fprintf('  %s\n', info.summary{:});
assert(isequal(info.supportX, [0; 20; 40]) && isequal(info.supportLetters, {'A'; 'B'; 'C'}) ...
    && isequal(info.supportTypes, {'Pin'; 'Roller'; 'Roller'}) && isempty(info.warnings), 'info fields');
expected = {'Spans: 20 + 20 m (total 40 m)'; ...
    'Mesh: 16 + 16 elements per span (32 elements, 33 nodes, 66 DOFs: v and theta at each node)'; ...
    'Supports: A Pin (x = 0 m), B Roller (x = 20 m), C Roller (x = 40 m)'; ...
    'Material: Steel (steel): E = 200 GPa, Is = 0.01 m^4, EI = 2e+06 kN*m^2'; ...
    'Basis: EI = Es*Is (steel section)'; ...
    'Permanent uniform load: 20 kN/m downward'};
assert(isequal(info.summary, expected), 'summary in SI display units');
slip = in;
slip.E = 200e9;                                      % Pa typed into the GPa column
[~, slipInfo] = buildModelFromTables(slip);
assert(numel(slipInfo.warnings) == 1 && ~isempty(strfind(slipInfo.warnings{1}, 'outside the usual')), 'unit warning');
[~, nextInfo] = buildModelFromTables(in);
assert(isempty(nextInfo.warnings), 'no warning carried over from the previous call');
res = solveStaticModel(model);
B = findNodeAtX(model, 20);
reportComparisons('Model from SI tables (two 20 m spans, q = 20 kN/m down): Benchmark D', [ ...
    compareToReference('M_B [kN*m] = -qL^2/8', res.elementForces.moment(B, 1)/1e3, -1000, 0.5), ...
    compareToReference('R_B [kN] = 5qL/4', res.R(2*B - 1)/1e3, 500, 0.5)]);

%% Each span gets its own element count
two = in;
two.spanLengths = [12 15];
two.elementsPerSpan = [8 10];
[model, info] = buildModelFromTables(two);
[x, xs] = meshSpans([12 15], [8 10]);
direct = createBeamModel(x, defineMaterial('steel', 200e9, 0.01));
for k = 1:3
    direct = addSupport(direct, findNodeAtX(direct, xs(k)), lower(two.supportTypes{k}));
end
direct = addUniformLoad(direct, -20e3);
assert(isequal(model, direct), 'per-span element counts: the model built directly with meshSpans([12 15], [8 10])');
assert(numel(model.nodes.x) == 19 && isequal(model.supports.node, [1; 9; 19]), '8 + 10 elements, supports at nodes 1, 9, 19');
assert(abs(model.nodes.x(2) - 1.5) < 1e-12 && abs(model.nodes.x(10) - 13.5) < 1e-12, '1.5 m elements in both spans');
assert(strcmp(info.summary{2}, 'Mesh: 8 + 10 elements per span (18 elements, 19 nodes, 38 DOFs: v and theta at each node)'), ...
    'summary lists the element count of each span');
fprintf('  PASS spans 12 + 15 m with 8 + 10 elements: 19 nodes, supports at nodes 1, 9, 19\n');

%% US customary tables convert exactly to the SI engine model
us = struct('spanLengths', [66 66], 'elementsPerSpan', [16 16], 'supportTypes', {{'Pin', 'Roller', 'Roller'}}, ...
    'materialType', 'steel', 'E', 29000, 'I', 24000, 'udlDown', 1.2);
[model, info] = buildModelFromTables(us, US);
[x, xs] = meshSpans([66 66] * 0.3048, [16 16]);
assert(isequal(model.nodes.x, x) && isequal(info.supportX, xs), 'node and support x = meshSpans(ft x 0.3048)');
fprintf('  %s\n', info.summary{:});
assert(strcmp(info.summary{1}, 'Spans: 66 + 66 ft (total 132 ft)') ...
    && strcmp(info.summary{3}, 'Supports: A Pin (x = 0 ft), B Roller (x = 66 ft), C Roller (x = 132 ft)') ...
    && strcmp(info.summary{4}, sprintf('Material: Steel (steel): E = 29000 ksi, Is = 24000 in^4, EI = %.6g kip*ft^2', ...
        29000 * 24000 / 144)) ...
    && strcmp(info.summary{6}, 'Permanent uniform load: 1.2 kip/ft downward'), 'summary in US display units');
assert(isempty(info.warnings), '29000 ksi = 199.9 GPa is a usual steel modulus');
res = solveStaticModel(model);
B = findNodeAtX(model, 66 * ft);
reportComparisons('US tables (two 66 ft spans, E = 29000 ksi, I = 24000 in^4, q = 1.2 kip/ft) -> SI engine', [ ...
    compareToReference('E [Pa] = 29000 ksi x (kip/in^2)', model.materials(1).E, 29000 * kip / inch^2, 1e-12), ...
    compareToReference('I [m^4] = 24000 in^4 x 0.0254^4', model.materials(1).I, 24000 * inch^4, 1e-12), ...
    compareToReference('EI [N*m^2] = E*I', model.elements.EI(1), (29000 * kip / inch^2) * (24000 * inch^4), 1e-12), ...
    compareToReference('w [N/m] = -1.2 kip/ft', max(model.loads.elementUDL), -1.2 * kip / ft, 1e-12), ...
    compareToReference('w [N/m] (smallest element value)', min(model.loads.elementUDL), -1.2 * kip / ft, 1e-12), ...
    compareToReference('beam length [m] = 132 ft', model.nodes.x(end), 132 * ft, 1e-12), ...
    compareToReference('M_B [kip*ft] = -qL^2/8 = -653.4', res.elementForces.moment(B, 1) / (kip * ft), -653.4, 0.5), ...
    compareToReference('R_B [kip] = 5qL/4 = 99', res.R(2*B - 1) / kip, 99, 0.5)]);

%% Every invalid table entry gives an error that names its row
bad = @(field, value) setfield(in, field, value); %#ok<SFLD>
cases = { ...
    @() buildModelFromTables(bad('spanLengths', [20 -5])), 'BridgeFE:invalidInput', 'Span 2: length must be a positive number (m)'; ...
    @() buildModelFromTables(bad('spanLengths', {20, 'abc'})), 'BridgeFE:invalidInput', 'Span 2: length must be a positive number'; ...
    @() buildModelFromTables(bad('spanLengths', [NaN 20])), 'BridgeFE:invalidInput', 'Span 1: length must be a positive number'; ...
    @() buildModelFromTables(bad('spanLengths', [66 0]), US), 'BridgeFE:invalidInput', 'Span 2: length must be a positive number (ft)'; ...
    @() buildModelFromTables(bad('spanLengths', [])), 'BridgeFE:invalidInput', 'Add at least one span'; ...
    @() buildModelFromTables(bad('elementsPerSpan', [16 0])), 'BridgeFE:invalidInput', 'Span 2: elements must be a whole number from 1 to 2000'; ...
    @() buildModelFromTables(bad('elementsPerSpan', [2.5 16])), 'BridgeFE:invalidInput', 'Span 1: elements must be a whole number'; ...
    @() buildModelFromTables(bad('elementsPerSpan', [16 2001])), 'BridgeFE:invalidInput', 'Span 2: elements must be a whole number'; ...
    @() buildModelFromTables(bad('elementsPerSpan', 16)), 'BridgeFE:invalidInput', 'Give the number of elements for each of the 2 span(s); 1 given'; ...
    @() buildModelFromTables(bad('supportTypes', {'Pin', 'Roller', 'Hinge'})), 'BridgeFE:invalidSupportType', 'Support C: unknown type'; ...
    @() buildModelFromTables(bad('supportTypes', {'Pin', 'Guided', 'Roller'})), 'BridgeFE:invalidSupportType', 'Support B: unknown type'; ...
    @() buildModelFromTables(bad('supportTypes', {'Pin', [], 'Roller'})), 'BridgeFE:invalidSupportType', 'Support B: unknown type'; ...
    @() buildModelFromTables(bad('supportTypes', {'Pin', 'Roller'})), 'BridgeFE:invalidInput', 'Give one support type for each of the 3 span ends (A to C); 2 given'; ...
    @() buildModelFromTables(bad('supportTypes', {'Free', 'Free', 'Free'})), 'BridgeFE:underRestrained', 'Under-restrained model'; ...
    @() buildModelFromTables(bad('E', 0)), 'BridgeFE:invalidInput', 'E [GPa] must be'; ...
    @() buildModelFromTables(bad('I', -1), US), 'BridgeFE:invalidInput', 'I [in^4] must be'; ...
    @() buildModelFromTables(bad('udlDown', -5)), 'BridgeFE:invalidInput', 'Enter the uniform load as a downward magnitude (>= 0) in kN/m'; ...
    @() buildModelFromTables(bad('materialType', 'timber')), 'BridgeFE:invalidMaterial', 'Material type must be'; ...
    @() vehicleFromTable([80 0 120], [4.2 1.4]), 'BridgeFE:invalidVehicle', 'Axle 2: load must be a positive number (kN)'; ...
    @() vehicleFromTable({80, 120, 'x'}, [4.2 1.4]), 'BridgeFE:invalidVehicle', 'Axle 3: load must be a positive number'; ...
    @() vehicleFromTable([80 120 120], [4.2 -1.4]), 'BridgeFE:invalidVehicle', 'Axle 3: spacing from axle 2 must be a positive number (m)'; ...
    @() vehicleFromTable([8 32 32], [NaN 14], '', US), 'BridgeFE:invalidVehicle', 'Axle 2: spacing from axle 1 must be a positive number (ft)'; ...
    @() vehicleFromTable([8 32 32], 14, '', US), 'BridgeFE:invalidVehicle', 'Give 2 spacing(s) for 3 axle(s)'; ...
    @() vehicleFromTable([], []), 'BridgeFE:invalidVehicle', 'Add at least one axle'};
for k = 1:size(cases, 1)
    message = '';
    id = '';
    try
        cases{k, 1}();
    catch err
        message = err.message;
        id = err.identifier;
    end
    prefix = cases{k, 3};
    assert(strcmp(id, cases{k, 2}) && strncmp(message, prefix, numel(prefix)), ...
        'case %d: expected "%s..." [%s], got "%s" [%s]', k, prefix, cases{k, 2}, message, id);
    fprintf('  PASS [%s] %s\n', id, message);
end
many = in;
many.spanLengths = ones(1, 27);                       % 28 span ends: A ... Z, AA, AB
many.elementsPerSpan = ones(1, 27);
many.supportTypes = [{'Pin'}, repmat({'Roller'}, 1, 26), {'Hinge'}];
message = '';
try
    buildModelFromTables(many);
catch err
    message = err.message;
end
assert(strncmp(message, 'Support AB: unknown type', numel('Support AB: unknown type')), 'row names beyond Z');
many.supportTypes{end} = 'roller';
[~, info] = buildModelFromTables(many);
assert(strcmp(info.supportLetters{27}, 'AA') && strcmp(info.supportLetters{28}, 'AB') ...
    && ~isempty(strfind(info.summary{3}, 'AB Roller (x = 27 m)')), 'letters beyond Z in the model info');
fprintf('  PASS 28 span ends: the last is support AB (x = 27 m)\n');

%% Vehicle tables give the engine vehicle in SI
v = vehicleFromTable([80 120 120], [4.2 1.4], 'spec truck');
assert(isequal(v, createVehicle([80e3 120e3 120e3], [4.2 1.4], 'spec truck')) ...
    && isequal(v, vehicleFromInputs('80 120 120', '4.2 1.4', 'spec truck')), 'SI axle table = createVehicle in N and m');
assert(isequal(vehicleFromTable({80; 120; 120}, {4.2; 1.4}, 'spec truck', SI), v), 'cell-array table columns, U = SI');
oneAxle = vehicleFromTable(100, [], '');
assert(isequal(oneAxle, vehicleFromInputs('100', '', '')) && strcmp(oneAxle.name, 'vehicle'), 'single axle, default name');
hl = vehicleFromTable([8 32 32], [14 14], 'HL-93 axles', US);
reportComparisons('US axle table (8, 32, 32 kip; 14, 14 ft) -> SI engine vehicle', [ ...
    compareToReference('front axle [N] = 8 kip', hl.axleLoads(1), 8 * kip, 1e-12), ...
    compareToReference('middle axle [N] = 32 kip', hl.axleLoads(2), 32 * kip, 1e-12), ...
    compareToReference('rear axle [N] = 32 kip', hl.axleLoads(3), 32 * kip, 1e-12), ...
    compareToReference('spacing 1-2 [m] = 14 ft', hl.axleSpacings(1), 14 * ft, 1e-12), ...
    compareToReference('spacing 2-3 [m] = 14 ft', hl.axleSpacings(2), 14 * ft, 1e-12)]);

%% Vehicle presets convert exactly between SI and US customary units
pSI = vehiclePresets(SI);
pUS = vehiclePresets(US);
assert(isequal(vehiclePresets(), pSI), 'SI is the default');
names = {'Illustrative 3-axle truck (spec)', 'AASHTO HL-93 design truck (axles only)', 'Custom'};
assert(isequal({pSI.name}, names) && isequal({pUS.name}, names) && isequal({pSI.note}, {pUS.note}), 'names and notes');
assert(isequal(pSI(1).loads, [80 120 120]) && isequal(pSI(1).spacings, [4.2 1.4]), 'spec truck as typed in SI');
assert(isequal(pUS(2).loads, [8 32 32]) && isequal(pUS(2).spacings, [14 14]), 'HL-93 axles as typed in US units');
assert(isempty(pSI(3).loads) && isempty(pSI(3).spacings) && isempty(pUS(3).loads) && isempty(pUS(3).spacings), ...
    'Custom carries no axles (the app keeps its table)');
hlNote = pSI(2).note;
assert(~isempty(strfind(hlNote, 'Axle loads only')) && ~isempty(strfind(hlNote, 'no design lane load')) ...
    && ~isempty(strfind(hlNote, 'no dynamic load allowance')) && ~isempty(strfind(hlNote, '14-30 ft')) ...
    && ~isempty(strfind(hlNote, 'AASHTO LRFD 3.6.1.2.2')) && ~isempty(strfind(pSI(1).note, 'not an AASHTO design truck')), ...
    'notes state what the presets leave out');
fprintf('  %s: %s\n', pSI(2).name, hlNote);
relDiff = @(a, b) max(abs(a(:) - b(:)) ./ abs(b(:)));
assert(relDiff(pUS(1).loads * kip / 1e3, [80 120 120]) < 1e-14 && relDiff(pUS(1).spacings * ft, [4.2 1.4]) < 1e-14 ...
    && relDiff(pSI(2).loads * 1e3 / kip, [8 32 32]) < 1e-14 && relDiff(pSI(2).spacings / ft, [14 14]) < 1e-14, ...
    'display values convert with the exact factors, both ways');
for k = 1:2
    a = vehicleFromTable(pSI(k).loads, pSI(k).spacings, pSI(k).name, SI);
    b = vehicleFromTable(pUS(k).loads, pUS(k).spacings, pUS(k).name, US);
    assert(relDiff(a.axleLoads, b.axleLoads) < 1e-14 && relDiff(a.axleSpacings, b.axleSpacings) < 1e-14, ...
        'the same engine vehicle from either unit system');
end
truckSI = vehicleFromTable(pSI(2).loads, pSI(2).spacings, pSI(2).name, SI);
truckUS = vehicleFromTable(pUS(2).loads, pUS(2).spacings, pUS(2).name, US);
fprintf('  HL-93 axles from the SI preset: %s N, spacings %s m\n', mat2str(truckSI.axleLoads.', 10), mat2str(truckSI.axleSpacings.', 10));
reportComparisons('vehicleFromTable of the HL-93 preset (SI and US presets)', [ ...
    compareToReference('SI preset: front axle [N] = 35585.77', truckSI.axleLoads(1), 35585.77, 1e-5), ...
    compareToReference('SI preset: rear axles [N] = 142343.09', truckSI.axleLoads(3), 142343.09, 1e-5), ...
    compareToReference('SI preset: spacing [m] = 4.2672', truckSI.axleSpacings(2), 4.2672, 1e-12), ...
    compareToReference('US preset: front axle [N] = 35585.77', truckUS.axleLoads(1), 35585.77, 1e-5), ...
    compareToReference('US preset: middle axle [N] = 142343.09', truckUS.axleLoads(2), 142343.09, 1e-5), ...
    compareToReference('US preset: spacing [m] = 4.2672', truckUS.axleSpacings(1), 4.2672, 1e-12)]);
spec = vehicleFromTable(pUS(1).loads, pUS(1).spacings, pUS(1).name, US);
reportComparisons('vehicleFromTable of the spec-truck preset in US units', [ ...
    compareToReference('front axle [N] = 80 kN', spec.axleLoads(1), 80e3, 1e-12), ...
    compareToReference('rear axle [N] = 120 kN', spec.axleLoads(3), 120e3, 1e-12), ...
    compareToReference('spacing 1-2 [m] = 4.2', spec.axleSpacings(1), 4.2, 1e-12), ...
    compareToReference('spacing 2-3 [m] = 1.4', spec.axleSpacings(2), 1.4, 1e-12)]);

%% Drawing: bold support letters below the span ends and load texts in the display units
th = appTheme();
[model, info] = buildModelFromTables(in);               % 2 x 20 m, q = 20 kN/m
model = addPointLoad(model, 30, -100e3);
model = addNodalLoad(model, findNodeAtX(model, 10), 0, 30e3);
h = 0.04 * 40;
ends = struct('x', info.supportX, 'text', {info.supportLetters});
prims = bridgeDrawing(model, struct('EndLabels', ends));
bold = prims(arrayfun(@(p) strcmp(p.kind, 'text') && strcmp(p.fontWeight, 'bold'), prims));
assert(isequal({bold.text}, {'A', 'B', 'C'}) && isequal([bold.x], [0 20 40]) && all(strcmp({bold.vAlign}, 'top')) ...
    && all(abs([bold.y] + 1.55*h) < 1e-12), 'bold letters A, B, C at the span ends, top at y = -1.55 h');
shapes = prims(~strcmp({prims.kind}, 'text'));
assert(max([bold.y]) < min([shapes.y]), 'letters below every support symbol');
drawSI = bridgeDrawing(model);
assert(~any(strcmp({drawSI.fontWeight}, 'bold')), 'no bold text without EndLabels');
assertThrows(@() bridgeDrawing(model, struct('EndLabels', struct('x', [0 20 40], 'text', {{'A', 'B'}}))), 'BridgeFE:invalidInput');
drawUS = bridgeDrawing(model, struct('Units', US));
assert(isequal(bridgeDrawing(model, struct('Units', SI)), drawSI), 'Units = SI is the default');
assert(all(ismember({'q = 20 kN/m', '100 kN', '30 kN*m (CCW)'}, {drawSI.text})), 'SI load texts');
usTexts = {sprintf('q = %g kip/ft', 20e3 / (kip / ft)), sprintf('%g kip', 100e3 / kip), ...
    sprintf('%g kip*ft (CCW)', 30e3 / (kip * ft))};
fprintf('  US load texts: %s\n', strjoin(usTexts, ' | '));
assert(all(ismember(usTexts, {drawUS.text})) && ~any(ismember({'q = 20 kN/m', '100 kN', '30 kN*m (CCW)'}, {drawUS.text})), ...
    'US load texts');
assert(isequal([drawUS.x], [drawSI.x]) && isequal([drawUS.y], [drawSI.y]), 'Units change texts only; coordinates stay in m');
fprintf('  PASS bold A, B, C below the symbols; load texts in kN, kN/m, kN*m or kip, kip/ft, kip*ft\n');

%% Drawing: close axles share one label and the uniform-load label sits at the left end of its load
th = appTheme();
model = createBeamModel(generateUniformMesh(40, 16), 2e9);       % 6 % of 40 m = 2.4 m
model = addSupport(model, 1, 'pin');
model = addSupport(model, 17, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
prep = prepareMovingLoad(model, defaultEnvelopeStations(model.nodes.x, 4));
isLabel = @(p, c) strcmp(p.kind, 'text') && isequal(p.color, c);
res = analyzeVehiclePosition(prep, truck, 30, 1);                % axles at 30, 25.8, 24.4 m
prims = bridgeDrawing(model, struct('Axles', res.axles));
lab = prims(arrayfun(@(p) isLabel(p, th.vehicle), prims));
assert(isequal({lab.text}, {'2 x 120 kN', '80 kN'}) && abs(lab(1).x - 25.1) < 1e-9 && abs(lab(2).x - 30) < 1e-9, ...
    'rear axles 1.4 m apart (< 2.4 m) share one label at their middle');
stems = prims(arrayfun(@(p) strcmp(p.kind, 'line') && numel(p.x) == 2 && p.x(1) == p.x(2) && isequal(p.color, th.vehicle), prims));
assert(numel(stems) == 3, 'every axle keeps its arrow');
prims = bridgeDrawing(model, struct('Axles', res.axles, 'Units', US));
lab = prims(arrayfun(@(p) isLabel(p, th.vehicle), prims));
assert(isequal({lab.text}, {sprintf('2 x %g kip', 120e3 / kip), sprintf('%g kip', 80e3 / kip)}), 'merged label in kip');
other = createVehicle([80e3 120e3 120e3], [1.4 4.2]);
res = analyzeVehiclePosition(prep, other, 10, -1);               % moving left: axles at 10, 11.4, 15.6 m
prims = bridgeDrawing(model, struct('Axles', res.axles, 'Direction', -1));
lab = prims(arrayfun(@(p) isLabel(p, th.vehicle), prims));
assert(isequal({lab.text}, {'80 + 120 kN', '120 kN'}) && abs(lab(1).x - 10.7) < 1e-9, 'different loads listed left to right');
res = analyzeVehiclePosition(prep, truck, 1, 1);                 % entering: axles at 1, -3.2, -4.6 m
prims = bridgeDrawing(model, struct('Axles', res.axles));
offLab = prims(arrayfun(@(p) isLabel(p, th.vehicleOff), prims));
onLab = prims(arrayfun(@(p) isLabel(p, th.vehicle), prims));
assert(isequal({offLab.text}, {'120 kN', '120 kN'}) && isequal({onLab.text}, {'80 kN'}), 'axles off the bridge keep their own labels');
short = createBeamModel(generateUniformMesh(20, 8), 2e9);         % 6 % of 20 m = 1.2 m < 1.4 m
short = addSupport(short, 1, 'pin');
short = addSupport(short, 9, 'roller');
res = analyzeVehiclePosition(prepareMovingLoad(short, defaultEnvelopeStations(short.nodes.x, 4)), truck, 18, 1);
prims = bridgeDrawing(short, struct('Axles', res.axles));
lab = prims(arrayfun(@(p) isLabel(p, th.vehicle), prims));
assert(isequal({lab.text}, {'120 kN', '120 kN', '80 kN'}), 'axles 1.4 m apart on a 20 m beam keep their own labels');
[x, xs] = meshSpans([20 20], [8 8]);
twoSpan = createBeamModel(x, 2e9);
twoSpan = addSupport(twoSpan, 1, 'pin');
twoSpan = addSupport(twoSpan, 9, 'roller');
twoSpan = addSupport(twoSpan, 17, 'roller');
loaded = addUniformLoad(twoSpan, -20e3, elementsBetween(twoSpan, 20, 40));
q = bridgeDrawing(loaded);
q = q(strcmp({q.text}, 'q = 20 kN/m'));
assert(numel(q) == 1 && q.x == 20 && strcmp(q.hAlign, 'left'), 'load on span 2: label left-aligned at x = 20 m');
loaded = addUniformLoad(addUniformLoad(twoSpan, -10e3, 1:8), -20e3, 9:16);
q = bridgeDrawing(loaded);
q = q(strncmp({q.text}, 'q = ', 4));
assert(isequal({q.text}, {'q = 10 kN/m', 'q = 20 kN/m'}) && isequal([q.x], [0 20]) && all(strcmp({q.hAlign}, 'left')), ...
    'two load runs: each label at the left end of its run');
fprintf('  PASS ''2 x 120 kN'' and ''80 + 120 kN'' merged labels, separate labels off the bridge and on a short beam; q labels left-aligned\n');

%% Drawing with node numbers leaves out the numbers where a support letter is drawn
[x, xs] = meshSpans([20 20], [8 8]);
model = createBeamModel(x, 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
model = addSupport(model, 17, 'roller');
nodeText = arrayfun(@(n) sprintf('%d', n), 1:17, 'UniformOutput', false);
isNumber = @(p) strcmp(p.kind, 'text') && strcmp(p.fontWeight, 'normal') && any(strcmp(p.text, nodeText));
plain = bridgeDrawing(model, struct('ShowNumbers', true));
assert(nnz(arrayfun(isNumber, plain)) == 17, 'all 17 node numbers without end labels');
prims = bridgeDrawing(model, struct('ShowNumbers', true, 'EndLabels', struct('x', xs, 'text', {{'A', 'B', 'C'}})));
numbers = prims(arrayfun(isNumber, prims));
assert(numel(numbers) == 14 && ~any(ismember([numbers.x], [0 20 40])) && ~any(ismember({numbers.text}, {'1', '9', '17'})), ...
    'node numbers 1, 9 and 17 give way to the letters A, B, C');
assert(nnz(arrayfun(@(p) strcmp(p.kind, 'text') && strcmp(p.fontWeight, 'bold'), prims)) == 3, 'three letters');
fprintf('  PASS 14 node numbers + letters A, B, C (numbers 1, 9, 17 left out)\n');
