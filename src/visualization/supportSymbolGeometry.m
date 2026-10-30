function prims = supportSymbolGeometry(type, x0, y0, h, side, color)
%SUPPORTSYMBOLGEOMETRY Conventional support symbol at a beam node, as drawing primitives.
%   PRIMS = SUPPORTSYMBOLGEOMETRY(TYPE, X0, Y0, H, SIDE, COLOR) draws the
%   symbol for a support at node (X0, Y0) with overall size H [m]
%   (PROJECT_SPEC.md sections 2 and 9):
%     'pin'     triangle with its apex at the node, on a hatched ground line
%     'roller'  triangle on two wheels, on a hatched ground line
%     'fixed'   wall through the node with hatching on SIDE ('left' or 'right'),
%               i.e. outside the beam
%     'none'    nothing
%   The symbols only show the bending restraints of this model (v for pin
%   and roller; v and theta for fixed).
%
%   See also BRIDGEDRAWING, DRAWINGPRIMITIVE.

paper = [0.98 0.98 0.97];
prims = drawingPrimitive('line', 0, 0, color);
prims(1) = [];
switch lower(type)
    case 'pin'
        prims(end+1) = drawingPrimitive('patch', [x0, x0 - h/2, x0 + h/2], [y0, y0 - h, y0 - h], color, ...
            'faceColor', paper, 'lineWidth', 1.5);
        prims = [prims, groundLine(x0, y0 - h, h, color)];
    case 'roller'
        r = 0.13 * h;
        top = y0 - 0.7*h;
        prims(end+1) = drawingPrimitive('patch', [x0, x0 - 0.45*h, x0 + 0.45*h], [y0, top, top], color, ...
            'faceColor', paper, 'lineWidth', 1.5);
        a = linspace(0, 2*pi, 25);
        for xc = [x0 - 0.24*h, x0 + 0.24*h]
            prims(end+1) = drawingPrimitive('patch', xc + r*cos(a), top - r + r*sin(a), color, ...
                'faceColor', paper, 'lineWidth', 1.2); %#ok<AGROW>
        end
        prims = [prims, groundLine(x0, top - 2*r, h, color)];
    case 'fixed'
        if strcmpi(side, 'right')
            s = -1;
        else
            s = 1;
        end
        prims(end+1) = drawingPrimitive('line', [x0, x0], [y0 - h, y0 + h], color, 'lineWidth', 2.5);
        for yi = linspace(y0 - 0.75*h, y0 + h, 7)
            prims(end+1) = drawingPrimitive('line', [x0, x0 - s*0.3*h], [yi, yi - 0.3*h], color); %#ok<AGROW>
        end
    case 'none'
    otherwise
        error('BridgeFE:invalidSupportType', 'Unknown support type ''%s''.', type);
end
end

function prims = groundLine(x0, y, h, color)
prims = drawingPrimitive('line', [x0 - 0.8*h, x0 + 0.8*h], [y, y], color, 'lineWidth', 1.5);
for xi = linspace(x0 - 0.65*h, x0 + 0.8*h, 6)
    prims(end+1) = drawingPrimitive('line', [xi, xi - 0.25*h], [y, y - 0.3*h], color); %#ok<AGROW>
end
end
