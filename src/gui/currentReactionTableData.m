function [data, columns] = currentReactionTableData(res, model)
%CURRENTREACTIONTABLEDATA Support reactions at one vehicle position, as table text.
%   [DATA, COLUMNS] = CURRENTREACTIONTABLEDATA(RES, MODEL) returns one row
%   per support of MODEL with the reaction force [kN] (+ up) and, for fixed
%   supports, the reaction couple [kN*m] (+ counterclockwise) from the
%   result RES of ANALYZEVEHICLEPOSITION or SOLVESTATICMODEL (field R).
%
%   See also ANALYZEVEHICLEPOSITION, BRIDGECONDITIONAPP.

columns = {'Node', 'x [m]', 'Support', 'Force [kN] (+ up)', 'Couple [kN*m] (+ CCW)'};
ns = numel(model.supports.node);
data = cell(ns, numel(columns));
for s = 1:ns
    n = model.supports.node(s);
    couple = '-';
    if model.supports.restraint(s, 2)
        couple = formatNumber(res.R(2*n) / 1e3, 3);
    end
    data(s, :) = {sprintf('%d', n), sprintf('%.3f', model.nodes.x(n)), model.supports.type{s}, ...
        formatNumber(res.R(2*n - 1) / 1e3, 3), couple};   % no -0.000
end
end
