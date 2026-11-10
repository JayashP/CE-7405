%TESTDRAWINGGEOMETRY Geometry of the beam drawing: support symbols, loads, vehicle and limits.
%   Script-based test file (see runAllTests). The app draws exactly the
%   primitives returned by bridgeDrawing (renderDrawing only loops over
%   them), so the conventional symbols required by PROJECT_SPEC.md section 9
%   are checked here as data: a pin triangle on a hatched ground line, a
%   roller triangle on two wheels, and a fixed wall hatched outside the beam.

%% Pin, roller and fixed symbols have the conventional geometry
h = 2;
pin = supportSymbolGeometry('pin', 5, 0, h, 'left', [0 0 0]);
tri = pin(1);
assert(strcmp(tri.kind, 'patch') && isequal(tri.x, [5, 4, 6]) && isequal(tri.y, [0, -2, -2]), 'pin triangle: apex at node, base h below');
ground = pin(2);
assert(strcmp(ground.kind, 'line') && all(ground.y == -h) && ground.x(1) < 4 && ground.x(2) > 6, 'pin sits on a ground line');
assert(numel(pin) == 8 && all(strcmp({pin(3:end).kind}, 'line')), 'pin ground line carries 6 hatch strokes');
roller = supportSymbolGeometry('roller', 0, 0, h, 'left', [0 0 0]);
patches = roller(strcmp({roller.kind}, 'patch'));
wheelBottom = min(patches(2).y);
groundY = roller(4).y(1);
assert(numel(patches) == 3 && abs(wheelBottom - groundY) < 1e-12 && max(patches(1).y) == 0, ...
    'roller: triangle with apex at node on two wheels touching the ground line');
left = supportSymbolGeometry('fixed', 0, 0, h, 'left', [0 0 0]);
right = supportSymbolGeometry('fixed', 10, 0, h, 'right', [0 0 0]);
assert(isequal(left(1).x, [0 0]) && isequal(left(1).y, [-h h]), 'fixed wall through the node');
hatchL = [left(2:end).x];
hatchR = [right(2:end).x];
assert(all(hatchL <= 0) && all(hatchR >= 10), 'wall hatching lies outside the beam (left end: x <= 0, right end: x >= L)');
assert(isempty(supportSymbolGeometry('none', 0, 0, h, 'left', [0 0 0])), 'no symbol for a free end');
assertThrows(@() supportSymbolGeometry('hinge', 0, 0, h, 'left', [0 0 0]), 'BridgeFE:invalidSupportType');
fprintf('  PASS pin (triangle + ground + 6 hatch strokes), roller (triangle on 2 wheels on ground), fixed (wall, hatch outside), none\n');

%% Beam drawing contains every support, load and label
model = createBeamModel(generateUniformMesh(10, 8), 2e9);
model = addSupport(model, 1, 'fixed');
model = addSupport(model, 5, 'pin');
model = addSupport(model, 9, 'roller');
model = addUniformLoad(model, -20e3, 1:4);
model = addPointLoad(model, 7.3, -100e3);
model = addNodalLoad(model, 7, 0, 30e3);
th = appTheme();
prims = bridgeDrawing(model, struct('ShowNumbers', true));
kinds = {prims.kind};
texts = {prims(strcmp(kinds, 'text')).text};
beam = prims(1);
assert(strcmp(beam.kind, 'line') && isequal(beam.x, [0 10]) && isequal(beam.y, [0 0]), 'beam along y = 0 from x_1 to x_n');
assert(any(strcmp(texts, 'q = 20 kN/m')) && any(strcmp(texts, '100 kN')) && any(strcmp(texts, '30 kN*m (CCW)')), 'load labels');
nodeLabels = sum(ismember(texts, arrayfun(@(n) sprintf('%d', n), 1:9, 'UniformOutput', false)));
elementLabels = sum(ismember(texts, arrayfun(@(n) sprintf('(%d)', n), 1:8, 'UniformOutput', false)));
assert(nodeLabels == 9 && elementLabels == 8, 'node and element numbers');
loadPrims = prims(arrayfun(@(p) isequal(p.color, th.load), prims));
udlArrowHeads = sum(arrayfun(@(p) strcmp(p.kind, 'patch') && max(p.y) > 0 && min(p.x) >= 0 && max(p.x) <= 5, loadPrims));
assert(udlArrowHeads >= 5, 'uniform load drawn as a row of arrows over 0..5 m');
pointHead = loadPrims(arrayfun(@(p) strcmp(p.kind, 'patch') && abs(p.x(1) - 7.3) < 1e-12, loadPrims));
assert(numel(pointHead) == 1 && pointHead.y(1) > 0 && pointHead.y(2) > pointHead.y(1), 'point-load arrowhead at 7.3 m, pointing down onto the beam');
fprintf('  PASS beam, 3 supports, %d uniform-load arrowheads, point load at 7.3 m, couple, 9 node + 8 element labels\n', udlArrowHeads);

