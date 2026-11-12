function result = identifySingleDamage(model, vehicle, xvList, sensorX, uObs, varargin)
%IDENTIFYSINGLEDAMAGE Single-region inverse stiffness-loss search from sensor deflections (Stage 3).
%   RESULT = IDENTIFYSINGLEDAMAGE(MODEL, VEHICLE, XVLIST, SENSORX, UOBS, NAME, VALUE, ...)
%   estimates WHERE one region of the healthy baseline MODEL may have lost
%   effective flexural rigidity and HOW MUCH (EI_D = (1 - d) EI), from the
%   observed vehicle-induced deflections UOBS [m] (+ up; NS-by-NP: sensor i
%   at SENSORX(i), vehicle front axle at XVLIST(p)), following
%   PROJECT_SPEC.md section 7 (DECISIONS.md D-028, D-029):
%     1. the healthy model (d = 0) is evaluated ONCE;
%     2. coarse scan: every candidate group (default: each element; see
%        CANDIDATEGROUPS for regions of a chosen length) with d = 5 %,
%        10 %, ..., 60 % (20 elements: 240 + 1 = 241 structures);
%     3. refinement in 1 % steps within +/- one coarse step of each group's
%        coarse optimum: the 'RefineCount' best groups ('ratio' method) or
%        EVERY group plus one structure at the parabola vertex (when a
%        noise level is stated);
%     4. fit measures over the m observed (non-NaN) readings r = u_FE - u_obs:
%          J   = sqrt(mean(r.^2))              RMSE (spec section 7), always
%          J_N = sqrt(sum(r.^2) / sum(u_obs.^2))
%          S   = sum((r ./ sigma).^2)          chi-square misfit, only with
%                                              a stated noise level
%   Predictions use PREDICTSENSORDEFLECTIONS (vehicle-only deflection).
%   Missing observations are NaN and are left out.
%
%   The region of uncertainty depends on whether a noise level is stated:
%     'ratio'       (no noise level) candidates compete when their RMSE is
%                   within 'AmbiguityRatio' (default 1.10) of the best.
%                   Simple, but NOT a confidence region: with noisy data it
%                   often misses the true region (VERIFICATION_LOG V-018).
%     'likelihood'  ('NoiseLevel' and/or 'NoiseAbsolute' given) each
%                   reading gets the standard deviation
%                     sigma_i = sqrt((NoiseLevel * |u_healthy,i|)^2 + NoiseAbsolute^2)
%                   from the HEALTHY model's prediction u_healthy, so the
%                   weights do not depend on the noisy data (weights taken
%                   from the observed readings would favour readings that
%                   noise made smaller, D-029). For each group one more
%                   structure is analysed at the vertex of the parabola
%                   through its lowest 1 % point and the two neighbours
%                   (only between them, never at d <= 0), so the minimum
%                   between grid points is computed. The best candidate has
%                   the smallest S (weighted least squares; with a constant
%                   sigma it is the minimum-RMSE candidate), and a group is
%                   in the region when
%                     S_group - S_best <= chiSquareQuantile('Confidence', 2)
%                   (likelihood-ratio region for the two unknowns, location
%                   and loss; 5.99 for 95 %). It is an approximation:
%                   location is discrete, u is nonlinear in d, d = 0 is a
%                   boundary. Its coverage is MEASURED (tools/inverseNoiseStudy,
%                   VERIFICATION_LOG), not guaranteed.
%                   Fit check: if S_best > chiSquareQuantile('Confidence',
%                   dof) with dof = m - 2 (m when the healthy model fits
%                   best), no candidate explains the data within the stated
%                   noise (modelMisfit = true): the noise is underestimated
%                   or the model (supports, loads, baseline EI, one region)
%                   is wrong, and the region should not be relied on.
%
%   Options:
%     'Direction'      +1 (default) or -1, as in the moving-load engine
%     'Groups'         cell array of element index vectors (candidate
%                      regions), default {1; 2; ...; NE}; see CANDIDATEGROUPS
%     'Levels'         coarse d values, default 0.05:0.05:0.60
%     'RefineStep'     refinement step, default 0.01 (0 = no refinement)
%     'RefineCount'    'ratio' method: number of best groups refined, default 3
%     'AmbiguityRatio' 'ratio' method threshold, default 1.10
%     'NoiseLevel'     proportional noise, e.g. 0.02 for 2 % of each reading
%     'NoiseAbsolute'  absolute noise standard deviation [m]
%     'Confidence'     'likelihood' method level, default 0.95
%
%   RESULT fields (SI units):
%     method                     'ratio' or 'likelihood'
%     ambiguityRatio, noiseLevel, noiseAbsolute, confidence   the options used
%     m, sigma                   number of readings; per-reading sigma ([]
%                                for 'ratio')
%     Jhealthy, JNhealthy, Shealthy, uHealthy    healthy model fit
%     groups, levels, Jcoarse, Scoarse           coarse scan (NG-by-NL)
%     evaluated                  struct: group, d, J, S of every structure
%                                evaluated (healthy: group 0, d 0)
%     nStructures                number of distinct structures
%     best        group, elements, x ([start end] m), d, remaining (1 - d),
%                 J, JN, S, Smin (= S; NaN for 'ratio'), u (NS-by-NP),
%                 residual (u - uObs)
%     damageDetected     false when the healthy model fits best
%     minRMSE     the minimum-RMSE candidate of spec section 7 (group,
%                 elements, x, d, J); the same as best for 'ratio', and
%                 often different with a proportional noise level
%     competing   struct array, one per group in the region, best first:
%                 group, elements, x, d (best d), dRange ([min max] of the
%                 evaluated d inside the region), J, S, Smin, ratio (J / J_best;
%                 exact fits have ratio 1; below 1 is possible when the
%                 best is chosen by S), deltaS (Smin - Smin_best; NaN for
%                 'ratio')
%     ambiguous          more than one group in the region
%     healthyCompetes    damage found, but the healthy model is also in the
%                        region (no damage cannot be ruled out)
%     uncertaintyRegions K-by-2 [start end] m, merged x-ranges of the
%                        competing groups
%     dRange             [min max] evaluated d of the best group inside the region
%     boundaryFlag       best d at the largest coarse level (search limit)
%     regionAtSearchLimit  some candidate inside the region has d at the
%                        search limit: larger losses were not evaluated, so
%                        the upper ends of the d ranges are open (>= 60 %)
%     rccBaseline        the model uses an RCC material; a warning
%                        'BridgeFE:rccInverse' is issued (spec section 7
%                        defers RCC: cracking or uncertain I_eff can mimic
%                        damage)
%     chi2Region         region threshold on S ([] for 'ratio')
%     gof                struct S, dof, threshold, pValue ([] for 'ratio')
%     modelMisfit        true when S_best exceeds the fit threshold
%                        (false for 'ratio')
%
%   Ratios and chi-square values rank how well candidates fit; they are not
%   probabilities that a candidate is the damage (spec section 7). The
%   result says where effective stiffness may have changed, not the
%   physical cause. Agreement with self-generated data is algorithm
%   verification, not field validation.
%
%   See also PREDICTSENSORDEFLECTIONS, CANDIDATEGROUPS, CHISQUAREQUANTILE,
%   ADDMEASUREMENTNOISE.

