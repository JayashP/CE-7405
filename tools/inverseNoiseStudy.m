function summary = inverseNoiseStudy(nSeeds, caseIndices)
%INVERSENOISESTUDY Coverage of the Stage 3 region of uncertainty over noise seeds, for three methods.
%   SUMMARY = INVERSENOISESTUDY(NSEEDS, CASEINDICES) repeats
%   IDENTIFYSINGLEDAMAGE on synthetic data of the PROJECT_SPEC.md section 7
%   layout (20 m simple span, 20 elements of 1 m, EI = 2e9 N*m^2, spec
%   3-axle truck, sensors at L/4, L/2, 3L/4, front axle at 5, 10, 15, 20,
%   25 m) with proportional noise of 1, 2 and 5 % and seeds 1..NSEEDS
%   (default 10). Hidden cases (CASEINDICES selects, default all):
%     1  E7 at 30 %     2  E3 at 45 %     3  E15 at 20 %     4  undamaged
%   Methods compared on the same noisy data:
%     ratio-1m       1 m candidates, RMSE within 10 % of the best (D-028)
%     chi2-1m        1 m candidates, likelihood-ratio region with the true
%                    noise level stated ('NoiseLevel', D-029)
%     chi2-2m        2 m candidates (CANDIDATEGROUPS(model, 2)), same region
%   For each it counts, out of NSEEDS: the best region contains the true
%   element ("best right"); the true element lies inside the reported
%   region ("covered"); and gives the mean total region width [m]. For the
%   undamaged case "covered" means the healthy model is in the region
%   (no false claim of damage). chi2 methods also count modelMisfit flags.
%   Synthetic data only: algorithm verification, not field validation; the
%   counts estimate coverage, they are not probabilities of real damage.
%   Slow in GNU Octave (about 20 s per seed and noise level).
%
%   addProjectPaths; addpath tools; inverseNoiseStudy(20)
%
%   See also IDENTIFYSINGLEDAMAGE, CANDIDATEGROUPS, ADDMEASUREMENTNOISE.

if nargin < 1
    nSeeds = 10;
end
if nargin < 2
    caseIndices = 1:4;
end
model = createBeamModel(generateUniformMesh(20, 20), 2e9);
model = addSupport(model, 1, 'pin');
model = addSupport(model, 21, 'roller');
truck = createVehicle([80e3 120e3 120e3], [4.2 1.4]);
sensors = [5 10 15];
positions = [5 10 15 20 25];
cases = [7 0.30; 3 0.45; 15 0.20; 0 0];
levels = [0.01 0.02 0.05];
methods = {'ratio-1m', 'chi2-1m', 'chi2-2m'};
pairs = candidateGroups(model, 2);
summary = struct('element', {}, 'd', {}, 'noise', {}, 'method', {}, 'bestRight', {}, 'covered', {}, ...
    'meanWidth', {}, 'misfits', {});
fprintf('Stage 3 coverage study: %d seeds per row, proportional noise, spec layout (3 sensors x 5 positions)\n', nSeeds);
fprintf('  true       noise  method     best right  covered  mean width [m]  misfit flags\n');
for c = caseIndices
    e = cases(c, 1);
    if e == 0
        obs = predictSensorDeflections(model, truck, positions, sensors);
        label = 'none';
    else
        obs = predictSensorDeflections(applyStiffnessDamage(model, e, cases(c, 2)), truck, positions, sensors);
        label = sprintf('E%d %2.0f %%', e, 100 * cases(c, 2));
        xTrue = model.nodes.x([e, e + 1]);
    end
    for level = levels
        counts = zeros(numel(methods), 4);          % best right, covered, width, misfits
        for seed = 1:nSeeds
            u = addMeasurementNoise(obs, level, seed);
            for k = 1:numel(methods)
                switch methods{k}
                    case 'ratio-1m'
                        r = identifySingleDamage(model, truck, positions, sensors, u);
                    case 'chi2-1m'
                        r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', level);
                    case 'chi2-2m'
                        r = identifySingleDamage(model, truck, positions, sensors, u, 'NoiseLevel', level, 'Groups', pairs);
                end
                R = r.uncertaintyRegions;
                if e == 0
                    right = ~r.damageDetected;
                    covered = ~r.damageDetected || r.healthyCompetes;
                else
                    right = r.damageDetected && r.best.x(1) <= xTrue(1) + 1e-9 && r.best.x(2) >= xTrue(2) - 1e-9;
                    covered = any(R(:, 1) <= xTrue(1) + 1e-9 & R(:, 2) >= xTrue(2) - 1e-9);
                end
                counts(k, :) = counts(k, :) + [right, covered, sum(R(:, 2) - R(:, 1)), r.modelMisfit];
            end
        end
        for k = 1:numel(methods)
            summary(end+1) = struct('element', e, 'd', cases(c, 2), 'noise', level, 'method', methods{k}, ...
                'bestRight', counts(k, 1), 'covered', counts(k, 2), 'meanWidth', counts(k, 3) / nSeeds, ...
                'misfits', counts(k, 4)); %#ok<AGROW>
            fprintf('  %-9s  %3.0f %%  %-9s   %2d/%d       %2d/%d    %5.1f           %2d/%d\n', label, 100 * level, ...
                methods{k}, counts(k, 1), nSeeds, counts(k, 2), nSeeds, counts(k, 3) / nSeeds, counts(k, 4), nSeeds);
        end
    end
end
end
