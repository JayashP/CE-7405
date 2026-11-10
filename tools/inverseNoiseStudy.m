function summary = inverseNoiseStudy(nSeeds)
%INVERSENOISESTUDY How often the Stage 3 region of uncertainty contains the true damage, over noise seeds.
%   SUMMARY = INVERSENOISESTUDY(NSEEDS) repeats IDENTIFYSINGLEDAMAGE (default
%   options) on synthetic data of the PROJECT_SPEC.md section 7 layout
%   (20 m simple span, 20 elements, EI = 2e9 N*m^2, spec 3-axle truck,
%   sensors at L/4, L/2, 3L/4, front axle at 5, 10, 15, 20, 25 m) for three
%   hidden cases and three proportional noise levels, with noise seeds
%   1..NSEEDS (default 10). For each case and level it reports, out of
%   NSEEDS: the true element is the best element; the best element is
%   within one element of the truth; the true element lies inside the
%   reported region of uncertainty; the healthy model competes; and the
%   mean width of the region [m].
%   It characterizes the method on idealized synthetic data (algorithm
%   verification). It is not field validation and the counts are not
%   calibrated probabilities. Slow in GNU Octave (about 7 s per search).
%
%   addProjectPaths; addpath tools; inverseNoiseStudy(10)
%
%   See also IDENTIFYSINGLEDAMAGE, ADDMEASUREMENTNOISE.

if nargin < 1
    nSeeds = 10;
end
model = createBeamModel(generateUniformMesh(20, 20), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
sensors = [5 10 15];
positions = [5 10 15 20 25];
cases = [7 0.30; 3 0.45; 15 0.20];
levels = [0.01 0.02 0.05];
summary = struct('element', {}, 'd', {}, 'noise', {}, 'exact', {}, 'withinOne', {}, 'inRegion', {}, ...
    'healthyCompetes', {}, 'meanWidth', {});
fprintf('Stage 3 noise study: %d seeds per row, proportional noise, spec layout (3 sensors x 5 positions)\n', nSeeds);
fprintf('  true      noise  best=true  best+-1  true in region  healthy competes  mean region width [m]\n');
for c = 1:size(cases, 1)
    e = cases(c, 1);
    obs = predictSensorDeflections(applyStiffnessDamage(model, e, cases(c, 2)), truck, positions, sensors);
    xTrue = model.nodes.x([e, e + 1]);
    for level = levels
        n = zeros(1, 4);
        width = 0;
        for seed = 1:nSeeds
            r = identifySingleDamage(model, truck, positions, sensors, addMeasurementNoise(obs, level, seed));
            bestE = NaN;
            if r.damageDetected
                bestE = r.best.elements(1);
            end
            regions = r.uncertaintyRegions;
            n = n + [bestE == e, abs(bestE - e) <= 1, ...
                any(regions(:, 1) <= xTrue(1) + 1e-9 & regions(:, 2) >= xTrue(2) - 1e-9), r.healthyCompetes];
            width = width + sum(regions(:, 2) - regions(:, 1));
        end
        summary(end+1) = struct('element', e, 'd', cases(c, 2), 'noise', level, 'exact', n(1), 'withinOne', n(2), ...
            'inRegion', n(3), 'healthyCompetes', n(4), 'meanWidth', width / nSeeds); %#ok<AGROW>
        fprintf('  E%-2d %2.0f %%  %3.0f %%    %2d/%d      %2d/%d      %2d/%d           %2d/%d             %5.1f\n', ...
            e, 100*cases(c, 2), 100*level, n(1), nSeeds, n(2), nSeeds, n(3), nSeeds, n(4), nSeeds, width / nSeeds);
    end
end
end
