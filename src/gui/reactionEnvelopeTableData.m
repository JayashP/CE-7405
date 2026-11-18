function [data, columns] = reactionEnvelopeTableData(ml, x)
%REACTIONENVELOPETABLEDATA Maximum and minimum reactions over all vehicle positions, as table text.
%   [DATA, COLUMNS] = REACTIONENVELOPETABLEDATA(ML, X) returns one row per
%   restrained DOF of the moving-load result ML (RUNMOVINGLOAD): node,
%   coordinate (from node coordinates X), component, maximum and minimum
%   value and the front-axle position x_v that causes each. Forces are in
%   kN (+ up) and couples in kN*m (+ counterclockwise).
%
%   See also RUNMOVINGLOAD, CRITICALTABLEDATA.

columns = {'Node', 'x [m]', 'Component', 'Max', 'at x_v [m]', 'Min', 'at x_v [m]'};
r = ml.reactions;
n = numel(r.dof);
data = cell(n, numel(columns));
for k = 1:n
    if strcmp(r.component{k}, 'Fv')
        label = 'force [kN]';
    else
        label = 'couple [kN*m]';
    end
    data(k, :) = {sprintf('%d', r.node(k)), sprintf('%.3f', x(r.node(k))), label, ...
        formatNumber(r.Rmax(k) / 1e3, 3), formatNumber(r.RmaxXv(k), 3), ...
        formatNumber(r.Rmin(k) / 1e3, 3), formatNumber(r.RminXv(k), 3)};   % no -0.000
end
end
