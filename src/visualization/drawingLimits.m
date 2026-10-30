function [xl, yl] = drawingLimits(prims)
%DRAWINGLIMITS Axis limits [m] that contain every primitive, including room for labels.
%   [XL, YL] = DRAWINGLIMITS(PRIMS) returns 1-by-2 x and y limits covering
%   all coordinates of PRIMS (DRAWINGPRIMITIVE). Text is anchored at a single
%   point, so text primitives also reserve a label height of 3 % of the x
%   range on the side they extend to (above for vAlign 'bottom', below for
%   'top', half each way for 'middle'). A further margin of 4 % of the x
%   range (horizontal) and 12 % of the y range (vertical, at least 5 % of
%   the x range) is added.
%
%   See also RENDERDRAWING.

xs = [prims.x];
ys = [prims.y];
dx = max(max(xs) - min(xs), eps);
pad = 0.03 * dx;
isText = strcmp({prims.kind}, 'text');
for k = find(isText)
    switch prims(k).vAlign
        case 'bottom'
            ys(end+1) = prims(k).y(1) + pad; %#ok<AGROW>
        case 'top'
            ys(end+1) = prims(k).y(1) - pad; %#ok<AGROW>
        otherwise
            ys = [ys, prims(k).y(1) + [-pad, pad] / 2]; %#ok<AGROW>
    end
end
xl = [min(xs), max(xs)];
yl = [min(ys), max(ys)];
dy = max(yl(2) - yl(1), 0.05 * dx);
xl = xl + [-0.04, 0.04] * dx;
yl = yl + [-0.12, 0.12] * dy;
end
