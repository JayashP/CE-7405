function groups = candidateGroups(model, regionLength)
%CANDIDATEGROUPS Contiguous candidate damage regions of about a chosen length (Stage 3).
%   GROUPS = CANDIDATEGROUPS(MODEL, REGIONLENGTH) splits the elements of
%   MODEL, from left to right, into consecutive groups for the 'Groups'
%   option of IDENTIFYSINGLEDAMAGE. A group is closed as soon as its length
%   reaches REGIONLENGTH [m] (within 1e-9 of the beam length), so groups
%   always end on nodes and may be slightly longer than REGIONLENGTH on a
%   mesh whose element lengths do not divide it. A last group shorter than
%   half of REGIONLENGTH is joined to the group before it. A REGIONLENGTH
%   shorter than every element gives one group per element.
%   GROUPS is a column cell array of element index row vectors; every
%   element appears in exactly one group.
%
%   Larger regions are more robust with few sensors and noisy data but
%   give a coarser location, and their loss d is spread over the whole
%   region (a 30 % loss over 1 m appears as a smaller loss over 2 m).
%
%   Example (2 m regions on a 20 m beam of 1 m elements: 10 pairs):
%     groups = candidateGroups(model, 2);
%
%   See also IDENTIFYSINGLEDAMAGE.

validateModel(model);
if ~(isnumeric(regionLength) && isscalar(regionLength) && isfinite(regionLength) && regionLength > 0)
    error('BridgeFE:invalidInput', 'Region length must be a positive number [m].');
end
x = model.nodes.x(:);
Le = diff(x);
tol = 1e-9 * (x(end) - x(1));
groups = cell(0, 1);
current = [];
acc = 0;
for e = 1:numel(Le)
    current(end+1) = e; %#ok<AGROW>
    acc = acc + Le(e);
    if acc >= regionLength - tol
        groups{end+1, 1} = current; %#ok<AGROW>
        current = [];
        acc = 0;
    end
end
if ~isempty(current)
    if acc < 0.5 * regionLength - tol && ~isempty(groups)
        groups{end} = [groups{end}, current];
    else
        groups{end+1, 1} = current;
    end
end
end
