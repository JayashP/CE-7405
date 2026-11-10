function [code, items] = sensitivityQuantityCode(label)
%SENSITIVITYQUANTITYCODE Map the app's sensitivity drop-down label to a DAMAGESENSITIVITY quantity.
%   [CODE, ITEMS] = SENSITIVITYQUANTITYCODE(LABEL) returns the quantity code
%   for LABEL and the cell array ITEMS of all labels (for the drop-down).
%   SENSITIVITYQUANTITYCODE() returns CODE = '' and ITEMS.
%
%   See also DAMAGESENSITIVITY.

items = {'Largest downward deflection (vmin)', 'Largest sagging moment (Mmax)', ...
    'Largest hogging moment (Mmin)', 'Largest shear (Vmax)', 'Most negative shear (Vmin)', ...
    'Largest reaction at a support node (Rmax)'};
codes = {'vmin', 'Mmax', 'Mmin', 'Vmax', 'Vmin', 'Rmax'};
code = '';
if nargin >= 1
    k = find(strcmp(items, label));
    if isempty(k)
        error('BridgeFE:invalidInput', 'Unknown sensitivity quantity ''%s''.', label);
    end
    code = codes{k};
end
end
