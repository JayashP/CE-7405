function p = fitProfileData(result, model)
%FITPROFILEDATA How well each candidate region fits, for the Stage 3 bar chart.
%   P = FITPROFILEDATA(RESULT, MODEL) turns an IDENTIFYSINGLEDAMAGE RESULT
%   into one value per candidate group (fields are column vectors):
%     x1, x2     group start and end [m]
%     d          the group's best loss
%     value      'likelihood': S_group - S_best (chi-square units);
%                'ratio': RMSE_group / RMSE_best
%     inRegion   the group is in the region of uncertainty
%   and scalars threshold (chi2Region, or the ambiguity ratio),
%   healthyValue (the same measure for the healthy model), label (axis
%   label, TeX) and ratio (true for the ratio method).
%   A group is in the region when value <= threshold.
%
%   See also IDENTIFYSINGLEDAMAGE, PLOTFITPROFILE.

x = model.nodes.x;
ev = result.evaluated;
nG = numel(result.groups);
p.x1 = zeros(nG, 1);
p.x2 = zeros(nG, 1);
p.d = zeros(nG, 1);
p.value = zeros(nG, 1);
likelihood = strcmp(result.method, 'likelihood');
if likelihood
    ref = min(ev.S);
    p.threshold = result.chi2Region;
    p.healthyValue = result.Shealthy - ref;
    p.label = 'S - S_{best} [-]';               % TeX: braces keep "best" as one subscript
    p.ratio = false;
else
    uObs = result.best.u - result.best.residual;
    floorJ = 1e-9 * sqrt(mean(uObs(~isnan(uObs)).^2));
    ref = max(result.best.J, floorJ);
    p.threshold = result.ambiguityRatio;
    p.healthyValue = max(result.Jhealthy, floorJ) / ref;
    p.label = 'RMSE / best RMSE [-]';
    p.ratio = true;
end
for g = 1:nG
    els = result.groups{g};
    own = find(ev.group == g);
    if likelihood
        [v, i] = min(ev.S(own));
        p.value(g) = v - ref;
    else
        [v, i] = min(ev.J(own));
        p.value(g) = max(v, floorJ) / ref;
    end
    p.x1(g) = x(min(els));
    p.x2(g) = x(max(els) + 1);
    p.d(g) = ev.d(own(i));
end
p.inRegion = ismember((1:nG)', [result.competing.group]');
end
