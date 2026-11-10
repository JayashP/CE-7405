function result = identifySingleDamage(model, vehicle, xvList, sensorX, uObs, varargin)
%IDENTIFYSINGLEDAMAGE Single-region inverse stiffness-loss search from sensor deflections (Stage 3).
%   RESULT = IDENTIFYSINGLEDAMAGE(MODEL, VEHICLE, XVLIST, SENSORX, UOBS, NAME, VALUE, ...)
%   estimates WHERE one region of the healthy baseline MODEL may have lost
%   effective flexural rigidity and HOW MUCH (EI_D = (1 - d) EI), from the
%   observed vehicle-induced deflections UOBS [m] (+ up; NS-by-NP: sensor i
%   at SENSORX(i), vehicle front axle at XVLIST(p)), following
%   PROJECT_SPEC.md section 7 (DECISIONS.md D-028):
%     1. the healthy model (d = 0) is evaluated ONCE;
%     2. coarse scan: every candidate group (default: each element) with
%        d = 5 %, 10 %, ..., 60 % (20 elements: 240 + 1 = 241 structures);
%     3. refinement in 1 % steps within +/- 5 % of the coarse optimum, for
%        the 'RefineCount' best groups;
%     4. objective J = RMSE = sqrt(mean((u_FE - u_obs)^2)) over the m
%        observed (non-NaN) entries; also J_N = sqrt(sum r^2 / sum u_obs^2).
%   Predictions use PREDICTSENSORDEFLECTIONS (vehicle-only deflection).
%   Missing observations are NaN and are left out of J.
%
%   Options:
%     'Direction'      +1 (default) or -1, as in the moving-load engine
%     'Groups'         cell array of element index vectors (candidate
%                      regions), default {1, 2, ..., NE}
%     'Levels'         coarse d values, default 0.05:0.05:0.60
%     'RefineStep'     refinement step, default 0.01 (0 = no refinement)
%     'RefineCount'    number of best groups refined, default 3
%     'AmbiguityRatio' candidates with J <= ratio * J_best compete with the
%                      best one, default 1.10 (a fit within 10 %); J below
%                      1e-9 * RMS(UOBS) counts as an exact fit (round-off)
%     'NoiseRMS'       optional expected noise standard deviation [m]; if
%                      given, RESULT.healthyConsistentWithNoise tells whether
%                      the healthy model fits the data to within that noise
%                      (approximate one-sided 95 % chi-square test,
%                      m*J0^2/sigma^2 <= m + 1.645*sqrt(2m), assuming
%                      independent Gaussian noise of that size)
%
%   RESULT fields (SI units):
%     m, Jhealthy, JNhealthy, uHealthy      data count and healthy fit
%     groups, levels, Jcoarse               coarse scan (NG-by-NL)
%     evaluated                             struct: group, d, J of every
%                                           structure evaluated (healthy: group 0)
%     nStructures                           number of distinct structures
%     best        group, elements, x ([start end] m), d, remaining (1 - d),
%                 J, JN, u (predicted, NS-by-NP), residual (u - uObs)
%     damageDetected     false when the healthy model fits best
%     competing   struct array, best J per group within the ambiguity ratio,
%                 sorted: group, elements, x, d, J, ratio (J / J_best; exact
%                 fits, J at round-off level, have ratio 1)
%     ambiguous          more than one group competes
%     healthyCompetes    the healthy model is within the ambiguity ratio
%     uncertaintyRegions K-by-2 [start end] m, merged regions of the
%                        competing groups
%     dRange             [min max] d of the best group within the ratio
%     boundaryFlag       best d at the largest coarse level (search limit)
%     healthyConsistentWithNoise   true/false, or [] without 'NoiseRMS'
%
%   J ratios rank how well candidates fit; they are NOT probabilities
%   (spec section 7). The result says where effective stiffness may have
%   changed, not the physical cause (corrosion, cracking, ...). Agreement
%   with self-generated data is algorithm verification, not field
%   validation.
%
%   See also PREDICTSENSORDEFLECTIONS, APPLYSTIFFNESSDAMAGE, ADDMEASUREMENTNOISE.

