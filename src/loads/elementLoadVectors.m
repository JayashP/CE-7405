function f0 = elementLoadVectors(model)
%ELEMENTLOADVECTORS Consistent load vectors of the loads acting inside each element.
%   F0 = ELEMENTLOADVECTORS(MODEL) returns an NE-by-4 matrix whose row e is
%   the consistent load vector f_e0 of element e, in element DOF order
%   [v_i theta_i v_j theta_j] and global signs (force + up, couple + CCW).
%   Member loads included:
%     - uniform load per element, model.loads.elementUDL (EQUIVALENTDISTRIBUTEDLOAD);
%     - point loads strictly inside an element, model.loads.point
%       (LOCATEPOINTLOADS, EQUIVALENTPOINTLOAD). Point loads at a node are
%       nodal loads and are added by ASSEMBLELOADVECTOR instead.
%   Rows of unloaded elements are zero.
%
%   See also EQUIVALENTDISTRIBUTEDLOAD, EQUIVALENTPOINTLOAD, LOCATEPOINTLOADS,
%   ASSEMBLELOADVECTOR, RECOVERELEMENTFORCES.

validateModel(model);
x = model.nodes.x;
conn = model.elements.conn;
w = model.loads.elementUDL;
ne = size(conn, 1);

f0 = zeros(ne, 4);
for e = find(w ~= 0).'
    Le = x(conn(e, 2)) - x(conn(e, 1));
    f0(e, :) = equivalentDistributedLoad(w(e), Le).';
end

loc = locatePointLoads(model);
for k = find(loc.element > 0).'
    e = loc.element(k);
    Le = x(conn(e, 2)) - x(conn(e, 1));
    f0(e, :) = f0(e, :) + equivalentPointLoad(loc.P(k), loc.a(k), Le).';
end
end
