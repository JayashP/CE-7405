function values = parseNumberList(text, name)
%PARSENUMBERLIST Numbers typed in an app text field, e.g. '20 20' or '80, 120, 120'.
%   VALUES = PARSENUMBERLIST(TEXT, NAME) returns the row vector of numbers
%   in TEXT, separated by spaces, commas or semicolons. TEXT is read with
%   STR2DOUBLE (no code is evaluated). A numeric TEXT is accepted as is.
%   An empty field, or any entry that is not a real, finite number, throws
%   'BridgeFE:invalidInput' with a message naming NAME.
%
%   See also BUILDMODELFROMINPUTS, VEHICLEFROMINPUTS.

if isa(text, 'string') && isscalar(text)
    text = char(text);
end
if isnumeric(text)
    values = double(text(:).');
    if isempty(values) || ~isreal(values) || any(~isfinite(values))
        error('BridgeFE:invalidInput', '%s must contain real, finite numbers.', name);
    end
    return
end
if ~ischar(text)
    error('BridgeFE:invalidInput', '%s must be typed as numbers separated by spaces or commas.', name);
end
tokens = regexp(strtrim(text), '[\s,;]+', 'split');
tokens = tokens(~cellfun(@isempty, tokens));
if isempty(tokens)
    error('BridgeFE:invalidInput', '%s is empty.', name);
end
values = zeros(1, numel(tokens));
for k = 1:numel(tokens)
    v = str2double(tokens{k});
    if ~(isreal(v) && isfinite(v))
        error('BridgeFE:invalidInput', '"%s" in %s is not a real, finite number.', tokens{k}, name);
    end
    values(k) = v;
end
end
