%TESTIDENTIFICATIONHELPERS Stage 3 app helpers: defaults, synthetic readings, options, tables, text, drawing.
%   Script-based test file (see runAllTests). The Identification tab only
%   calls these helpers and the verified engine (identifySingleDamage), so
%   checking them here covers the numbers, tables, text and drawing
%   primitives the tab shows. The fit chart (plotFitProfile) and readings
%   plot (plotReadings) are checked object by object in
%   checkBridgeConditionApp, and their rendering by the MATLAB run.
%   Display units: m, mm, %.
model = createBeamModel(generateUniformMesh(20, 20), 2e9);   % 1 m elements, EI = 2e9 N*m^2
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);       % spec 3-axle example
positions = [5 10 15 20 25];                                 % front-axle positions [m]
sensors = [5 10 15];                                         % L/4, L/2, 3L/4

%% Default sensors and truck positions follow the spec and drop positions with no axle on the beam
[s, p] = identificationDefaults(model, truck, 1);
assert(isequal(s, [5 10 15]) && isequal(p, [5 10 15 20 25]), 'spec section 7 layout for a 20 m span');
[~, p] = identificationDefaults(model, truck, -1);
assert(isequal(p, [15 10 5 0 -5]), 'travel toward -x: positions measured from the right end');
one = createVehicle(100e3, []);
[~, p] = identificationDefaults(model, one, 1);
assert(isequal(p, [5 10 15]), 'single axle: at 25 m it is off the beam, at 20 m on the support (zero readings): both left out');
two = createBeamModel(meshSpans([12 15], 8), 2e9);
two = addSupport(addSupport(addSupport(two, 1, 'pin'), 9, 'roller'), 17, 'roller');
[s, p] = identificationDefaults(two, truck, 1);
assert(isequal(s, [6.75 13.5 20.25]) && isequal(p, [6.75 13.5 20.25 27]), '27 m: 33.75 m dropped (all axles off)');
assert(strcmp(numberListText([6.75 13.5 20]), '6.75 13.5 20') && isequal(parseNumberList(numberListText(p), 'p'), p), ...
    'list text round trip');
twoEqual = createBeamModel(meshSpans([10 10], 10), 2e9);
twoEqual = addSupport(addSupport(addSupport(twoEqual, 1, 'pin'), 11, 'roller'), 21, 'roller');
[s, p] = identificationDefaults(twoEqual, truck, 1);
assert(isequal(s, [5 15]) && isequal(p, [5 10 15 20 25]), 'sensor at L/2 = middle support always reads 0: left out');
fprintf('  PASS spec layout; -x travel; positions without axles and a sensor on a support dropped\n');

%% Synthetic readings are the forward model of the hidden case plus reproducible noise
[u, truth] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 2, 4);
ref = addMeasurementNoise(predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors), 0.02, 4);
assert(isequal(u, ref), 'readings = addMeasurementNoise(predictSensorDeflections(damaged model))');
assert(isequal(truth.elements, 7) && isequal(truth.x, [6 7]) && truth.d == 0.30 && truth.noise == 0.02 && truth.seed == 4, ...
    'hidden case recorded apart');
[u0, truth0] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 0, 0, 1);
assert(isequal(u0, predictSensorDeflections(model, truck, positions, sensors)) && isempty(truth0.elements) && truth0.d == 0, ...
    'd = 0 %, no noise: undamaged readings exactly');
assertThrows(@() syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 100, 0, 1), 'BridgeFE:invalidInput');
assertThrows(@() syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, -1, 1), 'BridgeFE:invalidInput');
assertThrows(@() syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 1, 1.5), 'BridgeFE:invalidInput');
assertThrows(@() syntheticObservations(model, truck, positions, sensors, 1, 6, 7.5, 30, 1, 1), 'BridgeFE:notOnNode');
fprintf('  PASS synthetic readings = forward model + noise; undamaged case; invalid inputs rejected\n');

