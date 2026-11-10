function [data, columns] = sensitivityTableData(s, model)
%SENSITIVITYTABLEDATA Ranked damage-location sensitivity, as table text.
%   [DATA, COLUMNS] = SENSITIVITYTABLEDATA(S, MODEL) lists the groups of
%   DAMAGESENSITIVITY result S in rank order (largest |change| first), with
%   their element range, coordinates, value with the loss, change from the
%   healthy value and signed percentage (QUANTITYDISPLAY units).
%
%   See also DAMAGESENSITIVITY.

q = quantityDisplay(s.quantity);
columns = {'Rank', 'Elements', 'x [m]', sprintf('%s [%s]', s.quantity, q.unit), 'Change', 'Change [%]'};
x = model.nodes.x;
n = numel(s.rank);
data = cell(n, numel(columns));
for k = 1:n
    g = s.rank(k);
    els = s.groups{g};
    pct = 'n/a (healthy = 0)';
    if ~isnan(s.pctChange(g))
        pct = sprintf('%+.2f', s.pctChange(g));
    end
    data(k, :) = {sprintf('%d', k), sprintf('%d-%d', min(els), max(els)), sprintf('%g-%g', x(min(els)), x(max(els) + 1)), ...
        sprintf('%.4f', s.values(g) * q.scale), sprintf('%+.4f', s.change(g) * q.scale), pct};
end
end