validateModel(model);
ne = size(model.elements.conn, 1);
if any(model.elements.stiffnessFactor ~= 1)
    error('BridgeFE:invalidInput', 'The baseline model must be healthy (all stiffness factors 1).');
end
opts = struct('Direction', 1, 'Groups', {num2cell((1:ne)')}, 'Levels', 0.05:0.05:0.60, 'RefineStep', 0.01, ...
    'RefineCount', 3, 'AmbiguityRatio', 1.10, 'NoiseRMS', []);
if mod(numel(varargin), 2) ~= 0
    error('BridgeFE:invalidInput', 'Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    if ~(ischar(varargin{k}) && isfield(opts, varargin{k}))
        error('BridgeFE:invalidInput', 'Unknown option ''%s''.', char(varargin{k}));
    end
    opts.(varargin{k}) = varargin{k + 1};
end
groups = opts.Groups(:);
levels = opts.Levels(:)';
if isempty(groups) || ~all(cellfun(@(g) isnumeric(g) && ~isempty(g) && all(g >= 1 & g <= ne & g == round(g)), groups))
    error('BridgeFE:invalidInput', 'Groups must be a cell array of element index vectors (1 to %d).', ne);
end
if isempty(levels) || any(~isfinite(levels) | levels <= 0 | levels >= 1)
    error('BridgeFE:invalidInput', 'Levels must be values of d with 0 < d < 1.');
end
step = opts.RefineStep;
if ~(isnumeric(step) && isscalar(step) && step >= 0 && step < 1)
    error('BridgeFE:invalidInput', 'RefineStep must satisfy 0 <= step < 1.');
end
if ~(isnumeric(opts.AmbiguityRatio) && isscalar(opts.AmbiguityRatio) && opts.AmbiguityRatio >= 1)
    error('BridgeFE:invalidInput', 'AmbiguityRatio must be a number >= 1.');
end
nS = numel(sensorX);
nP = numel(xvList);
if ~(isnumeric(uObs) && isreal(uObs) && isequal(size(uObs), [nS nP]))
    error('BridgeFE:invalidInput', 'Observed deflections must be a %d-by-%d matrix (sensors x vehicle positions).', nS, nP);
end
known = ~isnan(uObs);
if ~any(known(:)) || any(isinf(uObs(:)))
    error('BridgeFE:invalidInput', 'Observed deflections need at least one finite value (NaN = missing).');
end
m = nnz(known);
rmsObs = sqrt(mean(uObs(known).^2));
predict = @(mdl) predictSensorDeflections(mdl, vehicle, xvList, sensorX, opts.Direction);
rmse = @(u) sqrt(mean((u(known) - uObs(known)).^2));

% 1. Healthy model, once
uHealthy = predict(model);
J0 = rmse(uHealthy);
evGroup = 0;
evD = 0;
evJ = J0;

% 2. Coarse scan
nG = numel(groups);
Jcoarse = zeros(nG, numel(levels));
for g = 1:nG
    for k = 1:numel(levels)
        Jcoarse(g, k) = rmse(predict(applyStiffnessDamage(model, groups{g}, levels(k))));
    end
end
[gg, kk] = ndgrid(1:nG, 1:numel(levels));
evGroup = [evGroup; gg(:)];
evD = [evD; levels(kk(:))'];
evJ = [evJ; Jcoarse(:)];

% 3. Refinement around the coarse optimum of the best groups
if step > 0
    [JgCoarse, kBest] = min(Jcoarse, [], 2);
    [~, order] = sort(JgCoarse);
    spacing = max([diff(sort(levels)), step]);
    for g = order(1:min(opts.RefineCount, nG))'
        dc = levels(kBest(g));
        lo = max(1, ceil((dc - spacing) / step - 1e-9));
        hi = min(floor(max(levels) / step + 1e-9), floor((dc + spacing) / step + 1e-9));
        for i = lo:hi
            d = i * step;
            if any(evGroup == g & abs(evD - d) < 1e-12)
                continue                                   % already evaluated (coarse value)
            end
            evGroup(end+1, 1) = g; %#ok<AGROW>
            evD(end+1, 1) = d; %#ok<AGROW>
            evJ(end+1, 1) = rmse(predict(applyStiffnessDamage(model, groups{g}, d))); %#ok<AGROW>
        end
    end
end
result.m = m;
result.Jhealthy = J0;
result.JNhealthy = normalizedError(uHealthy, uObs, known);
result.uHealthy = uHealthy;
result.groups = groups;
result.levels = levels;
result.Jcoarse = Jcoarse;
result.evaluated = struct('group', evGroup, 'd', evD, 'J', evJ);
result.nStructures = numel(evJ);

% 4. Best candidate (the healthy model wins ties: no damage without evidence)
[Jbest, iBest] = min(evJ);
x = model.nodes.x;
if iBest == 1
    best = struct('group', 0, 'elements', [], 'x', [NaN NaN], 'd', 0, 'remaining', 1, 'J', J0, 'JN', ...
        normalizedError(uHealthy, uObs, known), 'u', uHealthy, 'residual', uHealthy - uObs);
else
    g = evGroup(iBest);
    els = groups{g};
    uBest = predict(applyStiffnessDamage(model, els, evD(iBest)));
    best = struct('group', g, 'elements', els(:)', 'x', [x(min(els)), x(max(els) + 1)], 'd', evD(iBest), ...
        'remaining', 1 - evD(iBest), 'J', Jbest, 'JN', normalizedError(uBest, uObs, known), 'u', uBest, 'residual', uBest - uObs);
end
result.best = best;
result.damageDetected = best.group ~= 0;

% 5. Competing candidates: best J of every group within the ambiguity ratio
floorJ = 1e-9 * rmsObs;                        % round-off level of J
threshold = max(opts.AmbiguityRatio * Jbest, floorJ);
competing = struct('group', {}, 'elements', {}, 'x', {}, 'd', {}, 'J', {}, 'ratio', {});
for g = 1:nG
    in = evGroup == g;
    [Jg, i] = min(evJ(in));
    if Jg <= threshold
        dg = evD(in);
        els = groups{g};
        competing(end+1) = struct('group', g, 'elements', els(:)', 'x', [x(min(els)), x(max(els) + 1)], ...
            'd', dg(i), 'J', Jg, 'ratio', max(Jg, floorJ) / max(Jbest, floorJ)); %#ok<AGROW>
    end
end
if ~isempty(competing)
    [~, order] = sort([competing.J]);
    competing = competing(order);
end
result.competing = competing;
result.ambiguous = numel(competing) > 1;
result.healthyCompetes = result.damageDetected && J0 <= threshold;
result.uncertaintyRegions = mergeRanges(reshape([competing.x], 2, [])');
if result.damageDetected
    near = evGroup == best.group & evJ <= threshold;
    result.dRange = [min(evD(near)), max(evD(near))];
else
    result.dRange = [0 0];
end
result.boundaryFlag = result.damageDetected && best.d >= max(levels) - 1e-12;
result.healthyConsistentWithNoise = [];
if ~isempty(opts.NoiseRMS)
    sigma = opts.NoiseRMS;
    result.healthyConsistentWithNoise = m * J0^2 / sigma^2 <= m + 1.645 * sqrt(2 * m);
end
end

function jn = normalizedError(u, uObs, known)
den = sum(uObs(known).^2);
if den > 0
    jn = sqrt(sum((u(known) - uObs(known)).^2) / den);
else
    jn = NaN;
end
end

function merged = mergeRanges(r)
merged = zeros(0, 2);
if isempty(r)
    return
end
r = sortrows(r, 1);
merged = r(1, :);
for k = 2:size(r, 1)
    if r(k, 1) <= merged(end, 2) + 1e-9 * max(1, abs(merged(end, 2)))
        merged(end, 2) = max(merged(end, 2), r(k, 2));
    else
        merged(end+1, :) = r(k, :); %#ok<AGROW>
    end
end
end
