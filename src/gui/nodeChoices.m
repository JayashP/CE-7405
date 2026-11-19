function [labels, xSI] = nodeChoices(model, U)
%NODECHOICES Node labels and coordinates for the app's region drop-downs.
%   [LABELS, XSI] = NODECHOICES(MODEL) returns one entry per node of MODEL:
%   LABELS{k} = 'node k (x = 7.5 m)' (coordinate with %g) and XSI(k) the
%   node coordinate [m], both 1-by-NN (drop-down Items and ItemsData).
%   [LABELS, XSI] = NODECHOICES(MODEL, U) writes the coordinates in the
%   labels in U.length (display units U of UNITSYSTEM, e.g.
%   'node 7 (x = 24.6063 ft)'); XSI stays in m.
%
%   See also UNITSYSTEM, DAMAGEMODELFROMINPUTS, FINDNODEATX.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end
xSI = model.nodes.x(:)';
labels = arrayfun(@(k) sprintf('node %d (x = %g %s)', k, xSI(k) / U.length.toSI, U.length.unit), ...
    1:numel(xSI), 'UniformOutput', false);
end
