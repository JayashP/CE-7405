function [freeDofs, restrainedDofs] = partitionDofs(model)
%PARTITIONDOFS Split global DOFs into free and restrained sets and check stability.
%   [FREE, RESTRAINED] = PARTITIONDOFS(MODEL) returns sorted column vectors
%   of global DOF indices (node n: v -> 2n-1, theta -> 2n). Restrained DOFs
%   have zero prescribed displacement, so the reduced system is
%   Kff*Uf = Ff. No penalty numbers or row/column zeroing are used.
%
%   Kinematic stability check (exact for this model): one continuous beam
%   with EI > 0 in every element has exactly two rigid-body modes,
%   vertical translation (v = 1, theta = 0) and rigid rotation
%   (v = x - x0, theta = 1). The supports suppress both if and only if
%     (a) v is restrained at two or more distinct nodes, or
%     (b) v is restrained at one or more nodes AND theta is restrained at
%         one or more nodes.
%   Otherwise Kff is singular, and 'BridgeFE:underRestrained' is thrown
%   with a message that names the free rigid-body mode.
%
%   See also ADDSUPPORT, SOLVESTATICMODEL.

validateModel(model);
nn = numel(model.nodes.x);

restrained = false(2 * nn, 1);
for s = 1:numel(model.supports.node)
    n = model.supports.node(s);
    restrained(2*n - 1) = model.supports.restraint(s, 1);
    restrained(2*n)     = model.supports.restraint(s, 2);
end

vRestrainedNodes = find(restrained(1:2:end));
nThetaRestrained = nnz(restrained(2:2:end));
if isempty(vRestrainedNodes)
    error('BridgeFE:underRestrained', ...
        ['Under-restrained model: no vertical displacement is restrained, so rigid-body ' ...
         'vertical translation is free. Add two pin/roller supports or one fixed support.']);
elseif numel(vRestrainedNodes) == 1 && nThetaRestrained == 0
    n = vRestrainedNodes(1);
    error('BridgeFE:underRestrained', ...
        ['Under-restrained model: only node %d (x = %g m) restrains v and no rotation is ' ...
         'restrained, so rigid-body rotation about that node is free. Add a second ' ...
         'pin/roller support or make a support fixed.'], n, model.nodes.x(n));
end

freeDofs = find(~restrained);
restrainedDofs = find(restrained);
end
