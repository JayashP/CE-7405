function g = patch(ax, x, y, c, varargin)
%PATCH Mock filled polygon on a MockUIAxes (GNU Octave app check only).
if ~(isnumeric(x) && isnumeric(y) && numel(x) == numel(y) && numel(x) >= 3)
    error('Mock:value', 'patch: x and y must be numeric vectors of equal length (>= 3 vertices).');
end
mockCheckColor(c, 'patch colour');
allowed = {'EdgeColor', 'FaceColor', 'LineWidth', 'LineStyle', 'FaceAlpha', 'EdgeAlpha', 'DisplayName', 'Tag', 'HandleVisibility'};
for k = 1:2:numel(varargin)
    if any(strcmp(varargin{k}, {'EdgeColor', 'FaceColor'})) && ~strcmp(varargin{k + 1}, 'none')
        mockCheckColor(varargin{k + 1}, ['patch ' varargin{k}]);
    end
end
g = mockAxesCall('patch', ax, allowed, varargin, x, y);
end
