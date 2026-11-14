function [lines, flags] = identificationSummary(result, truth)
%IDENTIFICATIONSUMMARY Plain-language result of the Stage 3 search, for the app.
%   LINES = IDENTIFICATIONSUMMARY(RESULT) returns a cell column of text
%   lines describing an IDENTIFYSINGLEDAMAGE RESULT: the method, the best
%   fit, the region of uncertainty, every flag that limits the result (fit
%   check, healthy model competing, search limit, RCC) and what the result
%   does not say. LINES = IDENTIFICATIONSUMMARY(RESULT, TRUTH) adds the
%   hidden case of a synthetic test (SYNTHETICOBSERVATIONS) and whether
%   the search found it.
%   [LINES, FLAGS] = IDENTIFICATIONSUMMARY(...) also returns the lines that
%   limit how far the result can be trusted (ratio method, damage not ruled
%   out, healthy model in the region, failed fit check, search limit, RCC),
%   so the app can show them next to the best fit.
%
%   See also IDENTIFYSINGLEDAMAGE, SYNTHETICOBSERVATIONS.

if nargin < 2
    truth = [];
end
likelihood = strcmp(result.method, 'likelihood');
lines = {};
flags = cell(0, 1);
if likelihood
    parts = {};
    if ~isempty(result.noiseLevel) && result.noiseLevel > 0
        parts{end+1} = sprintf('%g %% of each reading', 100 * result.noiseLevel);
    end
    if ~isempty(result.noiseAbsolute) && result.noiseAbsolute > 0
        parts{end+1} = sprintf('%g mm', 1e3 * result.noiseAbsolute);
    end
    lines{end+1, 1} = sprintf('Method: noise-based region (%g %% likelihood ratio), stated noise %s; %d readings, %d structures analysed.', ...
        100 * result.confidence, strjoin(parts, ' + '), result.m, result.nStructures);
else
    lines{end+1, 1} = sprintf(['Method: no noise level stated, so candidates within %g %% of the best RMSE are listed. ' ...
        'This is NOT a confidence region; state a noise level for a noise-based one. %d readings, %d structures.'], ...
        100 * (result.ambiguityRatio - 1), result.m, result.nStructures);
    flags{end+1, 1} = 'No noise level stated: the listed candidates are NOT a confidence region.';
end
b = result.best;
ranking = 'smallest RMSE';
if likelihood
    ranking = 'smallest noise-weighted misfit S';
end
regions = strjoin(arrayfun(@(k) sprintf('%g-%g m', result.uncertaintyRegions(k, 1), result.uncertaintyRegions(k, 2)), ...
    1:size(result.uncertaintyRegions, 1), 'UniformOutput', false), ', ');
if result.damageDetected
    lines{end+1, 1} = sprintf('Best fit (%s): %s (x = %g-%g m), loss d = %s %% (remaining EI x %s), RMSE %s mm, J_N %s %%.', ...
        ranking, elementText(b.elements), b.x(1), b.x(2), formatNumber(100 * b.d, 1), formatNumber(1 - b.d, 3), ...
        formatNumber(1e3 * b.J, 4), formatNumber(100 * b.JN, 2));
    lines{end+1, 1} = sprintf('Region of uncertainty: %s (%d candidate region(s)); loss in the best region %s-%s %%.', ...
        regions, numel(result.competing), formatNumber(100 * result.dRange(1), 1), formatNumber(100 * result.dRange(2), 1));
    mr = result.minRMSE;
    if likelihood && (mr.group ~= b.group || mr.d ~= b.d)
        if mr.group == 0
            what = 'no damage';
        else
            what = sprintf('%s (x = %g-%g m), d = %s %%', elementText(mr.elements), mr.x(1), mr.x(2), formatNumber(100 * mr.d, 1));
        end
        lines{end+1, 1} = sprintf(['Minimum-RMSE candidate (spec section 7 ranking): %s, RMSE %s mm. It differs because ' ...
            'the noise-weighted fit gives small readings their due weight.'], what, formatNumber(1e3 * mr.J, 4));
    end
