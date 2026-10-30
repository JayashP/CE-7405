function g = text(ax, x, y, str, varargin)
%TEXT Mock text label on a MockUIAxes (GNU Octave app check only).
if ~(isnumeric(x) && isnumeric(y) && isscalar(x) && isscalar(y) && ischar(str))
    error('Mock:value', 'text: x and y must be scalars and the label a character vector.');
end
allowed = {'Color', 'FontSize', 'FontWeight', 'HorizontalAlignment', 'VerticalAlignment', 'Interpreter', 'Rotation', ...
    'FontAngle', 'BackgroundColor', 'Margin', 'Clipping'};
g = mockAxesCall('text', ax, allowed, varargin, x, y, str);
end
