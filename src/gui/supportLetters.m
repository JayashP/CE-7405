function letters = supportLetters(n)
%SUPPORTLETTERS Names of the span ends (supports): A, B, ..., Z, AA, AB, ...
%   LETTERS = SUPPORTLETTERS(N) returns a 1-by-N cellstr naming the span
%   ends from the left: 'A' to 'Z', then 'AA', 'AB', ..., 'AZ', 'BA', ...,
%   'ZZ', 'AAA', ... (spreadsheet-column style). The app uses these names
%   in the support table, in the model summary and below the span ends of
%   the drawing. N is an integer >= 0; N = 0 gives a 1-by-0 cell.
%
%   Example (three spans, four span ends):
%     supportLetters(4)           % {'A', 'B', 'C', 'D'}
%
%   See also SUPPORTTYPELIST, BUILDMODELFROMTABLES, BRIDGEDRAWING.

assertIntegerScalarInRange(n, 'Number of support letters', 0, Inf);
letters = cell(1, n);
for k = 1:n
    m = k;
    name = '';
    while m > 0
        r = mod(m - 1, 26);                  % 0 -> 'A', ..., 25 -> 'Z'
        name = [char('A' + r), name]; %#ok<AGROW>
        m = (m - 1 - r) / 26;
    end
    letters{k} = name;
end
end