%% Vehicle axles on and off the bridge and the deformed shape are drawn distinctly
model = createBeamModel(generateUniformMesh(12, 6), 2e9);
model = addSupport(model, 7, 'fixed');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
prep = prepareMovingLoad(model, defaultEnvelopeStations(model.nodes.x, 4));
res = analyzeVehiclePosition(prep, truck, 3, 1);
d = responseDiagramData(res);
th = appTheme();
prims = bridgeDrawing(model, struct('Axles', res.axles, 'Deformed', struct('x', d.x, 'y', d.v * 50), 'DeformedLabel', 'deformed x 50'));
stems = prims(arrayfun(@(p) strcmp(p.kind, 'line') && numel(p.x) == 2 && p.x(1) == p.x(2) ...
    && (isequal(p.color, th.vehicle) || isequal(p.color, th.vehicleOff)), prims));
on = stems(arrayfun(@(p) isequal(p.color, th.vehicle), stems));
off = stems(arrayfun(@(p) isequal(p.color, th.vehicleOff), stems));
assert(numel(on) == 1 && on.x(1) == 3 && strcmp(on.lineStyle, '-'), 'front axle at 3 m on the bridge: solid, vehicle colour');
assert(numel(off) == 2 && all(arrayfun(@(p) strcmp(p.lineStyle, ':') && p.x(1) < 0, off)), 'two axles off the bridge: dotted, grey');
deformed = prims(arrayfun(@(p) isequal(p.color, th.deformed) && strcmp(p.kind, 'line'), prims));
assert(numel(deformed) == 1 && strcmp(deformed.lineStyle, '--') && abs(min(deformed.y) - 50*min(d.v)) < 1e-12, 'deformed shape: dashed, magnified v');
fprintf('  PASS 1 axle on the bridge (solid), 2 off (dotted grey), dashed deformed shape magnified x50\n');

%% Damaged elements are overdrawn in the damage colour with their EI factor
model = createBeamModel(generateUniformMesh(20, 8), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
damaged = applyStiffnessDamage(model, [3 4], 0.30);
damaged = applyStiffnessDamage(damaged, 5, 0.50);         % adjacent run, different factor
th = appTheme();
prims = bridgeDrawing(model, struct('StiffnessFactor', damaged.elements.stiffnessFactor));
runs = prims(arrayfun(@(p) strcmp(p.kind, 'line') && isequal(p.color, th.damage), prims));
labels = prims(arrayfun(@(p) strcmp(p.kind, 'text') && isequal(p.color, th.damage), prims));
assert(numel(runs) == 2 && isequal(runs(1).x, [5 10]) && isequal(runs(2).x, [10 12.5]), ...
    'one thick line per run of equal factors: 5-10 m and 10-12.5 m');
assert(all([runs.lineWidth] > 3), 'damage lines thicker than the beam');
assert(isequal(sort({labels.text}), {'EI x 0.50', 'EI x 0.70'}), 'labels give the EI factor');
plain = bridgeDrawing(model, struct('StiffnessFactor', ones(8, 1)));
assert(~any(arrayfun(@(p) isequal(p.color, th.damage), plain)), 'healthy factors draw no highlight');
fprintf('  PASS 2 adjacent damaged runs (5-10 m x0.70, 10-12.5 m x0.50) highlighted; none for a healthy model\n');

%% Axis limits contain every primitive and leave room for labels
model = createBeamModel(generateUniformMesh(20, 8), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 9, 'roller');
model = addPointLoad(model, 10, -100e3);
prims = bridgeDrawing(model);
[xl, yl] = drawingLimits(prims);
xs = [prims.x];
ys = [prims.y];
label = prims(strcmp({prims.text}, '100 kN'));
fprintf('  limits x %s m, y %s m; label anchor y = %.3f m\n', mat2str(xl, 4), mat2str(yl, 4), label.y);
assert(xl(1) < min(xs) && xl(2) > max(xs) && yl(1) < min(ys) && yl(2) > max(ys), 'limits contain all coordinates');
assert(yl(2) >= label.y + 0.03 * (max(xs) - min(xs)), 'room above a bottom-aligned label');
assertThrows(@() drawingPrimitive('line', 0, 0, [0 0 0], 'colour', [1 0 0]), 'BridgeFE:invalidInput');
fprintf('  PASS limits contain every primitive with label room above\n');
