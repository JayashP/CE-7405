function plotFitProfile(ax, p, x, th)
%PLOTFITPROFILE Bar chart of how well each candidate region fits (Stage 3).
%   PLOTFITPROFILE(AX, P, X, TH) clears AX and draws one bar per candidate
%   region of FITPROFILEDATA result P over its x-range (beam nodes X [m],
%   theme TH): amber inside the region of uncertainty, grey outside; the
%   dashed line is the region limit (P.threshold), the dotted line the
%   healthy model ("no damage"), with a legend above the chart. The best
%   fit is the reference (its bar has zero height), so it is marked with a
%   star on the axis. Bars taller
%   than four times the limit are cut off and marked with a triangle, so
%   the regions near the limit stay readable. For the ratio method the bars
%   start at 1 (RMSE / best RMSE). No object has hidden handles, so the
%   next CLA removes everything.
%
%   See also FITPROFILEDATA, IDENTIFYSINGLEDAMAGE.

base = 0;
if p.ratio
    base = 1;
end
cap = base + 4 * (p.threshold - base);
cla(ax);
hold(ax, 'on');
handles = [];
labels = {};
for g = 1:numel(p.value)
    pad = 0.08 * (p.x2(g) - p.x1(g));
    top = min(p.value(g), cap);
    colour = th.candidate;
    if p.inRegion(g)
        colour = th.regionBest;
    end
    h = patch(ax, [p.x1(g) + pad, p.x2(g) - pad, p.x2(g) - pad, p.x1(g) + pad], [base, base, top, top], colour, ...
        'EdgeColor', colour);
    if p.inRegion(g) && ~any(strcmp(labels, 'in region'))
        handles = [handles, h]; %#ok<AGROW>
        labels{end+1} = 'in region'; %#ok<AGROW>
    elseif ~p.inRegion(g) && ~any(strcmp(labels, 'outside'))
        handles = [handles, h]; %#ok<AGROW>
        labels{end+1} = 'outside'; %#ok<AGROW>
    end
    if p.value(g) > cap
        plot(ax, (p.x1(g) + p.x2(g)) / 2, cap, 'LineStyle', 'none', 'Marker', '^', 'MarkerSize', 5, ...
            'MarkerEdgeColor', th.text, 'MarkerFaceColor', th.text);
    end
end
if p.bestGroup > 0
    handles = [handles, plot(ax, (p.x1(p.bestGroup) + p.x2(p.bestGroup)) / 2, base, 'LineStyle', 'none', ...
        'Marker', 'p', 'MarkerSize', 12, 'MarkerEdgeColor', th.text, 'MarkerFaceColor', th.regionBest)];
    labels{end+1} = 'best fit';
end
handles = [handles, plot(ax, [x(1), x(end)], [p.threshold, p.threshold], 'Color', th.text, 'LineStyle', '--', ...
    'LineWidth', 1.2)];
labels{end+1} = 'limit';
if p.healthyValue <= cap
    handles = [handles, plot(ax, [x(1), x(end)], [p.healthyValue, p.healthyValue], 'Color', th.truth, ...
        'LineStyle', ':', 'LineWidth', 1.2)];
    labels{end+1} = 'no damage';
end
hold(ax, 'off');
legend(ax, handles, labels, 'Location', 'northoutside', 'Orientation', 'horizontal');
grid(ax, 'on');
xlim(ax, [x(1), x(end)]);
top = cap * 1.05 + (cap == base);
ylim(ax, [base - 0.05 * (top - base), top]);   % room for the star of the best fit on the axis
xlabel(ax, 'candidate region x [m]');
ylabel(ax, p.label);
end
