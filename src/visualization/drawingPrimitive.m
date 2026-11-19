function p = drawingPrimitive(kind, x, y, color, varargin)
%DRAWINGPRIMITIVE One drawable item (line, marker set, filled polygon or text) as plain data.
%   P = DRAWINGPRIMITIVE(KIND, X, Y, COLOR, NAME, VALUE, ...) returns a struct
%   describing what RENDERDRAWING will draw. KIND is 'line', 'marker',
%   'patch' or 'text'. X and Y are coordinates [m] (row vectors) and COLOR
%   is RGB. Optional NAME/VALUE fields: faceColor, lineWidth, lineStyle,
%   marker, markerSize, text, fontSize, fontWeight ('normal' or 'bold'),
%   hAlign, vAlign.
%   Keeping the geometry as data lets it be unit-tested and previewed
%   without a graphics window.
%
%   See also BRIDGEDRAWING, RENDERDRAWING, SUPPORTSYMBOLGEOMETRY.

p = struct('kind', kind, 'x', x(:).', 'y', y(:).', 'color', color, 'faceColor', color, ...
    'lineWidth', 1, 'lineStyle', '-', 'marker', 'none', 'markerSize', 4, 'text', '', ...
    'fontSize', 9, 'hAlign', 'center', 'vAlign', 'middle', 'fontWeight', 'normal');
for k = 1:2:numel(varargin)
    if ~isfield(p, varargin{k})
        error('BridgeFE:invalidInput', 'Unknown drawing property ''%s''.', varargin{k});
    end
    p.(varargin{k}) = varargin{k + 1};
end
end
