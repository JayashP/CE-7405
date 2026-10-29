function loc = locatePointLoads(model)
%LOCATEPOINTLOADS Node or element that carries each point load of the model.
%   LOC = LOCATEPOINTLOADS(MODEL) resolves every row [x Fv] of
%   model.loads.point (DECISIONS.md D-017):
%     - within 1e-9 times the beam length of a node -> applied AT that node
%       (identical to a nodal force there; this tolerance only absorbs
%       round-off and is not a snap to the nearest node);
%     - otherwise -> inside the element e with x_e < x < x_e+1, at local
%       distance a = x - x_e from its left node.
%   LOC fields (NP-by-1 columns):
%     x        load coordinate [m]
%     P        load value [N] (+ up)
%     node     node index if applied at a node, else 0
%     element  element index if applied inside an element, else 0
%     a        distance from the element's left node [m] (0 when at a node)
%
%   See also ADDPOINTLOAD, ELEMENTLOADVECTORS, ASSEMBLELOADVECTOR.

validateModel(model);
x = model.nodes.x;
loads = model.loads.point;
np = size(loads, 1);
tol = 1e-9 * (x(end) - x(1));

loc.x = loads(:, 1);
loc.P = loads(:, 2);
loc.node = zeros(np, 1);
loc.element = zeros(np, 1);
loc.a = zeros(np, 1);
for k = 1:np
    [gap, n] = min(abs(x - loc.x(k)));
    if gap <= tol
        loc.node(k) = n;
    else
        e = find(x(1:end-1) < loc.x(k), 1, 'last');
        loc.element(k) = e;
        loc.a(k) = loc.x(k) - x(e);
    end
end
end
