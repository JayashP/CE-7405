function prims = bridgeDrawing(model, opts)
%BRIDGEDRAWING Beam, conventional supports, loads and vehicle as drawing primitives.
%   PRIMS = BRIDGEDRAWING(MODEL, OPTS) returns the struct array of
%   primitives (DRAWINGPRIMITIVE) for a schematic of MODEL in metres. The
%   beam lies along y = 0; supports sit below it, loads and the vehicle
%   above it. RENDERDRAWING draws the result on any axes. OPTS fields (all
%   optional):
%     SymbolSize   symbol height h [m], default 4 % of the beam length
%     ShowNumbers  true to label node numbers (below) and element numbers
%                  (above, small), default false
%     Axles        struct with fields x [m], P [N] (+ up) and onBridge, as
%                  in ANALYZEVEHICLEPOSITION's RES.axles; axles not on the
%                  bridge are drawn in grey
%     Direction    vehicle travel direction (+1 / -1) for the cab, default +1
%     Deformed     struct with fields x [m] and y [m] (already magnified)
%     DeformedLabel text shown with the deformed shape
%     Theme        colours (APPTHEME), default appTheme()
%   Drawn items: beam and nodes; pin, roller and fixed supports
%   (SUPPORTSYMBOLGEOMETRY); permanent uniform loads (arrows with
%   'q = .. kN/m'); permanent point loads and nodal forces (arrows with
%   kN values); nodal couples (arc with kN*m value); vehicle axles (arrows
%   with kN values) under a truck schematic; and the deformed shape.
%
%   See also RENDERDRAWING, SUPPORTSYMBOLGEOMETRY, BRIDGECONDITIONAPP.

if nargin < 2
    opts = struct();
end
validateModel(model);
x = model.nodes.x;
nn = numel(x);
L = x(end) - x(1);
th = optionOr(opts, 'Theme', appTheme());
h = optionOr(opts, 'SymbolSize', 0.04 * L);
gap = 0.08 * h;

prims = drawingPrimitive('line', [x(1), x(end)], [0, 0], th.beam, 'lineWidth', 3);
prims(end+1) = drawingPrimitive('marker', x, zeros(size(x)), th.beam, 'marker', 'o', 'markerSize', 3);

% Supports
for s = 1:numel(model.supports.node)
    n = model.supports.node(s);
    side = 'left';
    if n == nn
        side = 'right';
    end
    prims = [prims, supportSymbolGeometry(model.supports.type{s}, x(n), 0, h, side, th.support)]; %#ok<AGROW>
end

% Permanent uniform loads, grouped into runs of equal intensity
w = model.loads.elementUDL;
e = 1;
while e <= numel(w)
    if w(e) == 0
        e = e + 1;
        continue
    end
    last = e;
    while last < numel(w) && w(last + 1) == w(e)
        last = last + 1;
    end
    xa = x(e);
    xb = x(last + 1);
    sgn = -sign(w(e));                         % +1 for a downward load (drawn above)
    level = sgn * (gap + 0.9*h);
    nArrows = max(2, ceil((xb - xa) / (L / 25)) + 1);
    prims(end+1) = drawingPrimitive('line', [xa, xb], [level, level], th.load, 'lineWidth', 1.2); %#ok<AGROW>
    for xi = linspace(xa, xb, nArrows)
        prims = [prims, arrow(xi, sgn*gap, level, h, th.load, 1)]; %#ok<AGROW>
    end
    prims(end+1) = drawingPrimitive('text', (xa + xb)/2, level + sgn*0.15*h, th.load, ...
        'text', sprintf('q = %g kN/m', abs(w(e)) / 1e3), 'vAlign', vertical(sgn), 'fontSize', 9); %#ok<AGROW>
    e = last + 1;
end

% Permanent point loads and nodal forces / couples
forces = [model.loads.point; x(model.loads.nodal(:, 1)), model.loads.nodal(:, 2)];
for k = 1:size(forces, 1)
    if forces(k, 2) ~= 0
        prims = [prims, labelledArrow(forces(k, 1), forces(k, 2), gap, 1.2*h, h, th.load, '-')]; %#ok<AGROW>
    end
end
couples = model.loads.nodal(model.loads.nodal(:, 3) ~= 0, :);
for k = 1:size(couples, 1)
    prims = [prims, coupleSymbol(x(couples(k, 1)), couples(k, 3), h, th.load)]; %#ok<AGROW>
end

