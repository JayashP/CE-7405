function plotReadings(ax, positions, uObs, uHealthy, uBest, th)
%PLOTREADINGS Sensor readings with the healthy and best-fit predictions (Stage 3).
%   PLOTREADINGS(AX, POSITIONS, UOBS, UHEALTHY, UBEST, TH) clears AX and
%   draws, for every sensor (rows of the matrices, in m; shown in mm)
%   against the truck front-axle POSITIONS [m]: the readings as markers,
%   the healthy model as a dotted line and the best fit as a solid line,
%   one colour per sensor, labelled S1, S2, ... at the right-most position.
%   The gap between markers and the solid line is the residual of the best
%   fit. UBEST may be empty (before a search). Missing readings (NaN) are
%   simply not drawn. The legend is built from the first sensor's handles;
%   no object has hidden handles, so the next CLA removes everything.
%
%   See also IDENTIFYSINGLEDAMAGE.

palette = [th.sensor; th.deflection; th.load; th.moment; th.shear; th.damage];
xv = positions(:)';
[xRight, jRight] = max(xv);
cla(ax);
hold(ax, 'on');
for i = 1:size(uObs, 1)
    c = palette(mod(i - 1, size(palette, 1)) + 1, :);
    hHealthy = plot(ax, xv, 1e3 * uHealthy(i, :), 'Color', c, 'LineStyle', ':', 'LineWidth', 1.2);
    yLabel = uHealthy(i, jRight);
    if ~isempty(uBest)
        hBest = plot(ax, xv, 1e3 * uBest(i, :), 'Color', c, 'LineWidth', 1.8);
        yLabel = uBest(i, jRight);
    end
    hObs = plot(ax, xv, 1e3 * uObs(i, :), 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 6, ...
        'MarkerEdgeColor', c, 'MarkerFaceColor', c);
    text(ax, xRight, 1e3 * yLabel, sprintf('  S%d', i), 'Color', c, 'FontSize', 9, 'HorizontalAlignment', 'left');
    if i == 1
        if isempty(uBest)
            handles = [hHealthy, hObs];
            labels = {'healthy model', 'readings'};
        else
            handles = [hHealthy, hBest, hObs];
            labels = {'healthy model', 'best fit', 'readings'};
        end
    end
end
hold(ax, 'off');
if size(uObs, 1) > 0
    legend(ax, handles, labels, 'Location', 'best');
end
grid(ax, 'on');
span = max(xv) - min(xv);
xlim(ax, [min(xv) - 0.05 * span - (span == 0), xRight + 0.15 * span + (span == 0)]);
xlabel(ax, 'truck front-axle position x_v [m]');
ylabel(ax, 'deflection [mm]');
title(ax, 'Readings and fits');
end
