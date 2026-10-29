function assertIntegerScalarInRange(value, name, lo, hi)
%ASSERTINTEGERSCALARINRANGE Error unless VALUE is an integer-valued scalar in [LO, HI].
%   ASSERTINTEGERSCALARINRANGE(VALUE, NAME, LO, HI) returns silently for a
%   valid VALUE and otherwise throws 'BridgeFE:invalidInput' naming the
%   argument NAME. Use HI = Inf for no upper bound.

if ~(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value) ...
        && value == round(value) && value >= lo && value <= hi)
    if isinf(hi)
        error('BridgeFE:invalidInput', ...
            '%s must be an integer scalar >= %d.', name, lo);
    else
        error('BridgeFE:invalidInput', ...
            '%s must be an integer scalar between %d and %d.', name, lo, hi);
    end
end
end
