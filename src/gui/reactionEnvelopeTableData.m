function [data, columns] = reactionEnvelopeTableData(ml, x, U)
%REACTIONENVELOPETABLEDATA Maximum and minimum reactions over all vehicle positions, as table text.
%   [DATA, COLUMNS] = REACTIONENVELOPETABLEDATA(ML, X) returns one row per
%   restrained DOF of the moving-load result ML (RUNMOVINGLOAD): node,
%   coordinate (from node coordinates X [m]), component, maximum and minimum
%   value and the front-axle position x_v that causes each. Forces are in
%   kN (+ up), couples in kN*m (+ counterclockwise), x and x_v in m.
%   [DATA, COLUMNS] = REACTIONENVELOPETABLEDATA(ML, X, U) shows forces in
%   U.force, couples in U.moment and x, x_v in U.length (display units U of
%   UNITSYSTEM; X stays in m); the column headers and components name the
%   units.
%
%   See also RUNMOVINGLOAD, CRITICALTABLEDATA, UNITSYSTEM.

if nargin < 3 || isempty(U)
    U = unitSystem('SI');
end
len = U.length;
columns = {'Node', sprintf('x [%s]', len.unit), 'Component', 'Max', sprintf('at x_v [%s]', len.unit), 'Min', ...
    sprintf('at x_v [%s]', len.unit)};
r = ml.reactions;
n = numel(r.dof);
data = cell(n, numel(columns));
for k = 1:n
    if strcmp(r.component{k}, 'Fv')
        u = U.force;
        label = sprintf('force [%s]', u.unit);
    else
        u = U.moment;
        label = sprintf('couple [%s]', u.unit);
    end
    data(k, :) = {sprintf('%d', r.node(k)), sprintf('%.3f', x(r.node(k)) / len.toSI), label, ...
        formatNumber(r.Rmax(k) / u.toSI, 3), formatNumber(r.RmaxXv(k) / len.toSI, 3), ...
        formatNumber(r.Rmin(k) / u.toSI, 3), formatNumber(r.RminXv(k) / len.toSI, 3)};   % no -0.000
end
end
