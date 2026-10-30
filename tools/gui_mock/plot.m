function g = plot(ax, x, y, varargin)
%PLOT Mock line plot on a MockUIAxes (GNU Octave app check only).
if ~(isnumeric(x) && isnumeric(y) && numel(x) == numel(y) && ~isempty(x))
    error('Mock:value', 'plot: x and y must be numeric with the same number of elements.');
end
allowed = {'Color', 'LineWidth', 'LineStyle', 'Marker', 'MarkerSize', 'MarkerEdgeColor', 'MarkerFaceColor', 'DisplayName', 'Tag', 'HandleVisibility'};
g = mockAxesCall('plot', ax, allowed, varargin, x, y);
end
