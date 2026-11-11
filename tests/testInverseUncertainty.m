%TESTINVERSEUNCERTAINTY Stage 3: noise-based region of uncertainty, fit check and candidate region size.
%   Script-based test file (see runAllTests). DECISIONS.md D-029. With a
%   stated noise level, IDENTIFYSINGLEDAMAGE weights each reading by its
%   standard deviation sigma_i, chooses the candidate with the smallest
%   chi-square misfit S = sum((r_i/sigma_i)^2) and reports every candidate
%   with S - S_best <= chi2(0.95, 2) = 5.99 (likelihood-ratio region).
%   Fixed references:
%   * chi-square quantiles from standard tables (e.g. chi2(0.95, 13) = 22.362);
%     chi2(p, 2) = -2 ln(1 - p) exactly.
%   * With one constant sigma, S = m J^2 / sigma^2 for every candidate, so
%     the best candidate is the minimum-RMSE one.
%   * sigma_i = sqrt((NoiseLevel*|u_healthy,i|)^2 + NoiseAbsolute^2), from the
%     healthy prediction, never from the noisy readings.
%   * An exhaustive 1 % scan (every element, d = 1 %, 2 %, ..., 60 %) gives
%     the same region as the default coarse scan + refinement.
%   All observations are SYNTHETIC: algorithm verification, not field
%   validation. Coverage over many noise seeds is a study
%   (tools/inverseNoiseStudy.m, VERIFICATION_LOG.md), not a test here.
model = createBeamModel(generateUniformMesh(20, 20), 2e9);   % 1 m elements, EI = 2e9 N*m^2
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);       % spec 3-axle example
sensors = [5 10 15];                                         % L/4, L/2, 3L/4
positions = [5 10 15 20 25];                                 % front-axle positions [m]

%% Chi-square quantiles match the tables without a toolbox
rows = compareToReference('chi2(0.95, 1) [-]', chiSquareQuantile(0.95, 1), 3.841459, 1e-4);
rows(end+1) = compareToReference('chi2(0.95, 2) = -2 ln 0.05 [-]', chiSquareQuantile(0.95, 2), -2*log(0.05), 1e-9);
rows(end+1) = compareToReference('chi2(0.95, 3) [-]', chiSquareQuantile(0.95, 3), 7.814728, 1e-4);
rows(end+1) = compareToReference('chi2(0.95, 10) [-]', chiSquareQuantile(0.95, 10), 18.307038, 1e-4);
rows(end+1) = compareToReference('chi2(0.95, 13) [-]', chiSquareQuantile(0.95, 13), 22.362032, 1e-4);
rows(end+1) = compareToReference('chi2(0.95, 30) [-]', chiSquareQuantile(0.95, 30), 43.772972, 1e-4);
rows(end+1) = compareToReference('chi2(0.99, 2) = -2 ln 0.01 [-]', chiSquareQuantile(0.99, 2), -2*log(0.01), 1e-9);
reportComparisons('Chi-square quantiles (tables; exact for 2 degrees of freedom)', rows);
assertThrows(@() chiSquareQuantile(1, 2), 'BridgeFE:invalidInput');
assertThrows(@() chiSquareQuantile(0.95, 0.5), 'BridgeFE:invalidInput');

%% Candidate regions of a chosen length cover every element once and end on nodes
g = candidateGroups(model, 2);
assert(numel(g) == 10 && all(cellfun(@numel, g) == 2) && isequal(g{4}, [7 8]), '2 m: 10 pairs, E7 in [7 8]');
assert(numel(candidateGroups(model, 4)) == 5 && numel(candidateGroups(model, 0.5)) == 20, '4 m: 5 groups; 0.5 m: single elements');
g = candidateGroups(model, 3);
assert(numel(g) == 7 && isequal(g{7}, [19 20]), '3 m on 20 m: six 3 m groups and a 2 m group (>= half of 3 m)');
g = candidateGroups(model, 9);
assert(numel(g) == 2 && isequal(g{2}, 10:20), '9 m on 20 m: a 2 m remainder (< 4.5 m) is joined to the last group');
two = createBeamModel(meshSpans([12 15], 8), 2e9);              % 1.5 m and 1.875 m elements
g = candidateGroups(two, 3);
listed = sort([g{:}]);
assert(numel(g) == 8 && isequal(listed, 1:16) && all(cellfun(@(v) isequal(v, v(1):v(end)), g)), ...
    'two spans, 3 m: 8 contiguous pairs, each element once');
assertThrows(@() candidateGroups(model, 0), 'BridgeFE:invalidInput');
fprintf('  PASS 2, 3, 4, 9 and 0.5 m regions on 1 m elements; 3 m regions on 1.5/1.875 m elements\n');

