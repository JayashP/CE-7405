function [data, columns] = sensitivityTableData(s, model, U)
%SENSITIVITYTABLEDATA Ranked damage-location sensitivity, as table text.
%   [DATA, COLUMNS] = SENSITIVITYTABLEDATA(S, MODEL) lists the groups of
%   DAMAGESENSITIVITY result S in rank order (largest |change| first), with
%   their element range, coordinates [m], value with the loss, change from
%   the healthy value and signed percentage (QUANTITYDISPLAY units).
%   [DATA, COLUMNS] = SENSITIVITYTABLEDATA(S, MODEL, U) shows the
%   coordinates in U.length and the values in the display units U of
%   UNITSYSTEM (QUANTITYDISPLAY); the column headers name the units.
%
%   See also DAMAGESENSITIVITY, PLOTSENSITIVITY, UNITSYSTEM.

if nargin < 3 || isempty(U)
    U = unitSystem('SI');
end
q = quantityDisplay(s.quantity, U);
columns = {'Rank', 'Elements', sprintf('x [%s]', U.length.unit), sprintf('%s [%s]', s.quantity, q.unit), 'Change', ...
    'Change [%]'};
x = model.nodes.x / U.length.toSI;
n = numel(s.rank);
data = cell(n, numel(columns));
for k = 1:n
    g = s.rank(k);
    els = s.groups{g};
    pct = 'n/a (healthy = 0)';
    if ~isnan(s.pctChange(g))
        pct = formatNumber(s.pctChange(g), 2, true);
    end
    elementText = sprintf('%d-%d', min(els), max(els));
    if min(els) == max(els)
        elementText = sprintf('%d', els);
    end
    data(k, :) = {sprintf('%d', k), elementText, sprintf('%g-%g', x(min(els)), x(max(els) + 1)), ...
        formatNumber(s.values(g) * q.scale, 4), formatNumber(s.change(g) * q.scale, 4, true), pct};
end
end