else
    lines{end+1, 1} = sprintf('Best fit: NO DAMAGE (the healthy model fits best), RMSE %s mm.', formatNumber(1e3 * b.J, 4));
    if ~isempty(result.competing)
        dMax = max(arrayfun(@(c) c.dRange(2), result.competing));
        lines{end+1, 1} = sprintf('Damage cannot be ruled out in: %s (%d candidate region(s), loss up to %s %%).', ...
            regions, numel(result.competing), formatNumber(100 * dMax, 1));
        flags{end+1, 1} = lines{end};
    end
end
if result.healthyCompetes
    lines{end+1, 1} = 'No damage cannot be ruled out: the healthy model is also inside the region.';
    flags{end+1, 1} = lines{end};
end
if likelihood && ~isempty(result.gof) && ~isnan(result.gof.threshold)
    if result.modelMisfit
        lines{end+1, 1} = sprintf(['FIT CHECK FAILED (S = %s > %s, %d degrees of freedom): no single region explains the ' ...
            'readings within the stated noise. The noise may be underestimated, or supports, loads, baseline EI or ' ...
            'the one-region assumption are wrong. Do not rely on the region.'], formatNumber(result.gof.S, 1), ...
            formatNumber(result.gof.threshold, 1), result.gof.dof);
        flags{end+1, 1} = 'FIT CHECK FAILED: no single region explains the readings within the stated noise. Do not rely on the region.';
    else
        lines{end+1, 1} = sprintf('Fit check passed: S = %s <= %s (%d degrees of freedom).', ...
            formatNumber(result.gof.S, 1), formatNumber(result.gof.threshold, 1), result.gof.dof);
    end
end
if result.boundaryFlag
    lines{end+1, 1} = sprintf(['Best loss at the %g %% search limit: a larger loss cannot be represented, and the location ' ...
        'is not reliable.'], 100 * max(result.levels));
    flags{end+1, 1} = lines{end};
elseif result.regionAtSearchLimit
    lines{end+1, 1} = sprintf(['The region reaches the %g %% search limit: larger losses were not evaluated (d ranges ' ...
        'are open above).'], 100 * max(result.levels));
    flags{end+1, 1} = lines{end};
end
if result.rccBaseline
    lines{end+1, 1} = 'RCC baseline: normal cracking or an uncertain I_eff can mimic a stiffness loss (spec section 7).';
    flags{end+1, 1} = lines{end};
end
if ~isempty(truth)
    if truth.d > 0
        inside = any(result.uncertaintyRegions(:, 1) <= truth.x(1) + 1e-9 & result.uncertaintyRegions(:, 2) >= truth.x(2) - 1e-9);
        covers = result.damageDetected && b.x(1) <= truth.x(1) + 1e-9 && b.x(2) >= truth.x(2) - 1e-9;
        lines{end+1, 1} = sprintf(['Synthetic test case (hidden from the search): %s (x = %g-%g m), d = %g %%, noise %g %%, ' ...
            'seed %d. True region inside the reported region: %s. Best-fit region contains the true region: %s.'], ...
            elementText(truth.elements), truth.x(1), truth.x(2), 100 * truth.d, 100 * truth.noise, truth.seed, ...
            yesNo(inside), yesNo(covers));
        if result.damageDetected && numel(b.elements) > numel(truth.elements)
            lines{end+1, 1} = ['The candidate regions are longer than the hidden region: the best-fit loss is spread ' ...
                'over the whole candidate region, so it is smaller than the hidden loss.'];
        end
    else
        lines{end+1, 1} = sprintf(['Synthetic test case (hidden from the search): NO damage, noise %g %%, seed %d. ' ...
            '"No damage" kept possible: %s.'], 100 * truth.noise, truth.seed, yesNo(~result.damageDetected || result.healthyCompetes));
    end
    lines{end+1, 1} = 'Self-generated readings: this checks the algorithm, it is not field validation.';
end
lines{end+1, 1} = ['The result locates a change of effective stiffness in the model; it does not identify the cause ' ...
    '(corrosion, cracking, ...). Fit measures rank candidates; they are not probabilities.'];
end

function s = elementText(els)
if numel(els) == 1
    s = sprintf('element %d', els);
else
    s = sprintf('elements %d-%d', min(els), max(els));
end
end

function s = yesNo(flag)
if flag
    s = 'yes';
else
    s = 'no';
end
end