%% With one constant sigma the chi-square misfit is m J^2 / sigma^2 and selects the minimum-RMSE candidate
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
[u, sigma] = addMeasurementNoise(obs, 0.02, 7, 'rms');
rr = identifySingleDamage(model, truck, positions, sensors, u);
rl = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseAbsolute', sigma(1));
ev = rl.evaluated;
assert(strcmp(rr.method, 'ratio') && strcmp(rl.method, 'likelihood'), 'method chosen by the noise options');
assert(max(abs(ev.S - rl.m * ev.J.^2 / sigma(1)^2)) <= 1e-9 * max(ev.S), 'S = m J^2 / sigma^2 for every candidate');
assert(rl.minRMSE.group == rl.best.group && rl.minRMSE.d == rl.best.d, ...
    'minimum S = minimum RMSE among the same evaluated structures');
fprintf('  PASS S = m J^2/sigma^2 for all %d structures; minimum S = minimum RMSE: E%d, d = %.3f\n', ...
    rl.nStructures, rl.best.elements, rl.best.d);

%% Noise per reading comes from the healthy prediction, and S is the weighted misfit
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
u = addMeasurementNoise(obs, 0.02, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02, 'NoiseAbsolute', 2e-5);
uH = predictSensorDeflections(model, truck, positions, sensors);
sigmaRef = sqrt((0.02 * abs(uH)).^2 + (2e-5)^2);
assert(max(abs(r.sigma(:) - sigmaRef(:))) <= 1e-15, 'sigma = sqrt((p |u_healthy|)^2 + s^2)');
assert(abs(r.best.S - sum((r.best.residual(:) ./ sigmaRef(:)).^2)) <= 1e-9 * r.best.S, 'S = sum((r / sigma)^2)');
assert(abs(r.Shealthy - sum(((uH(:) - u(:)) ./ sigmaRef(:)).^2)) <= 1e-9 * r.Shealthy, 'healthy S');
fprintf('  PASS sigma from the healthy prediction (2 %% + 0.02 mm); S_best = %.2f, S_healthy = %.2f\n', r.best.S, r.Shealthy);

%% Noise-free data with a stated noise level: exact best fit, true region inside, no misfit
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', 0.01);
assert(isequal(r.best.elements, 7) && abs(r.best.d - 0.30) < 1e-9 && r.best.S <= 1e-12, 'exact best fit');
assert(~r.modelMisfit && r.gof.dof == 13 && abs(r.gof.threshold - chiSquareQuantile(0.95, 13)) < 1e-12, ...
    'fit check with 15 - 2 = 13 degrees of freedom');
first = r.competing(1);
assert(first.group == 7 && first.dRange(1) <= 0.30 && first.dRange(2) >= 0.30 && ~r.healthyCompetes, ...
    'E7 first in the region, its d range contains 0.30, healthy model excluded');
assert(r.Shealthy > chiSquareQuantile(0.95, 15), 'the healthy model does not fit noise-free damaged data');
fprintf('  PASS exact fit S = %.1e; region %s m; d range of E7 [%.2f %.2f]\n', r.best.S, ...
    mat2str(r.uncertaintyRegions), first.dRange);

%% Losses between the 1 % grid points with a small stated noise are not mistaken for a misfit
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.274), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', 0.001);
onGrid = r.evaluated.group == 7 & abs(r.evaluated.d * 100 - round(r.evaluated.d * 100)) < 1e-6;
gridS = min(r.evaluated.S(onGrid));
fprintf('  true E7 at 27.4 %%, noise-free, stated 0.1 %%: S at the best 1 %% point %.2f; at the parabola vertex d = %.4f: S = %.4f; limit %.1f\n', ...
    gridS, r.best.d, r.best.S, r.gof.threshold);
assert(isequal(r.best.elements, 7) && abs(r.best.d - 0.274) < 0.002 && ~r.modelMisfit && r.competing(1).group == 7, ...
    'E7 best, d close to 27.4 % (vertex between grid points), no false misfit');
assert(r.best.S < gridS && r.best.S < 1 && r.best.S == r.best.Smin, 'the computed minimum between grid points is used');
fprintf('  PASS no false misfit from the 1 %% grid\n');

