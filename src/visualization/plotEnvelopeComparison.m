function plotEnvelopeComparison(ax, x, hMax, hMin, dMax, dMin, colorHealthy, colorDamaged, yLabelText, titleText, xLabelText)
%PLOTENVELOPECOMPARISON Damaged (solid, thick) and healthy (dashed, on top) max/min envelopes on one axes.
%   PLOTENVELOPECOMPARISON(AX, X, HMAX, HMIN, DMAX, DMIN, COLORHEALTHY,
%   COLORDAMAGED, YLABELTEXT, TITLETEXT) clears AX and draws, at the
%   stations X [m], the damaged envelope as thick lines (max solid, min
%   dash-dot) and then the healthy envelope as thinner dashed lines ON TOP.
%   Where the two coincide (e.g. moments of a statically determinate beam)
%   the dashed healthy line stays visible over the damaged one, so the
%   reader sees "unchanged" instead of a missing curve. Legend and labels
%   are added.
%
%   See also COMPAREHEALTHYDAMAGED, PLOTENVELOPE.

x = x(:);
cla(ax);
hold(ax, 'on');
plot(ax, [min(x), max(x)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8);
h1 = plot(ax, x, dMax(:), 'Color', colorDamaged, 'LineWidth', 2.4);
h2 = plot(ax, x, dMin(:), 'Color', colorDamaged, 'LineWidth', 2.4, 'LineStyle', '-.');
h3 = plot(ax, x, hMax(:), 'Color', colorHealthy, 'LineWidth', 1.2, 'LineStyle', '--');
h4 = plot(ax, x, hMin(:), 'Color', colorHealthy, 'LineWidth', 1.2, 'LineStyle', ':');
hold(ax, 'off');
legend(ax, [h1, h2, h3, h4], {'damaged max', 'damaged min', 'healthy max', 'healthy min'}, 'Location', 'best');
grid(ax, 'on');
xlim(ax, [min(x), max(x)]);
if nargin < 11
    xLabelText = 'x [m]';                       % optional: the app passes its display length unit
end
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
title(ax, titleText);
end