%% Tab inputs become the documented search options, and readings come back in metres
opts = identificationOptions(model, 2, 1.5, 0.05, -1);
assert(isequal(opts(1:2), {'Direction', -1}) && isequal(opts{4}, candidateGroups(model, 2)) && ...
    strcmp(opts{5}, 'NoiseLevel') && opts{6} == 0.015 && strcmp(opts{7}, 'NoiseAbsolute') && abs(opts{8} - 5e-5) < 1e-18, ...
    '2 m regions, 1.5 % and 0.05 mm');
assert(isequal(identificationOptions(model, 0, 0, 0, 1), {'Direction', 1}), 'no noise: ratio method, each element');
assertThrows(@() identificationOptions(model, 0, -1, 0, 1), 'BridgeFE:invalidInput');
[len, items] = candidateRegionLength();
assert(isempty(len) && numel(items) == 3 && candidateRegionLength(items{1}) == 0 && candidateRegionLength(items{3}) == 4, ...
    'region size labels');
assertThrows(@() candidateRegionLength('3 m'), 'BridgeFE:invalidInput');
mm = [-5 NaN; -10.5 -2];
assert(isequaln(readingsFromTable(mm, 2, 2), mm / 1000), 'mm to m, missing stays NaN');
assert(isequaln(readingsFromTable({-5, []; '-10.5', -2}, 2, 2), mm / 1000), 'cell input: empty = missing, text read');
assertThrows(@() readingsFromTable(mm, 3, 2), 'BridgeFE:invalidInput');
assertThrows(@() readingsFromTable([-5 Inf; 1 2], 2, 2), 'BridgeFE:invalidInput');
fprintf('  PASS options, region sizes and readings conversion\n');

%% Fit profile, candidate table and summary describe the search result
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
u = addMeasurementNoise(obs, 0.01, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.01, 'Groups', {2; 5; 7; 10; 15});
pr = fitProfileData(r, model);
bestRow = find(pr.value == 0);
assert(abs(pr.threshold - 5.991465) < 1e-6 && strcmp(pr.label, 'S - S_{best} [-]') && ~pr.ratio, ...
    'likelihood: limit chi2(0.95, 2); TeX label keeps "best" as one subscript');
assert(isequal(pr.inRegion, pr.value <= pr.threshold), 'in region exactly when S - S_best <= 5.99');
assert(any(pr.inRegion) && any(~pr.inRegion), 'candidates on both sides of the limit');
assert(numel(bestRow) == 1 && bestRow == r.best.group && pr.x1(bestRow) == r.best.x(1) && pr.d(bestRow) == r.best.d, ...
    'best group has value 0');
assert(abs(pr.healthyValue - (r.Shealthy - min(r.evaluated.S))) < 1e-12, 'healthy value');
[data, cols] = identificationTableData(r);
assert(numel(cols) == 7 && strcmp(cols{7}, 'S - S_best') && size(data, 1) == numel(r.competing) + r.healthyCompetes, ...
    'one row per candidate (+ healthy when it competes)');
assert(strcmp(data{1, 1}, sprintf('%g-%g', r.best.x)) && strcmp(data{1, 3}, formatNumber(100 * r.best.d, 1)) ...
    && strcmp(data{1, 7}, '0.00'), 'first row = best fit');
