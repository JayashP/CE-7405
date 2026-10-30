function plotDiagram(ax, x, y, color, yLabelText, titleText)
%PLOTDIAGRAM Shaded response diagram (M, V or v) along the beam.
%   PLOTDIAGRAM(AX, X, Y, COLOR, YLABELTEXT, TITLETEXT) clears AX and draws
%   Y against X [m] as a line with a light fill to the zero axis, labels the
%   largest positive and negative values, and adds the axis labels. X may
%   repeat a coordinate (left and right limits), which draws jumps as
%   vertical steps (RESPONSEDIAGRAMDATA).
%
%   See also RESPONSEDIAGRAMDATA, PLOTENVELOPE.

x = x(:);
y = y(:);
cla(ax);
hold(ax, 'on');
patch(ax, [x; flipud(x)], [y; zeros(size(y))], color, 'FaceAlpha', 0.18, 'EdgeColor', 'none');
plot(ax, x, y, 'Color', color, 'LineWidth', 1.6);
plot(ax, [min(x), max(x)], [0, 0], 'Color', [0.30 0.30 0.30], 'LineWidth', 0.8);
[yMax, iMax] = max(y);
[yMin, iMin] = min(y);
if yMax > 0
    text(ax, x(iMax), yMax, sprintf(' %.4g', yMax), 'Color', color, 'FontSize', 8, ...
        'VerticalAlignment', 'bottom', 'Interpreter', 'none');
end
if yMin < 0
    text(ax, x(iMin), yMin, sprintf(' %.4g', yMin), 'Color', color, 'FontSize', 8, ...
        'VerticalAlignment', 'top', 'Interpreter', 'none');
end
hold(ax, 'off');
grid(ax, 'on');
xlim(ax, [min(x), max(x)]);
xlabel(ax, 'x [m]');
ylabel(ax, yLabelText);
title(ax, titleText);
end