%% A noisy case (one realization): the region contains the truth and equals an exhaustive 1 % scan
obs = predictSensorDeflections(applyStiffnessDamage(model, 3, 0.45), truck, positions, sensors);   % 2-3 m
u = addMeasurementNoise(obs, 0.02, 7);
rr = identifySingleDamage(model, truck, positions, sensors, u);
rl = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02);
covers = @(R) any(R(:, 1) <= 2 + 1e-9 & R(:, 2) >= 3 - 1e-9);
fprintf('  true E3 at 45 %%, 2 %% noise, seed 7 (one realization)\n');
fprintf('  ratio:      best E%d, d = %.2f, region %s m\n', rr.best.elements, rr.best.d, mat2str(rr.uncertaintyRegions));
fprintf('  likelihood: best E%d, d = %.2f, region %s m, S = %.1f (fit limit %.1f)\n', rl.best.elements, rl.best.d, ...
    mat2str(rl.uncertaintyRegions), rl.best.S, rl.gof.threshold);
assert(covers(rl.uncertaintyRegions) && ~rl.modelMisfit, 'noise-based region contains 2-3 m; fit acceptable');
ev = rl.evaluated;
assert(rl.competing(1).group == rl.best.group && rl.competing(1).deltaS == 0 && rl.gof.S == rl.best.Smin, ...
    'one best: first in the region, anchor of the region and of the fit check');
assert(rl.best.S == min(ev.S(ev.group == rl.best.group)), 'reported d = best evaluated point of the best group');
assert(rl.minRMSE.J == min(ev.J) && rr.minRMSE.J == rr.best.J, 'minimum-RMSE candidate reported (spec section 7)');
assert(abs(rl.chi2Region - 5.991465) < 1e-6, 'region threshold chi2(0.95, 2) = 5.991465 (tables)');
assert(all(arrayfun(@(c) c.deltaS <= 5.991465 + 1e-9, rl.competing)), 'every listed group within 5.99 of the best');
offGrid = @(dd) any(abs(dd * 20 - round(dd * 20)) > 1e-6);   % some d not on the 5 % grid
assert(all(arrayfun(@(gIdx) offGrid(ev.d(ev.group == gIdx)), 1:numel(rl.groups))), 'every group refined to 1 %');
ex = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02, 'Levels', 0.01:0.01:0.60, 'RefineStep', 0);
inRegion = sort([rl.competing.group]);
assert(isequal(inRegion, sort([ex.competing.group])) && abs(ex.best.Smin - rl.best.Smin) <= 1e-9 * rl.best.Smin, ...
    'same region and best fit as an exhaustive 1 % scan (%d structures)', ex.nStructures);
fprintf('  PASS the noise-based region (%d groups) contains the true 2-3 m and equals the exhaustive 1 %% scan\n', numel(inRegion));

%% A region that reaches the 60 % search limit is flagged even when the best loss is below it
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.55), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', 0.05);
fprintf('  true E7 at 55 %%, noise-free, stated 5 %%: best d = %.2f, d range of E7 [%.2f %.2f]\n', r.best.d, r.dRange);
assert(abs(r.best.d - 0.55) < 1e-9 && ~r.boundaryFlag && r.regionAtSearchLimit && abs(r.dRange(2) - 0.60) < 1e-9, ...
    'best below the limit, but the region reaches 60 %: regionAtSearchLimit');
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', 0.01);
assert(~r.regionAtSearchLimit && ~r.rccBaseline, '30 % loss: region far from the limit; steel-equivalent EI model');
fprintf('  PASS region at the 60 %% limit flagged; not flagged for a 30 %% loss\n');

%% An RCC baseline gives the spec's caveat
rcc = createBeamModel(generateUniformMesh(20, 20), defineMaterial('rcc', 32e9, 0.0625));
rcc = addSupport(rcc, 1, 'pin');
rcc = addSupport(rcc, 21, 'roller');
obs = predictSensorDeflections(applyStiffnessDamage(rcc, 7, 0.30), truck, positions, sensors);
lastwarn('');
r = identifySingleDamage(rcc, truck, positions, sensors, obs, 'Groups', {6; 7}, 'Levels', 0.30, 'RefineStep', 0);
[~, id] = lastwarn();
assert(r.rccBaseline && strcmp(id, 'BridgeFE:rccInverse') && isequal(r.best.elements, 7), ...
    'RCC: warning BridgeFE:rccInverse and rccBaseline = true (the search still runs)');
fprintf('  PASS RCC baseline: warning %s\n', id);

%% A wrong support assumption is flagged by the fit check
propped = addSupport(createBeamModel(generateUniformMesh(20, 20), 2e9), 1, 'fixed');   % real bridge: fixed left end
propped = addSupport(propped, 21, 'roller');
obs = predictSensorDeflections(applyStiffnessDamage(propped, 7, 0.30), truck, positions, sensors);
u = addMeasurementNoise(obs, 0.01, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.01);     % analysed as pin-roller
fprintf('  data from a fixed-roller beam, model pin-roller: S_best = %.0f, limit %.1f, p = %.2g\n', ...
    r.best.S, r.gof.threshold, r.gof.pValue);
