function [len, items] = candidateRegionLength(label)
%CANDIDATEREGIONLENGTH Candidate region size chosen in the Stage 3 tab.
%   [LEN, ITEMS] = CANDIDATEREGIONLENGTH(LABEL) returns the region length
%   [m] for a drop-down LABEL (0 = each element) and the cell array ITEMS of
%   all labels. CANDIDATEREGIONLENGTH() returns LEN = [] and ITEMS.
%
%   See also CANDIDATEGROUPS, IDENTIFICATIONOPTIONS.

items = {'Each element', '2 m regions', '4 m regions'};
lengths = [0 2 4];
len = [];
if nargin >= 1
    k = find(strcmp(items, label));
    if isempty(k)
        error('BridgeFE:invalidInput', 'Unknown candidate region size ''%s''.', label);
    end
    len = lengths(k);
end
end