validateModel(model);
ne = size(model.elements.conn, 1);
if any(model.elements.stiffnessFactor ~= 1)
    error('BridgeFE:invalidInput', 'The baseline model must be healthy (all stiffness factors 1).');
end
opts = struct('Direction', 1, 'Groups', {num2cell((1:ne)')}, 'Levels', 0.05:0.05:0.60, 'RefineStep', 0.01, ...
    'RefineCount', 3, 'AmbiguityRatio', 1.10, 'NoiseLevel', [], 'NoiseAbsolute', [], 'Confidence', 0.95);
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
if isempty(groups) || ~iscell(groups) || ...
        ~all(cellfun(@(g) isnumeric(g) && ~isempty(g) && all(g >= 1 & g <= ne & g == round(g)), groups))
    error('BridgeFE:invalidInput', 'Groups must be a cell array of element index vectors (1 to %d).', ne);
end
if ~isnumeric(opts.Levels) || isempty(opts.Levels) || any(~isfinite(opts.Levels(:)) | opts.Levels(:) <= 0 | opts.Levels(:) >= 1)
    error('BridgeFE:invalidInput', 'Levels must be values of d with 0 < d < 1.');
end
levels = unique(opts.Levels(:))';                 % sorted row
step = opts.RefineStep;
if ~(isnumeric(step) && isscalar(step) && step >= 0 && step < 1)
    error('BridgeFE:invalidInput', 'RefineStep must satisfy 0 <= step < 1.');
end
if ~(isnumeric(opts.AmbiguityRatio) && isscalar(opts.AmbiguityRatio) && opts.AmbiguityRatio >= 1)
    error('BridgeFE:invalidInput', 'AmbiguityRatio must be a number >= 1.');
end
noiseOk = @(v) isempty(v) || (isnumeric(v) && isscalar(v) && isfinite(v) && v >= 0);
if ~(noiseOk(opts.NoiseLevel) && noiseOk(opts.NoiseAbsolute))
    error('BridgeFE:invalidInput', 'NoiseLevel and NoiseAbsolute must be numbers >= 0 (or empty).');
end
if ~(isnumeric(opts.Confidence) && isscalar(opts.Confidence) && opts.Confidence > 0 && opts.Confidence < 1)
    error('BridgeFE:invalidInput', 'Confidence must satisfy 0 < Confidence < 1.');
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
ids = model.elements.materialId(model.elements.materialId > 0);
result.rccBaseline = ~isempty(ids) && any(strcmpi({model.materials(unique(ids)).type}, 'rcc'));
if result.rccBaseline
    warning('BridgeFE:rccInverse', ['RCC baseline: normal cracking or an uncertain I_eff can mimic a stiffness ' ...
        'loss, so the result cannot be separated from them (PROJECT_SPEC.md section 7). Use it only with a ' ...
        'defensibly established baseline E_c*I_eff.']);
end
predict = @(mdl) predictSensorDeflections(mdl, vehicle, xvList, sensorX, opts.Direction);

% 1. Healthy model, once; per-reading noise from its prediction
uHealthy = predict(model);
likelihood = ~isempty(opts.NoiseLevel) || ~isempty(opts.NoiseAbsolute);
sigma = [];
if likelihood
    p = 0;
    s = 0;
    if ~isempty(opts.NoiseLevel)
        p = opts.NoiseLevel;
    end
    if ~isempty(opts.NoiseAbsolute)
        s = opts.NoiseAbsolute;
    end
    sigma = sqrt((p * abs(uHealthy)).^2 + s^2);
    sigma(~known) = NaN;
    if any(sigma(known) <= 0)
        error('BridgeFE:invalidInput', ['Every observed reading needs a noise standard deviation > 0; ' ...
            'give NoiseAbsolute when a predicted reading is zero (e.g. the vehicle off the span).']);
    end
    delta = chiSquareQuantile(opts.Confidence, 2);
end
fit = @(u) fitMeasures(u, uObs, known, sigma);
[J0, S0] = fit(uHealthy);
evGroup = 0;
evD = 0;
evJ = J0;
evS = S0;

% 2. Coarse scan
nG = numel(groups);
nL = numel(levels);
Jcoarse = zeros(nG, nL);
Scoarse = NaN(nG, nL);
for g = 1:nG
    for k = 1:nL
        [Jcoarse(g, k), Scoarse(g, k)] = fit(predict(applyStiffnessDamage(model, groups{g}, levels(k))));
    end
end
[gg, kk] = ndgrid(1:nG, 1:nL);
evGroup = [evGroup; gg(:)];
evD = [evD; reshape(levels(kk(:)), [], 1)];
evJ = [evJ; Jcoarse(:)];
evS = [evS; Scoarse(:)];
if likelihood
    Fcoarse = Scoarse;
else
    Fcoarse = Jcoarse;
end

% 3. Refinement around each selected group's coarse optimum
if step > 0
    [FgCoarse, kBest] = min(Fcoarse, [], 2);
    [~, order] = sort(FgCoarse);
    refine = false(nG, 1);
    if likelihood
        refine(:) = true;              % region membership must not be decided on the coarse grid
    else
        refine(order(1:min(opts.RefineCount, nG))) = true;
    end
    spacing = max([diff(levels), step]);
    for g = order(refine(order))'
        dc = levels(kBest(g));
        lo = max(1, ceil((dc - spacing) / step - 1e-9));
        hi = min(floor(max(levels) / step + 1e-9), floor((dc + spacing) / step + 1e-9));
        for i = lo:hi
            d = i * step;
            if any(evGroup == g & abs(evD - d) < 1e-12)
                continue                                   % already evaluated (coarse value)
            end
            [Jd, Sd] = fit(predict(applyStiffnessDamage(model, groups{g}, d)));
            evGroup(end+1, 1) = g; %#ok<AGROW>
            evD(end+1, 1) = d; %#ok<AGROW>
            evJ(end+1, 1) = Jd; %#ok<AGROW>
            evS(end+1, 1) = Sd; %#ok<AGROW>
        end
    end
end
% With a stated noise level: one more structure per group at the vertex of the parabola through
% its lowest point and the two neighbours, so the minimum between grid points is COMPUTED, not
% estimated (a loss between grid points would otherwise inflate S and the fit check).
if likelihood
    for g = 1:nG
        own = evGroup == g;
        dv = parabolaVertex(evD(own), evS(own), S0);
        if ~isnan(dv) && all(abs(evD(own) - dv) > 1e-9)
            [Jd, Sd] = fit(predict(applyStiffnessDamage(model, groups{g}, dv)));
            evGroup(end+1, 1) = g; %#ok<AGROW>
            evD(end+1, 1) = dv; %#ok<AGROW>
            evJ(end+1, 1) = Jd; %#ok<AGROW>
            evS(end+1, 1) = Sd; %#ok<AGROW>
        end
    end
end
if likelihood
    evF = evS;
else
    evF = evJ;
end
result.method = 'ratio';
if likelihood
    result.method = 'likelihood';
end
result.ambiguityRatio = opts.AmbiguityRatio;
result.noiseLevel = opts.NoiseLevel;
result.noiseAbsolute = opts.NoiseAbsolute;
result.confidence = opts.Confidence;
result.m = m;
result.sigma = sigma;
result.Jhealthy = J0;
result.JNhealthy = normalizedError(uHealthy, uObs, known);
result.Shealthy = S0;
result.uHealthy = uHealthy;
result.groups = groups;
result.levels = levels;
result.Jcoarse = Jcoarse;
result.Scoarse = Scoarse;
result.evaluated = struct('group', evGroup, 'd', evD, 'J', evJ, 'S', evS);
result.nStructures = numel(evJ);

% Smallest computed S of each group ('likelihood' only)
Smin = NaN(nG, 1);
if likelihood
    for g = 1:nG
        Smin(g) = min(evS(evGroup == g));
    end
    SminBest = min([S0; Smin]);
end

% 4. Best candidate (the healthy model, listed first, wins ties: no damage without evidence)
[~, iBest] = min(evF);
x = model.nodes.x;
if iBest == 1
    best = struct('group', 0, 'elements', [], 'x', [NaN NaN], 'd', 0, 'remaining', 1, 'J', J0, ...
        'JN', result.JNhealthy, 'S', S0, 'Smin', S0, 'u', uHealthy, 'residual', uHealthy - uObs);
    if ~likelihood
        best.Smin = NaN;
    end
else
    g = evGroup(iBest);
    els = groups{g};
    uBest = predict(applyStiffnessDamage(model, els, evD(iBest)));
    best = struct('group', g, 'elements', els(:)', 'x', [x(min(els)), x(max(els) + 1)], 'd', evD(iBest), ...
        'remaining', 1 - evD(iBest), 'J', evJ(iBest), 'JN', normalizedError(uBest, uObs, known), ...
        'S', evS(iBest), 'Smin', Smin(g), 'u', uBest, 'residual', uBest - uObs);
end
result.best = best;
result.damageDetected = best.group ~= 0;
[~, iJ] = min(evJ);                            % spec section 7 best: minimum RMSE
if iJ == 1
    result.minRMSE = struct('group', 0, 'elements', [], 'x', [NaN NaN], 'd', 0, 'J', J0);
else
    els = groups{evGroup(iJ)};
    result.minRMSE = struct('group', evGroup(iJ), 'elements', els(:)', 'x', [x(min(els)), x(max(els) + 1)], ...
        'd', evD(iJ), 'J', evJ(iJ));
end

% 5. Region of uncertainty: every group whose best fit passes the method's criterion
floorJ = 1e-9 * rmsObs;                        % round-off level of J
if likelihood
    inGroup = Smin - SminBest <= delta;
    insidePoint = evS - SminBest <= delta;     % grid points inside (for the d ranges)
    healthyInside = S0 - SminBest <= delta;
    result.chi2Region = delta;
else
    threshold = max(opts.AmbiguityRatio * best.J, floorJ);
    insidePoint = evJ <= threshold;
    inGroup = false(nG, 1);
    for g = 1:nG
        inGroup(g) = any(insidePoint(evGroup == g));
    end
    healthyInside = insidePoint(1);
    result.chi2Region = [];
end
competing = struct('group', {}, 'elements', {}, 'x', {}, 'd', {}, 'dRange', {}, 'J', {}, 'S', {}, 'Smin', {}, ...
    'ratio', {}, 'deltaS', {});
rank = [];
for g = find(inGroup)'
    own = find(evGroup == g);
    [Fg, i] = min(evF(own));
    els = groups{g};
    dIn = evD(own(insidePoint(own)));
    if isempty(dIn)
        dIn = evD(own(i));                     % inside only between grid points
    end
    deltaS = NaN;
    rankValue = Fg;
    if likelihood
        deltaS = Smin(g) - SminBest;
        rankValue = Smin(g);
    end
    competing(end+1) = struct('group', g, 'elements', els(:)', 'x', [x(min(els)), x(max(els) + 1)], ...
        'd', evD(own(i)), 'dRange', [min(dIn), max(dIn)], 'J', evJ(own(i)), 'S', evS(own(i)), 'Smin', Smin(g), ...
        'ratio', max(evJ(own(i)), floorJ) / max(best.J, floorJ), 'deltaS', deltaS); %#ok<AGROW>
    rank(end+1) = rankValue; %#ok<AGROW>
end
[~, order] = sort(rank);
competing = competing(order);
result.competing = competing;
result.ambiguous = numel(competing) > 1;
result.healthyCompetes = result.damageDetected && healthyInside;
result.uncertaintyRegions = mergeRanges(reshape([competing.x], 2, [])');
result.dRange = [0 0];
if result.damageDetected
    match = [competing.group] == best.group;
    if any(match)
        result.dRange = competing(match).dRange;
    else
        result.dRange = [best.d best.d];
    end
end
result.boundaryFlag = result.damageDetected && best.d >= max(levels) - 1e-12;
result.regionAtSearchLimit = any(evGroup(insidePoint) > 0 & evD(insidePoint) >= max(levels) - 1e-12);

% 6. Goodness of fit against the stated noise
result.gof = [];
result.modelMisfit = false;
if likelihood
    dof = m - 2;
    if ~result.damageDetected
        dof = m;                               % the healthy model has no fitted unknowns
    end
    gof = struct('S', SminBest, 'dof', dof, 'threshold', NaN, 'pValue', NaN);
    if dof > 0
        gof.threshold = chiSquareQuantile(opts.Confidence, dof);
        gof.pValue = 1 - gammainc(SminBest / 2, dof / 2);
        result.modelMisfit = SminBest > gof.threshold;
    end
    result.gof = gof;
end
end

function [J, S] = fitMeasures(u, uObs, known, sigma)
r = u(known) - uObs(known);
J = sqrt(mean(r.^2));
S = NaN;
if ~isempty(sigma)
    S = sum((r ./ sigma(known)).^2);
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

function dv = parabolaVertex(d, S, S0)
% d at the vertex of the parabola through one group's lowest evaluated
% point and its nearest neighbours on both sides, when they are equally
% spaced (the healthy value S0 is the d = 0 neighbour); NaN when there is
% no such vertex strictly between the neighbours (never d <= 0).
[d, order] = sort(d);
S = S(order);
[b, k] = min(S);
dv = NaN;
if k > 1
    dl = d(k - 1);
    Sl = S(k - 1);
else
    dl = 0;
    Sl = S0;
end
if k == numel(d)
    return                                     % at the upper search limit
end
dr = d(k + 1);
Sr = S(k + 1);
h = d(k) - dl;
if h <= 0 || abs((dr - d(k)) - h) > 1e-9
    return
end
den = Sl - 2 * b + Sr;
if den > 0
    vertex = d(k) - h * (Sr - Sl) / (2 * den);
    if vertex > max(dl, 0) && vertex < dr     % only between the tested neighbours, never at d <= 0
        dv = vertex;
    end
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
