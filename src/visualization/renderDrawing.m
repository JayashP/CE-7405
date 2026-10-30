function renderDrawing(ax, prims)
%RENDERDRAWING Draw primitives from BRIDGEDRAWING on axes (UIAxes or regular axes).
%   RENDERDRAWING(AX, PRIMS) adds every primitive to AX with PLOT, PATCH and
%   TEXT, then sets equal axis scaling and limits from DRAWINGLIMITS, hides
%   the y ticks and labels the x axis in metres. Clear AX first (CLA) if
%   needed. All geometry comes from PRIMS, so what is drawn is exactly what
%   the tested drawing functions produced.
%
%   See also BRIDGEDRAWING, DRAWINGPRIMITIVE.

hold(ax, 'on');
for k = 1:numel(prims)
    p = prims(k);
    switch p.kind
        case 'line'
            plot(ax, p.x, p.y, 'Color', p.color, 'LineWidth', p.lineWidth, 'LineStyle', p.lineStyle);
        case 'marker'
            plot(ax, p.x, p.y, 'LineStyle', 'none', 'Marker', p.marker, 'MarkerSize', p.markerSize, ...
                'MarkerEdgeColor', p.color, 'MarkerFaceColor', p.faceColor);
        case 'patch'
            patch(ax, p.x, p.y, p.faceColor, 'EdgeColor', p.color, 'LineWidth', p.lineWidth);
        case 'text'
            text(ax, p.x, p.y, p.text, 'Color', p.color, 'FontSize', p.fontSize, ...
                'HorizontalAlignment', p.hAlign, 'VerticalAlignment', p.vAlign, 'Interpreter', 'none');
        otherwise
            error('BridgeFE:invalidInput', 'Unknown primitive kind ''%s''.', p.kind);
    end
end
hold(ax, 'off');
[xl, yl] = drawingLimits(prims);
axis(ax, 'equal');
xlim(ax, xl);
ylim(ax, yl);
ax.YTick = [];
xlabel(ax, 'x [m]');
end
