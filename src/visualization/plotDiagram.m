function plotDiagram(ax, x, y, color, yLabelText, titleText, xLabelText)
%PLOTDIAGRAM Shaded response diagram (M, V or v) along the beam.
%   PLOTDIAGRAM(AX, X, Y, COLOR, YLABELTEXT, TITLETEXT) clears AX and draws
%   Y against X [m] as a line with a light fill to the zero axis, labels the
%   largest positive and negative values (on the side of the point that faces
%   the inside of the plot, clipped to the axes when zoomed), and adds the
%   axis labels. X may repeat a coordinate (left and right limits), which
%   draws jumps as vertical steps (RESPONSEDIAGRAMDATA).
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
middle = (min(x) + max(x)) / 2;
if yMax > 0
    peakLabel(ax, x(iMax), yMax, color, 'bottom', middle);
end
if yMin < 0
    peakLabel(ax, x(iMin), yMin, color, 'top', middle);
end
hold(ax, 'off');
grid(ax, 'on');
xlim(ax, [min(x), max(x)]);
if nargin < 7
    xLabelText = 'x [m]';                       % optional: the app passes its display length unit
end
xlabel(ax, xLabelText);
ylabel(ax, yLabelText);
title(ax, titleText);
end

function peakLabel(ax, x, y, color, vAlign, middle)
% Value label beside its point, towards the middle of the plot, so it stays inside the axes. MATLAB draws
% text outside the axes unless Clipping is on: without it, labels are left behind when the user zooms.
if x <= middle
    str = sprintf(' %.4g', y);
    hAlign = 'left';
else
    str = sprintf('%.4g ', y);
    hAlign = 'right';
end
text(ax, x, y, str, 'Color', color, 'FontSize', 8, 'HorizontalAlignment', hAlign, 'VerticalAlignment', vAlign, ...
    'Interpreter', 'none', 'Clipping', 'on');
end
