function plotEnvelopeComparison(ax, x, hMax, hMin, dMax, dMin, colorHealthy, colorDamaged, yLabelText, titleText, xLabelText)
%PLOTENVELOPECOMPARISON Healthy and damaged max/min envelopes on one axes, one colour per curve.
%   PLOTENVELOPECOMPARISON(AX, X, HMAX, HMIN, DMAX, DMIN, COLORHEALTHY,
%   COLORDAMAGED, YLABELTEXT, TITLETEXT) clears AX and draws, at the
%   stations X [m], four solid curves told apart by colour: the damaged
%   envelope as thick lines and the healthy envelope as thinner lines ON
%   TOP. Where the two coincide (e.g. moments of a statically determinate
%   beam) the thin healthy line stays visible inside the thick damaged
%   one, so the reader sees "unchanged" instead of a missing curve.
%   COLORHEALTHY and COLORDAMAGED are 2-by-3 RGB rows [max; min] (a single
%   1-by-3 row colours both curves). A legend and labels are added; the
%   optional XLABELTEXT sets the x label (default 'x [m]').
%
%   See also COMPAREHEALTHYDAMAGED, PLOTENVELOPE, APPTHEME.

x = x(:);
cla(ax);
hold(ax, 'on');
plot(ax, [min(x), max(x)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8);
if size(colorHealthy, 1) == 1
    colorHealthy = [colorHealthy; colorHealthy];
end
if size(colorDamaged, 1) == 1
    colorDamaged = [colorDamaged; colorDamaged];
end
h1 = plot(ax, x, dMax(:), 'Color', colorDamaged(1, :), 'LineWidth', 2.6);
h2 = plot(ax, x, dMin(:), 'Color', colorDamaged(2, :), 'LineWidth', 2.6);
h3 = plot(ax, x, hMax(:), 'Color', colorHealthy(1, :), 'LineWidth', 1.3);
h4 = plot(ax, x, hMin(:), 'Color', colorHealthy(2, :), 'LineWidth', 1.3);
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
