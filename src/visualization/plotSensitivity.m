function plotSensitivity(ax, s, model, color, U)
%PLOTSENSITIVITY Bar chart of the change caused by the same loss at each candidate location.
%   PLOTSENSITIVITY(AX, S, MODEL, COLOR) clears AX and draws one bar per
%   group of DAMAGESENSITIVITY result S at the group's mid-coordinate [m],
%   with height = change from the healthy value in display units
%   (QUANTITYDISPLAY). Bars are drawn as filled rectangles with PATCH.
%   PLOTSENSITIVITY(AX, S, MODEL, COLOR, U) draws the x axis in U.length
%   and the change in the display units U of UNITSYSTEM; the axis labels
%   name the units.
%
%   See also DAMAGESENSITIVITY, SENSITIVITYTABLEDATA, UNITSYSTEM.

if nargin < 5 || isempty(U)
    U = unitSystem('SI');
end
q = quantityDisplay(s.quantity, U);
x = model.nodes.x / U.length.toSI;
cla(ax);
hold(ax, 'on');
for g = 1:numel(s.groups)
    els = s.groups{g};
    x1 = x(min(els));
    x2 = x(max(els) + 1);
    pad = 0.1 * (x2 - x1);
    y = s.change(g) * q.scale;
    patch(ax, [x1 + pad, x2 - pad, x2 - pad, x1 + pad], [0, 0, y, y], color, 'EdgeColor', color);
end
plot(ax, [x(1), x(end)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8);
hold(ax, 'off');
grid(ax, 'on');
xlim(ax, [x(1), x(end)]);
xlabel(ax, sprintf('location of the loss, x [%s]', U.length.unit));
ylabel(ax, sprintf('change of %s [%s]', s.quantity, q.unit));
title(ax, sprintf('Same loss d = %g %% at each location', 100 * s.d));
end
