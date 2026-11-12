%TESTINVERSEDAMAGE Stage 3: single-region stiffness-loss search from sensor deflections.
%   Script-based test file (see runAllTests). PROJECT_SPEC.md section 7 and
%   DECISIONS.md D-028. Observations are SYNTHETIC: they are generated with
%   the forward model from a hidden damage case, and the search receives
%   only the observations, never the true element or loss ("blind" cases).
%   Recovering them is algorithm verification, NOT field validation.
%   Fixed references:
%   * Simple span L, single load P at midspan, sensor at x <= L/2:
%       v(x) = -P*x*(3L^2 - 4x^2)/(48 EI)   (downward negative)
%   * Noise-free blind cases: the true element and loss are recovered
%     exactly (the true losses are whole percentages, on the 1 % grid).
%   * Noisy case E7 at 30 %, noise seed 7: the true element must lie inside
%     the reported region of uncertainty (spec: report a region rather than
%     unjustified precision). This is checked for ONE noise realization; it
%     does not hold for every realization or case (see tools/inverseNoiseStudy
%     and VERIFICATION_LOG.md), because the region is a set of candidates
%     whose fit is within 10 % of the best, not a calibrated confidence set.
model = createBeamModel(generateUniformMesh(20, 20), 2e9);   % 1 m elements, EI = 2e9 N*m^2
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);       % spec 3-axle example
sensors = [5 10 15];                                         % L/4, L/2, 3L/4 (spec section 7)
positions = [5 10 15 20 25];                                 % front-axle positions [m]

%% Sensor deflections equal the static engine and the closed form, vehicle only
P = 100e3;
one = createVehicle(P, []);
u = predictSensorDeflections(model, one, 10, [2.5 5 7.3 10]);
xs = [2.5 5 7.3 10];
rows = compareToReference('v(2.5 m), P at midspan [mm]', u(1)*1e3, -P*2.5*(3*400 - 4*2.5^2)/(48*2e9)*1e3, 1e-8);
rows(end+1) = compareToReference('v(5 m) [mm]', u(2)*1e3, -P*5*(3*400 - 4*25)/(48*2e9)*1e3, 1e-8);
rows(end+1) = compareToReference('v(7.3 m), between nodes [mm]', u(3)*1e3, -P*7.3*(3*400 - 4*7.3^2)/(48*2e9)*1e3, 1e-8);
rows(end+1) = compareToReference('v(10 m) = PL^3/48EI [mm]', u(4)*1e3, -P*20^3/(48*2e9)*1e3, 1e-8);
loaded = addUniformLoad(applyStiffnessDamage(model, 4:6, 0.4), -20e3);       % permanent load + damage
xvB = [8.7 16.2];
u = predictSensorDeflections(loaded, truck, xvB, [3.3 10 14.6], -1);
worst = 0;
for p = 1:2
    withTruck = modelWithVehicle(loaded, truck, xvB(p), -1);       % axles as point loads (needed for v inside elements)
    total = evaluateDeflection(withTruck, solveStaticModel(withTruck).U, [3.3 10 14.6]);
    permanent = evaluateDeflection(loaded, solveStaticModel(loaded).U, [3.3 10 14.6]);
    worst = max(worst, max(abs(u(:, p) - (total(:) - permanent(:)))) / max(abs(u(:))));
end
% Two solver paths of the same engine (Cholesky fast path vs backslash, then a difference of two
% solutions): they differ only by round-off, up to about eps*cond(Kff) = 2.2e-16 * 1.6e5 = 3.5e-11.
% Same criterion (1e-9) as the damaged fast-path test in testStiffnessDamage.
rows(end+1) = compareToReference('vehicle-only v: max|fast path - static (total - permanent)| / max|v| [-]', ...
    worst, 0, [], 1e-9);
reportComparisons('Sensor deflections: closed form (single 100 kN load) and the static engine', rows);
assertThrows(@() predictSensorDeflections(model, truck, 10, [5 21]), 'BridgeFE:offBeam');
fprintf('  PASS closed form to 1e-8 %%; damaged model with a permanent load, travel toward -x, sensors between nodes = static engine\n');

%% Noise generator is reproducible on every platform and has the intended size
z = deterministicNormal(20000, 11);
assert(isequal(z, deterministicNormal(20000, 11)) && ~isequal(z(1:10), deterministicNormal(10, 12)), 'same seed, same numbers');
hashes = arrayfun(@hashSeed32, [0 1 2 3 7 123456789 4294967295]);
assert(isequal(hashes, [0 1753845952 3507691905 1408362973 2492178918 2834422664 1734902346]), ...
    'lowbias32 hash = independent Python implementation (arbitrary-precision integers)');
