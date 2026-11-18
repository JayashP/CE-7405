function [data, columns] = criticalTableData(ml)
%CRITICALTABLEDATA Critical vehicle positions of a moving-load run, as table text.
%   [DATA, COLUMNS] = CRITICALTABLEDATA(ML) returns one row per entry of
%   ML.critical (RUNMOVINGLOAD): quantity and unit, extreme, value, the
%   coordinate x where it occurs, the front-axle position x_v that causes
%   it, the axle coordinates on the bridge at that position, and the value
%   on the coarse grid before refinement. Units: M in kN*m (+ sagging),
%   V in kN, v in mm (+ up).
%
%   See also RUNMOVINGLOAD, REACTIONENVELOPETABLEDATA.

columns = {'Quantity', 'Extreme', 'Value', 'x [m]', 'x_v [m]', 'Axles on bridge [m]', 'Coarse value'};
labels = struct('M', 'Moment M [kN*m]', 'V', 'Shear V [kN]', 'v', 'Deflection v [mm]');
scales = struct('M', 1e-3, 'V', 1e-3, 'v', 1e3);
c = ml.critical;
data = cell(numel(c), numel(columns));
for k = 1:numel(c)
    s = scales.(c(k).quantity);
    axles = strjoin(arrayfun(@(v) sprintf('%.2f', v), c(k).axleX, 'UniformOutput', false), ', ');
    if isempty(axles)
        axles = '(none)';
    end
    data(k, :) = {labels.(c(k).quantity), c(k).extreme, formatNumber(c(k).value * s, 3), ...
        formatNumber(c(k).x, 3), formatNumber(c(k).xv, 3), axles, formatNumber(c(k).coarseValue * s, 3)};   % no -0.000
end
end
