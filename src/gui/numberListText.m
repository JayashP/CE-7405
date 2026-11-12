function text = numberListText(values)
%NUMBERLISTTEXT Numbers as the space-separated text used in the app's list fields.
%   TEXT = NUMBERLISTTEXT(VALUES) returns e.g. '5 10 15' (format %g), the
%   inverse of PARSENUMBERLIST for display.
%
%   See also PARSENUMBERLIST.

text = strjoin(arrayfun(@(v) sprintf('%g', v), values(:)', 'UniformOutput', false), ' ');
end