[~, truth] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 1, 7);
lines = identificationSummary(r, truth);
text = strjoin(lines', ' ');
inside = any(r.uncertaintyRegions(:, 1) <= 6 & r.uncertaintyRegions(:, 2) >= 7);
yn = {'no', 'yes'};
assert(~isempty(strfind(lines{1}, 'noise-based region (95 % likelihood ratio), stated noise 1 % of each reading')), 'method');
assert(~isempty(strfind(text, 'Best fit (smallest noise-weighted misfit S): element')) && ~isempty(strfind(text, 'Region of uncertainty:')), 'best fit and region');
covers = r.damageDetected && r.best.x(1) <= 6 && r.best.x(2) >= 7;
assert(~isempty(strfind(text, ['True region inside the reported region: ' yn{inside + 1}])) ...
    && ~isempty(strfind(text, ['Best-fit region contains the true region: ' yn{covers + 1}])), 'truth comparison');
assert(~isempty(strfind(text, 'Best fit (smallest noise-weighted misfit S)')), 'ranking named');
differs = r.minRMSE.group ~= r.best.group || r.minRMSE.d ~= r.best.d;
assert(differs == ~isempty(strfind(text, 'Minimum-RMSE candidate')), 'minimum-RMSE line exactly when it differs');
assert(~isempty(strfind(text, 'not field validation')) && ~isempty(strfind(text, 'not probabilities')), 'caveats');
assert(~isempty(strfind(text, 'Fit check passed')) == ~r.modelMisfit, 'fit check line');
fprintf('  PASS profile (%d of 5 candidates in region), table (%d rows), summary (%d lines)\n', ...
    nnz(pr.inRegion), size(data, 1), numel(lines));

%% The summary states every limiting flag in plain words
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
rr = identifySingleDamage(model, truck, positions, sensors, obs, 'Groups', {6; 7; 8});        % no noise stated
lines = identificationSummary(rr);
assert(~isempty(strfind(lines{1}, 'NOT a confidence region')), 'ratio method warns that it is not a confidence region');
prr = fitProfileData(rr, model);
assert(prr.ratio && strcmp(prr.label, 'RMSE / best RMSE [-]') && prr.threshold == 1.10 && prr.value(2) == 1 ...
    && all(prr.value >= 1) && isequal(prr.inRegion, prr.value <= 1.10) && prr.healthyValue > 1.10, ...
    'ratio profile: best (E7, exact data) = 1 at the floor, others >= 1, healthy outside');
fixed = addSupport(addSupport(createBeamModel(generateUniformMesh(20, 20), 2e9), 1, 'fixed'), 21, 'roller');
wrong = addMeasurementNoise(predictSensorDeflections(fixed, truck, positions, sensors), 0.01, 7);
rm = identifySingleDamage(model, truck, positions, sensors, wrong, 'NoiseLevel', 0.01, 'Groups', {6; 7; 8});
assert(rm.modelMisfit && ~isempty(strfind(strjoin(identificationSummary(rm)', ' '), 'FIT CHECK FAILED')), 'misfit stated');
obs70 = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.70), truck, positions, sensors);
rb = identifySingleDamage(model, truck, positions, sensors, obs70, 'Groups', {6; 7; 8});
assert(rb.boundaryFlag && ~isempty(strfind(strjoin(identificationSummary(rb)', ' '), '60 % search limit')), 'search limit stated');
[u0, truth0] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 0, 2, 1);   % seed 1: a candidate fits
r0 = identifySingleDamage(model, truck, positions, sensors, u0, 'NoiseLevel', 0.02, 'Groups', {6; 7; 8});  % the noise best
text0 = strjoin(identificationSummary(r0, truth0)', ' ');
assert(r0.damageDetected && r0.healthyCompetes, 'this realization: damage "detected", but no damage inside the region');
assert(~isempty(strfind(text0, 'NO damage, noise 2 %')) && ~isempty(strfind(text0, '"No damage" kept possible: yes')) ...
    && ~isempty(strfind(text0, 'No damage cannot be ruled out')), 'undamaged synthetic case');
data0 = identificationTableData(r0);
assert(size(data0, 1) == numel(r0.competing) + 1 && strcmp(data0{end, 1}, 'no damage (healthy)'), 'healthy row in the table');
obs55 = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.55), truck, positions, sensors);
ra = identifySingleDamage(model, truck, positions, sensors, obs55, 'NoiseLevel', 0.05, 'Groups', {6; 7; 8});
assert(ra.regionAtSearchLimit && ~ra.boundaryFlag && ~isempty(strfind(strjoin(identificationSummary(ra)', ' '), ...
    'reaches the 60 % search limit')), 'region at the search limit stated');
rcc = createBeamModel(generateUniformMesh(20, 20), defineMaterial('rcc', 32e9, 0.0625));
rcc = addSupport(addSupport(rcc, 1, 'pin'), 21, 'roller');
warnState = warning('off', 'BridgeFE:rccInverse');
rc = identifySingleDamage(rcc, truck, positions, sensors, obs, 'Groups', {7}, 'Levels', 0.3, 'RefineStep', 0);
warning(warnState);
assert(~isempty(strfind(strjoin(identificationSummary(rc)', ' '), 'RCC baseline')), 'RCC caveat stated');
[u3, truth3] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 0, 2, 3);
r3 = identifySingleDamage(model, truck, positions, sensors, u3, 'NoiseLevel', 0.02, 'Groups', {6; 7; 8});
text3 = strjoin(identificationSummary(r3, truth3)', ' ');
data3 = identificationTableData(r3);
assert(~r3.damageDetected && ~isempty(r3.competing) && strcmp(data3{1, 1}, 'no damage (healthy)') ...
    && size(data3, 1) == numel(r3.competing) + 1 && ~isempty(strfind(text3, 'Damage cannot be ruled out in:')), ...
    'healthy best: first table row, and the region where damage cannot be ruled out is still reported');
groups2 = candidateGroups(model, 2);
[u2, truth2] = syntheticObservations(model, truck, positions, sensors, 1, 6, 7, 30, 0, 1);
r2 = identifySingleDamage(model, truck, positions, sensors, u2, 'NoiseLevel', 0.01, 'Groups', groups2(3:5));
text2 = strjoin(identificationSummary(r2, truth2)', ' ');
assert(~isempty(strfind(text2, 'Best-fit region contains the true region: yes')) ...
    && ~isempty(strfind(text2, 'longer than the hidden region')), '2 m candidates around a 1 m hidden case');
fprintf('  PASS ratio warning, failed fit check, search limits, RCC, healthy best and longer candidates are stated\n');

%% The drawing shows sensors, the region of uncertainty, the best fit and the hidden case
th = appTheme();
prims = bridgeDrawing(model, struct('Sensors', [5 10 15], 'Regions', [4 8; 12 13], 'BestRegion', [6 7], ...
    'BestLabel', 'best fit: d = 30 %', 'TrueRegion', [6 7]));
assert(strcmp(prims(1).kind, 'patch') && strcmp(prims(2).kind, 'patch') && isequal(prims(1).faceColor, th.region) ...
    && isequal(prims(1).x, [4 8 8 4]) && strcmp(prims(3).kind, 'line') && isequal(prims(3).color, th.beam), ...
    'two region bands drawn first, then the beam on top');
best = prims(arrayfun(@(q) strcmp(q.kind, 'line') && isequal(q.color, th.regionBest), prims));
assert(numel(best) == 1 && isequal(best.x, [6 7]) && best.lineWidth > 3, 'best fit: thick line on the beam');
box = prims(arrayfun(@(q) strcmp(q.kind, 'line') && isequal(q.color, th.truth), prims));
assert(numel(box) == 1 && numel(box.x) == 5 && strcmp(box.lineStyle, '--'), 'hidden case: dashed box');
marks = prims(arrayfun(@(q) strcmp(q.kind, 'marker') && isequal(q.color, th.sensor), prims));
labels = prims(arrayfun(@(q) strcmp(q.kind, 'text') && isequal(q.color, th.sensor), prims));
assert(numel(marks) == 3 && isequal([marks.x], [5 10 15]) && all([marks.y] < 0) && isequal({labels.text}, {'S1', 'S2', 'S3'}), ...
    'three sensors below the beam, labelled S1-S3');
assert(any(strcmp({prims.text}, 'best fit: d = 30 %')) && any(strcmp({prims.text}, 'true (hidden)')), 'labels');
plain = bridgeDrawing(model);
assert(~any(arrayfun(@(q) isequal(q.color, th.region) || isequal(q.color, th.sensor), plain)), 'nothing extra by default');
fprintf('  PASS bands behind the beam, best-fit line, dashed hidden box, sensors S1-S3\n');
