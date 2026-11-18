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
%     StiffnessFactor NE-by-1 factors 1 - d (model.elements.stiffnessFactor);
%                  elements with a factor < 1 are overdrawn thick in the
%                  damage colour with an 'EI x 0.70' label
%     Regions      K-by-2 [start end] m: Stage 3 region of uncertainty, a
%                  light band behind the beam
%     BestRegion   [start end] m: Stage 3 best fit, thick line on the beam,
%                  with the text BestLabel below it
%     TrueRegion   [start end] m: hidden true region of a synthetic case,
%                  dashed box labelled 'true (hidden)'
%     Sensors      sensor coordinates [m]: markers S1, S2, ... in a band
%                  below the region labels
%     EndLabels    struct with fields x [m] and text (cellstr, one per x),
%                  e.g. the support letters A, B, ... (SUPPORTLETTERS) at
%                  the span ends: drawn bold below the support symbols
%                  (top at y = -1.55 h)
%     Units        display units (UNITSYSTEM) of the load and axle label
%                  texts, default SI (kN, kN/m, kN*m); the coordinates stay
%                  in m (RENDERDRAWING scales them)
%     Theme        colours (APPTHEME), default appTheme()
%   Drawn items: beam and nodes; pin, roller and fixed supports
%   (SUPPORTSYMBOLGEOMETRY); permanent uniform loads (arrows with
%   'q = .. kN/m'); permanent point loads and nodal forces (arrows with
%   kN values); nodal couples (arc with kN*m value); vehicle axles (arrows
%   with kN values) under a truck schematic; and the deformed shape.
%   Labels are kept apart: on-bridge axles closer together than 6 % of the
%   beam length share one label ('2 x 120 kN', or '80 + 120 kN' when the
%   loads differ, listed from left to right); a uniform-load label sits at
%   the left end of its load, left-aligned; with ShowNumbers, no node
%   number is drawn where an end label is drawn.
%
%   See also RENDERDRAWING, SUPPORTSYMBOLGEOMETRY, SUPPORTLETTERS,
%   UNITSYSTEM, BRIDGECONDITIONAPP.

if nargin < 2
    opts = struct();
end
validateModel(model);
x = model.nodes.x;
nn = numel(x);
L = x(end) - x(1);
th = optionOr(opts, 'Theme', appTheme());
U = optionOr(opts, 'Units', unitSystem('SI'));
h = optionOr(opts, 'SymbolSize', 0.04 * L);
gap = 0.08 * h;

prims = drawingPrimitive('line', [x(1), x(end)], [0, 0], th.beam, 'lineWidth', 3);
% Stage 3: region of uncertainty, a light band drawn BEHIND the beam
regions = optionOr(opts, 'Regions', zeros(0, 2));
band = [];
for k = 1:size(regions, 1)
    band = [band, drawingPrimitive('patch', regions(k, [1 2 2 1]), 0.22*h*[-1 -1 1 1], th.region, ...
        'faceColor', th.region)]; %#ok<AGROW>
end
prims = [band, prims];
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

% Span-end labels (support letters), bold, below the support symbols
labelled = false(nn, 1);
ends = optionOr(opts, 'EndLabels', []);
if ~isempty(ends)
    if ~(isstruct(ends) && isfield(ends, 'x') && isfield(ends, 'text'))
        error('BridgeFE:invalidInput', 'EndLabels needs a field x [m] and a field text with one text per x.');
    end
    endText = ends.text;
    if ischar(endText)
        endText = {endText};
    end
    if ~(isnumeric(ends.x) && iscellstr(endText) && numel(endText) == numel(ends.x))
        error('BridgeFE:invalidInput', 'EndLabels needs a field x [m] and a field text with one text per x.');
    end
    for k = 1:numel(ends.x)
        prims(end+1) = drawingPrimitive('text', ends.x(k), -1.55*h, th.support, 'text', endText{k}, ...
            'vAlign', 'top', 'fontSize', 10, 'fontWeight', 'bold'); %#ok<AGROW>
        labelled(abs(x - ends.x(k)) <= 1e-9 * L) = true;
    end
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
    % label left-aligned at the left end of the load, not at mid-length
    prims(end+1) = drawingPrimitive('text', xa, level + sgn*0.15*h, th.load, ...
        'text', sprintf('q = %g %s', abs(w(e)) / U.distributed.toSI, U.distributed.unit), ...
        'hAlign', 'left', 'vAlign', vertical(sgn), 'fontSize', 9); %#ok<AGROW>
    e = last + 1;
end

% Permanent point loads and nodal forces / couples
forces = [model.loads.point; x(model.loads.nodal(:, 1)), model.loads.nodal(:, 2)];
for k = 1:size(forces, 1)
    if forces(k, 2) ~= 0
        prims = [prims, labelledArrow(forces(k, 1), forces(k, 2), gap, 1.2*h, h, th.load, '-', U.force)]; %#ok<AGROW>
    end
