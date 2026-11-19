function plotReadings(ax, positions, sensorX, uObs, uHealthy, uBest, th, U)
%PLOTREADINGS Sensor readings with the healthy and best-fit predictions (Stage 3).
%   PLOTREADINGS(AX, POSITIONS, SENSORX, UOBS, UHEALTHY, UBEST, TH) clears AX
%   and draws, for every sensor i at SENSORX(i) (rows of the matrices, in m;
%   shown in mm) against the truck front-axle POSITIONS [m]: the readings as
%   markers, the healthy model as a dotted line and the best fit as a solid
%   line. Each sensor has its own colour and marker shape (distinct for up
%   to 6 x 9 sensors); the legend names the sensors by their reading
%   markers ('S1 (x = 5 m)', ...); the two-line title explains the styles. The gap
%   between markers and the solid line is the residual of the best fit.
%   UBEST may be empty (before a search). Missing readings (NaN) are not
%   drawn. No object has hidden handles, so the next CLA removes
%   everything.
%   PLOTREADINGS(..., TH, U) draws the positions and sensor coordinates in
%   U.length and the deflections in U.deflection (display units U of
%   UNITSYSTEM); the inputs stay in m.
%
%   See also IDENTIFYSINGLEDAMAGE, UNITSYSTEM.

if nargin < 8 || isempty(U)
    U = unitSystem('SI');
end
perM = 1 / U.deflection.toSI;                % deflection display units per m (1000 for mm, exactly)
palette = [th.sensor; th.deflection; th.load; th.moment; th.shear; th.damage];
markers = 'osd^v><ph';
xv = positions(:)' / U.length.toSI;
cla(ax);
hold(ax, 'on');
handles = [];
labels = cell(1, size(uObs, 1));
for i = 1:size(uObs, 1)
    c = palette(mod(i - 1, size(palette, 1)) + 1, :);
    mk = markers(mod(floor((i - 1) / size(palette, 1)), numel(markers)) + 1);
    plot(ax, xv, perM * uHealthy(i, :), 'Color', c, 'LineStyle', ':', 'LineWidth', 1.2);
    if ~isempty(uBest)
        plot(ax, xv, perM * uBest(i, :), 'Color', c, 'LineWidth', 1.8);
    end
    h = plot(ax, xv, perM * uObs(i, :), 'LineStyle', 'none', 'Marker', mk, 'MarkerSize', 6, 'MarkerEdgeColor', c, ...
        'MarkerFaceColor', c);
    handles = [handles, h]; %#ok<AGROW>
    labels{i} = sprintf('S%d (x = %g %s)', i, sensorX(i) / U.length.toSI, U.length.unit);
end
hold(ax, 'off');
if ~isempty(handles)
    legend(ax, handles, labels, 'Location', 'best');
end
grid(ax, 'on');
span = max(xv) - min(xv);
xlim(ax, [min(xv) - 0.05 * span - (span == 0), max(xv) + 0.05 * span + (span == 0)]);
xlabel(ax, sprintf('truck front-axle position x_v [%s]', U.length.unit));
ylabel(ax, sprintf('deflection [%s]', U.deflection.unit));
if isempty(uBest)
    title(ax, {'Readings and healthy model', 'markers: readings, dotted: healthy'});
else
    title(ax, {'Readings and fits', 'markers: readings, solid: fit, dotted: healthy'});   % fits a 330 px plot
end
end