state = mod(1664525 * hashSeed32(11) + 1013904223, 2^32);    % first LCG step from the hashed seed, by hand
u1 = (state + 0.5) / 2^32;
state = mod(1664525 * state + 1013904223, 2^32);
u2 = (state + 0.5) / 2^32;
assert(abs(z(1) - sqrt(-2*log(u1))*cos(2*pi*u2)) < 1e-14, 'Box-Muller of the first two LCG numbers');
fprintf('  mean %.4f, standard deviation %.4f of 20000 numbers\n', mean(z), std(z));
assert(abs(mean(z)) < 0.03 && abs(std(z) - 1) < 0.03, 'standard normal');
first = arrayfun(@(s) deterministicNormal(1, s), 1:2000);     % first number of seeds 1..2000
lag = corrcoef(first(1:end-1), first(2:end));
fprintf('  first number over seeds 1..2000: mean %.3f, std %.3f, correlation of neighbouring seeds %.3f\n', ...
    mean(first), std(first), lag(1, 2));
assert(abs(mean(first)) < 0.1 && abs(std(first) - 1) < 0.1 && abs(lag(1, 2)) < 0.1, ...
    'neighbouring seeds give unrelated numbers (no correlation through the seed)');
u = [-0.010 NaN; -0.020 -0.005];
[un, sigma] = addMeasurementNoise(u, 0.02, 3);
zz = reshape(deterministicNormal(4, 3), 2, 2);
assert(isnan(un(1, 2)) && max(abs(un([1 2 4]) - u([1 2 4]).*(1 + 0.02*zz([1 2 4])))) < 1e-15 ...
    && abs(sigma(2) - 0.0004) < 1e-15, 'proportional noise, NaN kept');
[un, sigma] = addMeasurementNoise(u, 0.02, 3, 'rms');
assert(all(abs(sigma([1 2 4]) - 0.02*sqrt(mean([0.01 0.02 0.005].^2))) < 1e-15), 'rms noise: one sigma');
assert(isequal(addMeasurementNoise(u(:, 1), 0, 5), u(:, 1)), 'zero noise leaves the data unchanged');
fprintf('  PASS hash = Python reference; reproducible, independent across seeds; proportional and rms noise; NaN kept\n');

%% Blind noise-free cases are recovered exactly, including losses between the 5 % steps
hidden = [7 0.30; 3 0.45; 15 0.20; 12 0.27; 19 0.55];        % [element, d]; never passed to the search
rows = [];
for k = 1:size(hidden, 1)
    obs = predictSensorDeflections(applyStiffnessDamage(model, hidden(k, 1), hidden(k, 2)), truck, positions, sensors);
    r = identifySingleDamage(model, truck, positions, sensors, obs);
    fprintf('  case %d: best element %s, d = %.2f, J = %.2e m, healthy J = %.3f mm, %d structures\n', ...
        k, mat2str(r.best.elements), r.best.d, r.best.J, r.Jhealthy*1e3, r.nStructures);
    rows = [rows, compareToReference(sprintf('case %d: element found', k), r.best.elements, hidden(k, 1), 0), ...
        compareToReference(sprintf('case %d: loss d [%%]', k), 100*r.best.d, 100*hidden(k, 2), 1e-6)]; %#ok<AGROW>
    assert(r.damageDetected && ~r.ambiguous && ~r.boundaryFlag && r.best.J <= 1e-9 * r.Jhealthy, ...
        'case %d: unique, exact fit', k);
end
reportComparisons('Blind noise-free cases (spec sensors L/4, L/2, 3L/4; 5 truck positions)', rows);

%% The undamaged bridge is recognized, and the coarse scan has 241 structures for 20 elements
obs = predictSensorDeflections(model, truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs);
assert(~r.damageDetected && r.best.d == 0 && r.best.J == 0 && isempty(r.competing), 'healthy model fits best');
coarse = identifySingleDamage(model, truck, positions, sensors, obs, 'RefineStep', 0);
assert(coarse.nStructures == 241 && isequal(size(coarse.Jcoarse), [20 12]), '240 damaged + 1 healthy');
assert(abs(coarse.levels(end) - 0.60) < 1e-12 && abs(coarse.levels(1) - 0.05) < 1e-12, 'd = 5 % ... 60 %');
fprintf('  PASS undamaged data: best = healthy (d = 0); coarse scan = %d structures\n', coarse.nStructures);

