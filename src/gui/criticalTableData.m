function [data, columns] = criticalTableData(ml, U)
%CRITICALTABLEDATA Critical vehicle positions of a moving-load run, as table text.
%   [DATA, COLUMNS] = CRITICALTABLEDATA(ML) returns one row per entry of
%   ML.critical (RUNMOVINGLOAD): quantity and unit, extreme, value, the
%   coordinate x where it occurs, the front-axle position x_v that causes
%   it, the axle coordinates on the bridge at that position, and the value
%   on the coarse grid before refinement. Units: M in kN*m (+ sagging),
%   V in kN, v in mm (+ up), x in m.
%   [DATA, COLUMNS] = CRITICALTABLEDATA(ML, U) shows the values in the
%   display units U of UNITSYSTEM (QUANTITYDISPLAY) and x, x_v and the axle
%   positions in U.length; the column headers name the units.
%
%   See also RUNMOVINGLOAD, REACTIONENVELOPETABLEDATA, UNITSYSTEM.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end
len = U.length;
columns = {'Quantity', 'Extreme', 'Value', sprintf('x [%s]', len.unit), sprintf('x_v [%s]', len.unit), ...
    sprintf('Axles on bridge [%s]', len.unit), 'Coarse value'};
c = ml.critical;
data = cell(numel(c), numel(columns));
for k = 1:numel(c)
    [q, extra] = quantityDisplay(c(k).quantity, U);
    s = q.scale;
    axles = strjoin(arrayfun(@(v) sprintf('%.2f', v / len.toSI), c(k).axleX, 'UniformOutput', false), ', ');
    if isempty(axles)
        axles = '(none)';
    end
    data(k, :) = {sprintf('%s [%s]', q.label, q.unit), c(k).extreme, formatNumber(c(k).value * s, 3 + extra), ...
        formatNumber(c(k).x / len.toSI, 3), formatNumber(c(k).xv / len.toSI, 3), axles, ...
        formatNumber(c(k).coarseValue * s, 3 + extra)};   % no -0.000
end
end
