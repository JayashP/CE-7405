function plotEnvelope(ax, x, yMax, yMin, colorMax, colorMin, yLabelText, titleText, markX, markY)
%PLOTENVELOPE Maximum and minimum response envelope along the beam.
%   PLOTENVELOPE(AX, X, YMAX, YMIN, COLORMAX, COLORMIN, YLABELTEXT, TITLETEXT,
%   MARKX, MARKY) clears AX, shades the band between YMIN and YMAX at the
%   stations X [m], draws both curves with a legend, and marks the critical
%   points (MARKX, MARKY), which may be empty.
%
%   See also RUNMOVINGLOAD, PLOTDIAGRAM.

x = x(:);
yMax = yMax(:);
yMin = yMin(:);
cla(ax);
hold(ax, 'on');
patch(ax, [x; flipud(x)], [yMax; flipud(yMin)], colorMax, 'FaceAlpha', 0.10, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');
plot(ax, x, yMax, 'Color', colorMax, 'LineWidth', 1.6);
plot(ax, x, yMin, 'Color', colorMin, 'LineWidth', 1.6);
plot(ax, [min(x), max(x)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8, 'HandleVisibility', 'off');
if nargin >= 10 && ~isempty(markX)
    plot(ax, markX, markY, 'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 6, ...
        'MarkerEdgeColor', [0.20 0.20 0.20], 'MarkerFaceColor', [1.00 0.85 0.30], 'HandleVisibility', 'off');
end
hold(ax, 'off');
legend(ax, {'max', 'min'}, 'Location', 'best');   % only the two curves are visible to the legend
grid(ax, 'on');
xlim(ax, [min(x), max(x)]);
xlabel(ax, 'x [m]');
ylabel(ax, yLabelText);
title(ax, titleText);
end
