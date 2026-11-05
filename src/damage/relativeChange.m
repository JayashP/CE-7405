function pct = relativeChange(healthy, damaged, scale)
%RELATIVECHANGE Percentage change from healthy to damaged, undefined for a zero healthy value.
%   PCT = RELATIVECHANGE(HEALTHY, DAMAGED, SCALE) returns
%       100 * (DAMAGED - HEALTHY) ./ |HEALTHY|
%   element by element (PROJECT_SPEC.md section 6). Where the healthy value
%   is zero, a percentage would be misleading, so PCT is NaN there and the
%   absolute difference DAMAGED - HEALTHY should be reported instead. A
%   healthy value counts as zero when |HEALTHY| <= 1e-9 * SCALE, where SCALE
%   is the characteristic magnitude of the quantity (round-off level).
%   The formula is signed, as in the spec: for a negative quantity such as
%   a downward deflection, a NEGATIVE percentage means a LARGER magnitude
%   (e.g. -24.9 mm -> -30.8 mm is -23.7 %).
%
%   See also COMPAREHEALTHYDAMAGED, DAMAGESENSITIVITY.

pct = 100 * (damaged - healthy) ./ abs(healthy);
pct(abs(healthy) <= 1e-9 * scale) = NaN;
end
