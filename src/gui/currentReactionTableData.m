function [data, columns] = currentReactionTableData(res, model, U)
%CURRENTREACTIONTABLEDATA Support reactions at one vehicle position, as table text.
%   [DATA, COLUMNS] = CURRENTREACTIONTABLEDATA(RES, MODEL) returns one row
%   per support of MODEL with the reaction force [kN] (+ up) and, for fixed
%   supports, the reaction couple [kN*m] (+ counterclockwise) from the
%   result RES of ANALYZEVEHICLEPOSITION or SOLVESTATICMODEL (field R);
%   support coordinates x in m.
%   [DATA, COLUMNS] = CURRENTREACTIONTABLEDATA(RES, MODEL, U) shows forces
%   in U.force, couples in U.moment and x in U.length (display units U of
%   UNITSYSTEM); the column headers name the units.
%
%   See also ANALYZEVEHICLEPOSITION, BRIDGECONDITIONAPP, UNITSYSTEM.

if nargin < 3 || isempty(U)
    U = unitSystem('SI');
end
columns = {'Node', sprintf('x [%s]', U.length.unit), 'Support', sprintf('Force [%s] (+ up)', U.force.unit), ...
    sprintf('Couple [%s] (+ CCW)', U.moment.unit)};
ns = numel(model.supports.node);
data = cell(ns, numel(columns));
for s = 1:ns
    n = model.supports.node(s);
    couple = '-';
    if model.supports.restraint(s, 2)
        couple = formatNumber(res.R(2*n) / U.moment.toSI, 3);
    end
    data(s, :) = {sprintf('%d', n), sprintf('%.3f', model.nodes.x(n) / U.length.toSI), model.supports.type{s}, ...
        formatNumber(res.R(2*n - 1) / U.force.toSI, 3), couple};   % no -0.000
end
end
