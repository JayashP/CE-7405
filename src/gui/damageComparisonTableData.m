function [data, columns] = damageComparisonTableData(cmp, U)
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
%   [DATA, COLUMNS] = DAMAGECOMPARISONTABLEDATA(CMP, U) shows the extremes
%   in the display units U of UNITSYSTEM (QUANTITYDISPLAY) and the
%   reactions in U.force; the row labels name the units. Percentages do not
%   depend on U.
%
%   See also COMPAREHEALTHYDAMAGED, RELATIVECHANGE, UNITSYSTEM.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end
force = U.force;
columns = {'Quantity', 'Healthy', 'Damaged', 'Change', 'Change [%]'};
data = cell(0, 5);
for k = 1:numel(cmp.critical)
    c = cmp.critical(k);
    [q, extra] = quantityDisplay(c.quantity, U);
    data(end+1, :) = {sprintf('%s %s [%s]', q.label, c.extreme, q.unit), formatNumber(c.healthy * q.scale, 3 + extra), ...
        formatNumber(c.damaged * q.scale, 3 + extra), formatNumber(c.change * q.scale, 3 + extra, true), ...
        percentText(c.pctChange)}; %#ok<AGROW>
end
for k = 1:numel(cmp.reactions)
    r = cmp.reactions(k);
    if ~strcmp(r.component, 'Fv')
        continue
    end
    data(end+1, :) = {sprintf('Reaction at node %d max [%s]', r.node, force.unit), formatNumber(r.healthyMax / force.toSI, 3), ...
        formatNumber(r.damagedMax / force.toSI, 3), formatNumber(r.changeMax / force.toSI, 3, true), ...
        percentText(r.pctChangeMax)}; %#ok<AGROW>
    data(end+1, :) = {sprintf('Reaction at node %d min [%s]', r.node, force.unit), formatNumber(r.healthyMin / force.toSI, 3), ...
        formatNumber(r.damagedMin / force.toSI, 3), formatNumber(r.changeMin / force.toSI, 3, true), ...
        percentText(r.pctChangeMin)}; %#ok<AGROW>
end
end

function s = percentText(p)
if isnan(p)
    s = 'n/a (healthy = 0)';
else
    s = formatNumber(p, 2, true);
end
end
