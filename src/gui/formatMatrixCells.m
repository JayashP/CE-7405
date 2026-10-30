function cells = formatMatrixCells(A, fmt)
%FORMATMATRIXCELLS Numeric matrix as a cell array of formatted strings for tables.
%   CELLS = FORMATMATRIXCELLS(A, FMT) returns a cell array the size of A with
%   every entry printed by SPRINTF(FMT, value) (default '%.4g'). Exact zeros
%   are shown as '0'.
%
%   See also BRIDGECONDITIONAPP.

if nargin < 2
    fmt = '%.4g';
end
A = full(double(A));
cells = cell(size(A));
for k = 1:numel(A)
    if A(k) == 0
        cells{k} = '0';
    else
        cells{k} = sprintf(fmt, A(k));
    end
end
end
