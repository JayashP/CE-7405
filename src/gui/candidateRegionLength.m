function [len, items] = candidateRegionLength(label, U)
%CANDIDATEREGIONLENGTH Candidate region size chosen in the Stage 3 tab.
%   [LEN, ITEMS] = CANDIDATEREGIONLENGTH(LABEL) returns the region length
%   [m] for a drop-down LABEL (0 = each element) and the cell array ITEMS of
%   all labels. CANDIDATEREGIONLENGTH() returns LEN = [] and ITEMS.
%   [LEN, ITEMS] = CANDIDATEREGIONLENGTH(LABEL, U) uses the labels of the
%   display units U of UNITSYSTEM, LEN still in m:
%     SI  'Each element', '2 m regions', '4 m regions'    -> 0, 2, 4 m
%     US  'Each element', '6 ft regions', '12 ft regions' -> 0, 1.8288, 3.6576 m
%   CANDIDATEREGIONLENGTH([], U) returns LEN = [] and the ITEMS of U.
%
%   See also CANDIDATEGROUPS, IDENTIFICATIONOPTIONS, UNITSYSTEM.

if nargin < 2 || isempty(U)
    U = unitSystem('SI');
end
if strcmp(U.name, 'US')
    sizes = [6 12];              % ft: round numbers close to 2 m and 4 m
else
    sizes = [2 4];               % m
end
items = {'Each element', sprintf('%g %s regions', sizes(1), U.length.unit), ...
    sprintf('%g %s regions', sizes(2), U.length.unit)};
lengths = [0, sizes * U.length.toSI];
len = [];
if nargin >= 1 && ~(isnumeric(label) && isempty(label))
    k = find(strcmp(items, label));
    if isempty(k)
        error('BridgeFE:invalidInput', 'Unknown candidate region size ''%s''.', label);
    end
    len = lengths(k);
end
end