% Vehicle
if isfield(opts, 'Axles') && ~isempty(opts.Axles)
    ax = opts.Axles;
    d = optionOr(opts, 'Direction', 1);
    body = [gap + 1.85*h, gap + 2.4*h];
    xs = [min(ax.x) - 0.4*h, max(ax.x) + 0.4*h];
    light = 0.75 + 0.25 * th.vehicle;
    prims(end+1) = drawingPrimitive('patch', xs([1 2 2 1]), body([1 1 2 2]), th.vehicle, 'faceColor', light);
    cab = sort([ax.x(1) + d*0.4*h, ax.x(1) + d*1.1*h]);
    prims(end+1) = drawingPrimitive('patch', cab([1 2 2 1]), [body(1), body(1), body(2) - 0.1*h, body(2) - 0.1*h], ...
        th.vehicle, 'faceColor', 0.55 + 0.45 * th.vehicle);
    for k = 1:numel(ax.x)
        if ax.onBridge(k)
            c = th.vehicle;
            style = '-';
        else
            c = th.vehicleOff;
            style = ':';
        end
        prims = [prims, arrow(ax.x(k), gap, gap + 1.75*h, h, c, 1.4, style)]; %#ok<AGROW>
        prims(end+1) = drawingPrimitive('text', ax.x(k), body(2) + 0.12*h, c, ...
            'text', sprintf('%g kN', abs(ax.P(k)) / 1e3), 'vAlign', 'bottom', 'fontSize', 8); %#ok<AGROW>
    end
end

% Deformed shape
if isfield(opts, 'Deformed') && ~isempty(opts.Deformed)
    prims(end+1) = drawingPrimitive('line', opts.Deformed.x, opts.Deformed.y, th.deformed, ...
        'lineWidth', 1.6, 'lineStyle', '--');
    if isfield(opts, 'DeformedLabel') && ~isempty(opts.DeformedLabel)
        prims(end+1) = drawingPrimitive('text', x(1), -2.3*h, th.deformed, 'text', opts.DeformedLabel, ...
            'hAlign', 'left', 'vAlign', 'top', 'fontSize', 8);
    end
end

% Node and element numbers
if optionOr(opts, 'ShowNumbers', false)
    for n = 1:nn
        prims(end+1) = drawingPrimitive('text', x(n), -1.55*h, th.support, 'text', sprintf('%d', n), ...
            'vAlign', 'top', 'fontSize', 7); %#ok<AGROW>
    end
    for k = 1:nn - 1
        prims(end+1) = drawingPrimitive('text', (x(k) + x(k+1))/2, 0.15*h, th.sageDark, ...
            'text', sprintf('(%d)', k), 'vAlign', 'bottom', 'fontSize', 6); %#ok<AGROW>
    end
end
end

function value = optionOr(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    value = opts.(name);
else
    value = default;
end
end

function a = vertical(sgn)
if sgn > 0
    a = 'bottom';
else
    a = 'top';
end
end

function prims = arrow(xTip, yTip, yTail, h, color, lineWidth, style)
% Vertical arrow from yTail to the tip at yTip.
if nargin < 7
    style = '-';
end
dir = sign(yTip - yTail);                       % -1 points down
headLength = 0.3 * h;
headHalf = 0.12 * h;
prims = drawingPrimitive('line', [xTip, xTip], [yTail, yTip - dir*headLength], color, ...
    'lineWidth', lineWidth, 'lineStyle', style);
prims(end+1) = drawingPrimitive('patch', [xTip, xTip - headHalf, xTip + headHalf], ...
    [yTip, yTip - dir*headLength, yTip - dir*headLength], color);
end

function prims = labelledArrow(xp, P, gap, len, h, color, style)
% Downward force: arrow above the beam pointing down; upward force: below, pointing up.
if P < 0
    prims = arrow(xp, gap, gap + len, h, color, 1.4, style);
    prims(end+1) = drawingPrimitive('text', xp, gap + len + 0.1*h, color, ...
        'text', sprintf('%g kN', abs(P) / 1e3), 'vAlign', 'bottom', 'fontSize', 8);
else
    prims = arrow(xp, -gap, -gap - len, h, color, 1.4, style);
    prims(end+1) = drawingPrimitive('text', xp, -gap - len - 0.1*h, color, ...
        'text', sprintf('%g kN', abs(P) / 1e3), 'vAlign', 'top', 'fontSize', 8);
end
end

function prims = coupleSymbol(xn, Mz, h, color)
% Three-quarter arc around the node with an arrowhead showing the sense.
r = 0.45 * h;
a = linspace(-pi/4, 5*pi/4, 30);
prims = drawingPrimitive('line', xn + r*cos(a), r*sin(a), color, 'lineWidth', 1.3);
if Mz > 0
    aTip = a(end);
    t = [-sin(aTip), cos(aTip)];                 % counterclockwise tangent
    sense = 'CCW';
else
    aTip = a(1);
    t = [sin(aTip), -cos(aTip)];                 % clockwise tangent
    sense = 'CW';
end
tip = [xn + r*cos(aTip), r*sin(aTip)] + 0.15*h*t;
n = [-t(2), t(1)];
base = tip - 0.25*h*t;
prims(end+1) = drawingPrimitive('patch', [tip(1), base(1) + 0.1*h*n(1), base(1) - 0.1*h*n(1)], ...
    [tip(2), base(2) + 0.1*h*n(2), base(2) - 0.1*h*n(2)], color);
prims(end+1) = drawingPrimitive('text', xn, r + 0.2*h, color, ...
    'text', sprintf('%g kN*m (%s)', abs(Mz) / 1e3, sense), 'vAlign', 'bottom', 'fontSize', 8);
end
