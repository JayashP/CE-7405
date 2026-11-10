function plotEnvelopeComparison(ax, x, hMax, hMin, dMax, dMin, colorHealthy, colorDamaged, yLabelText, titleText)
%PLOTENVELOPECOMPARISON Healthy (dashed) and damaged (solid) max/min envelopes on one axes.
%   PLOTENVELOPECOMPARISON(AX, X, HMAX, HMIN, DMAX, DMIN, COLORHEALTHY,
%   COLORDAMAGED, YLABELTEXT, TITLETEXT) clears AX and draws the healthy
%   envelope as dashed lines and the damaged envelope as solid lines at the
%   stations X [m], with a legend and labelled axes.
%
%   See also COMPAREHEALTHYDAMAGED, PLOTENVELOPE.

x = x(:);
cla(ax);
hold(ax, 'on');
plot(ax, x, hMax(:), 'Color', colorHealthy, 'LineWidth', 1.4, 'LineStyle', '--');
plot(ax, x, hMin(:), 'Color', colorHealthy, 'LineWidth', 1.4, 'LineStyle', ':');
plot(ax, x, dMax(:), 'Color', colorDamaged, 'LineWidth', 1.8);
plot(ax, x, dMin(:), 'Color', colorDamaged, 'LineWidth', 1.8, 'LineStyle', '-.');
plot(ax, [min(x), max(x)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8, 'HandleVisibility', 'off');
hold(ax, 'off');
legend(ax, {'healthy max', 'healthy min', 'damaged max', 'damaged min'}, 'Location', 'best');
grid(ax, 'on');
xlim(ax, [min(x), max(x)]);
xlabel(ax, 'x [m]');
ylabel(ax, yLabelText);
title(ax, titleText);
end
