function s = formatNumber(value, decimals, signed)
%FORMATNUMBER Fixed-decimal text for a table cell, without a negative zero.
%   S = FORMATNUMBER(VALUE, DECIMALS) rounds VALUE to DECIMALS places and
%   returns it as text, e.g. formatNumber(1349.1024, 3) = '1349.102'. A value
%   that rounds to zero (round-off such as -2e-12) is shown as '0.000', not
%   '-0.000'.
%   S = FORMATNUMBER(VALUE, DECIMALS, true) adds a '+' to positive values
%   (for changes); zero is still shown without a sign. NaN gives 'n/a'.
%   Only the display is rounded; the stored results are not changed.
%
%   See also DAMAGECOMPARISONTABLEDATA, SENSITIVITYTABLEDATA.

if nargin < 3
    signed = false;
end
if isnan(value)
    s = 'n/a';
    return
end
r = round(value * 10^decimals) / 10^decimals;
if r == 0
    s = sprintf('%.*f', decimals, 0);
elseif signed
    s = sprintf('%+.*f', decimals, r);
else
    s = sprintf('%.*f', decimals, r);
end
end