end
couples = model.loads.nodal(model.loads.nodal(:, 3) ~= 0, :);
for k = 1:size(couples, 1)
    prims = [prims, coupleSymbol(x(couples(k, 1)), couples(k, 3), h, th.load, U.moment)]; %#ok<AGROW>
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
        if ~ax.onBridge(k)
            prims(end+1) = drawingPrimitive('text', ax.x(k), body(2) + 0.12*h, c, ...
                'text', axleLabel(ax.P(k), U.force), 'vAlign', 'bottom', 'fontSize', 8); %#ok<AGROW>
        end
    end
    % On-bridge axles closer than 6 % of the beam length share one label (left to right)
    on = find(ax.onBridge(:));
    [~, order] = sort(ax.x(on));
    on = on(order);
    first = 1;
    for k = 1:numel(on)
        if k == numel(on) || ax.x(on(k + 1)) - ax.x(on(k)) >= 0.06 * L
            group = on(first:k);
            prims(end+1) = drawingPrimitive('text', (ax.x(group(1)) + ax.x(group(end)))/2, body(2) + 0.12*h, ...
                th.vehicle, 'text', axleLabel(ax.P(group), U.force), 'vAlign', 'bottom', 'fontSize', 8); %#ok<AGROW>
            first = k + 1;
        end
    end
end

% Elements with a prescribed stiffness loss (Stage 2)
if isfield(opts, 'StiffnessFactor') && ~isempty(opts.StiffnessFactor)
    f = opts.StiffnessFactor(:);
    e = 1;
    while e <= numel(f)
        if f(e) >= 1
            e = e + 1;
            continue
        end
        last = e;
        while last < numel(f) && f(last + 1) == f(e)
            last = last + 1;
        end
        prims(end+1) = drawingPrimitive('line', [x(e), x(last + 1)], [0, 0], th.damage, 'lineWidth', 7); %#ok<AGROW>
        prims(end+1) = drawingPrimitive('text', (x(e) + x(last + 1))/2, -0.25*h, th.damage, ...
            'text', sprintf('EI x %.2f', f(e)), 'vAlign', 'top', 'fontSize', 11); %#ok<AGROW>
        e = last + 1;
    end
end

% Stage 3: best-fit region (thick line on the beam), hidden true region (dashed box), sensors
best = optionOr(opts, 'BestRegion', []);
if ~isempty(best)
    prims(end+1) = drawingPrimitive('line', best, [0, 0], th.regionBest, 'lineWidth', 6);
    prims(end+1) = drawingPrimitive('text', mean(best), -0.45*h, th.regionBest, 'text', ...
        optionOr(opts, 'BestLabel', 'best fit'), 'vAlign', 'top', 'fontSize', 9);   % below: loads use the space above
end
truthX = optionOr(opts, 'TrueRegion', []);
if ~isempty(truthX) && all(isfinite(truthX))
    prims(end+1) = drawingPrimitive('line', truthX([1 2 2 1 1]), 0.4*h*[-1 -1 1 1 -1], th.truth, ...
        'lineStyle', '--', 'lineWidth', 1.2);
    prims(end+1) = drawingPrimitive('text', mean(truthX), -1.0*h, th.truth, 'text', 'true (hidden)', ...
        'vAlign', 'top', 'fontSize', 8);
end
sensors = optionOr(opts, 'Sensors', []);
for k = 1:numel(sensors)
    % own band below the region labels (best fit -0.45h, hidden case -1.0h)
    prims(end+1) = drawingPrimitive('marker', sensors(k), -1.65*h, th.sensor, 'marker', '^', 'markerSize', 7); %#ok<AGROW>
    prims(end+1) = drawingPrimitive('text', sensors(k), -1.9*h, th.sensor, 'text', sprintf('S%d', k), ...
        'vAlign', 'top', 'fontSize', 8); %#ok<AGROW>
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
    for n = find(~labelled).'
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

function prims = labelledArrow(xp, P, gap, len, h, color, style, force)
% Downward force: arrow above the beam pointing down; upward force: below, pointing up.
label = sprintf('%g %s', abs(P) / force.toSI, force.unit);
if P < 0
    prims = arrow(xp, gap, gap + len, h, color, 1.4, style);
    prims(end+1) = drawingPrimitive('text', xp, gap + len + 0.1*h, color, ...
        'text', label, 'vAlign', 'bottom', 'fontSize', 8);
else
    prims = arrow(xp, -gap, -gap - len, h, color, 1.4, style);
    prims(end+1) = drawingPrimitive('text', xp, -gap - len - 0.1*h, color, ...
        'text', label, 'vAlign', 'top', 'fontSize', 8);
end
end

function label = axleLabel(P, force)
% One axle: '120 kN'; equal axles: '2 x 120 kN'; different axles: '80 + 120 kN'.
values = arrayfun(@(p) sprintf('%g', abs(p) / force.toSI), P(:).', 'UniformOutput', false);
if numel(values) == 1
    label = sprintf('%s %s', values{1}, force.unit);
elseif all(strcmp(values, values{1}))
    label = sprintf('%d x %s %s', numel(values), values{1}, force.unit);
else
    label = sprintf('%s %s', strjoin(values, ' + '), force.unit);
end
end

function prims = coupleSymbol(xn, Mz, h, color, moment)
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
    'text', sprintf('%g %s (%s)', abs(Mz) / moment.toSI, moment.unit, sense), 'vAlign', 'bottom', 'fontSize', 8);
end