assert(r.modelMisfit && r.gof.pValue < 0.05, 'mis-specified support must be flagged');
r = identifySingleDamage(propped, truck, positions, sensors, u, 'NoiseLevel', 0.01);   % correct supports
assert(~r.modelMisfit, 'correct supports: no misfit flag');
fprintf('  PASS wrong supports flagged (no single region explains the data); correct supports not flagged\n');

%% Larger candidate regions recover a region-sized loss exactly
groups = candidateGroups(model, 2);
obs = predictSensorDeflections(applyStiffnessDamage(model, [7 8], 0.30), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs, 'Groups', groups, 'NoiseLevel', 0.01);
assert(isequal(r.best.elements, [7 8]) && isequal(r.best.x, [6 8]) && abs(r.best.d - 0.30) < 1e-9 && r.best.S <= 1e-12, ...
    'hidden 6-8 m at 30 %: found exactly with 2 m regions');
assert(r.nStructures < 241, 'fewer structures than the 1 m search');
fprintf('  PASS 2 m regions: 6-8 m at 30 %% recovered exactly with %d structures\n', r.nStructures);

%% The undamaged bridge with noise is not reported as certainly damaged
obs = predictSensorDeflections(model, truck, positions, sensors);
u = addMeasurementNoise(obs, 0.02, 7);
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02);
fprintf('  undamaged, 2 %% noise, seed 7: damage detected %d, healthy in region %d, S_healthy = %.1f, S_best = %.1f\n', ...
    r.damageDetected, r.healthyCompetes, r.Shealthy, r.gof.S);
assert(~r.damageDetected || r.healthyCompetes, 'no damage must remain possible');
r = identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', 0.02);     % noise-free undamaged
assert(~r.damageDetected && r.gof.dof == 15 && abs(r.gof.threshold - 24.995790) < 1e-5, ...
    'healthy model best: fit check with m = 15 degrees of freedom (no fitted unknowns), chi2(0.95, 15) = 24.996');
fprintf('  PASS undamaged data: "no damage" stays inside the region; healthy best uses 15 degrees of freedom\n');

%% A different confidence level and missing readings change the thresholds as the tables say
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
u = addMeasurementNoise(obs, 0.02, 7);
r95 = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02);
r90 = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02, 'Confidence', 0.90);
assert(abs(r90.chi2Region - (-2*log(0.10))) < 1e-9 && abs(r90.gof.threshold - 19.811929) < 1e-5, ...
    '90 %: chi2(0.90, 2) = -2 ln 0.1, chi2(0.90, 13) = 19.812 (tables)');
assert(all(ismember([r90.competing.group], [r95.competing.group])), '90 % region inside the 95 % region');
u([2 7 15]) = NaN;
r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', 0.02);
assert(r.m == 12 && r.gof.dof == 10 && abs(r.gof.threshold - 18.307038) < 1e-5 && all(isnan(r.sigma([2 7 15]))), ...
    '3 readings missing: m = 12, 10 degrees of freedom, chi2(0.95, 10) = 18.307');
assert((r.gof.pValue < 0.05) == r.modelMisfit && abs(r.gof.pValue - (1 - gammainc(r.gof.S/2, 5))) < 1e-12, ...
    'p-value consistent with the threshold');
fprintf('  PASS 90 %% region (%d groups) inside 95 %% region (%d groups); missing readings: m = 12, dof = 10\n', ...
    numel(r90.competing), numel(r95.competing));

%% Invalid noise input is rejected
obs = predictSensorDeflections(model, truck, positions, sensors);
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs, 'NoiseLevel', -0.01), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs, 'Confidence', 1), 'BridgeFE:invalidInput');
offSpan = [5 10 40];                                        % at 40 m the whole truck is off the span
obsOff = predictSensorDeflections(model, truck, offSpan, sensors);
assert(all(obsOff(:, 3) == 0), 'truck off the span: predicted readings are zero');
assertThrows(@() identifySingleDamage(model, truck, offSpan, sensors, obsOff, 'NoiseLevel', 0.02), 'BridgeFE:invalidInput');
r = identifySingleDamage(model, truck, offSpan, sensors, obsOff, 'NoiseLevel', 0.02, 'NoiseAbsolute', 1e-5);
assert(all(r.sigma(:) > 0) && all(abs(r.sigma(:, 3) - 1e-5) < 1e-18), 'the absolute part makes every sigma positive');
fprintf('  PASS negative noise, confidence 1 and zero predicted readings without an absolute noise part are rejected\n');