%% Data from a finer mesh and missing readings still give the true region
fine = createBeamModel(generateUniformMesh(20, 40), 2e9);          % 0.5 m elements
fine = addSupport(fine, 1, 'pin');
fine = addSupport(fine, 41, 'roller');
obs = predictSensorDeflections(applyStiffnessDamage(fine, 13:14, 0.30), truck, positions, sensors);   % 6-7 m
r = identifySingleDamage(model, truck, positions, sensors, obs);
assert(isequal(r.best.elements, 7) && abs(r.best.d - 0.30) < 1e-9 && r.best.J <= 1e-9 * r.Jhealthy, ...
    '40-element data, 6-7 m at 30 %: element 7 at 30 % on the 20-element mesh');
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
obs([2 7 15]) = NaN;
r = identifySingleDamage(model, truck, positions, sensors, obs);
assert(r.m == 12 && isequal(r.best.elements, 7) && abs(r.best.d - 0.30) < 1e-9, '3 of 15 readings missing');
fprintf('  PASS other mesh for the data: E7 at 30 %%; 3 missing readings: m = %d, E7 at 30 %%\n', r.m);

%% One noise realization (seed 7): the true E7 stays inside the reported region at 1-10 % noise
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), truck, positions, sensors);
fprintf('  true: element 7 (6-7 m), d = 0.30; proportional noise, seed 7\n');
fprintf('  noise   best    d     d range       J/J_healthy  competing  region [m]        healthy competes\n');
for level = [0.01 0.02 0.05 0.10]
    r = identifySingleDamage(model, truck, positions, sensors, addMeasurementNoise(obs, level, 7));
    region = sprintf('%g-%g ', r.uncertaintyRegions');
    best = 'none';
    if r.damageDetected
        best = sprintf('E%d', r.best.elements);
    end
    fprintf('  %4.0f %%  %-5s %.2f  [%.2f %.2f]   %.2f         %2d         %-17s %d\n', 100*level, ...
        best, r.best.d, r.dRange, r.best.J/r.Jhealthy, numel(r.competing), region, r.healthyCompetes);
    inside = any(r.uncertaintyRegions(:, 1) <= 6 + 1e-9 & r.uncertaintyRegions(:, 2) >= 7 - 1e-9);
    assert(inside, '%g %% noise: true region 6-7 m must lie in the region of uncertainty', 100*level);
    assert(r.ambiguous, '%g %% noise: competing candidates must be reported', 100*level);
end
fprintf('  PASS the true element is inside the reported region at 1, 2, 5 and 10 %% noise, and competitors are listed\n');

%% Symmetric data are reported as ambiguous, and a loss beyond 60 % is flagged
one = createVehicle(100e3, []);
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.30), one, 10, 10);   % 1 sensor, 1 load, both at midspan
r = identifySingleDamage(model, one, 10, 10, obs, 'RefineCount', 2);
groupsFound = sort([r.competing(1:2).group]);
assert(r.ambiguous && isequal(groupsFound, [7 14]) && abs(r.competing(2).ratio - 1) < 1e-6, ...
    'mirror elements 7 and 14 fit equally well');
assert(size(r.uncertaintyRegions, 1) >= 2, 'two separate regions reported');
ratio = r.competing(2).ratio;
obs = predictSensorDeflections(applyStiffnessDamage(model, 7, 0.70), truck, positions, sensors);
r = identifySingleDamage(model, truck, positions, sensors, obs);
assert(abs(r.best.d - 0.60) < 1e-12 && r.boundaryFlag && r.best.J > 0, 'true 70 %: best at the 60 % limit, flagged, no exact fit');
fprintf(['  PASS mirror elements 7 and 14 tie (ratio %.6f); true E7 at 70 %%: best E%d at the 60 %% limit, flagged ' ...
    '(beyond the limit the location is not reliable)\n'], ratio, r.best.elements);

%% Invalid inverse input is rejected
obs = predictSensorDeflections(model, truck, positions, sensors);
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs(:, 1:4)), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, NaN(3, 5)), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(applyStiffnessDamage(model, 2, 0.1), truck, positions, sensors, obs), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs, 'Levels', [0.1 1.2]), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs, 'Groups', {[1 2], 25}), 'BridgeFE:invalidInput');
assertThrows(@() identifySingleDamage(model, truck, positions, sensors, obs, 'Tolerance', 2), 'BridgeFE:invalidInput');
fprintf('  PASS wrong data size, no data, damaged baseline, d >= 1, element 25 and unknown option are rejected\n');
