function [data, columns] = damageComparisonTableData(cmp)
%DAMAGECOMPARISONTABLEDATA Healthy vs damaged extremes and reactions, as table text.
%   [DATA, COLUMNS] = DAMAGECOMPARISONTABLEDATA(CMP) turns the result of
%   COMPAREHEALTHYDAMAGED into rows: the six global extremes (M, V, v,
%   max/min), then the maximum and minimum vertical reaction of each
%   support. Values are in kN*m, kN or mm (QUANTITYDISPLAY), rounded by
%   FORMATNUMBER (round-off shows as 0.000, never -0.000). The percentage
%   is signed (spec section 6); where the healthy value is zero it reads
%   'n/a (healthy = 0)' and only the absolute change applies. For negative
%   quantities (downward deflection, hogging moment) a negative percentage
%   means a larger magnitude.
%
%   See also COMPAREHEALTHYDAMAGED, RELATIVECHANGE.

columns = {'Quantity', 'Healthy', 'Damaged', 'Change', 'Change [%]'};
data = cell(0, 5);
for k = 1:numel(cmp.critical)
    c = cmp.critical(k);
    q = quantityDisplay(c.quantity);
    data(end+1, :) = {sprintf('%s %s [%s]', q.label, c.extreme, q.unit), formatNumber(c.healthy * q.scale, 3), ...
        formatNumber(c.damaged * q.scale, 3), formatNumber(c.change * q.scale, 3, true), percentText(c.pctChange)}; %#ok<AGROW>
end
for k = 1:numel(cmp.reactions)
    r = cmp.reactions(k);
    if ~strcmp(r.component, 'Fv')
        continue
    end
    data(end+1, :) = {sprintf('Reaction at node %d max [kN]', r.node), formatNumber(r.healthyMax / 1e3, 3), ...
        formatNumber(r.damagedMax / 1e3, 3), formatNumber(r.changeMax / 1e3, 3, true), percentText(r.pctChangeMax)}; %#ok<AGROW>
    data(end+1, :) = {sprintf('Reaction at node %d min [kN]', r.node), formatNumber(r.healthyMin / 1e3, 3), ...
        formatNumber(r.damagedMin / 1e3, 3), formatNumber(r.changeMin / 1e3, 3, true), percentText(r.pctChangeMin)}; %#ok<AGROW>
end
end

function s = percentText(p)
if isnan(p)
    s = 'n/a (healthy = 0)';
else
    s = formatNumber(p, 2, true);
end
end
